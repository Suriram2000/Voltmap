# VoltMapEV product execution plan

## Phase 1: reliable foundation

- Label each station source as government directory, operator live feed,
  community report, or demo.
- Keep PIN/area search usable before and during location mode.
- Synchronize map and nearby list, including permission, offline, empty, stale,
  and provider-error states.
- Use production OTP only through a server-side provider with expiry, resend
  cooldown, attempt limits, and abuse protection.

Exit gate: authentication, search, location, navigation, and data-label tests
pass on supported platforms.

## Phase 2: vehicle-aware route planning

- Store connector, battery, consumption, range, and reserve data.
- Show compatible chargers as soon as route locations or a PIN are selected.
- Rank stops by reachability, detour, reliability, availability, power, and
  tariff; provide alternatives and recalculate when conditions change.

Exit gate: tested routes do not recommend incompatible or unreachable stops.

## Phase 3: first verified charging operator

- Integrate one operator through authenticated OCPP, OCPI, or vendor APIs.
- Map location, EVSE, connector, tariff, and status identifiers.
- Implement start, live updates, stop, final meter values, and CDR ingestion.
- Persist the active session across navigation and app restart.

Exit gate: controlled real-station tests complete start-to-CDR with auditable
records.

## Phase 4: payments and receipts

- Complete merchant onboarding and use hosted gateway checkout.
- Create orders on the backend and verify signed webhooks.
- Link one payment lifecycle to one charging session with idempotency.
- Support authorization, capture, cancellation, refund, dispute, and daily
  reconciliation.
- Generate receipts only from verified payment and final CDR data, then retain
  them in-app and deliver them through verified channels.

Exit gate: every test payment, session, refund, and receipt reconciles.

## Phase 5: feedback and controlled release

- Add Help and Feedback under Profile.
- Offer optional post-charge ratings and issue categories; include Maybe Later.
- Train support for payment-success/charge-failure, interruption, refund, and
  receipt cases.
- Use staged store rollout, monitoring, rollback, and a limited operator/city
  cohort before expansion.

## Critical release tests

1. Valid, wrong, expired, and rate-limited OTP flows.
2. PIN results appear before Plan Route.
3. Search remains available with location enabled or unavailable.
4. Vehicle-compatible route with reserve and alternatives.
5. Active charging session survives navigation and restart.
6. Payment produces exactly one verified receipt.
7. Authorized payment plus rejected charger start recovers safely.
8. Duplicate webhooks do not duplicate charges or receipts.
9. Interrupted session reconciles against final CDR.
10. Refund, optional feedback, and account deletion complete correctly.

## Release blockers

- No verified operator or authoritative final meter values.
- Client-only payment success or incomplete webhook verification.
- Missing idempotency, refunds, or reconciliation.
- Active session loss after navigation or restart.
- OTPs, financial credentials, or secrets in logs or client storage.
- Store/privacy disclosures that differ from actual runtime behavior.
- Receipts that cannot be reproduced from auditable records.

