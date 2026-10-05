# lib/models/enums/location_enums.dart

## Purpose
Defines the closed set of campus location categories and their display metadata (label, icon, filter ordering) used by the Map feature.

## Key members
- `LocationCategory` enum — `academicBlock`, `department`, `classroom`, `lab`, `library`, `canteen`, `printShop`, `parking`, `sports`, `medical`, `admin`, `other`.
- `fromName(String?)` — safe parse defaulting to `other`.
- `label` / `chipLabel` (shorter variant for filter chips) / `icon` (Material `IconData`) getters.
- `filterOrder` static const list — display order for quick-filter chips.

## Dependencies & relationships
Imports `flutter/material.dart` for `Icons`/`IconData`. Consumed by `campus_location.dart` (`CampusLocation.category`) and by the Map screen's filter chip UI and location detail/list rendering.

## Notable behavior / gotchas
None noted.
