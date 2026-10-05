# test/print_order_test.dart

## Purpose
Tests `lib/models/print_order.dart` and `lib/models/enums/print_enums.dart` — `PrintOrder` queue ordering/deadline logic, `PrintOrderStatus` state flags, `PrintSettings` summary/validation, and `estimateCost`.

## Test cases
- **queue ordering**: sorts by deadline (soonest first) rather than creation time; orders with no deadline sort after all dated orders; among undated orders, oldest goes first; an overdue order sorts ahead of all future-dated orders.
- **deadline state**: `isOverdue` true once deadline passes if not yet ready/collected; false once status is `readyForPickup` or `collected`; `isUrgent` true within 30 minutes of deadline but false once overdue or far out; an order with no deadline is neither urgent nor overdue, and `remainingTime` is null.
- **status**: `isActive` true for `printing`/`readyForPickup`, false for `collected`/`rejected`/`cancelled`; `isCancellableByStudent` true only for `received`/`accepted`, false once `printing` or later.
- **settings**: `PrintSettings.summary` includes copy count, colour mode, sides; singular "1 copy" wording; blank page range counts as `isAllPages`.
- **estimateCost**: multiplies pages × copies × per-page rate; uses colour rate for colour jobs; returns null when page count is unknown; returns null when the shop has not published prices.

## Dependencies & relationships
Exercises `PrintOrder`, `PrintDocument`, `PrintSettings`, `PrintOrderStatus`, `PrintColour`, `PrintSides`, and the `estimateCost` function directly via a local `_order()` builder. No mocks.

## Notable behavior / gotchas
`estimateCost` deliberately returns null instead of a guessed price when inputs are missing (unreadable PDF page count, or no shop pricing) rather than silently defaulting.
