import assert from 'node:assert/strict';
import {test} from 'node:test';

import {createWorker} from '../src/worker.mjs';

class MemoryKv {
  constructor() {
    this.values = new Map();
  }

  async get(key, type) {
    const raw = this.values.get(key);
    if (raw === undefined) return null;
    return type === 'json' ? JSON.parse(raw) : raw;
  }

  async put(key, value) {
    this.values.set(key, value);
  }

  async delete(key) {
    this.values.delete(key);
  }
}

function environment() {
  return {
    OTP_CHALLENGES: new MemoryKv(),
    OTP_RATE_LIMITS: new MemoryKv(),
    OTP_HMAC_SECRET: 'test-only-secret-at-least-32-characters',
    WHATSAPP_ACCESS_TOKEN: 'test-meta-token',
    WHATSAPP_PHONE_NUMBER_ID: '123456789',
    WHATSAPP_AUTH_TEMPLATE: 'voltmapev_authentication',
    WHATSAPP_GRAPH_API_VERSION: 'v23.0',
    WHATSAPP_TEMPLATE_LANGUAGE: 'en',
    OTP_PILOT_MODE: 'true',
    WHATSAPP_PILOT_ALLOWLIST: '919000000001',
    RESEND_API_KEY: 'test-email-token',
    OTP_FROM_EMAIL: 'VoltMapEV <verify@voltmapev.com>',
  };
}

function jsonRequest(path, body, headers = {}) {
  return new Request(`https://api.voltmapev.com${path}`, {
    method: 'POST',
    headers: {'content-type': 'application/json', ...headers},
    body: JSON.stringify(body),
  });
}

test('sends a WhatsApp authentication template without exposing the OTP', async () => {
  const env = environment();
  let providerBody;
  const worker = createWorker({
    fetchImpl: async (_url, init) => {
      providerBody = JSON.parse(init.body);
      return new Response(JSON.stringify({messages: [{id: 'wamid.1'}]}), {
        status: 200,
      });
    },
  });

  const response = await worker.fetch(
    jsonRequest('/v1/identity/otp/challenges', {
      channel: 'whatsapp',
      destination: '9000000001',
      purpose: 'account_sign_in',
    }),
    env,
  );
  const body = await response.json();
  const sentCode = providerBody.template.components[0].parameters[0].text;

  assert.equal(response.status, 201);
  assert.equal(body.destination, '9000000001');
  assert.equal(providerBody.messaging_product, 'whatsapp');
  assert.equal(providerBody.to, '919000000001');
  assert.match(sentCode, /^\d{6}$/);
  assert.equal(JSON.stringify(body).includes(sentCode), false);
  const stored = await env.OTP_CHALLENGES.get(
    `challenge:${body.challengeId}`,
    'json',
  );
  assert.equal(JSON.stringify(stored).includes(sentCode), false);

  const verified = await worker.fetch(
    jsonRequest(
      `/v1/identity/otp/challenges/${body.challengeId}/verify`,
      {code: sentCode},
    ),
    env,
  );
  const verifiedBody = await verified.json();
  assert.equal(verified.status, 200);
  assert.equal(verifiedBody.verified, true);
  assert.match(verifiedBody.verifiedContactToken, /^v1\.[^.]+\.[^.]+$/);
  assert.equal(verifiedBody.destination, '+91 ••••••0001');
  assert.equal(
    await env.OTP_CHALLENGES.get(`challenge:${body.challengeId}`),
    null,
  );
});

test('rejects legacy SMS requests and invalid India numbers', async () => {
  const worker = createWorker({fetchImpl: async () => new Response('{}')});
  const env = environment();

  const sms = await worker.fetch(
    jsonRequest('/v1/identity/otp/challenges', {
      channel: 'sms',
      destination: '9000000001',
      purpose: 'account_sign_in',
    }),
    env,
  );
  assert.equal(sms.status, 400);
  assert.equal((await sms.json()).code, 'unsupported_otp_channel');

  const invalid = await worker.fetch(
    jsonRequest('/v1/identity/otp/challenges', {
      channel: 'whatsapp',
      destination: '12345',
      purpose: 'account_sign_in',
    }),
    env,
  );
  assert.equal(invalid.status, 400);
  assert.equal((await invalid.json()).code, 'invalid_phone');
});

test('production pilot rejects every non-allowlisted WhatsApp number', async () => {
  let called = false;
  const worker = createWorker({
    fetchImpl: async () => {
      called = true;
      return new Response('{}', {status: 200});
    },
  });
  const response = await worker.fetch(
    jsonRequest('/v1/identity/otp/challenges', {
      channel: 'whatsapp',
      destination: '9876543210',
      purpose: 'account_sign_in',
    }),
    environment(),
  );

  assert.equal(response.status, 403);
  assert.equal(
    (await response.json()).code,
    'whatsapp_pilot_destination_not_allowed',
  );
  assert.equal(called, false);
});

test('production pilot fails closed when its allowlist secret is missing', async () => {
  let called = false;
  const worker = createWorker({
    fetchImpl: async () => {
      called = true;
      return new Response('{}', {status: 200});
    },
  });
  const env = environment();
  delete env.WHATSAPP_PILOT_ALLOWLIST;
  const response = await worker.fetch(
    jsonRequest('/v1/identity/otp/challenges', {
      channel: 'whatsapp',
      destination: '9000000001',
      purpose: 'account_sign_in',
    }),
    env,
  );

  assert.equal(response.status, 503);
  assert.equal((await response.json()).code, 'whatsapp_pilot_not_configured');
  assert.equal(called, false);
});

test('enforces resend delay without sending a second message', async () => {
  const env = environment();
  let sends = 0;
  const worker = createWorker({
    fetchImpl: async () => {
      sends += 1;
      return new Response('{}', {status: 200});
    },
  });
  const payload = {
    channel: 'whatsapp',
    destination: '9000000001',
    purpose: 'account_sign_in',
  };

  const first = await worker.fetch(
    jsonRequest('/v1/identity/otp/challenges', payload),
    env,
  );
  const second = await worker.fetch(
    jsonRequest('/v1/identity/otp/challenges', payload),
    env,
  );

  assert.equal(first.status, 201);
  assert.equal(second.status, 429);
  assert.equal((await second.json()).code, 'otp_resend_too_soon');
  assert.equal(sends, 1);
});

test('decrements attempts and never accepts an incorrect code', async () => {
  const env = environment();
  const worker = createWorker({
    fetchImpl: async () => new Response('{}', {status: 200}),
  });
  const created = await worker.fetch(
    jsonRequest('/v1/identity/otp/challenges', {
      channel: 'whatsapp',
      destination: '9000000001',
      purpose: 'account_sign_in',
    }),
    env,
  );
  const challenge = await created.json();
  const failed = await worker.fetch(
    jsonRequest(
      `/v1/identity/otp/challenges/${challenge.challengeId}/verify`,
      {code: '999999'},
    ),
    env,
  );
  const failedBody = await failed.json();

  assert.equal(failed.status, 401);
  assert.equal(failedBody.code, 'otp_incorrect');
  assert.equal(failedBody.attemptsRemaining, 4);
});

test('fails closed before provider calls when secrets are missing', async () => {
  let called = false;
  const worker = createWorker({
    fetchImpl: async () => {
      called = true;
      return new Response('{}');
    },
  });
  const env = environment();
  delete env.WHATSAPP_ACCESS_TOKEN;
  const response = await worker.fetch(
    jsonRequest('/v1/identity/otp/challenges', {
      channel: 'whatsapp',
      destination: '9000000001',
      purpose: 'account_sign_in',
    }),
    env,
  );

  assert.equal(response.status, 503);
  assert.equal(called, false);
});

test('supports verified email destinations for payment receipts', async () => {
  const env = environment();
  let providerBody;
  const worker = createWorker({
    fetchImpl: async (_url, init) => {
      providerBody = JSON.parse(init.body);
      return new Response('{}', {status: 200});
    },
  });
  const response = await worker.fetch(
    jsonRequest('/v1/identity/otp/challenges', {
      channel: 'email',
      destination: 'Driver@Example.com',
      purpose: 'charging_receipt',
    }),
    env,
  );

  assert.equal(response.status, 201);
  assert.deepEqual(providerBody.to, ['driver@example.com']);
  assert.equal((await response.json()).destination, 'driver@example.com');
});

test('allows only configured website origins', async () => {
  const worker = createWorker();
  const response = await worker.fetch(
    new Request('https://api.voltmapev.com/health', {
      headers: {origin: 'https://attacker.example'},
    }),
    environment(),
  );
  assert.equal(response.status, 403);
  assert.equal(response.headers.get('access-control-allow-origin'), null);
});
