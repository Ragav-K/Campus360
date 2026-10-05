# lib/models/print_order.dart

## Purpose
Models a print order placed by a student at a print shop: the attached document, print settings, and order lifecycle/queue logic.

## Key members
- `PrintDocument` class — `fileName`, `storagePath`, `downloadUrl`, `mimeType`, `sizeBytes`, `pageCount` (nullable); `isPdf`; `fromMap`/`toMap`.
- `PrintSettings` class — `copies`, `colour` (`PrintColour`), `sides` (`PrintSides`), `paper`, `pageRange` (nullable, e.g. "2-7"), `note`; `isAllPages`, `summary` (human-readable one-liner); `copyWith`; `fromMap`/`toMap`.
- `PrintOrder` class — fields `id`, `orderNumber`, `studentId`, `studentName`, `studentPhone`, `shopId`, `shopName`, `document`, `settings`, `status` (`PrintOrderStatus`), `createdAt`, `statusChangedAt`, `neededBy`, `estimatedCost`, `rejectionReason`.
  - `isActive`, `remainingTime([now])`, `isOverdue([now])`, `isUrgent([now])`, `queueSortKey` (shop queue ordering), `fromMap(id, d, {toDate})`.
- `estimateCost({settings, pageCount, bwPerPage, colourPerPage})` — top-level helper computing an estimated cost.

## Dependencies & relationships
Imports `enums/print_enums.dart`. Maps to the `printOrders/{id}` Firestore collection. Related to `print_shop.dart` (pricing/rates) and the Printout feature's order-placement and shop-queue screens.

## Notable behavior / gotchas
`queueSortKey` encodes queue priority as a single int: overdue/deadline orders sort by deadline; undated orders sort after all dated ones, oldest first — computed here (not in the UI) so the student app and the shop dashboard can't disagree about "next". `isOverdue` excludes orders already `readyForPickup`/`collected`. `estimateCost` returns null whenever page count or the relevant per-page rate is unknown, rather than guessing — and is explicitly only an estimate; the shop confirms the real price.
