# lib/features/campus_map/screens/navigate_screen.dart

## Purpose
Full-screen walking navigation to a single campus location, working entirely offline (cached tiles, on-device route graph, GPS).

## Key members
- `NavigateScreen` (`ConsumerStatefulWidget`) — loads the destination via `locationDetailProvider`; handles not-found and "not mapped yet" cases before handing off to `_Navigator`.
- `_Navigator` — watches `positionStreamProvider` and `routeProvider`, renders the map with the live route, a "follow me" camera toggle, and the route info card; shows `_LocationProblem` when GPS fails.
- `_RouteCard` — bottom card showing destination name/category, distance, ETA, a note when the route is only a direct/straight line (not a real path), and the current GPS accuracy.
- `_LocationProblem` — error view for location/permission failures with a retry or "open settings" action depending on whether the failure is retryable.

## Dependencies & relationships
Uses `CampusMapView`, `locationDetailProvider`, `positionStreamProvider`, `routeProvider`, `formatDistance`/`formatEta`, and `TileCache`. Errors are classified through `AppFailure`/`FailureMapper`.

## Notable behavior / gotchas
When "follow me" is on, the map re-centres on the user's position every frame via `addPostFrameCallback` without fighting manual panning (follow can be toggled off). If the route is a direct line (no mapped path between the points), the UI explicitly says so rather than implying a real walking route. GPS accuracy is shown numerically rather than implying metre-level precision.
