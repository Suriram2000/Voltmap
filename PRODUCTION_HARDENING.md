# VoltMapEV production payment, receipt, map, and release contract

## Release environments

- Release builds default to `production`. They never display sandbox UPI IDs,
  sandbox cards, demo wallets, simulated meters, or simulated success states.
- Local debug and automated-test builds use the clearly labelled `sandbox`.
  `driver@upi` is test data only and is rejected outside that environment.
- Production charging stays fail-closed until
  `VOLTMAP_PAYMENT_API_BASE_URL` is an HTTPS VoltMapEV server and the selected
  station has a verified charger-session integration.
- Production OTP stays fail-closed until `VOLTMAP_IDENTITY_API_BASE_URL` is an
  HTTPS VoltMapEV identity service. Release builds never fall back to the
  preview code.
- Live map status may be enabled through
  `VOLTMAP_REALTIME_CHARGER_API_BASE_URL` only when the server returns
  operator-authorized, timestamped availability, tariff, connector, and
  charger identifiers. The dated BEE inventory remains the honest fallback.
- Provider and monitoring secrets must be injected into their server-side secret
  stores. They must never be passed through Dart defines or committed to this
  repository.

## Required server workflow

1. Verify the user-controlled email address and Indian mobile number with
   expiring, rate-limited OTP challenges. Return an opaque contact token; never
   return the OTP.
2. `POST /v1/charging-sessions/authorize` accepts the station, charger,
   user-approved energy limit, disclosed rate, tax rate, service fee, verified
   contact token, and an `Idempotency-Key` header.
3. The server creates an authorization with the RBI-compliant provider and
   returns only a provider-hosted HTTPS checkout URL. The provider UI collects
   UPI/card/wallet credentials. VoltMapEV never receives raw card numbers, CVVs,
   UPI PINs, or banking credentials.
4. A redirect or client callback is not payment proof. Only a timestamp-checked,
   signature-verified provider webhook may change the server payment state.
5. At the end of charging, the charger network sends the final signed meter
   reading. The server rejects decreases, impossible readings, duplicate final
   readings, and readings for a different charger or session.
6. Calculate the amount from confirmed kWh, disclosed rate, taxes, and fee. Use
   minor currency units and deterministic rounding. Capture no more than the
   approved estimate without a new user approval.
7. Generate an immutable receipt only when both `paymentVerified` and
   `meterReadingConfirmed` are true. `GET
   /v1/charging-sessions/{id}/receipt` returns `202` until then.
8. Send the receipt to all verified destinations. Log provider message ID,
   masked destination, channel, attempt number, status, timestamp, and a safe
   error code. Retry temporary failures with exponential backoff (1, 5, 30, 120
   minutes, then 24 hours); do not retry invalid/unsubscribed destinations.
9. Expose `POST /v1/receipts/{id}/deliveries/retry` for an authenticated manual
   retry. It must be idempotent and must recheck destination verification.
10. Store a double-entry payment ledger. Run daily provider reconciliation and
    alert on missing webhooks, amount mismatches, duplicate captures, orphaned
    refunds, and settlement differences.

Refund and dispute endpoints must use idempotency keys, role-based access,
reason codes, and append-only audit events. Duplicate webhooks and API calls
must return the original result rather than charging again. Merchant settlement
details belong only in the provider's verified onboarding portal; no personal
UPI ID is allowed in source, builds, or runtime configuration.

## Receipt record

Every receipt includes station and charger IDs, confirmed kWh, rate per kWh,
energy subtotal, taxes, transparent service fee, total, masked payment method,
provider payment reference, date, charging-session ID, environment, verification
flags, and delivery attempts. The app can view and export retained receipts.

## Map data truthfulness

The current map uses a dated BEE inventory. It automatically requests location,
centres the fixed-radius map, and keeps the nearby list and markers on the same
result set. BEE does not publish live availability or price in this dataset, so
the app displays those fields as `Not published` instead of inventing values.
Live values may be shown only after an operator API supplies a timestamped
availability, connector status, price, and charger ID.

## Release verification and staged rollout

Block release unless analysis, unit/widget tests, coverage, and a production web
build pass. Test location permission states, empty and failed map services,
marker/list synchronization, navigation, live-operator freshness, signed meter
readings, rounding, success/failure/cancel/duplicate payment webhooks, email/SMS
delivery and retry, refunds, interrupted sessions, offline/slow/server-error
states, and supported iOS/Android versions on physical devices.

Connect crash reporting, server metrics, provider audit logs, alerting, and
privacy-safe session correlation before live payments. Release to internal QA,
then 1%, 10%, 50%, and 100% cohorts with rollback thresholds for crash-free
sessions, payment mismatches, webhook delay, receipt delivery, and map errors.
The reliability target is high reliability with fast detection and response,
never “zero error.”

## Monetization gates

Keep revenue features disabled until their value and disclosure are validated:

- a small service fee shown before approval and itemized on the receipt;
- memberships only when expected savings exceed the fee for the target user;
- fleet/business subscriptions with consolidated billing and controls;
- sponsored results clearly labelled `Ad` and never allowed to falsify distance,
  compatibility, or availability;
- operator partnerships and reservations only with live confirmation/refunds;
- rewards/referrals with fraud controls and simple expiry terms;
- route planning based on verified vehicle range and compatible, route-relevant
  chargers.

No monetization experiment may silently alter ranking, price, or final billing.
