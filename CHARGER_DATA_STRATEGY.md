# VoltMapEV charger data strategy

## Current production-safe coverage

- The bundled national baseline is the Bureau of Energy Efficiency (BEE) public charging-station inventory dated 26 October 2025: 29,251 deduplicated, geocoded station records.
- VoltMapEV searches the national inventory even when location permission is denied.
- A configured VoltMapEV HTTPS data service can add timestamped operator records. The app merges those records with the national baseline instead of replacing the baseline with a partial feed.
- Only a fresh, operator-verified record may display live availability or a live tariff. Malformed coordinates, impossible connector counts, and invalid tariffs are excluded.

Official BEE source: <https://beeindia.gov.in/show_content.php?lang=1&level=2&lid=67&ls_id=345>

## Source priority

Use the most authoritative value for each field, not one winner for the entire station:

1. **Charge-point operator OCPI/OCPP feed** — EVSE identity, connector status, tariff, hours, service fee, and meter-backed session data.
2. **BEE / EV Yatra national database and open API** — nationwide station identity and government inventory baseline.
3. **Government/state open data** — for example, Delhi Open EV data, State Nodal Agency feeds, and future location-level PM E-DRIVE publications.
4. **Operator-published directories** — only through licensed APIs, files, or written data-sharing agreements.
5. **OpenStreetMap/OpenChargeMap** — supplemental discovery only, with required attribution and license compliance; never treated as proof that a charger is working.
6. **Private community corrections** — a moderation signal, never an automatic public overwrite.

Do not scrape or copy Google Maps. Do not reproduce e-Amrit/NITI Aayog data until written permission is obtained; its published copyright policy requires permission for reproduction.

## Accuracy rules already enforced by the app

- India coordinate bounds: latitude 6–38 and longitude 68–98.
- Available connectors cannot be negative or exceed total connectors.
- Connector power and tariffs must be positive and within defensive upper bounds.
- Availability is live for at most 15 minutes after an operator-verified update; future timestamps beyond five minutes are rejected as live.
- Candidate duplicates are removed only when they are within 80 metres and share an operator or a strong address match.
- Partial live coverage is combined with the BEE inventory so stations do not disappear when an operator feed is incomplete.
- Every station card identifies whether it is an operator-verified record or an inventory record.

## Recommended backend ingestion

Run ingestion server-side; never embed operator API credentials in iOS, Android, or web builds.

- Poll OCPI status deltas every 30–60 seconds and retain the provider timestamp.
- Refresh tariffs every 15 minutes and static location/connector metadata nightly.
- Import new BEE/EV Yatra releases when published, preserve the source snapshot, and produce a change report before release.
- Normalize connector identifiers to CCS2, Type 2, CHAdeMO, Bharat AC-001, Bharat DC-001, and supported light-EV sockets without discarding the original value.
- Maintain a canonical station ID plus every provider ID. Keep field-level provenance, first seen, last seen, last verified, and confidence.
- Quarantine large coordinate moves, sudden closures, tariff spikes, connector-count reductions, and conflicting operator records for admin review.
- Monitor feed age, rejection rate, duplicate rate, stations without coordinates, and user corrections per operator.

The public endpoint consumed by the app is `GET /v1/chargers/nearby`. Each row should include `providerStationId`, `operatorName`, coordinates, address, postcodes, connectors, `availableConnectors`, `totalConnectors`, `pricePerKwh`, `currency`, `statusUpdatedAt`, `operatorVerified`, and `sources`.

## Private station feedback

- “Report station information” is available from charger details and every nearby Map card.
- The form captures the correction type, evidence, observation time, station identity, coordinates, and source labels.
- It opens an email addressed only to `skotla100@gmail.com`; no public GitHub issue is created.
- A report must be verified against an operator, government source, or field evidence before the public catalog changes.
- For cross-device administration, replace email transport with an authenticated backend inbox using role-based access, audit logs, spam controls, attachment scanning, and an admin identity claim for `skotla100@gmail.com`.

## Highest-value next partnerships

1. Apply to BEE for the national open API described in the Ministry of Power charging-infrastructure guidelines.
2. Sign OCPI data-sharing agreements with India’s largest CPOs and PSU oil-marketing-company networks.
3. Add State Nodal Agency and Delhi Open EV feeds where the license permits reuse.
4. Ask operators to expose planned maintenance, outage reasons, reservation support, vehicle compatibility, and accessible amenities.
5. Build a “verified recently” program where station owners confirm GPS, photos, hours, connectors, and tariff, with an expiry date rather than a permanent badge.
