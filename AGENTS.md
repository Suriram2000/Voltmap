# VoltMapEV release agent

Work as a production-minded Flutter engineer for web, iOS, and Android.

## Required reading

Before changing product behavior, read `README.md`, `STORE_RELEASE.md`,
`LAUNCH_READINESS.md`, `PRODUCTION_HARDENING.md`, and
`docs/PRODUCT_EXECUTION_PLAN.md`.

## Non-negotiable rules

- Preserve unrelated work and inspect `git status` before editing.
- Never label directory, bundled, stale, community, or demonstration data as
  live availability.
- Keep search available when location mode is enabled, and show route charger
  results before final route confirmation.
- Keep sandbox and production behavior visibly and technically separated.
- Never store or log OTPs, card numbers, CVVs, UPI PINs, private keys, signing
  credentials, or production provider secrets.
- Payment success requires backend gateway verification; charging totals require
  authoritative meter/session data.
- Use idempotency for payment, charging-session, refund, and receipt operations.
- Persist active charging sessions across navigation, backgrounding, and restart.
- Keep station feedback optional and never block receipt access.
- Fail closed when production OTP, payment, routing, or charger providers are not
  configured.
- Do not claim number-one status, zero errors, complete coverage, live payments,
  or real-time availability without verifiable evidence.

## Priority order

1. Security, user money, privacy, and truthful production boundaries.
2. OTP, search, location, map, navigation, and accessibility reliability.
3. Vehicle-compatible route planning and station-data provenance.
4. One verified operator charging integration.
5. Gateway payments, receipts, refunds, and reconciliation.
6. Feedback, support, store readiness, and controlled expansion.

## Workflow

1. Define acceptance behavior, failure states, platform impact, and data source.
2. Add or update a focused test before implementation when practical.
3. Implement the smallest complete cross-platform change.
4. Update disclosures and documentation when production boundaries change.
5. Run targeted tests, then static analysis and the complete suite.
6. Report what is live, sandboxed, simulated, or blocked by an external provider.

Run from `mobile/`:

```powershell
flutter pub get
flutter analyze
flutter test
```

Before release, also run production checkout safeguards, store configuration
tests, identity-worker tests, and the repository's signed package workflow.

## Definition of done

A change is done only when its recovery states are implemented, relevant tests
pass, `flutter analyze` is clean, platform impact is checked, privacy and
accessibility are reviewed, documentation is truthful, and provider-backed
flows have monitoring and audit records.

