# lib/features/admin/screens/survey_screen.dart

## Purpose
Admin-only tool for field-surveying real campus GPS coordinates for locations and for building the walking-path graph used by map navigation.

## Key members
- `SurveyScreen` — tabbed screen (Places / Paths) hosting the survey workflow.
- `_PlacesTab` / `_PlacesTabState` — lists campus locations and lets the surveyor stand at a place and record its GPS coordinates via a button.
- `_PathsTab` / `_PathsTabState` — interactive map for dropping path nodes while walking, joining/disconnecting nodes, and deleting nodes, backed by a `CampusGraph`.
- `_TapMode` enum — tracks whether the next map tap selects, joins, or disconnects a node.
- `_SurveyHelp`, `_PlaceRow`, `_SelectedNodePanel`, `_NodeAction`, `_MapNotice` — supporting presentational widgets.

## Dependencies & relationships
Uses `locationServiceProvider` (GPS), `pathRepositoryProvider` (persists `CampusGraph`/location coordinates), `allLocationsProvider`, `unmappedCountProvider`, `campusGraphProvider`, `mappedLocationsProvider`, `tileCacheProvider`, `positionStreamProvider` from `campus_map` feature providers. Renders map via `CampusMapView`. Uses shared widgets `AsyncValueView`, `CButton`, `EmptyState`, and `describeFailure` for error display.

## Notable behavior / gotchas
- GPS fixes worse than `AppConfig.surveyMaxAccuracyMetres` are rejected to avoid placing inaccurate pins.
- Every graph edit re-fetches the graph before transforming and saving it, to avoid clobbering concurrent surveyor edits.
- Deleting a selected node that no longer exists (deleted elsewhere) is detected post-frame and clears the selection.
- `_lastNodeId` tracks the "continue from here" anchor so consecutive dropped points auto-join; "Start a new path" clears it intentionally.
