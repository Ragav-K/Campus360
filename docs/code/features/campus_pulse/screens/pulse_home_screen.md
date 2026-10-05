# lib/features/campus_pulse/screens/pulse_home_screen.dart

## Purpose
The Pulse tab, which also serves as the app's home screen: greeting, always-visible search, the swipeable highlight deck, quick actions, today's timetable, and the full filterable feed of live updates.

## Key members
- `PulseHomeScreen` (`ConsumerStatefulWidget`) — a `CustomScrollView` combining: header (greeting + notification bell + profile button), a search field, `PulseDeck` (hidden while searching), `TodayCard`, `QuickActions`, a category filter row, and the scrollable update list.
- `_CategoryFilterRow` / `_Chip` — horizontal scrollable chips for `PulseCategory` filtering, including an "All" chip.
- `_PulseSliverList` — renders the filtered update list as slivers: skeleton loading, error view, empty states (filtered vs. truly empty), or a list of `PulseCard`s.

## Dependencies & relationships
Watches `currentUserProvider`, `filteredPulseProvider`, `pulseFilterActiveProvider`, `pulseCategoryFilterProvider`, `pulseSearchProvider`, `activePulseProvider` (for pull-to-refresh invalidation). Renders `HomeGreeting`, `NotificationBell`, `QuickActions`, `TodayCard`, `PulseDeck`, `PulseCard`. Navigates to `Routes.profile` and `Routes.pulseDetail`.

## Notable behavior / gotchas
Below-the-fold sections (deck, TodayCard, QuickActions, "Happening now" header) are hidden entirely while actively searching, since a highlight deck makes no sense when hunting for one specific item. Pull-to-refresh invalidates `activePulseProvider`, and the list uses `skipLoadingOnRefresh: true` to avoid flashing a skeleton on manual refresh. Empty states differ by cause: "no updates match that filter" (with a clear action) vs. "campus is quiet" (nothing active at all).
