# Printout

Screens: `lib/features/printout/screens/{print_home_screen,new_order_screen,order_detail_screen}.dart`
Widgets: `lib/features/printout/widgets/deadline_picker.dart`
Providers: `lib/features/printout/providers/print_providers.dart`
Repository: `lib/repositories/print_repository.dart`
Models: `lib/models/{print_order,print_shop}.dart` (`PrintOrder`, `PrintDocument`, `PrintSettings`), `lib/models/enums/print_enums.dart`
Firestore: `printShops/{id}`, `printOrders/{id}`
Storage: `StoragePaths.printDoc(uid, orderId, fileName)`

Printout is the fourth tab (`Routes.print`, `/print`).

## Placing a print order

The composition flow is held in an `OrderDraft` (via
`OrderDraftController`/`orderDraftProvider`) across what the model's comment
calls "the four wizard steps", driven from `NewOrderScreen` (`Routes.newPrintOrder`):

1. **Pick a file.** The student picks a PDF/JPG/PNG (via `file_picker`/
   `image_picker`). `OrderDraftController.setFile(file, name, sizeBytes,
   pageCount)` stores it, and `PrintRepository.validateDocument(...)` checks
   extension (against `AppConfig.allowedDocumentExtensions`), size (against a
   configured max), and that the file isn't empty — returning a specific
   `AppFailure` (`unsupportedFile`/`fileTooLarge`) for each case rather than a
   generic error.
2. **Choose a print shop.** `printShopsProvider` streams `printShops` via
   `PrintRepository.watchShops()`. Calling
   `OrderDraftController.setShop(shop)` also silently downgrades any setting
   the chosen shop can't fulfil — colour → B&W if the shop doesn't support
   colour, double-sided → single if it doesn't support duplex, paper size to
   the shop's first supported size — rather than letting an order go through
   that the shop would have to reject.
3. **Configure print settings.** `PrintSettings` (copies, colour, sides,
   paper, page range, note) is edited via
   `OrderDraftController.setSettings(...)`. `OrderDraft.estimatedCost` is
   computed live from the shop's per-page rates
   (`shop.bwPerPage`/`colourPerPage`) and shown before placing the order.
4. **Choose a deadline.** `deadline_picker.dart` sets
   `OrderDraftController.setNeededBy(when)` — when the student needs the
   printout ready by.
5. **Place the order.** Once `OrderDraft.isReadyToPlace` (file + shop both
   set), `PrintRepository.placeOrder(...)` runs: it **uploads the document
   first**, deliberately, so an order never appears in a shop's queue
   pointing at a file that failed to upload; only after the upload succeeds
   does it write `printOrders/{id}` with status `PrintOrderStatus.received`
   (the only status a student is ever allowed to write — every later
   transition belongs to the shop, enforced by Firestore rules) and the
   computed `estimatedCost`. Upload progress is reported through
   `uploadProgressProvider` for a progress indicator.

## Tracking order status

6. `PrintHomeScreen` splits `myOrdersProvider` (`PrintRepository.watchMyOrders(uid)`)
   into `activeOrdersProvider` (still moving through the shop) and
   `pastOrdersProvider` (finished/rejected/cancelled), via `PrintOrder.isActive`.
7. `OrderDetailScreen` (`Routes.printOrder(id)`) streams one order via
   `orderDetailProvider.family(id)`.
8. **Cancelling.** A student can withdraw their own order before it's
   printed via `PrintRepository.cancelOrder(orderId)`.
9. **Pickup verification.** `Routes.printOtp(id)` and the staff-side
   `Routes.staffOrder(id)` / `Routes.staffVerifyOtp` routes exist for an
   OTP-based pickup handoff; OTP validity/conflict errors
   (`otp/invalid`, `otp/expired`, `otp/used`, `otp/locked`,
   `order/badStatus`) are server-side domain errors surfaced through
   `FailureMapper._functions` (see `architecture.md`), since they come back
   from a Cloud Functions callable rather than a plain Firestore write.
10. Push/in-app notifications for status changes
    (`print.received`/`printing`/`ready`/`rejected`/`collected`) are covered
    in `notifications.md`.
