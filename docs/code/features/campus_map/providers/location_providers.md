# lib/features/campus_map/providers/location_providers.dart

## Purpose
Riverpod providers for campus locations: fetching, in-memory search/category filtering, and derived lists for the map and directory UI.

## Key members
- `locationRepositoryProvider` — builds a `LocationRepository` from Firestore.
- `allLocationsProvider` (`StreamProvider`) — all active campus locations; kept alive (not autoDispose) since the whole app links into it.
- `locationDetailProvider` (`StreamProvider.autoDispose.family<CampusLocation?, String>`) — a single location by id.
- `locationSearchProvider` / `locationCategoryFilterProvider` (`StateProvider`) — current search text and selected category chip.
- `filteredLocationsProvider` — `allLocationsProvider` narrowed by search + category, with prefix matches ranked first.
- `locationFilterActiveProvider` — true when a search or category filter is active.
- `availableLocationCategoriesProvider` — only the categories actually present in the data, so filter chips never return empty results.

## Dependencies & relationships
Imports `LocationRepository`, `CampusLocation`, `LocationCategory`, and `firestoreProvider`. Consumed by `map_home_screen.dart`, `location_detail_screen.dart`, `location_tile.dart`, and `navigation_providers.dart` (for routing targets).

## Notable behavior / gotchas
Filtering/sorting happens entirely in memory over the already-fetched list rather than re-querying Firestore, to keep typing responsive and avoid per-keystroke reads. Search ranks locations whose name starts with the query above other matches.
