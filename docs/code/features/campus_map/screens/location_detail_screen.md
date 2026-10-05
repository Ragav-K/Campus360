# lib/features/campus_map/screens/location_detail_screen.dart

## Purpose
Shows full details for one campus location: identity, live Pulse status, open hours, and a way to start navigation.

## Key members
- `LocationDetailScreen` — `ConsumerWidget` that loads `locationDetailProvider(locationId)` and renders loading/empty/data states via `AsyncValueView`; shows "Location not found" when the location has been removed.
- `_Body` — renders the location's icon, name, category, a tappable live-Pulse-status card (if any), description, building/floor/room rows, open-hours table, and either a "Navigate here" button or an explanation that the place isn't mapped yet.
- `_Row` — simple icon/label/value row used for metadata fields.

## Dependencies & relationships
Watches `locationDetailProvider` (from `location_providers.dart`) and `locationPulseProvider` (from `campus_pulse/providers/pulse_providers.dart`) — this is the Map↔Pulse integration point. Navigates via `go_router` to `Routes.pulseDetail` and `Routes.navigate`. Uses shared widgets `AsyncValueView`, `EmptyState`, `StatusChip`, `CButton`.

## Notable behavior / gotchas
Open/closed status is tri-state (`null`/`true`/`false`) and explicitly renders "Not listed" rather than implying "closed" when hours aren't recorded. If the location has no coordinates, the navigate button is replaced with explanatory text instead of a button that would fail. `ref.watch(clockTickProvider)` keeps the open/closed state fresh over time.
