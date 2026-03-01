#!/usr/bin/env python3
"""Build TrackBound rail edge seed from public map data.

Primary source: OpenStreetMap rail ways via Overpass API.
Optional sources: extra GeoJSON files and OpenTrainTimes-derived CSV exports.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

import requests

Coord = Tuple[float, float]  # (lat, lng)

OVERPASS_URL = "https://overpass-api.de/api/interpreter"


def parse_bbox(text: str) -> Tuple[float, float, float, float]:
    parts = [p.strip() for p in text.split(",")]
    if len(parts) != 4:
        raise ValueError("bbox must be south,west,north,east")
    south, west, north, east = [float(p) for p in parts]
    return south, west, north, east


def edge_key(a: Coord, b: Coord) -> str:
    a_key = f"{a[0]:.6f},{a[1]:.6f}"
    b_key = f"{b[0]:.6f},{b[1]:.6f}"
    return f"{a_key}|{b_key}" if a_key <= b_key else f"{b_key}|{a_key}"


def add_polyline(points: Iterable[Coord], edges: Dict[str, Dict]) -> None:
    pts = list(points)
    if len(pts) < 2:
        return
    for i in range(len(pts) - 1):
        a = pts[i]
        b = pts[i + 1]
        if a == b:
            continue
        key = edge_key(a, b)
        if key in edges:
            continue
        edges[key] = {
            "edge_key": key,
            "start_lat": a[0],
            "start_lng": a[1],
            "end_lat": b[0],
            "end_lng": b[1],
            "source_route_id": None,
            "travelled": 0,
        }


def fetch_osm_rail_lines(bbox: Tuple[float, float, float, float], timeout: int = 90) -> List[List[Coord]]:
    south, west, north, east = bbox
    query = f"""
[out:json][timeout:60];
(
  way["railway"~"rail|light_rail|subway|tram|narrow_gauge"]({south},{west},{north},{east});
);
out geom;
"""
    response = requests.post(OVERPASS_URL, data={"data": query}, timeout=timeout)
    response.raise_for_status()
    data = response.json()

    lines: List[List[Coord]] = []
    for element in data.get("elements", []):
        if element.get("type") != "way":
            continue
        geom = element.get("geometry") or []
        points: List[Coord] = []
        for node in geom:
            lat = node.get("lat")
            lon = node.get("lon")
            if lat is None or lon is None:
                continue
            points.append((float(lat), float(lon)))
        if len(points) >= 2:
            lines.append(points)
    return lines


def parse_geojson_lines(path: Path) -> List[List[Coord]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    features = data.get("features", []) if isinstance(data, dict) else []

    lines: List[List[Coord]] = []
    for feature in features:
        if not isinstance(feature, dict):
            continue
        geom = feature.get("geometry")
        if not isinstance(geom, dict):
            continue
        gtype = geom.get("type")
        coords = geom.get("coordinates")

        if gtype == "LineString" and isinstance(coords, list):
            line = _coords_to_line(coords)
            if line:
                lines.append(line)
        elif gtype == "MultiLineString" and isinstance(coords, list):
            for line_coords in coords:
                if isinstance(line_coords, list):
                    line = _coords_to_line(line_coords)
                    if line:
                        lines.append(line)
    return lines


def _coords_to_line(coords: List) -> Optional[List[Coord]]:
    points: List[Coord] = []
    for c in coords:
        if not isinstance(c, list) or len(c) < 2:
            continue
        lng = float(c[0])
        lat = float(c[1])
        points.append((lat, lng))
    return points if len(points) >= 2 else None


def parse_wkt_linestring(text: str) -> Optional[List[Coord]]:
    raw = text.strip()
    if not raw.upper().startswith("LINESTRING"):
        return None
    start = raw.find("(")
    end = raw.rfind(")")
    if start == -1 or end == -1 or end <= start:
        return None
    parts = [p.strip() for p in raw[start + 1 : end].split(",")]

    points: List[Coord] = []
    for part in parts:
        comps = [c for c in part.split() if c]
        if len(comps) < 2:
            continue
        lng = float(comps[0])
        lat = float(comps[1])
        points.append((lat, lng))
    return points if len(points) >= 2 else None


def parse_opentraintimes_csv(path: Path) -> List[List[Coord]]:
    lines: List[List[Coord]] = []
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if not isinstance(row, dict):
                continue

            wkt = (row.get("geometry_wkt") or "").strip()
            if wkt:
                line = parse_wkt_linestring(wkt)
                if line:
                    lines.append(line)
                    continue

            try:
                slat = float(row["start_lat"])
                slng = float(row["start_lng"])
                elat = float(row["end_lat"])
                elng = float(row["end_lng"])
            except Exception:
                continue
            lines.append([(slat, slng), (elat, elng)])
    return lines


def build_seed(
    bbox: Tuple[float, float, float, float],
    extra_geojson: List[Path],
    opentraintimes_csv: Optional[Path],
) -> List[Dict]:
    edges: Dict[str, Dict] = {}

    osm_lines = fetch_osm_rail_lines(bbox)
    for line in osm_lines:
        add_polyline(line, edges)

    for path in extra_geojson:
        for line in parse_geojson_lines(path):
            add_polyline(line, edges)

    if opentraintimes_csv:
        for line in parse_opentraintimes_csv(opentraintimes_csv):
            add_polyline(line, edges)

    result = sorted(edges.values(), key=lambda x: x["edge_key"])
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="Build TrackBound rail edge seed from public map data")
    parser.add_argument("--bbox", required=True, help="south,west,north,east")
    parser.add_argument("--output", required=True, help="output JSON path")
    parser.add_argument(
        "--extra-geojson",
        action="append",
        default=[],
        help="optional GeoJSON file with LineString/MultiLineString data (repeatable)",
    )
    parser.add_argument(
        "--opentraintimes-csv",
        default=None,
        help="optional OpenTrainTimes-derived CSV with edge coordinates or WKT",
    )

    args = parser.parse_args()

    bbox = parse_bbox(args.bbox)
    output_path = Path(args.output)
    extra_geojson = [Path(p) for p in args.extra_geojson]
    opentraintimes_csv = Path(args.opentraintimes_csv) if args.opentraintimes_csv else None

    seed = build_seed(bbox=bbox, extra_geojson=extra_geojson, opentraintimes_csv=opentraintimes_csv)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(seed, indent=2), encoding="utf-8")

    print(f"Wrote {len(seed)} edges to {output_path}")


if __name__ == "__main__":
    main()
