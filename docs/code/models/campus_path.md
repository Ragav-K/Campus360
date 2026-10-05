# lib/models/campus_path.dart

## Purpose
Pure-Dart walking-network graph and A* pathfinding over campus nodes/edges, used for offline, on-device walking directions (no external routing API is possible offline).

## Key members
- `haversineMetres(lat1, lng1, lat2, lng2)` — great-circle distance helper.
- `PathNode` class — `id`, `lat`, `lng`, `name`; `distanceTo`, `fromMap`/`toMap`.
- `CampusGraph` class — holds `nodes` and undirected `edges` (`List<({String a, String b})>`) plus a derived adjacency map.
  - `nodeById`, `nearestNode(lat, lng, {maxMetres})`, `route({fromLat, fromLng, toLat, toLng})` — returns ordered `List<PathNode>?` or null if unroutable.
  - `_aStar`/`_reconstruct` — A* shortest path using straight-line heuristic.
  - `routeLength(List<PathNode>)` static — total route distance.
  - `neighboursOf`, `hasEdge`.
  - Immutable editing: `withNode`, `withoutNode`, `withEdge`, `withoutEdge` — each returns a new `CampusGraph`.
  - `fromMap`/`toMap` — Firestore (de)serialization.
- `walkingTime(double metres)` — estimates `Duration` at ~1.35 m/s.

## Dependencies & relationships
Imports `dart:collection` (`SplayTreeSet`) and `dart:math`. No Firebase/Flutter dependency by design — fully unit-testable and runs offline. Maps to a campus walking-graph document (e.g. `campusGraph/{id}` or similar config doc) consumed by the Map feature's survey/editing screen and the turn-by-turn/route-drawing UI.

## Notable behavior / gotchas
Dangling edges (referencing deleted nodes) are tolerated when reading but stripped on `withoutNode`. `route` returns null both when an endpoint can't snap to the network and when the two ends are in disconnected graph components — callers must draw a "no path" fallback rather than assume a straight line is a real route. All editing methods are non-mutating (return a new graph) since the survey screen persists the whole graph at once.
