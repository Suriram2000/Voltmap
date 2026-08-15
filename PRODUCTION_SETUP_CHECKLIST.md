# VoltMapEV production setup checklist

Reviewed: 13 August 2026

This checklist covers real India phone OTP, guest payments, receipt delivery,
cross-device data, and secure admin access. Never paste private keys, OTPs,
bank information, Aadhaar images, PAN images, API secrets, webhook secrets, or
service-account JSON into this repository, a GitHub issue, or a chat. Add
secrets only to the selected backend's encrypted environment and GitHub
Actions secrets when specifically required.

## Details already confirmed

- Production domain: `https://voltmapev.com/`
- GitHub repository: `Suriram2000/Voltmap`
- Hosting/deployment: GitHub Pages through GitHub Actions
- Admin and contact email: `skotla100@gmail.com`
- Contact phone: `+91 93927 88714`
- Android application ID: `in.voltmap.voltmap`
- iOS bundle ID: `in.voltmap.voltmap`
- Flutter version: `1.10.0+13`
- Guest charger search, guest trip planning, and guest sandbox checkout are in
  scope.
- Phone verification is required only when saving Favorites or Trips.
- Guest checkout must collect a receipt destination but must not force account
  creation.

## Owner decisions and accounts required

### 1. Business identity

- Legal business/entity name
- Entity type: individual/proprietorship, partnership, LLP, or company
- Registered business address
- Customer-support name, email, and phone
- GSTIN, Udyam number, CIN/LLPIN, or other registration that applies
- Personal and/or business PAN required for the selected entity type
- Aadhaar/authorized-signatory identity verification when requested by the
  payment provider
- Settlement bank account in the legal business name, account number, IFSC,
  and provider-requested proof such as a cancelled cheque or bank statement
- Refund window and cancellation/refund policy owner approval

KYC documents are uploaded only inside the payment provider's secure dashboard.

### 2. Firebase project for authentication and synchronized app data

Create or select a Firebase/Google Cloud project owned by the business Google
account, then provide the non-secret Firebase project ID.

Required console configuration:

- Upgrade to the Blaze billing plan; Firebase phone verification SMS requires a
  linked Cloud Billing account.
- Register Web, Android, and iOS apps.
- Add `voltmapev.com` to Firebase Authentication authorized domains.
- Enable Phone as an Authentication sign-in provider.
- Set the SMS region policy to allow India and deny markets the app does not
  serve.
- Add controlled fictional/test phone numbers and test codes for QA.
- Create a Firestore database and deploy deny-by-default security rules.
- Enable App Check and appropriate bot/abuse protection before launch.
- Set budget alerts and authentication/Cloud Functions usage alerts.

Platform inputs:

- Android: production release keystore, keystore alias, and SHA-1/SHA-256
  fingerprints. Release builds fail closed when `key.properties` is absent and
  never fall back to the debug signing key. Configure the ignored upload key
  locally or the encrypted GitHub Actions signing secrets before Play upload.
- iOS: Apple Developer Team ID, APNs authentication key (`.p8`), APNs Key ID,
  and permission to configure the bundle ID. Enable Push Notifications and
  Background Modes/remote notifications.
- Web: Firebase uses reCAPTCHA for phone sign-in. The privacy notice must state
  that phone numbers are sent to and stored by Google for spam/abuse prevention.

Flutter integration will use `firebase_core`, `firebase_auth`,
`cloud_firestore`, and optionally `firebase_app_check`. `flutterfire configure`
will generate public platform configuration; server credentials remain secret.

### 3. Data model and access policy

Recommended server-owned data:

- `users/{uid}`: normalized phone, display name, created/last-active timestamps,
  notification consent, and role reference
- `users/{uid}/favorites/{stationId}`
- `users/{uid}/trips/{tripId}`
- `chargerSubmissions/{submissionId}` with submitter UID and review state
- `orders/{orderId}` with amount in paise, currency, state, and anonymous or
  authenticated customer reference
- `payments/{paymentId}` containing only gateway identifiers and verified state
- `receipts/{receiptId}` with masked payment reference and delivery status
- `admins/{uid}` or a Firebase custom claim for authorized administrators

Rules:

- Users may read/write only their own profile, favorites, and trips.
- Payment capture status, receipts, roles, and admin claims are server-write-only.
- Guest orders use a random server-issued session/order token, never a client
  claim that the order is paid.
- Admin access is granted server-side to the verified UID belonging to
  `skotla100@gmail.com`; matching a client-entered email is not authorization.
- Log privileged admin reads and writes.

### 4. Razorpay account for real guest payments

Create and activate a Razorpay merchant account, complete CKYC/video KYC as
required, connect the settlement bank account, and get the website/business
category approved.

Inputs produced by the Razorpay dashboard:

- Test Key ID
- Test Key Secret
- Test webhook secret
- Live Key ID after account activation
- Live Key Secret after account activation
- Live webhook secret
- Merchant/account identifier and settlement configuration

Secrets go only in the backend environment. The public Key ID may be passed to
gateway-hosted Checkout. Never place Key Secret or webhook secret in Flutter.

Required payment flow:

1. Guest enters a valid receipt email or India mobile number and accepts the
   receipt/privacy notice.
2. Backend creates a Razorpay Order in INR paise with an idempotency key and
   stores the expected amount/currency.
3. App opens Razorpay-hosted checkout for approved UPI/card/wallet methods.
4. Backend verifies the returned payment signature using the server-held
   secret.
5. Webhook handler validates `X-Razorpay-Signature` against the unmodified raw
   request body and deduplicates `x-razorpay-event-id`.
6. Mark paid only when order ID, currency, amount, and captured status match
   the stored order.
7. Create and send a receipt only after server verification.
8. Handle failure, pending, timeout, duplicate callback, refund, partial
   refund, dispute, and reconciliation states explicitly.

Required public pages before live activation:

- Privacy policy
- Terms of service
- Refund and cancellation policy
- Pricing/platform-fee disclosure
- Contact/support page
- Business identity and customer grievance/contact information

### 5. Receipt email and SMS

Guest checkout fields:

- Delivery choice: email or SMS
- Email address or `+91` mobile number
- Explicit transactional-receipt consent
- Optional separate marketing consent, off by default

Email setup:

- Choose a transactional email provider.
- Create a sender such as `receipts@voltmapev.com`.
- Add provider-supplied SPF and DKIM DNS records at IONOS.
- Add and monitor a DMARC policy.
- Approve receipt, payment-failed, and refund templates.
- Store provider API credentials only in the backend.

India SMS setup:

- Select an India-capable transactional SMS provider.
- Complete TRAI Distributed Ledger Technology requirements: Principal Entity
  registration, sender/header registration, content-template registration,
  and consent-template/consent registration when applicable.
- Approve separate OTP and receipt content templates.
- Configure the provider's PE ID, header, template IDs, and API credential in
  the backend.
- Implement resend throttling, OTP expiry, attempt limits, fraud monitoring,
  delivery acknowledgement, retries, and permanent-failure handling.

Firebase Authentication sends authentication OTPs only. It is not the service
for sending arbitrary payment receipt messages; receipt SMS/email needs a
separate transactional messaging provider.

### 6. Receipt contents

- VoltMapEV legal/business display name and support contact
- Receipt ID and gateway order/payment reference (masked where appropriate)
- Station and connector
- Start/end timestamps
- Delivered kWh and tariff
- Platform fee, taxes if applicable, total, and currency
- Payment method label without raw card, CVV, UPI PIN, or full instrument data
- Payment/refund state
- Link to a secure receipt view or support/refund instructions

### 7. Admin dashboard

- Keep `skotla100@gmail.com` as the intended admin identity.
- Use Firebase Authentication plus a server-managed admin custom claim or role
  document.
- Require recent sign-in and preferably MFA for admin access.
- Show users, order/payment state, delivery status, refunds, and audit events.
- Never show password hashes, OTP codes, card numbers, CVV, UPI PIN, payment
  secrets, Aadhaar/PAN images, or unrestricted Firestore exports.

### 8. Production validation before launch

- Real-device India OTP tests on Android, iPhone, and web
- reCAPTCHA and abuse/rate-limit tests
- User data isolation and Firestore Rules emulator tests
- Guest checkout success/failure/pending/cancel/duplicate tests
- Signature and webhook tamper tests using raw request bodies
- Amount/currency/order mismatch rejection tests
- Email and SMS receipt success/failure/retry tests
- Refund and reconciliation tests
- Admin-role negative tests
- Accessibility, responsive layout, startup paint, performance, and offline
  failure checks
- Release web build, signed Android release build, and unsigned/signed iOS
  release checks as appropriate
- Staging payment and messaging approval before live credentials are enabled

## Safe implementation order

1. Owner completes Firebase project/billing and provides project access.
2. Configure real Firebase phone authentication and replace the preview OTP.
3. Move Favorites/Trips/users to Firestore and deploy/test rules.
4. Create backend order, webhook, receipt, and admin-role services.
5. Complete Razorpay test-mode integration and full payment verification tests.
6. Configure transactional email; add DLT-compliant SMS only after approval.
7. Complete KYC, production signing, privacy/terms/refund review, and security
   review.
8. Enable live payment/SMS credentials only after staging evidence passes.

## Official references

- [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup)
- [Firebase Flutter phone authentication](https://firebase.google.com/docs/auth/flutter/phone-auth)
- [Firebase Authentication limits](https://firebase.google.com/docs/auth/limits)
- [Firestore rule conditions](https://firebase.google.com/docs/firestore/security/rules-conditions)
- [Razorpay account setup](https://razorpay.com/docs/payments/set-up/)
- [Razorpay Standard Checkout](https://razorpay.com/docs/payments/payment-gateway/web-integration/standard/integration-steps/)
- [Razorpay webhook validation](https://razorpay.com/docs/webhooks/validate-test/)
- [TRAI advice to senders](https://trai.gov.in/advice-to-senders)
