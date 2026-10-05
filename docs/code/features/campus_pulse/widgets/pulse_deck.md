# lib/features/campus_pulse/widgets/pulse_deck.dart

## Purpose
The swipeable "card deck" at the top of the Pulse/home screen, showing up to 6 highlighted live updates as a stack of overlapping cards with physical drag-to-dismiss navigation.

## Key members
- `PulseDeck` (`ConsumerStatefulWidget`) — watches `homePulseHighlightsProvider` and `clockTickProvider`; renders loading/empty/error/data states and a row of position dots below the stack.
- `_PulseDeckState` — drives the deck via manual `Stack` positioning (not `PageView`) so stacked cards peek out behind the front one; handles drag gestures, fling-based index changes, and spring-back animation via an `AnimationController`.
- `DragEndDescription` — small helper struct wrapping drag velocity for testable drag-end logic.
- `_DeckCard` — the actual card UI: status wash circle, category label + relative time, location name as headline, status chip + occupancy, description, and expiry countdown; dimmed variant used for background stack cards.
- `_EmptyDeck` — "Campus is quiet" empty state shown when there are no highlighted updates.
- `_Dots` — animated pagination dots indicating deck position.

## Dependencies & relationships
Uses `homePulseHighlightsProvider`/`clockTickProvider` from `pulse_providers.dart`, `StatusPalette`, `StatusChip`, `Fmt` formatters, and navigates to `Routes.pulseDetail` on tap. Used by `pulse_home_screen.dart`.

## Notable behavior / gotchas
Uses a `Stack` rather than `PageView` deliberately — a `PageView` can't show the layered stacked-card depth effect. Depth effect is achieved by insetting cards from the right/top-bottom edges, not by scaling (scaling would cancel the offset). Forward swipe ("flingLeft") advances the index and removes the top card; backward swipe slides the previous card in from off-screen left while the current card holds still — asymmetric by design so the correct card is always what appears. Drag has resistance (0.3x) at the first/last card so the deck feels bounded. Index is clamped defensively if the underlying list shrinks mid-session (an update expiring).
