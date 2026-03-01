# TrackBound

TrackBound is a Flutter app for railway enthusiasts to log, visualise and share train journeys.

## Map controls

- `Draw` (floating button): enter/exit route drawing mode.
- `Save` (floating button): save current draft line as a route and rail-edge segments.
- `Snap` (app bar route icon): snap drawing taps to nearest rail/route geometry.
- `Rail Overlay` (app bar rail icon): show/hide the rail network overlay.
- `Mark Travelled` (app bar checklist icon): tap near a rail edge to toggle travelled status.
- `Help` (app bar `?` icon): opens control reference dialog.
- `Refresh` (app bar refresh icon): reload all map data from the database.

## Bundled rail network seed

- The app ships with precomputed rail edges in `assets/rail/rail_edges_seed.json`.
- On first run (or if DB has no rail edges), the seed is loaded into SQLite automatically.

## Build seed from GeoJSON

Use this script to convert imported rail line GeoJSON into bundled edge segments:

```bash
dart run tool/build_rail_seed.dart <input.geojson> assets/rail/rail_edges_seed.json
```

Then rebuild the app so updated seed data is bundled.
