# lib/repositories/location_repository.dart

## Purpose
Reads and writes the `campusLocations` collection (map points of interest), used for the campus Map feature.

## Key members
- `LocationRepository(FirebaseFirestore)` — targets `Paths.campusLocations`.
- `watchAll()` — streams all active locations ordered by name; search/filtering happens client-side in memory.
- `watchOne(id)` / `fetchOne(id)` — stream/future a single location.
- `create(CampusLocation)` — admin write, adds a new document.
- `update(CampusLocation)` — admin write, merge-set by id.
- `setActive(id, active)` — toggles `isActive`.
- `_toMap` / `_fromDoc` — model <-> Firestore map conversion (handles nested `geo` and `openHours`).

## Dependencies & relationships
Imports `firestore_paths.dart`, `failure_mapper.dart`, `CampusLocation` model, `LocationCategory` enum. Consumed by Map feature providers/screens and admin location-management screens.

## Notable behavior / gotchas
- Deliberately streams the *entire* active collection once rather than querying per keystroke, since the full set is small — documented as a performance/cost tradeoff (one listener instead of many queries).
- `watchAll` filters `isActive == true` and orders by name server-side; category/search filtering is client-side.
