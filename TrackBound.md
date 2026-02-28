App Name:
Trackbound

1. Executive Summary
App Goal: To provide railway enthusiasts, with a dedicated Android application built with Flutter, named Trackbound, to meticulously log, visualize, and share their past and present train journeys. The app aims to be intuitive, visually engaging, and highly functional for tracking specific train routes and their segments.

Target Audience: Railway enthusiasts, trainspotters, frequent train travelers, and anyone interested in mapping their rail adventures.

1. Core Features (MVP - Minimum Viable Product)
2.1. Journey Logging
Manual Journey Entry: Users can manually input details for each journey.
Required Details: Date of Travel, Start Station, End Station.
Highly Desired Optional Details (already defined): Train Operator, Train Number, Class of Service, Journey Notes, Photos/Videos.
NEW - Train/Route Selection:
Train Database: The app will incorporate a database of common/named train services (e.g., "Caledonian Sleeper," "Coast Starlight," "Shinkansen Nozomi") or potentially general service lines (e.g., "Eurostar service London-Paris"). This database could be:
Pre-loaded for major services.
User-definable (allowing users to add a new train service/route, potentially with its full path if they draw/import it).
Potentially fetched from an external (open-source) API if available and reliable.
Searchable List/Menu: Users can select a specific train/service from a searchable list.
Route Segment Selection: Once a train/service is selected, its known full route (if available in the database) will be displayed. Users can then visually select the specific segment(s) they traveled along that route using start and end points on the pre-defined path. This provides more granular route capture than just Start-End stations.
Station Database (Revised to support Train Routes):
Hybrid approach (as before): Suggest from database, allow custom input.
Integration with Train Routes: Stations in the database should ideally have geographical coordinates. When a user logs a journey on a specific train service, the start and end stations chosen for their specific segment will correspond to points on the selected train's full predefined route.
Route Definition (Revised):
Primary Method (MVP Focus): Selecting segments of pre-defined train routes. This is the core of your new requirement.
Fallback Method: For custom or less-known journeys, users can still define the route using:
"Start -> End" with an optional "via" text field.
Manually drawing a route segment on the map (as a future enhancement, but the architecture should allow for this data type).
2.2. Journey Visualization (Map Integration)
Offline Map Caching: OpenStreetMap/OpenRailwayMap tiles with offline caching.
Journey Overlay (Enhanced): Display logged journeys as colored lines on the map.
Precision: When a user selected a segment of a named train's route, the app will precisely highlight that segment on the map using the predefined route geometry.
Filtering: Users can filter which journeys are displayed (e.g., by date, operator, train service, mode, train class).
Station Markers: Display all visited stations as pin markers.
Full Train Routes Overlay (Optional): Users could optionally toggle on visibility of the full route of a selected train service, even for segments they haven't traveled, for context.
2.3. Statistics & Analytics (Enhanced)
Basic Statistics: Total distance traveled, number of unique stations visited, number of journeys, etc.
Filters/Toggles: Allow filtering statistics by date range, train operator, region.
NEW - Granular Statistics and Maps:
Per Operator: Visualize total distance, number of journeys, and map of routes traveled with each specific train operator.
Per Mode: (e.g., "High-Speed Rail," "Regional Commuter," "Sleeper Train" - this would need to be a field in the journey entry). Show stats and routes for each mode used.
Per Train/Service: Display specific statistics (e.g., how many times a user has traveled on the "Flying Scotsman" route, or specific segments of it) and show the mapped segments for each particular train service.
Per Train Class: (e.g., "First Class," "Standard Class"). Statistics and mapped routes for each class of service.
Visualizations: Charts (bar, pie).
Future Enhancement: GIF Export of route progression.
2.4. Data Management
Import/Export: JSON, CSV, GPX. Cloud Backup/Restore (Google Drive).
Privacy: Local data storage first.
1. Future Enhancements (Post-MVP)
Route Drawing Tool: An in-app tool for custom routes.
GPS Tracking: Live tracking.
Community Features.
Advanced Route Discovery.
Rich Media Integration.
Powerful Search/Filter.
Crowdsourced Train Route Data: Potentially, allow users to submit full train routes (as GPX tracks or drawn paths) for common services, or verify existing ones. This would significantly enrich the "Train Database" mentioned above.
1. Technical Architecture (Flutter Specific)
Framework: Flutter
Language: Dart
Architecture Pattern: Clean Architecture (Riverpod/BLoC).
Database:
Local Storage: sqflite (SQLite database). This will be crucial for storing:
User journey details.
Train Service Definitions: Table(s) for named train services, their operators, and crucially, their associated geometries (polylines) representing their full routes. These geometries can be stored as WKT (Well-Known Text) strings or BLOBs.
Station data with coordinates.
Geospatial Capabilities: SQLite with sqflite can handle basic geospatial queries by storing coordinates and polylines. More advanced geospatial indexing might require extensions, but for displaying lines and checking if a point is on a line, it's generally sufficient.
Mapping Library: flutter_map. This will be used to:
Display OSM/OpenRailwayMap tiles.
Render journey lines (polylines).
Allow interactive selection of route segments by clicking/touching points on a predefined train service polyline.
Networking: http or Dio for map tiles, potential initial train route data downloads, and cloud backup.
1. UI/UX Considerations
Train/Route Selection Flow: This needs to be very intuitive.
A clear search bar for train services.
Visual representation of the selected train's full route on a mini-map when choosing segments.
Easy "drag-and-drop" or "tap-to-select" for start and end points of the traveled segment on the route.
Statistics Dashboards: Clear and engaging dashboards with filters for operator, mode, train, and class.
Consistent Design: Material Design.
Clear Navigation.
Visual Feedback.
Offline First.