# test/campus_graph_test.dart

## Purpose
Tests `lib/models/campus_path.dart` — `CampusGraph`/`PathNode`, including distance math, nearest-node snapping, pathfinding (routing), length/time estimates, serialization, and graph editing operations.

## Test cases
- **haversineMetres**: zero for identical points; matches a known ~111.2 m per 0.001° latitude; symmetric in argument order.
- **nearestNode**: snaps to the closest node within range; refuses to snap when nothing is nearby (Chennai test); returns null / `isEmpty` true on an empty graph.
- **route**: follows the only available path rather than a straight line; prefers a direct edge once one exists; returns a single-node path when start/destination snap together; returns null across disconnected components; returns null with no edges; ignores edges pointing at deleted ("ghost") nodes.
- **routeLength and walkingTime**: sums leg distances; a single-node route has zero length; `walkingTime` computes seconds from metres at ~1.35 m/s, zero for zero distance.
- **serialisation**: round-trips via `toMap`/`fromMap`; a null/missing document yields an empty graph rather than throwing; malformed node/edge entries are skipped rather than fatal.
- **editing**: `withNode` adds an unconnected point, or joins it via `connectTo`; `withoutNode` removes a node and its edges; deleting a mid-path node severs routing through it; `withEdge` adds an edge (undirected) and rejects self-edges/unknown nodes/duplicate edges; `withoutEdge` removes a link but keeps both nodes; edits are immutable (don't mutate the original graph); an edited graph survives save-and-reload.

## Dependencies & relationships
Exercises `CampusGraph`, `PathNode`, `haversineMetres`, `walkingTime` directly. Uses a hand-built grid fixture (`_grid()`) simulating a small campus layout with real-world-like coordinates; no mocks.

## Notable behavior / gotchas
Routing deliberately returns null instead of inventing a path across disconnected components or dangling edges, so callers must fall back to a straight line. Edits (`withNode`, `withEdge`, etc.) are non-mutating/pure.
