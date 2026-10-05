# Admin

Screen: `lib/features/admin/screens/survey_screen.dart` (`SurveyScreen`)
Reuses: `lib/features/campus_map/providers/{location_providers,navigation_providers}.dart`,
`lib/repositories/path_repository.dart`, `lib/core/services/location_service.dart`
Route: `Routes.adminSurvey` (`/admin/survey`), gated to `UserRole.admin` by the router

The only admin-only screen in the codebase today is the **Campus survey**
tool — everything else admin-related referenced in `routes.dart`
(`adminPulse`, `adminLocations`, `adminLostFound`, `adminShops`,
`adminUsers`, `adminAnalytics`) is a reserved route without an implemented
screen yet. Admin write access to Pulse (`PulseRepository.create/update/...`)
and to print shop/location management happens through the respective
feature repositories, enforced by Firestore rules rather than a dedicated
admin UI (see `campus-pulse.md`).

## The survey flow

The campus map depends entirely on this tool: a `campusLocations` document
has no position, and the walking-path graph has no nodes, until someone
physically walks the campus running it.

1. **Places tab.** Lists every `campusLocations` document
   (`allLocationsProvider`), showing a checkmark for ones that already have
   coordinates and `unmappedCountProvider`'s count in the tab label for ones
   that don't.
2. **Recording a place's coordinates.** Standing at the location, the admin
   taps "Record here". `LocationService.currentPosition()` gets a GPS fix;
   if its accuracy is worse than `AppConfig.surveyMaxAccuracyMetres`, the
   reading is **rejected** with a prompt to move into the open — a vague fix
   is treated as worse than none, since it would place the pin on the wrong
   building while looking authoritative. A good fix is written via
   `PathRepository.setLocationCoordinates(locationId, lat, lng, accuracyMetres)`.
3. **Paths tab.** Builds the walking-path graph (`CampusGraph`: `PathNode`s +
   edges) that `navigation_providers.dart` later routes over.
   - **Drop a point:** walking the campus, the admin drops a `PathNode` at
     the current GPS fix (same accuracy gate as above), optionally
     auto-joined to the last point dropped (`_lastNodeId`) so a continuous
     walk becomes a connected path. "Start a new path" clears `_lastNodeId`
     so a separate walkway isn't accidentally joined to the previous one
     through a wall.
   - **Join / disconnect:** tap-select two existing points on the map, then
     `PathRepository.saveGraph(graph.withEdge(...))` /
     `withoutEdge(...)` to connect or disconnect them.
   - **Delete a point:** removes a `PathNode` and its edges; if it sits
     mid-path this splits the path in two, and the confirmation dialog warns
     of that before committing.
   - Every edit re-reads the graph (`PathRepository.fetchGraph()`)
     immediately before transforming and saving it, deliberately, since the
     whole graph is one Firestore document — editing a copy that went stale
     while the screen was open would silently discard anything surveyed by
     someone else in the meantime.
