# lib/repositories/path_repository.dart

## Purpose
Reads and writes the campus walking-path graph used for in-app navigation/routing, plus surveyed location coordinates.

## Key members
- `PathRepository(FirebaseFirestore)` — targets the single document `campusPaths/graph`.
- `watchGraph()` — streams the graph document, mapped via `CampusGraph.fromMap`.
- `fetchGraph()` — one-shot fetch.
- `saveGraph(CampusGraph)` — admin-only write from the survey screen, stamps `updatedAt`.
- `setLocationCoordinates({locationId, lat, lng, accuracyMetres})` — merge-writes `geo`, `geoAccuracyMetres`, `geoRecordedAt` onto a `campusLocations/{id}` document.

## Dependencies & relationships
Imports `failure_mapper.dart` and `CampusGraph` model. Consumed by Map/navigation routing logic and an admin survey screen for recording walkable paths and location geo-coordinates.

## Notable behavior / gotchas
- The entire graph is stored as one small document deliberately, relying on Firestore's offline persistence (enabled in `main.dart`) so routing works offline with no custom caching code.
- `setLocationCoordinates` writes to the `campusLocations` collection directly (not through `LocationRepository`), despite being a PathRepository method.
