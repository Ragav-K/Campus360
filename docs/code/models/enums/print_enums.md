# lib/models/enums/print_enums.dart

## Purpose
Enumerations for the Printout feature: print order lifecycle status plus colour/sides printing options.

## Key members
- `PrintOrderStatus` enum — `submitted`, `received`, `accepted`, `printing`, `readyForPickup`, `collected`, `rejected`, `cancelled`; `fromName`, `label` (shop-facing), `studentLabel` (student-facing wording), `tone` (`StatusTone`), `icon`, `isActive` (still in the shop's queue), `isCancellableByStudent`.
- `PrintColour` enum — `bw`, `colour`; `fromName`, `label`, `shortLabel`.
- `PrintSides` enum — `single`, `double`; `fromName`, `label`, `shortLabel`.

## Dependencies & relationships
Imports `flutter/material.dart` (`IconData`) and `pulse_enums.dart` (`StatusTone`) for shared status colouring. Consumed by `print_order.dart` (`PrintOrder.status`, `PrintSettings.colour/sides`) and the Printout UI (status chips, order form, shop queue).

## Notable behavior / gotchas
`label` and `studentLabel` intentionally diverge in wording for the same status (e.g. "Submitted" vs "Sending…") — UI must pick the right one per audience. `isCancellableByStudent` is only true for `submitted`/`received`/`accepted` — once printing starts, the student can no longer cancel.
