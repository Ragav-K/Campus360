# lib/models/enums/pulse_enums.dart

## Purpose
Core enumerations for the Pulse feature (and shared app-wide status semantics): update category, flattened status values, and the semantic colour tone used across Pulse, Lost & Found, and Printout.

## Key members
- `PulseCategory` enum — `crowd`, `availability`, `notice`, `alert`, `event`; `fromName`, `label`.
- `PulseStatus` enum — single flattened enum covering crowd levels (`low`, `moderate`, `high`, `veryHigh`), availability (`available`, `limited`, `occupied`, `closed`), and general (`information`, `warning`, `emergency`); `fromName`, `label`, `shortLabel`, `appliesTo` (which `PulseCategory` a status is intended for), `forCategory(PulseCategory)` static (valid statuses for a category).
- `StatusTone` enum — `good`, `caution`, `bad`, `info`, `neutral` — app-wide semantic colour tone.
- `PulseStatusTone` extension on `PulseStatus` — `tone` getter mapping each status to a `StatusTone`.

## Dependencies & relationships
No imports. Consumed widely: `calendar_event.dart`, `print_enums.dart`, `print_shop.dart`, `pulse_update.dart` all reference `StatusTone`/`PulseCategory`/`PulseStatus`. Maps to the `status` field on `pulseUpdates/{id}` documents.

## Notable behavior / gotchas
`PulseStatus` is deliberately one enum instead of three separate ones so a Firestore document/update can carry any status value without schema branching; `appliesTo` just records intended usage for form validation, it does not restrict what's storable. Comment notes labels are always shown alongside colour for accessibility (colour-blind/screen-reader support).
