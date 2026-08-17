# VoltMapEV identity worker

This server implements the OTP contract used by the shared Flutter web, iOS,
and Android app. Phone verification uses a Meta WhatsApp Business
authentication template; email remains available for verified receipt
delivery. Provider credentials and OTP values never enter the Flutter client.

## Security behavior

- Six-digit codes are generated with Web Crypto and stored only as keyed HMAC
  digests for five minutes.
- Codes are never returned by the API or written to application logs.
- Resends are delayed 30 seconds, attempts are limited to five, and destination
  and IP request limits are enforced.
- A successful verification deletes the challenge and returns a signed,
  one-day verified-contact token for the payment backend.
- The service fails closed when any provider secret or KV binding is missing.
- Browser CORS is restricted to VoltMapEV origins. Native iOS and Android calls
  do not depend on CORS.

KV rate limiting reduces routine abuse. Before a public production launch, add
Cloudflare WAF/rate-limiting rules and Meta business/provider fraud controls as
an additional enforcement layer; KV is eventually consistent.

## Provider setup required before live delivery

1. Complete Meta Business and WhatsApp sender verification.
2. Create and approve an **authentication** template with the one-time-code
   copy button. Set `WHATSAPP_AUTH_TEMPLATE` to its exact name.
3. Set `WHATSAPP_GRAPH_API_VERSION` to a currently supported Meta Graph API
   version after checking Meta's official release documentation.
4. Verify `verify@voltmapev.com` with the email provider.
5. Create the two KV namespaces and replace the placeholder IDs in
   `wrangler.toml`.
6. Store these as Worker secrets; never commit their values:

   - `OTP_HMAC_SECRET`
   - `WHATSAPP_ACCESS_TOKEN`
   - `WHATSAPP_PHONE_NUMBER_ID`
   - `RESEND_API_KEY`

7. Deploy the Worker and route `api.voltmapev.com` to it. Confirm `/health`
   returns `"ready": true` before setting the Flutter build variable
   `VOLTMAP_IDENTITY_API_BASE_URL=https://api.voltmapev.com`.

WhatsApp Business authentication messages are not guaranteed to be free. Meta
and any business-solution provider may charge per delivered authentication
message. Review the current India rate card before enabling production.

## Local tests

No live provider message is sent by the automated tests.

```bash
cd services/identity-worker
npm test
```
