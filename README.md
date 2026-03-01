# TrackBound

TrackBound is a Flutter app for railway enthusiasts to log, visualise and share train journeys.

## Map controls

- `Rail Overlay` (app bar rail icon): show/hide the rail network overlay.
- `Mark Travelled` (app bar checklist icon): tap near a rail edge to toggle travelled status.
- `Reset Progress` (app bar restart icon): set all rail segments to untravelled.
- `Help` (app bar `?` icon): opens control reference dialog.
- `Refresh` (app bar refresh icon): reload all map data from the database.

## Current status

- Direct map drawing is deprecated and not available in the current UI.
- Route progression is tracked by rail-edge toggling on the bundled/imported rail network.

## Bundled rail network seed

- The app ships with precomputed rail edges in `assets/rail/rail_edges_seed.json`.
- The seed is loaded into SQLite automatically and reseeded when the bundled seed fingerprint/count changes.
- A seed schema version check is also applied, so compatibility fixes can force a one-time reseed across installs.
- Seed rows may be grouped into station/junction-split progression segments via `source_route_id`.
- In map `Mark Travelled` mode, tapping toggles the whole segment group when available.
- Map `Refresh` forces a reseed check and reloads map data without requiring app reinstall/reset.

## Build seed from GeoJSON

Use this script to convert imported rail line GeoJSON into bundled edge segments:

```bash
dart run tool/build_rail_seed.dart <input.geojson> assets/rail/rail_edges_seed.json
```

Then rebuild the app so updated seed data is bundled.

## External rail model builder (public data)

For larger/production rail models, use the standalone builder in `tools/rail_model_builder`.
It can fetch OSM rail geometry from Overpass, merge extra GeoJSON, and merge OpenTrainTimes-derived CSV data.

```bash
python tools/rail_model_builder/build_rail_model.py \
	--bbox 49.8,-8.6,60.9,1.8 \
	--output assets/rail/rail_edges_seed.json
```


After regenerating the seed, rebuild/redeploy the app so the updated asset is bundled, then use map `Refresh` to apply it immediately.
