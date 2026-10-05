# test/survey_paths_widget_test.dart

## Purpose
Widget tests for the Paths tab of `lib/features/admin/screens/survey_screen.dart` (`SurveyScreen`), the admin tool for editing the campus walking-path graph (`CampusGraph`) used by map navigation.

## Test cases
- "an empty network explains what to do rather than showing a blank map" — empty graph shows "No paths yet" and "0 points · 0 connections".
- "counts the network it is editing" — shows correct point/connection counts for a 3-node path.
- "offers dropping a point and starting a separate path" — action buttons present.
- "draws a tappable dot for every point on the network" — each node renders a `path-node-<id>` keyed widget.
- "selecting a point offers the editing actions" — tapping a dot shows "Join to…", "Delete", "Continue from here".
- "a selected point says how many connections it has" — panel text reports connection count for the middle node.
- "an unconnected point is called out as unroutable" — isolated node shows "Not connected to anything" and hides "Disconnect…".
- "deleting warns that a mid-path point splits the path" — confirmation dialog mentions edges lost and path splitting.
- "cancelling the delete writes nothing" — tapping "Keep" leaves `repo.saved` null.
- "confirming the delete removes the point and its edges" — saved graph has the node and both its edges removed.
- "joining asks which point to join to before doing anything" — nothing is saved until a second point is tapped.
- "joining two points writes the new edge" — saved graph gains the new edge without adding nodes.

## Dependencies & relationships
Renders `SurveyScreen` in a `ProviderScope` overriding `pathRepositoryProvider` (with a custom `_FakePathRepository` that records `saveGraph` calls instead of hitting Firestore), `tileCacheProvider` (pointed at a temp directory, avoiding the `path_provider` plugin channel), `campusGraphProvider`, `mappedLocationsProvider`, `positionStreamProvider`, and `allLocationsProvider`. Uses `CampusGraph`/`PathNode` fixtures (`_run()`, `_node()`).

## Notable behavior / gotchas
Taps on map dots are driven by directly invoking the `GestureDetector.onTap` callback rather than `tester.tap`, because flutter_map's rendering transform disagrees with hit-testing in widget tests — so the real on-device gesture itself is untested here, only the callback logic. Uses manual `_settle()` (a few fixed `pump` calls) instead of `pumpAndSettle`, because the map's tile layer keeps retrying failed fetches and never goes idle in a test environment.
