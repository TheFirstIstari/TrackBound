#!/usr/bin/env python3
"""Build TrackBound rail edge seed from public map data.

Primary source: OpenStreetMap rail ways via Overpass API.
Optional sources: extra GeoJSON files and OpenTrainTimes-derived CSV exports.

Important: output edges are grouped by `source_route_id` segment groups,
where each group is split at junctions and station-adjacent nodes.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple

import requests

Coord = Tuple[float, float]  # (lat, lng)
NodeKey = str
EdgeTuple = Tuple[NodeKey, NodeKey]

OVERPASS_URL = "https://overpass-api.de/api/interpreter"


def parse_bbox(text: str) -> Tuple[float, float, float, float]:
    parts = [p.strip() for p in text.split(",")]
    if len(parts) != 4:
        raise ValueError("bbox must be south,west,north,east")
    south, west, north, east = [float(p) for p in parts]
    return south, west, north, east


def node_key(c: Coord) -> NodeKey:
    return f"{c[0]:.6f},{c[1]:.6f}"


def coord_from_key(key: NodeKey) -> Coord:
    lat, lng = key.split(",")
    return float(lat), float(lng)


def edge_key(a: Coord, b: Coord) -> str:
    a_key = node_key(a)
    b_key = node_key(b)
    return f"{a_key}|{b_key}" if a_key <= b_key else f"{b_key}|{a_key}"


def canonical_edge(a: NodeKey, b: NodeKey) -> EdgeTuple:
    return (a, b) if a <= b else (b, a)


def haversine_m(a: Coord, b: Coord) -> float:
    r = 6371000.0
    lat1 = math.radians(a[0])
    lon1 = math.radians(a[1])
    lat2 = math.radians(b[0])
    lon2 = math.radians(b[1])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * (math.sin(dlon / 2) ** 2)
    return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h))


def fetch_osm_rail_lines_and_stations(
    bbox: Tuple[float, float, float, float], timeout: int = 120
) -> Tuple[List[List[Coord]], List[Coord]]:
    south, west, north, east = bbox
    query = f"""
[out:json][timeout:90];
(
  way["railway"~"rail|light_rail|subway|tram|narrow_gauge"]({south},{west},{north},{east});
  node["railway"~"station|halt|tram_stop"]({south},{west},{north},{east});
);
out geom;
"""
    response = requests.post(OVERPASS_URL, data={"data": query}, timeout=timeout)
    response.raise_for_status()
    data = response.json()

    lines: List[List[Coord]] = []
    stations: List[Coord] = []
    for element in data.get("elements", []):
        etype = element.get("type")
        if etype == "way":
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
        elif etype == "node":
            lat = element.get("lat")
            lon = element.get("lon")
            if lat is not None and lon is not None:
                stations.append((float(lat), float(lon)))

    return lines, stations


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


def build_graph(lines: Iterable[List[Coord]]) -> Tuple[Dict[NodeKey, Set[NodeKey]], Set[EdgeTuple]]:
    adjacency: Dict[NodeKey, Set[NodeKey]] = {}
    edges: Set[EdgeTuple] = set()

    for line in lines:
        if len(line) < 2:
            continue
        keys = [node_key(p) for p in line]
        for i in range(len(keys) - 1):
            a = keys[i]
            b = keys[i + 1]
            if a == b:
                continue
            e = canonical_edge(a, b)
            if e in edges:
                continue
            edges.add(e)
            adjacency.setdefault(a, set()).add(b)
            adjacency.setdefault(b, set()).add(a)

    return adjacency, edges


def station_break_nodes(
    adjacency: Dict[NodeKey, Set[NodeKey]], stations: List[Coord], threshold_m: float
) -> Set[NodeKey]:
    node_coords = {k: coord_from_key(k) for k in adjacency.keys()}
    breaks: Set[NodeKey] = set()
    if not stations:
        return breaks

    node_items = list(node_coords.items())
    for station in stations:
        best_key: Optional[NodeKey] = None
        best_dist = float("inf")
        for key, coord in node_items:
            d = haversine_m(station, coord)
            if d < best_dist:
                best_dist = d
                best_key = key
        if best_key is not None and best_dist <= threshold_m:
            breaks.add(best_key)
    return breaks


def segment_graph(
    adjacency: Dict[NodeKey, Set[NodeKey]],
    edges: Set[EdgeTuple],
    extra_break_nodes: Set[NodeKey],
) -> List[List[NodeKey]]:
    if not edges:
        return []

    degree_breaks = {node for node, neighbors in adjacency.items() if len(neighbors) != 2}
    breaks = degree_breaks | extra_break_nodes
    visited: Set[EdgeTuple] = set()
    segments: List[List[NodeKey]] = []

    def walk_segment(start_node: NodeKey, next_node: NodeKey) -> List[NodeKey]:
        path = [start_node, next_node]
        prev = start_node
        cur = next_node

        while True:
            e = canonical_edge(prev, cur)
            visited.add(e)

            if cur in breaks and cur != start_node:
                break

            neighbors = adjacency.get(cur, set())
            candidates = [n for n in neighbors if n != prev and canonical_edge(cur, n) not in visited]
            if not candidates:
                break

            nxt = candidates[0]
            path.append(nxt)
            prev, cur = cur, nxt

            if cur == start_node:
                break

        return path

    start_nodes = [n for n in adjacency.keys() if n in breaks] + [n for n in adjacency.keys() if n not in breaks]
    for node in start_nodes:
        for neighbor in adjacency.get(node, set()):
            e = canonical_edge(node, neighbor)
            if e in visited:
                continue
            seg = walk_segment(node, neighbor)
            if len(seg) >= 2:
                segments.append(seg)

    for a, b in edges:
        if (a, b) not in visited:
            segments.append([a, b])

    return segments


def segments_to_seed(segments: List[List[NodeKey]]) -> List[Dict]:
    rows: Dict[str, Dict] = {}
    segment_id = 1
    for seg in segments:
        if len(seg) < 2:
            continue
        for i in range(len(seg) - 1):
            a = coord_from_key(seg[i])
            b = coord_from_key(seg[i + 1])
            if a == b:
                continue
            key = edge_key(a, b)
            if key in rows:
                continue
            rows[key] = {
                "edge_key": key,
                "start_lat": a[0],
                "start_lng": a[1],
                "end_lat": b[0],
                "end_lng": b[1],
                "source_route_id": segment_id,
                "travelled": 0,
            }
        segment_id += 1

    return sorted(rows.values(), key=lambda x: x["edge_key"])


def build_seed(
    bbox: Tuple[float, float, float, float],
    extra_geojson: List[Path],
    opentraintimes_csv: Optional[Path],
    station_snap_m: float,
) -> List[Dict]:
    osm_lines, stations = fetch_osm_rail_lines_and_stations(bbox)
    all_lines = list(osm_lines)

    for path in extra_geojson:
        all_lines.extend(parse_geojson_lines(path))

    if opentraintimes_csv:
        all_lines.extend(parse_opentraintimes_csv(opentraintimes_csv))

    adjacency, edges = build_graph(all_lines)
    extra_breaks = station_break_nodes(adjacency, stations, station_snap_m)
    segments = segment_graph(adjacency, edges, extra_breaks)
    return segments_to_seed(segments)


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
    parser.add_argument(
        "--station-snap-m",
        type=float,
        default=120.0,
        help="max meters to snap station points onto nearest graph node for segmentation",
    )

    args = parser.parse_args()

    bbox = parse_bbox(args.bbox)
    output_path = Path(args.output)
    extra_geojson = [Path(p) for p in args.extra_geojson]
    opentraintimes_csv = Path(args.opentraintimes_csv) if args.opentraintimes_csv else None

    seed = build_seed(
        bbox=bbox,
        extra_geojson=extra_geojson,
        opentraintimes_csv=opentraintimes_csv,
        station_snap_m=args.station_snap_m,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(seed, indent=2), encoding="utf-8")

    print(f"Wrote {len(seed)} edges to {output_path}")


if __name__ == "__main__":
    main()
