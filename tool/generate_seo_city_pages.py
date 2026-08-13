"""Generate crawlable VoltMapEV city charger pages from the bundled BEE index.

Usage:
  python tool/generate_seo_city_pages.py
  python tool/generate_seo_city_pages.py --check

The generated pages intentionally describe a dated official inventory. They do
not claim real-time charger status, pricing, rankings, or operator endorsement.
"""

from __future__ import annotations

import argparse
import html
import json
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_DIRECTORY = ROOT / "mobile" / "assets" / "data" / "bee"
WEB_DIRECTORY = ROOT / "mobile" / "web"
CITY_DIRECTORY = WEB_DIRECTORY / "charging-stations"
SITE = "https://voltmapev.com"
LAST_MODIFIED = "2026-08-12"


@dataclass(frozen=True)
class City:
    name: str
    state: str
    slug: str
    aliases: tuple[str, ...]
    intro: str


CITIES = (
    City(
        "Hyderabad",
        "Telangana",
        "hyderabad",
        ("hyderabad",),
        "Compare dated public-charger records across Hyderabad before a local drive or the Bengaluru highway corridor.",
    ),
    City(
        "Bengaluru",
        "Karnataka",
        "bengaluru",
        ("bengaluru", "bangalore"),
        "Review public-charger records labelled Bengaluru or Bangalore for everyday travel and longer Karnataka journeys.",
    ),
    City(
        "Delhi",
        "Delhi",
        "delhi",
        ("delhi", "new delhi"),
        "Explore dated public-charger records across Delhi and New Delhi, then verify the best option for your vehicle.",
    ),
    City(
        "Mumbai",
        "Maharashtra",
        "mumbai",
        ("mumbai",),
        "Review public-charger records labelled Mumbai before travelling across the city or beginning an intercity route.",
    ),
    City(
        "Chennai",
        "Tamil Nadu",
        "chennai",
        ("chennai",),
        "Compare dated public-charger records in Chennai and confirm connector access before setting out.",
    ),
    City(
        "Pune",
        "Maharashtra",
        "pune",
        ("pune",),
        "Explore Pune public-charger records for city journeys and popular routes toward Mumbai and western Maharashtra.",
    ),
    City(
        "Ahmedabad",
        "Gujarat",
        "ahmedabad",
        ("ahmedabad",),
        "Review dated public-charger records in Ahmedabad and verify access, connector type, and current status before travel.",
    ),
    City(
        "Kolkata",
        "West Bengal",
        "kolkata",
        ("kolkata",),
        "Compare Kolkata public-charger records from the official inventory before choosing a stop.",
    ),
    City(
        "Jaipur",
        "Rajasthan",
        "jaipur",
        ("jaipur",),
        "Explore dated public-charger records in Jaipur for local driving and Rajasthan road trips.",
    ),
    City(
        "Kochi",
        "Kerala",
        "kochi",
        ("kochi", "ernakulam"),
        "Review public-charger records labelled Kochi or Ernakulam and verify live access with the operator before arrival.",
    ),
)


def _load_data() -> tuple[dict, dict[str, list[dict]]]:
    manifest = json.loads((DATA_DIRECTORY / "manifest.json").read_text("utf-8"))
    stations_by_state: dict[str, list[dict]] = {}
    for state in manifest["states"]:
        asset_name = Path(state["asset"]).name
        payload = json.loads((DATA_DIRECTORY / asset_name).read_text("utf-8"))
        stations_by_state[state["name"]] = payload["stations"]
    return manifest, stations_by_state


def _city_stations(city: City, stations_by_state: dict[str, list[dict]]) -> list[dict]:
    aliases = {value.casefold() for value in city.aliases}
    return sorted(
        (
            station
            for station in stations_by_state[city.state]
            if str(station.get("c", "")).strip().casefold() in aliases
        ),
        key=lambda station: (
            str(station.get("o", "")).casefold(),
            str(station.get("a", "")).casefold(),
            float(station.get("lat", 0)),
            float(station.get("lng", 0)),
        ),
    )


def _representative(stations: list[dict], limit: int = 12) -> list[dict]:
    selected: list[dict] = []
    seen_operators: set[str] = set()
    for station in stations:
        operator = str(station.get("o", "Unknown operator")).casefold()
        if operator not in seen_operators:
            selected.append(station)
            seen_operators.add(operator)
        if len(selected) == limit:
            return selected
    for station in stations:
        if station not in selected:
            selected.append(station)
        if len(selected) == limit:
            break
    return selected


def _connector_summary(station: dict) -> str:
    connectors = station.get("ch", [])
    types = sorted({str(item.get("t", "")).strip() for item in connectors if item.get("t")})
    powers = [float(item["kw"]) for item in connectors if item.get("kw")]
    parts = []
    if types:
        parts.append(", ".join(types))
    if powers:
        maximum = max(powers)
        parts.append(f"up to {maximum:g} kW in the dated record")
    return " · ".join(parts) if parts else "Connector details not listed"


def _json_script(value: object) -> str:
    """Encode JSON safely for an inline application/ld+json element."""
    return (
        json.dumps(value, ensure_ascii=False, separators=(",", ":"))
        .replace("<", r"\u003c")
        .replace(">", r"\u003e")
        .replace("&", r"\u0026")
    )


def _page_styles() -> str:
    return """
    :root { color-scheme:light; --ink:#071d17; --muted:#47635a; --lime:#b9f34a; --paper:#f4f7f2; --card:#fff; --line:#d9e3dc; }
    * { box-sizing:border-box; }
    body { margin:0; background:var(--paper); color:var(--ink); font:16px/1.6 system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }
    header { background:linear-gradient(135deg,#071d17,#0b3829); color:#fff; padding:56px 20px; }
    header div, main, footer div { width:min(1040px,100%); margin:auto; }
    h1 { max-width:820px; margin:0 0 12px; font-size:clamp(2.15rem,6vw,4.4rem); line-height:1.04; letter-spacing:-.04em; }
    h2 { margin:42px 0 12px; font-size:clamp(1.45rem,3vw,2rem); }
    h3 { margin:0 0 5px; font-size:1.08rem; }
    p { margin:8px 0 16px; }
    .eyebrow { color:var(--lime); font-weight:800; letter-spacing:.08em; text-transform:uppercase; }
    .lead { max-width:760px; color:#c4d8cf; font-size:1.13rem; }
    .cta { display:inline-block; margin:14px 8px 0 0; padding:12px 18px; border-radius:999px; background:var(--lime); color:var(--ink); font-weight:800; text-decoration:none; }
    .cta.secondary { border:1px solid #729487; background:transparent; color:#fff; }
    main { padding:34px 20px 64px; }
    .facts, .station-grid, .city-grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(230px,1fr)); gap:14px; margin:22px 0; }
    .fact, .station, .city { padding:19px; border:1px solid var(--line); border-radius:17px; background:var(--card); }
    .fact strong { display:block; font-size:1.55rem; }
    .meta { color:var(--muted); font-size:.92rem; }
    .notice { margin:26px 0; padding:18px 20px; border-left:5px solid #6b8e23; background:#eef7dc; border-radius:10px; }
    nav.breadcrumbs { margin-bottom:22px; color:var(--muted); font-size:.92rem; }
    a { color:#126044; }
    footer { padding:28px 20px; background:#071d17; color:#c4d8cf; }
    footer a { color:var(--lime); }
    """


def _structured_city(city: City, stations: list[dict], representative: list[dict], as_of: str) -> str:
    canonical = f"{SITE}/charging-stations/{city.slug}.html"
    graph = [
        {
            "@type": "WebPage",
            "@id": f"{canonical}#page",
            "url": canonical,
            "name": f"EV Charging Stations in {city.name}, {city.state}",
            "description": f"Browse {len(stations):,} dated BEE public EV charging station records for {city.name} and search nearby chargers with VoltMapEV.",
            "dateModified": LAST_MODIFIED,
            "inLanguage": "en-IN",
            "isPartOf": {"@id": f"{SITE}/#website"},
        },
        {
            "@type": "BreadcrumbList",
            "itemListElement": [
                {"@type": "ListItem", "position": 1, "name": "VoltMapEV", "item": f"{SITE}/"},
                {"@type": "ListItem", "position": 2, "name": "Charging stations", "item": f"{SITE}/charging-stations/"},
                {"@type": "ListItem", "position": 3, "name": city.name, "item": canonical},
            ],
        },
        {
            "@type": "Dataset",
            "name": f"BEE public EV charging station records for {city.name}",
            "description": f"{len(stations):,} geocoded records labelled {city.name} or its configured city aliases in VoltMapEV's deduplicated BEE inventory dated {as_of}.",
            "dateModified": as_of,
            "spatialCoverage": {"@type": "Place", "name": f"{city.name}, {city.state}, India"},
            "creator": {"@type": "GovernmentOrganization", "name": "Bureau of Energy Efficiency, Government of India"},
            "isBasedOn": "https://beeindia.gov.in/WriteReadData/RTF1984/EV_PCS_Data_29277.pdf",
        },
        {
            "@type": "ItemList",
            "name": f"Sample BEE charger records in {city.name}",
            "numberOfItems": len(representative),
            "itemListElement": [
                {
                    "@type": "ListItem",
                    "position": position,
                    "item": {
                        "@type": "Place",
                        "name": str(station.get("o") or "Public EV charging station"),
                        "address": str(station.get("a") or city.name),
                        "geo": {
                            "@type": "GeoCoordinates",
                            "latitude": station["lat"],
                            "longitude": station["lng"],
                        },
                    },
                }
                for position, station in enumerate(representative, start=1)
            ],
        },
    ]
    return _json_script({"@context": "https://schema.org", "@graph": graph})


def _city_page(city: City, stations: list[dict], all_cities: list[tuple[City, int]], manifest: dict) -> str:
    representative = _representative(stations)
    canonical = f"{SITE}/charging-stations/{city.slug}.html"
    as_of_display = date.fromisoformat(manifest["asOf"]).strftime("%d %B %Y")
    cards = "\n".join(
        f"""      <article class="station">
        <h3>{html.escape(str(station.get('o') or 'Public EV charging station'))}</h3>
        <p>{html.escape(str(station.get('a') or city.name))}</p>
        <p class="meta">{html.escape(_connector_summary(station))}</p>
      </article>"""
        for station in representative
    )
    city_links = " · ".join(
        f'<a href="{other.slug}.html">{html.escape(other.name)} ({count:,})</a>'
        for other, count in all_cities
        if other != city
    )
    structured = _structured_city(city, stations, representative, manifest["asOf"])
    aliases = " or ".join(city.aliases)
    return f"""<!doctype html>
<html lang="en-IN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1">
  <meta name="description" content="Browse {len(stations):,} dated BEE EV charging station records in {html.escape(city.name)}, {html.escape(city.state)}, then search nearby chargers and plan trips with VoltMapEV.">
  <meta name="geo.region" content="IN">
  <link rel="canonical" href="{canonical}">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="VoltMapEV">
  <meta property="og:title" content="EV Charging Stations in {html.escape(city.name)} | VoltMapEV">
  <meta property="og:description" content="Explore {len(stations):,} dated official charger records and search nearby EV charging stations in {html.escape(city.name)}.">
  <meta property="og:url" content="{canonical}">
  <title>EV Charging Stations in {html.escape(city.name)}, {html.escape(city.state)} | VoltMapEV</title>
  <script type="application/ld+json">{structured}</script>
  <style>{_page_styles()}</style>
</head>
<body>
  <header><div>
    <p class="eyebrow">VoltMapEV · {html.escape(city.state)}</p>
    <h1>EV charging stations in {html.escape(city.name)}</h1>
    <p class="lead">{html.escape(city.intro)}</p>
    <a class="cta" href="/">Search chargers near me</a>
    <a class="cta secondary" href="/">Plan an EV trip</a>
  </div></header>
  <main>
    <nav class="breadcrumbs" aria-label="Breadcrumb"><a href="/">Home</a> / <a href="/charging-stations/">Charging stations</a> / {html.escape(city.name)}</nav>
    <h2>Official inventory snapshot</h2>
    <p>VoltMapEV found <strong>{len(stations):,} unique, geocoded station records</strong> whose BEE city field is labelled {html.escape(aliases)} in {html.escape(city.state)}. The source inventory is dated {as_of_display}; this count is not a live availability total.</p>
    <div class="facts">
      <div class="fact"><strong>{len(stations):,}</strong>matching dated city records</div>
      <div class="fact"><strong>{manifest['stationCount']:,}</strong>unique records across India</div>
      <div class="fact"><strong>No signup</strong>to search or plan a trip</div>
    </div>
    <div class="notice"><strong>Before you travel:</strong> station operation, access hours, connector condition, pricing, and availability can change. Verify important stops with the operator or the optional Google Maps verification link in VoltMapEV.</div>

    <h2>Sample charging-station records in {html.escape(city.name)}</h2>
    <p>These {len(representative)} examples are representative operator records from the dated inventory, not a ranking and not a claim that every charger is currently available. Open VoltMapEV to search the full city area or a six-digit PIN code on the same page.</p>
    <div class="station-grid">
{cards}
    </div>

    <h2>How to find the right charger</h2>
    <p>Search a PIN code, neighbourhood, landmark, or city in VoltMapEV. Compare connector type and listed power, then confirm live access and directions before departure. For a longer journey, use the Trips tab to see charging options relevant to the planned route.</p>
    <p><a href="/">Open VoltMapEV charger search</a> · <a href="/ev-charging-stations-india.html">Read the India EV charging guide</a> · <a href="https://beeindia.gov.in/show_content.php?lang=1&amp;level=2&amp;lid=67&amp;ls_id=345" rel="noopener">Check the BEE source</a></p>

    <h2>Explore other Indian cities</h2>
    <p>{city_links}</p>
  </main>
  <footer><div>© 2026 VoltMapEV. All rights reserved. · <a href="mailto:skotla100@gmail.com">Contact us</a> · <a href="/">Open VoltMapEV</a></div></footer>
</body>
</html>
"""


def _hub_page(city_counts: list[tuple[City, int]], manifest: dict) -> str:
    as_of_display = date.fromisoformat(manifest["asOf"]).strftime("%d %B %Y")
    cards = "\n".join(
        f"""      <article class="city"><h2><a href="{city.slug}.html">{html.escape(city.name)}</a></h2><p>{count:,} dated BEE records labelled for this city area.</p><p class="meta">{html.escape(city.state)}</p></article>"""
        for city, count in city_counts
    )
    state_rows = "".join(
        f"<li><strong>{html.escape(state['name'])}:</strong> {state['count']:,}</li>"
        for state in manifest["states"]
    )
    canonical = f"{SITE}/charging-stations/"
    structured = _json_script(
        {
            "@context": "https://schema.org",
            "@graph": [
                {
                    "@type": "CollectionPage",
                    "@id": f"{canonical}#page",
                    "url": canonical,
                    "name": "EV Charging Stations by City in India",
                    "description": f"Explore city charger guides based on {manifest['stationCount']:,} deduplicated, geocoded BEE inventory records.",
                    "dateModified": LAST_MODIFIED,
                    "inLanguage": "en-IN",
                    "isPartOf": {"@id": f"{SITE}/#website"},
                },
                {
                    "@type": "BreadcrumbList",
                    "itemListElement": [
                        {"@type": "ListItem", "position": 1, "name": "VoltMapEV", "item": f"{SITE}/"},
                        {"@type": "ListItem", "position": 2, "name": "Charging stations", "item": canonical},
                    ],
                },
                {
                    "@type": "ItemList",
                    "name": "VoltMapEV city charging guides",
                    "numberOfItems": len(city_counts),
                    "itemListElement": [
                        {
                            "@type": "ListItem",
                            "position": position,
                            "name": f"EV charging stations in {city.name}",
                            "url": f"{SITE}/charging-stations/{city.slug}.html",
                        }
                        for position, (city, _) in enumerate(city_counts, start=1)
                    ],
                },
            ],
        },
    )
    return f"""<!doctype html>
<html lang="en-IN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1">
  <meta name="description" content="Explore EV charging stations by city across India using a dated official BEE inventory, then search any PIN code or area with VoltMapEV.">
  <meta name="geo.region" content="IN">
  <link rel="canonical" href="{canonical}">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="VoltMapEV">
  <meta property="og:title" content="EV Charging Stations by City in India | VoltMapEV">
  <meta property="og:description" content="Explore city charger guides backed by {manifest['stationCount']:,} dated BEE records, or search any PIN code in VoltMapEV.">
  <meta property="og:url" content="{canonical}">
  <title>EV Charging Stations by City in India | VoltMapEV</title>
  <script type="application/ld+json">{structured}</script>
  <style>{_page_styles()} .state-list {{ columns:3 220px; padding-left:20px; }} .state-list li {{ margin:0 14px 8px 0; break-inside:avoid; }}</style>
</head>
<body>
  <header><div>
    <p class="eyebrow">VoltMapEV city guides</p>
    <h1>EV charging stations by city in India</h1>
    <p class="lead">Explore transparent, crawlable city summaries based on the dated Government of India BEE inventory, then use VoltMapEV for a PIN-code or area search.</p>
    <a class="cta" href="/">Search chargers near me</a>
    <a class="cta secondary" href="/ev-charging-stations-india.html">Read the India guide</a>
  </div></header>
  <main>
    <nav class="breadcrumbs" aria-label="Breadcrumb"><a href="/">Home</a> / Charging stations</nav>
    <h2>Choose a city</h2>
    <div class="city-grid">
{cards}
    </div>
    <div class="notice"><strong>Data transparency:</strong> these counts come from VoltMapEV's {manifest['stationCount']:,} deduplicated, geocoded BEE records dated {as_of_display}. They are inventory records, not real-time operational status. Verify access, connector compatibility, price, and availability before travel.</div>
    <h2>Official inventory totals by state and Union Territory</h2>
    <p>The underlying dataset covers {len(manifest['states'])} states and Union Territories. State totals below reflect the same dated, deduplicated VoltMapEV index.</p>
    <ul class="state-list">{state_rows}</ul>
    <h2>Search any PIN code or area</h2>
    <p>The city pages are starting points, not the limit of VoltMapEV coverage. Open the app and enter a six-digit PIN code, neighbourhood, landmark, city, or state to see matching station records on the same page.</p>
    <p><a href="/">Open VoltMapEV charger search</a> · <a href="https://beeindia.gov.in/show_content.php?lang=1&amp;level=2&amp;lid=67&amp;ls_id=345" rel="noopener">Review the BEE source</a></p>
  </main>
  <footer><div>© 2026 VoltMapEV. All rights reserved. · <a href="mailto:skotla100@gmail.com">Contact us</a> · <a href="/">Open VoltMapEV</a></div></footer>
</body>
</html>
"""


def _sitemap(city_counts: list[tuple[City, int]]) -> str:
    entries = [
        (f"{SITE}/", "weekly", "1.0"),
        (f"{SITE}/ev-charging-stations-india.html", "monthly", "0.9"),
        (f"{SITE}/charging-stations/", "monthly", "0.9"),
        *(
            (f"{SITE}/charging-stations/{city.slug}.html", "monthly", "0.8")
            for city, _ in city_counts
        ),
    ]
    urls = "\n".join(
        f"""  <url>
    <loc>{url}</loc>
    <lastmod>{LAST_MODIFIED}</lastmod>
    <changefreq>{frequency}</changefreq>
    <priority>{priority}</priority>
  </url>"""
        for url, frequency, priority in entries
    )
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
{urls}
</urlset>
'''


def _outputs() -> dict[Path, str]:
    manifest, stations_by_state = _load_data()
    city_data = [(city, _city_stations(city, stations_by_state)) for city in CITIES]
    city_counts = [(city, len(stations)) for city, stations in city_data]
    if any(count == 0 for _, count in city_counts):
        missing = ", ".join(city.name for city, count in city_counts if count == 0)
        raise RuntimeError(f"No official station records found for: {missing}")
    outputs = {
        CITY_DIRECTORY / "index.html": _hub_page(city_counts, manifest),
        WEB_DIRECTORY / "sitemap.xml": _sitemap(city_counts),
    }
    outputs.update(
        {
            CITY_DIRECTORY / f"{city.slug}.html": _city_page(city, stations, city_counts, manifest)
            for city, stations in city_data
        }
    )
    return outputs


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if generated files are stale")
    args = parser.parse_args()
    stale: list[Path] = []
    outputs = _outputs()
    for path, content in outputs.items():
        existing = path.read_text("utf-8") if path.exists() else None
        if existing == content:
            continue
        stale.append(path.relative_to(ROOT))
        if not args.check:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8", newline="\n")
    if args.check and stale:
        print("Generated SEO files are stale:", file=sys.stderr)
        for path in stale:
            print(f"  {path}", file=sys.stderr)
        raise SystemExit(1)
    verb = "Checked" if args.check else "Generated"
    print(f"{verb} {len(outputs)} SEO files for {len(CITIES)} cities.")


if __name__ == "__main__":
    main()
