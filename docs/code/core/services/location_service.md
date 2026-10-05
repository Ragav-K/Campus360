# lib/core/services/location_service.dart

## Purpose
Wraps the `geolocator` plugin for GPS access, mapping every permission/service failure to an `AppFailure` so map screens reuse existing error UI.

## Key members
- `LocationService` — const class with:
  - `ensurePermission()` — checks location service enabled and permission state, requesting if needed; throws specific `AppFailure`s (`_denied`, `_deniedForever`, `_serviceOff`) with actionable messages.
  - `currentPosition({accuracy, timeout})` — single GPS fix, used by the survey screen.
  - `positionStream({distanceFilterMetres})` — continuous position stream for navigation.
  - `openAppSettings()` / `openLocationSettings()` — deep links to OS settings.

## Dependencies & relationships
Imports `geolocator` and `core/errors/app_failure.dart`. Used by campus map features (navigation, location survey).

## Notable behavior / gotchas
Notes that GPS itself needs no network; only the *first* fix is slower offline because assisted-GPS normally downloads satellite almanac data over the network — this is what makes offline navigation possible. `positionStream` uses a `distanceFilter` (default 3m) to reduce battery drain from reporting GPS jitter while stationary.
