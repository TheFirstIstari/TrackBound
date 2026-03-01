# Rail Model Builder (External Tool)

Builds a packaged rail-edge model for TrackBound from public map data.

## Data Sources

- **Primary**: OpenStreetMap rail geometries via Overpass API.
- **Optional merge**: local GeoJSON line files.
- **Optional merge**: OpenTrainTimes-derived exports in CSV (if you manually export/prepare them).

## Install

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r tools/rail_model_builder/requirements.txt
```

## Usage

Generate UK rail edges from Overpass and write directly into the app seed asset:

```bash
python tools/rail_model_builder/build_rail_model.py \
  --bbox 49.8,-8.6,60.9,1.8 \
  --output assets/rail/rail_edges_seed.json
```

This builder splits the rail graph into progression segments at:
- rail junctions (graph nodes where degree != 2)
- station-adjacent nodes (snapped within a threshold)

Each output edge row is tagged with a segment group in `source_route_id` so TrackBound can colour/toggle whole segments.

Merge additional local line data (GeoJSON):

```bash
python tools/rail_model_builder/build_rail_model.py \
  --bbox 49.8,-8.6,60.9,1.8 \
  --extra-geojson data/manual_routes.geojson \
  --output assets/rail/rail_edges_seed.json
```

Merge an OpenTrainTimes-derived CSV export (manual source prep):

```bash
python tools/rail_model_builder/build_rail_model.py \
  --bbox 49.8,-8.6,60.9,1.8 \
  --opentraintimes-csv data/opentraintimes_edges.csv \
  --output assets/rail/rail_edges_seed.json
```

Tune station split snapping distance (meters):

```bash
python tools/rail_model_builder/build_rail_model.py \
  --bbox 49.8,-8.6,60.9,1.8 \
  --station-snap-m 120 \
  --output assets/rail/rail_edges_seed.json
```

## OpenTrainTimes CSV format

Supported columns:
- `start_lat`, `start_lng`, `end_lat`, `end_lng` (edge rows), OR
- `geometry_wkt` (LINESTRING lon lat, lon lat, ...)

## Notes

- Overpass has rate limits. For large areas, run in chunks and merge outputs.
- Output format matches TrackBound `rail_edges_seed.json` schema.
- `travelled` is always initialized as `0` in generated seed data.
