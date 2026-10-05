# lib/features/printout/providers/print_providers.dart

## Purpose
Riverpod providers for the Printout feature: repository access, shop/order streams, and the in-progress order draft state used by the multi-step order form.

## Key members
- `printRepositoryProvider` — builds `PrintRepository` from Firestore.
- `printShopsProvider` — stream of all print shops.
- `myOrdersProvider` — stream of the signed-in user's orders (empty when signed out).
- `activeOrdersProvider` / `pastOrdersProvider` — derived filters over `myOrdersProvider` using `order.isActive`.
- `orderDetailProvider` — `StreamProvider.autoDispose.family<PrintOrder?, String>` for one order by id.
- `OrderDraft` — immutable value object holding the order being composed: file, filename, size, page count, chosen shop, `PrintSettings`, and `neededBy` deadline; exposes `hasFile`, `isReadyToPlace`, and `estimatedCost` (via `estimateCost`).
- `OrderDraftController` (Notifier<OrderDraft>) — mutators `setFile`, `setShop` (auto-downgrades settings the chosen shop can't support), `setSettings`, `setNeededBy`, `reset`.
- `orderDraftProvider` — the `NotifierProvider` exposing the draft/controller.
- `uploadProgressProvider` — `StateProvider<double?>` tracking 0–1 upload progress, null when idle.

## Dependencies & relationships
Depends on `firebase_providers.dart`, `PrintRepository`, `PrintOrder`/`PrintShop`/`PrintSettings`/print enums, and `auth_providers.dart`. Drives `new_order_screen.dart` (draft composition), `print_home_screen.dart` (order lists), and `order_detail_screen.dart` (single order tracking).

## Notable behavior / gotchas
`setShop` silently falls back unsupported settings (colour → B&W, duplex → single, unsupported paper size → the shop's first supported size) rather than letting an order be placed that the shop would reject — explicitly called out in a comment.
