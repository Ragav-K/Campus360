# lib/repositories/print_repository.dart

## Purpose
Manages print shops and print orders: browsing shops, placing an order (with document upload and cost estimate), and student-side order lifecycle actions, plus static document-validation helpers.

## Key members
- `PrintRepository(FirebaseFirestore, {DocumentStorage? documents})` — touches `Paths.printOrders` and `Paths.printShops`.
- `watchShops()` / `watchShop(id)` — print shop list/detail streams.
- `watchMyOrders(studentId)` — a student's last 50 orders, newest first.
- `watchOrder(id)` — single order stream.
- `placeOrder({studentId, shop, file, settings, ...})` — uploads the document via `DocumentStorage` first, estimates cost, then creates the order doc with status `received`.
- `cancelOrder(orderId)` — student self-cancel.
- `validateDocument({fileName, sizeBytes, maxBytes})` (static) — checks extension against `AppConfig.allowedDocumentExtensions`, size limit, and non-empty file; returns an `AppFailure` or null.
- `mimeTypeFor(fileName)` (static) — maps extension to MIME type.

## Dependencies & relationships
Imports `app_config.dart`, `firestore_paths.dart`, `app_failure.dart`/`failure_mapper.dart`, `DocumentStorage`, and `PrintOrder`/`PrintShop`/print enums models. Consumed by the Printout feature's order-placement screen, order history, and file-picker validation flow.

## Notable behavior / gotchas
- Upload happens before the Firestore write so an order is never created for a file that failed to upload.
- `orderNumber` is derived from `DateTime.now().millisecondsSinceEpoch % 100000` client-side; comment notes a Cloud Function will later replace this with a proper sequence — not guaranteed unique/ordered.
- Students may only create orders as `received`; all later status transitions are shop-side and enforced by Firestore rules, not this class.
