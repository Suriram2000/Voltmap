const OTP_TTL_SECONDS = 300;
const RESEND_DELAY_SECONDS = 30;
const MAX_VERIFY_ATTEMPTS = 5;
const MAX_SENDS_PER_DESTINATION_HOUR = 5;
const MAX_SENDS_PER_IP_HOUR = 20;
const CONTACT_TOKEN_TTL_SECONDS = 86400;
const ALLOWED_PURPOSES = new Set(['account_sign_in', 'charging_receipt']);
const ALLOWED_CHANNELS = new Set(['whatsapp', 'email']);

class ApiError extends Error {
  constructor(status, code, message, extra = {}) {
    super(message);
    this.status = status;
    this.code = code;
    this.extra = extra;
  }
}

export function createWorker({fetchImpl = globalThis.fetch} = {}) {
  return {
    async fetch(request, env) {
      const origin = request.headers.get('origin');
      try {
        assertAllowedOrigin(origin, env);
        if (request.method === 'OPTIONS') {
          return response(null, 204, origin, env);
        }

        const url = new URL(request.url);
        if (request.method === 'GET' && url.pathname === '/health') {
          return response(
            {
              status: 'ok',
              service: 'voltmapev-identity',
              otpChannels: ['whatsapp', 'email'],
              pilotMode: isPilotMode(env),
              ready: isConfigured(env),
            },
            200,
            origin,
            env,
          );
        }

        if (
          request.method === 'POST' &&
          url.pathname === '/v1/identity/otp/challenges'
        ) {
          return await createChallenge(request, env, fetchImpl, origin);
        }

        const verifyMatch = url.pathname.match(
          /^\/v1\/identity\/otp\/challenges\/([0-9a-f-]{36})\/verify$/i,
        );
        if (request.method === 'POST' && verifyMatch) {
          return await verifyChallenge(
            request,
            env,
            verifyMatch[1],
            origin,
          );
        }

        throw new ApiError(404, 'not_found', 'Endpoint not found.');
      } catch (error) {
        const safe = error instanceof ApiError
          ? error
          : new ApiError(
              500,
              'identity_internal_error',
              'The verification service could not complete the request.',
            );
        return response(
          {code: safe.code, message: safe.message, ...safe.extra},
          safe.status,
          origin,
          env,
        );
      }
    },
  };
}

async function createChallenge(request, env, fetchImpl, origin) {
  assertStorageConfigured(env);
  const body = await readJson(request);
  const channel = String(body.channel ?? '').toLowerCase();
  const purpose = String(body.purpose ?? '');
  if (!ALLOWED_CHANNELS.has(channel)) {
    throw new ApiError(
      400,
      'unsupported_otp_channel',
      'Use WhatsApp or email verification.',
    );
  }
  if (!ALLOWED_PURPOSES.has(purpose)) {
    throw new ApiError(400, 'invalid_otp_purpose', 'Invalid OTP purpose.');
  }
  assertChannelConfigured(env, channel);

  const destination = normalizeDestination(channel, body.destination);
  assertPilotDestinationAllowed(channel, destination, env);
  const destinationKey = await sha256Hex(`${channel}:${destination}`);
  const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
  const ipKey = await sha256Hex(ip);
  const now = Date.now();

  await enforceRateLimit(
    env.OTP_RATE_LIMITS,
    `destination:${destinationKey}`,
    MAX_SENDS_PER_DESTINATION_HOUR,
    3600,
    now,
  );
  await enforceRateLimit(
    env.OTP_RATE_LIMITS,
    `ip:${ipKey}`,
    MAX_SENDS_PER_IP_HOUR,
    3600,
    now,
  );

  const activeKey = `active:${destinationKey}:${purpose}`;
  const activeChallengeId = await env.OTP_CHALLENGES.get(activeKey);
  if (activeChallengeId) {
    const active = await readChallenge(env, activeChallengeId);
    if (active && now < active.resendAt) {
      const retryAfterSeconds = Math.max(
        1,
        Math.ceil((active.resendAt - now) / 1000),
      );
      throw new ApiError(
        429,
        'otp_resend_too_soon',
        `Wait ${retryAfterSeconds} seconds before requesting another code.`,
        {retryAfterSeconds, attemptsRemaining: active.attemptsRemaining},
      );
    }
  }

  const id = crypto.randomUUID();
  const otp = secureSixDigitCode();
  const salt = randomBase64Url(16);
  const expiresAt = now + OTP_TTL_SECONDS * 1000;
  const resendAt = now + RESEND_DELAY_SECONDS * 1000;
  const challenge = {
    id,
    channel,
    destination,
    purpose,
    otpDigest: await hmacHex(env.OTP_HMAC_SECRET, `${id}:${salt}:${otp}`),
    salt,
    expiresAt,
    resendAt,
    attemptsRemaining: MAX_VERIFY_ATTEMPTS,
  };

  await env.OTP_CHALLENGES.put(`challenge:${id}`, JSON.stringify(challenge), {
    expirationTtl: OTP_TTL_SECONDS,
  });
  await env.OTP_CHALLENGES.put(activeKey, id, {
    expirationTtl: OTP_TTL_SECONDS,
  });

  try {
    await sendProviderOtp(channel, destination, otp, env, fetchImpl);
  } catch (error) {
    await Promise.all([
      env.OTP_CHALLENGES.delete(`challenge:${id}`),
      env.OTP_CHALLENGES.delete(activeKey),
    ]);
    if (error instanceof ApiError) throw error;
    throw new ApiError(
      502,
      'otp_delivery_failed',
      'The verification message could not be delivered. Try again.',
    );
  }

  return response(
    {
      challengeId: id,
      destination: clientDestination(channel, destination),
      expiresAt: new Date(expiresAt).toISOString(),
      resendAt: new Date(resendAt).toISOString(),
      attemptsRemaining: MAX_VERIFY_ATTEMPTS,
    },
    201,
    origin,
    env,
  );
}

async function verifyChallenge(request, env, challengeId, origin) {
  assertStorageConfigured(env);
  const body = await readJson(request);
  const code = String(body.code ?? '').trim();
  if (!/^\d{6}$/.test(code)) {
    throw new ApiError(
      400,
      'invalid_otp_format',
      'Enter the complete 6-digit verification code.',
    );
  }

  const challenge = await readChallenge(env, challengeId);
  if (!challenge) {
    throw new ApiError(
      404,
      'otp_challenge_not_found',
      'That verification challenge is no longer available.',
    );
  }
  if (Date.now() >= challenge.expiresAt) {
    await deleteChallenge(env, challenge);
    throw new ApiError(
      410,
      'otp_expired',
      'That verification code expired. Request a new code.',
      {attemptsRemaining: challenge.attemptsRemaining},
    );
  }

  const actual = await hmacHex(
    env.OTP_HMAC_SECRET,
    `${challenge.id}:${challenge.salt}:${code}`,
  );
  if (!constantTimeEqual(actual, challenge.otpDigest)) {
    challenge.attemptsRemaining -= 1;
    if (challenge.attemptsRemaining <= 0) {
      await deleteChallenge(env, challenge);
    } else {
      const remainingTtl = Math.max(
        1,
        Math.ceil((challenge.expiresAt - Date.now()) / 1000),
      );
      await env.OTP_CHALLENGES.put(
        `challenge:${challenge.id}`,
        JSON.stringify(challenge),
        {expirationTtl: remainingTtl},
      );
    }
    throw new ApiError(
      401,
      'otp_incorrect',
      challenge.attemptsRemaining > 0
        ? 'That verification code is incorrect.'
        : 'Too many incorrect attempts. Request a new code.',
      {attemptsRemaining: Math.max(0, challenge.attemptsRemaining)},
    );
  }

  await deleteChallenge(env, challenge);
  const token = await issueVerifiedContactToken(challenge, env);
  return response(
    {
      verified: true,
      verifiedContactToken: token,
      destination: maskDestination(challenge.channel, challenge.destination),
    },
    200,
    origin,
    env,
  );
}

async function sendProviderOtp(channel, destination, otp, env, fetchImpl) {
  if (channel === 'whatsapp') {
    const graphVersion = env.WHATSAPP_GRAPH_API_VERSION;
    if (!/^v\d+\.\d+$/.test(graphVersion)) {
      throw new ApiError(
        503,
        'whatsapp_not_configured',
        'WhatsApp verification is not configured.',
      );
    }
    const result = await fetchImpl(
      `https://graph.facebook.com/${graphVersion}/${encodeURIComponent(env.WHATSAPP_PHONE_NUMBER_ID)}/messages`,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${env.WHATSAPP_ACCESS_TOKEN}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: destination,
          type: 'template',
          template: {
            name: env.WHATSAPP_AUTH_TEMPLATE,
            language: {code: env.WHATSAPP_TEMPLATE_LANGUAGE ?? 'en'},
            components: [
              {
                type: 'body',
                parameters: [{type: 'text', text: otp}],
              },
              {
                type: 'button',
                sub_type: 'url',
                index: '0',
                parameters: [{type: 'text', text: otp}],
              },
            ],
          },
        }),
      },
    );
    if (!result.ok) {
      throw new ApiError(
        502,
        'whatsapp_delivery_failed',
        'WhatsApp could not deliver the verification code. Try again.',
      );
    }
    return;
  }

  if (!env.RESEND_API_KEY || !env.OTP_FROM_EMAIL) {
    throw new ApiError(
      503,
      'email_not_configured',
      'Email verification is not configured.',
    );
  }
  const result = await fetchImpl('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${env.RESEND_API_KEY}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      from: env.OTP_FROM_EMAIL,
      to: [destination],
      subject: 'Your VoltMapEV verification code',
      text: `Your VoltMapEV verification code is ${otp}. It expires in 5 minutes. Do not share it.`,
    }),
  });
  if (!result.ok) {
    throw new ApiError(
      502,
      'email_delivery_failed',
      'Email could not deliver the verification code. Try again.',
    );
  }
}

function normalizeDestination(channel, rawDestination) {
  const raw = String(rawDestination ?? '').trim();
  if (channel === 'email') {
    const email = raw.toLowerCase();
    if (
      email.length > 254 ||
      !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)
    ) {
      throw new ApiError(400, 'invalid_email', 'Enter a valid email address.');
    }
    return email;
  }

  let digits = raw.replace(/\D/g, '');
  if (digits.length === 12 && digits.startsWith('91')) digits = digits.slice(2);
  if (digits.length === 11 && digits.startsWith('0')) digits = digits.slice(1);
  if (!/^[6-9]\d{9}$/.test(digits)) {
    throw new ApiError(
      400,
      'invalid_phone',
      'Enter a valid 10-digit India WhatsApp number.',
    );
  }
  return `91${digits}`;
}

function clientDestination(channel, destination) {
  return channel === 'whatsapp' ? destination.slice(2) : destination;
}

function maskDestination(channel, destination) {
  if (channel === 'whatsapp') return `+91 ••••••${destination.slice(-4)}`;
  const [local, domain] = destination.split('@');
  return `${local.slice(0, 1)}•••@${domain}`;
}

async function enforceRateLimit(kv, key, limit, windowSeconds, now) {
  const stored = await kv.get(key, 'json');
  const current =
    stored && Number.isFinite(stored.resetAt) && stored.resetAt > now
      ? stored
      : {count: 0, resetAt: now + windowSeconds * 1000};
  if (current.count >= limit) {
    const retryAfterSeconds = Math.max(
      1,
      Math.ceil((current.resetAt - now) / 1000),
    );
    throw new ApiError(
      429,
      'otp_rate_limited',
      'Too many verification requests. Try again later.',
      {retryAfterSeconds, attemptsRemaining: 0},
    );
  }
  current.count += 1;
  await kv.put(key, JSON.stringify(current), {
    expirationTtl: Math.max(1, Math.ceil((current.resetAt - now) / 1000)),
  });
}

async function readChallenge(env, id) {
  return env.OTP_CHALLENGES.get(`challenge:${id}`, 'json');
}

async function deleteChallenge(env, challenge) {
  const destinationKey = await sha256Hex(
    `${challenge.channel}:${challenge.destination}`,
  );
  await Promise.all([
    env.OTP_CHALLENGES.delete(`challenge:${challenge.id}`),
    env.OTP_CHALLENGES.delete(
      `active:${destinationKey}:${challenge.purpose}`,
    ),
  ]);
}

async function issueVerifiedContactToken(challenge, env) {
  const now = Math.floor(Date.now() / 1000);
  const payload = base64Url(
    new TextEncoder().encode(
      JSON.stringify({
        iss: 'voltmapev-identity',
        sub: challenge.destination,
        channel: challenge.channel,
        purpose: challenge.purpose,
        iat: now,
        exp: now + CONTACT_TOKEN_TTL_SECONDS,
        jti: crypto.randomUUID(),
      }),
    ),
  );
  const signature = await hmacBytes(env.OTP_HMAC_SECRET, payload);
  return `v1.${payload}.${base64Url(signature)}`;
}

function assertStorageConfigured(env) {
  if (
    !env.OTP_CHALLENGES ||
    !env.OTP_RATE_LIMITS ||
    typeof env.OTP_HMAC_SECRET !== 'string' ||
    env.OTP_HMAC_SECRET.length < 32
  ) {
    throw new ApiError(
      503,
      'identity_backend_not_configured',
      'The verification service is not configured.',
    );
  }
}

function assertChannelConfigured(env, channel) {
  if (
    channel === 'whatsapp' &&
    (!env.WHATSAPP_ACCESS_TOKEN ||
      !env.WHATSAPP_PHONE_NUMBER_ID ||
      !env.WHATSAPP_AUTH_TEMPLATE ||
      !env.WHATSAPP_GRAPH_API_VERSION)
  ) {
    throw new ApiError(
      503,
      'whatsapp_not_configured',
      'WhatsApp verification is not configured.',
    );
  }
  if (channel === 'email' && (!env.RESEND_API_KEY || !env.OTP_FROM_EMAIL)) {
    throw new ApiError(
      503,
      'email_not_configured',
      'Email verification is not configured.',
    );
  }
}

function assertPilotDestinationAllowed(channel, destination, env) {
  if (channel !== 'whatsapp' || !isPilotMode(env)) return;

  const allowed = pilotWhatsAppDestinations(env);
  if (allowed.size === 0) {
    throw new ApiError(
      503,
      'whatsapp_pilot_not_configured',
      'The WhatsApp production pilot is not configured.',
    );
  }
  if (!allowed.has(destination)) {
    throw new ApiError(
      403,
      'whatsapp_pilot_destination_not_allowed',
      'WhatsApp verification is restricted during the production pilot.',
    );
  }
}

function isPilotMode(env) {
  return String(env.OTP_PILOT_MODE ?? '').trim().toLowerCase() === 'true';
}

function pilotWhatsAppDestinations(env) {
  const configured = String(env.WHATSAPP_PILOT_ALLOWLIST ?? '');
  return new Set(
    configured
      .split(',')
      .map((value) => value.replace(/\D/g, ''))
      .map((value) => value.length === 10 ? `91${value}` : value)
      .filter((value) => /^91[6-9]\d{9}$/.test(value)),
  );
}

function isConfigured(env) {
  return Boolean(
    env.OTP_CHALLENGES &&
      env.OTP_RATE_LIMITS &&
      env.OTP_HMAC_SECRET &&
      env.WHATSAPP_ACCESS_TOKEN &&
      env.WHATSAPP_PHONE_NUMBER_ID &&
      env.WHATSAPP_AUTH_TEMPLATE &&
      env.WHATSAPP_GRAPH_API_VERSION &&
      (!isPilotMode(env) || pilotWhatsAppDestinations(env).size > 0) &&
      env.RESEND_API_KEY &&
      env.OTP_FROM_EMAIL,
  );
}

function assertAllowedOrigin(origin, env) {
  if (!origin) return;
  const allowed = allowedOrigins(env);
  if (!allowed.has(origin)) {
    throw new ApiError(403, 'origin_not_allowed', 'Origin not allowed.');
  }
}

function allowedOrigins(env) {
  const configured = env.ALLOWED_ORIGINS ??
    'https://voltmapev.com,https://www.voltmapev.com,https://suriram2000.github.io';
  return new Set(
    configured
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean),
  );
}

async function readJson(request) {
  const contentLength = Number(request.headers.get('content-length') ?? 0);
  if (contentLength > 4096) {
    throw new ApiError(413, 'request_too_large', 'Request is too large.');
  }
  if (!request.headers.get('content-type')?.includes('application/json')) {
    throw new ApiError(415, 'json_required', 'Send a JSON request.');
  }
  try {
    const text = await request.text();
    if (new TextEncoder().encode(text).byteLength > 4096) {
      throw new ApiError(413, 'request_too_large', 'Request is too large.');
    }
    return JSON.parse(text);
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(400, 'invalid_json', 'Request body is invalid JSON.');
  }
}

function secureSixDigitCode() {
  const range = 1_000_000;
  const upperBound = Math.floor(0x1_0000_0000 / range) * range;
  const values = new Uint32Array(1);
  do crypto.getRandomValues(values); while (values[0] >= upperBound);
  return (values[0] % range).toString().padStart(6, '0');
}

function randomBase64Url(length) {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return base64Url(bytes);
}

async function sha256Hex(value) {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  );
  return bytesToHex(new Uint8Array(digest));
}

async function hmacHex(secret, value) {
  return bytesToHex(await hmacBytes(secret, value));
}

async function hmacBytes(secret, value) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    {name: 'HMAC', hash: 'SHA-256'},
    false,
    ['sign'],
  );
  return new Uint8Array(
    await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(value)),
  );
}

function constantTimeEqual(left, right) {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

function bytesToHex(bytes) {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

function base64Url(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

function response(body, status, origin, env) {
  const headers = new Headers({
    'cache-control': 'no-store',
    'content-security-policy': "default-src 'none'",
    'referrer-policy': 'no-referrer',
    'x-content-type-options': 'nosniff',
  });
  if (body !== null) headers.set('content-type', 'application/json; charset=utf-8');
  if (origin && allowedOrigins(env).has(origin)) {
    headers.set('access-control-allow-origin', origin);
    headers.set('access-control-allow-methods', 'GET, POST, OPTIONS');
    headers.set('access-control-allow-headers', 'content-type');
    headers.set('access-control-max-age', '600');
    headers.set('vary', 'Origin');
  }
  return new Response(body === null ? null : JSON.stringify(body), {
    status,
    headers,
  });
}

export default createWorker();
