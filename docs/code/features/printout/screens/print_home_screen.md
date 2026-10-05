# lib/features/printout/screens/print_home_screen.dart

## Purpose
The Printout tab: lists the student's current and past print orders, with an entry point to place a new one.

## Key members
- `PrintHomeScreen` (ConsumerWidget) — watches `myOrdersProvider`/`activeOrdersProvider`/`pastOrdersProvider`; shows loading skeletons, an error view, an empty state with a "New print order" CTA, or two sections ("Current orders", "Previous orders") of `OrderCard`.
- `OrderCard` (StatelessWidget) — card with a colored left accent (`StatusPalette.colorOf(order.status.tone)`), status chip, filename, shop + settings summary, and an overdue/deadline row when `neededBy` is set.

## Dependencies & relationships
Uses `print_providers.dart`, `PrintOrder` model, `StatusChip`/`StatusPalette`, `Routes` (navigates to `newPrintOrder` and `printOrder(id)`), and shared `EmptyState`/`SkeletonCard`/`CButton`/`ErrorStateView`.

## Notable behavior / gotchas
Overdue orders get a warning icon and error-colored, bold deadline text ("Was needed by …" instead of "Needed by …"). None otherwise noted.
