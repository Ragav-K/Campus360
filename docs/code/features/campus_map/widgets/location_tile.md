# lib/features/campus_map/widgets/location_tile.dart

## Purpose
A reusable list row for a `CampusLocation` that also surfaces its live Campus Pulse status and open/closed state.

## Key members
- `LocationTile` (`ConsumerWidget`) — renders the location's icon, name, subtitle, an optional `StatusChip.pulse` for its live status, an "Open now"/"Closed now" label when hours are known, a "show on map" icon button (when the location has coordinates), or a plain chevron otherwise.

## Dependencies & relationships
Watches `locationPulseProvider` from `campus_pulse/providers/pulse_providers.dart` — this is the Map↔Pulse connection used for markers/search results. Used by `map_home_screen.dart`'s results sheet.

## Notable behavior / gotchas
`onShowOnMap` is only wired up for locations that have coordinates; unmapped locations get a plain chevron instead. Open/closed text is only shown when `isOpenAt` returns a non-null value — absence of hours data is treated as "unknown," not "closed."
