# lib/features/printout/screens/order_detail_screen.dart

## Purpose
Tracks a single print order's status and lets the student cancel it while still cancellable.

## Key members
- `OrderDetailScreen` (ConsumerWidget) — loads `orderDetailProvider(orderId)` and renders `_Body`, or an empty state if the order no longer exists.
- `_Progress` — renders the 5-step pipeline (received → accepted → printing → readyForPickup → collected) as a vertical stepper with checkmarks up to the current status; renders nothing for rejected/cancelled orders since they never "progress".
- `_CancelButton` (ConsumerStatefulWidget) — confirms via dialog, then calls `printRepository.cancelOrder`; only shown when `order.status.isCancellableByStudent`.
- `_Row` — labeled icon/value row used for shop, deadline, placed time, file size, estimated cost.

## Dependencies & relationships
Uses `print_providers.dart`, `PrintOrder`/`PrintOrderStatus` model/enum, `StatusChip`/`StatusPalette` for status styling, and `AsyncValueView`/`EmptyState` shared widgets.

## Notable behavior / gotchas
Shows a rejection-reason banner only when status is `rejected` and a reason is present. Marks the deadline row in error color when `order.isOverdue()`. When status is `readyForPickup`, shows a banner instructing the student to show their order number at the counter. `ScaffoldMessenger.of(context)` is captured before any `await` in the cancel flow because `context` belongs to `build()` and using it after an await would be unsafe (commented explicitly).
