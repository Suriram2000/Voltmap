"""Build VoltMapEV's compact in-app charger index from the official BEE PDF.

Usage:
  python tool/generate_bee_station_data.py INPUT.pdf OUTPUT_DIRECTORY
"""

from __future__ import annotations

import json
import os
import re
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

import pdfplumber


SOURCE_URL = (
    "https://beeindia.gov.in/WriteReadData/RTF1984/EV_PCS_Data_29277.pdf"
)
POSTCODE_PATTERN = re.compile(r"(?<!\d)([1-9]\d{5})(?!\d)")
STATE_NAMES = {
    "andaman & nicobar": "Andaman and Nicobar Islands",
    "ut of d&nh and d&d": "Dadra and Nagar Haveli and Daman and Diu",
    "uttrakhand": "Uttarakhand",
}


def _clean(value: object) -> str:
    return " ".join(str(value or "").replace("\n", " ").split())


def _number(value: str) -> float | None:
    try:
        return float(value)
    except ValueError:
        return None


def _connector_count(value: str) -> int | None:
    number = _number(value)
    if number is None or number < 1:
        return None
    return int(number)


def _canonical_state(value: str) -> str:
    cleaned = _clean(value)
    key = cleaned.casefold()
    return STATE_NAMES.get(key, cleaned.title())


def _station_key(row: list[str], latitude: float, longitude: float) -> tuple:
    return (
        row[0].casefold(),
        row[5].casefold(),
        round(latitude, 6),
        round(longitude, 6),
    )


def _extract_pages(
    input_path: str,
    start_page: int,
    end_page: int,
) -> tuple[dict[tuple, dict], int, int, int, int]:
    stations: dict[tuple, dict] = {}
    table_rows = 0
    skipped_rows = 0

    with pdfplumber.open(input_path) as document:
        for page_number in range(start_page, end_page + 1):
            page = document.pages[page_number - 1]
            for table in page.extract_tables():
                for raw_row in table:
                    if not raw_row or len(raw_row) != 12:
                        skipped_rows += 1
                        continue

                    row = [_clean(value) for value in raw_row]
                    if not row[0] or row[0].casefold() == "cpo name":
                        continue

                    table_rows += 1
                    latitude = _number(row[6])
                    longitude = _number(row[7])
                    if (
                        latitude is None
                        or longitude is None
                        or not 6 <= latitude <= 38
                        or not 68 <= longitude <= 98
                    ):
                        skipped_rows += 1
                        continue

                    key = _station_key(row, latitude, longitude)
                    station = stations.setdefault(
                        key,
                        {
                            "o": row[0],
                            "g": row[1],
                            "s": row[2],
                            "d": row[3],
                            "c": row[4],
                            "a": row[5],
                            "lat": round(latitude, 6),
                            "lng": round(longitude, 6),
                            "p": sorted(set(POSTCODE_PATTERN.findall(row[5]))),
                            "ch": [],
                        },
                    )

                    connector = {
                        "t": row[8],
                        "kw": _number(row[10]) or _number(row[9]),
                        "n": _connector_count(row[11]),
                    }
                    connector = {
                        name: value
                        for name, value in connector.items()
                        if value not in (None, "")
                    }
                    if connector and connector not in station["ch"]:
                        station["ch"].append(connector)

    return stations, table_rows, skipped_rows, start_page, end_page


def build_index(input_path: Path) -> dict:
    with pdfplumber.open(input_path) as document:
        page_count = len(document.pages)

    chunk_size = 75
    tasks = [
        (str(input_path), start, min(start + chunk_size - 1, page_count))
        for start in range(1, page_count + 1, chunk_size)
    ]
    worker_count = min(4, os.cpu_count() or 2, len(tasks))
    stations: dict[tuple, dict] = {}
    table_rows = 0
    skipped_rows = 0

    with ProcessPoolExecutor(max_workers=worker_count) as executor:
        futures = [executor.submit(_extract_pages, *task) for task in tasks]
        for future in as_completed(futures):
            chunk_stations, chunk_rows, chunk_skipped, start, end = future.result()
            table_rows += chunk_rows
            skipped_rows += chunk_skipped
            for key, incoming in chunk_stations.items():
                station = stations.get(key)
                if station is None:
                    stations[key] = incoming
                    continue
                station["p"] = sorted(set(station["p"]) | set(incoming["p"]))
                for connector in incoming["ch"]:
                    if connector not in station["ch"]:
                        station["ch"].append(connector)
            print(f"Processed pages {start}-{end}/{page_count}...", flush=True)

    station_list = sorted(
        stations.values(),
        key=lambda station: (
            station["s"].casefold(),
            station["d"].casefold(),
            station["c"].casefold(),
            station["o"].casefold(),
            station["lat"],
            station["lng"],
        ),
    )
    return {
        "source": "Bureau of Energy Efficiency (BEE), Government of India",
        "sourceUrl": SOURCE_URL,
        "asOf": "2025-10-26",
        "stationCount": len(station_list),
        "tableRowCount": table_rows,
        "skippedRowCount": skipped_rows,
        "stations": station_list,
    }


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(
            "Usage: generate_bee_station_data.py INPUT.pdf OUTPUT_DIRECTORY"
        )

    input_path = Path(sys.argv[1]).resolve()
    output_directory = Path(sys.argv[2]).resolve()
    output_directory.mkdir(parents=True, exist_ok=True)

    index = build_index(input_path)
    states: dict[str, list[dict]] = {}
    for station in index["stations"]:
        station["s"] = _canonical_state(station["s"]) or "Unknown"
        states.setdefault(station["s"], []).append(station)

    manifest_states = []
    for state, stations in sorted(states.items(), key=lambda item: item[0]):
        slug = re.sub(r"[^a-z0-9]+", "_", state.casefold()).strip("_")
        filename = f"{slug or 'unknown'}.json"
        state_payload = {
            "source": index["source"],
            "sourceUrl": index["sourceUrl"],
            "asOf": index["asOf"],
            "stationCount": len(stations),
            "stations": stations,
        }
        (output_directory / filename).write_text(
            json.dumps(state_payload, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
        manifest_states.append(
            {"name": state, "asset": f"assets/data/bee/{filename}", "count": len(stations)}
        )

    manifest = {
        "source": index["source"],
        "sourceUrl": index["sourceUrl"],
        "asOf": index["asOf"],
        "stationCount": index["stationCount"],
        "tableRowCount": index["tableRowCount"],
        "skippedRowCount": index["skippedRowCount"],
        "states": manifest_states,
    }
    (output_directory / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(
        f"Created {len(manifest_states)} state indexes in {output_directory} "
        f"with {index['stationCount']} stations from "
        f"{index['tableRowCount']} table rows; "
        f"{index['skippedRowCount']} rows skipped.",
        flush=True,
    )


if __name__ == "__main__":
    main()
