# VoltMapEV launch readiness

This file separates what is live today from the account-dependent steps required for search growth, real payments, authoritative station data, and paid promotion.

## Search discovery

Implemented in the website build:

- keyword-specific page titles and descriptions
- canonical, language, sharing, and crawler metadata
- Organization, WebSite, and WebApplication JSON-LD
- `robots.txt` access for Googlebot, Bingbot, OAI-SearchBot, ChatGPT-User, and OAI-AdsBot
- XML sitemap and `llms.txt`
- a crawlable India EV charging guide linked to the interactive app
- a crawlable city-guide hub and ten substantive city pages generated from the dated BEE inventory, with unique metadata, structured data, source disclosures, sample records, and internal links
- an automated freshness check that blocks deployment when generated city pages or the sitemap are stale
- an installable Progressive Web App manifest with Android/desktop install prompting, iPhone/iPad Safari home-screen guidance, standalone display mode, and 192 px, 512 px, maskable, and Apple touch icons

Account steps still required:

1. Add and verify `https://voltmapev.com/` as a domain property in Google Search Console.
2. Submit `https://voltmapev.com/sitemap.xml` and request indexing for the home page, public guide, and city-guide hub. The sitemap exposes the individual city pages.
3. Add the site in Bing Webmaster Tools and submit the same sitemap.
4. Connect a production analytics property and record search, route-plan, live-directions, signup, favorite, charger-report, checkout-start, and checkout-complete events.
5. Monitor indexed-page and query reports, correct crawl or content issues, and expand to additional city or corridor guides only when each page has useful, sourced data and a stable URL. Do not create thin keyword pages.

No vendor can guarantee first position. Search ranking is earned over time through useful content, crawlability, performance, reliable data, brand demand, and reputable links.

## Authoritative charger data

The current national aggregate is sourced from the Government of India answer dated 1 August 2025. VoltMapEV also bundles 29,251 deduplicated, geocoded BEE inventory records dated 26 October 2025. These are dated inventory records, not claims of real-time operation. Prices, live availability, route-stop suitability, and charging sessions must still be verified.

Production station records should require:

- provider station and connector identifiers
- source name, source URL or OCPI party, and license/usage permission
- coordinates, address, PIN, connector standard, maximum power, tariff, and access hours
- `last_verified_at`, `last_status_at`, and source timestamp in UTC
- status source (`operator`, `OCPI`, `OCPP`, `community`, or `manual`)
- reviewer identity and evidence for community additions
- automatic quarantine for invalid coordinates, impossible connector counts, stale status, or duplicate provider IDs

Never describe the inventory as complete, live, or verified unless the upstream contracts and freshness checks support that exact claim.

## Phone verification and receipt delivery

The app now uses a compact India `+91` phone flow for protected Favorites and Saved trips actions. The current GitHub Pages release is a static, local preview: it displays a clearly labeled preview OTP and does not claim that an SMS was sent. Payments remain accessible to guests.

Before enabling real phone verification or sending payment receipts by SMS/email:

1. Select a hosted identity provider that supports India phone authentication and abuse controls.
2. Configure restricted production credentials outside the Flutter bundle.
3. Enforce OTP expiry, resend throttling, attempt limits, bot protection, and audited account linking on the server/provider.
4. Store consent and a verified receipt destination separately from payment instrument data.
5. Send receipts from a server-side transactional SMS/email provider only after a server-verified payment event.
6. Add delivery status, retry, bounce/failure handling, and a user-accessible receipt fallback.

Never treat the local preview code as production verification or state that a receipt was sent without a provider delivery acknowledgement.

### In-app live charger lookup

The app currently embeds Open Charge Map's supported community map for PIN-code and area searches on web, Android, and iOS. Search `500079`, choose the Karmanghat/Vaishalinagar suggestion, and the in-app map centers on `17.3366, 78.5349`. The screen visibly attributes Open Charge Map and OpenStreetMap, warns that community data may be incomplete or stale, and provides Google Maps as a separate verification action.

Do not claim that this is the complete Google result set. Matching Google Places results inside the app requires a billing-enabled Google Cloud project, Places API (New), restricted production credentials, the correct EV charging place type, required Google branding/attribution, and compliance with Google's storage and display policies. Keep secrets out of the Flutter bundle and add quotas, error handling, monitoring, and cost alerts before switching providers.

## Production payments

The current checkout is intentionally a sandbox and must remain unable to move money until a licensed gateway and backend are configured. A production integration should use the gateway-hosted checkout so VoltMapEV never handles raw card numbers, UPI PINs, or CVV values.

Required flow:

1. Authenticated server creates an order in paise with a unique merchant order ID.
2. Client opens the gateway-hosted checkout for enabled methods: UPI Intent/QR, cards, and gateway-supported wallets/apps.
3. Server verifies the checkout signature using a secret that never reaches the app.
4. Server validates webhook signatures against the raw request body and deduplicates event IDs.
5. Order becomes paid only after server verification confirms the expected order ID, currency, amount, and captured status.
6. Late authorization, retries, duplicate events, partial or full refunds, disputes, and timeouts are handled as explicit states.
7. A reconciliation job compares local orders with gateway payments and settlements every day.
8. Admin access uses server-side roles and multi-factor authentication; payment credentials and full payment instruments are never shown.

UPI collection rules change. The selected gateway must expose the currently permitted UPI Intent or QR flow. PhonePe and Paytm can be UPI apps; Amazon Pay and PhonePe wallets may be available through supported wallet-on-UPI or gateway wallet capabilities, subject to merchant onboarding and the gateway's current account configuration.

Before live mode, obtain:

- approved Indian merchant account and settlement bank account
- business KYC, tax, privacy, refund, cancellation, and terms pages
- test and live gateway key IDs stored as deployment secrets
- backend URL, database, webhook URL, and webhook secret
- written refund and customer-support procedure
- gateway test evidence plus an independent security review
- PCI DSS scope confirmation with the acquiring bank or gateway

## India promotion campaign

No advertising spend should start without the account owner approving the campaign, billing method, audience, creative, and daily cap.

Prepared campaign concept:

- Objective: landing-page views first; optimize for route plans after analytics records enough events.
- Geography: India, with separate ad sets for Bengaluru, Hyderabad, Delhi NCR, Mumbai/Pune, Chennai, Kerala, Gujarat, and key intercity EV corridors.
- Placements: Instagram Reels and Stories, Facebook Reels and Feed, plus a separate Google Search campaign for high-intent terms.
- Landing page: `https://voltmapev.com/ev-charging-stations-india.html`
- Primary message: "Find EV chargers by PIN code. Plan a route. See charging options near the journey."
- Headline: "Plan your next EV trip with VoltMapEV"
- Safety line: "Verify live charger status with the operator before travel."
- Reel outline: search Hyderabad, choose Bengaluru, show route-relevant chargers, open live directions, end on the VoltMapEV URL.

Use distinct tracking links:

- Instagram: `https://voltmapev.com/ev-charging-stations-india.html?utm_source=instagram&utm_medium=paid_social&utm_campaign=india_launch`
- Facebook: `https://voltmapev.com/ev-charging-stations-india.html?utm_source=facebook&utm_medium=paid_social&utm_campaign=india_launch`
- Google: `https://voltmapev.com/ev-charging-stations-india.html?utm_source=google&utm_medium=cpc&utm_campaign=india_ev_chargers`

Start with a controlled seven-day test, exclude existing users when possible, cap frequency, and stop creatives that drive clicks without meaningful route plans. Scale only after measuring cost per engaged search, route plan, signup, and retained visitor.

## Quality gates

Every release should pass:

- Dart formatting and static analysis
- all unit, data-integrity, field-validation, model round-trip, authorization, tab-navigation, route-filtering, checkout, and web-discoverability tests
- production web build
- Android debug build and unsigned iOS release build
- post-deploy checks for HTTPS, canonical metadata, `robots.txt`, sitemap, guide page, guest search/trips, protected saves, and sandbox-only checkout messaging

The hourly automation should report failures; it must not deploy, activate payments, alter production data, or spend advertising money.
