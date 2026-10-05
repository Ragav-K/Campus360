# lib/features/campus_pulse/providers/pulse_providers.dart

## Purpose
Riverpod providers for Campus Pulse live updates: fetching, filtering by category/search, deriving per-location status, and a shared clock tick for relative-time UI.

## Key members
- `pulseRepositoryProvider` — builds `PulseRepository` from Firestore.
- `activePulseProvider` (`StreamProvider<List<PulseUpdate>>`) — all live updates, priority-ordered; single source for the Pulse tab.
- `pulseDetailProvider` (`StreamProvider.autoDispose.family<PulseUpdate?, String>`) — one update by id.
- `locationPulseProvider` (`StreamProvider.autoDispose.family<PulseUpdate?, String>`) — most recent update for a given location id; powers map markers and location detail.
- `pulseCategoryFilterProvider` / `pulseSearchProvider` (`StateProvider`) — selected category chip and live search text.
- `filteredPulseProvider` — `activePulseProvider` narrowed by category and search, filtered in memory.
- `pulseFilterActiveProvider` — true when a filter/search is applied.
- `homePulseHighlightsProvider` — up to 6 highest-priority updates that have a location attached, for the home carousel/deck.
- `clockTickProvider` (`StreamProvider<DateTime>`) — emits immediately then every minute, so relative timestamps/expiry stay accurate without manual rebuilds.

## Dependencies & relationships
Imports `PulseRepository`, `PulseUpdate`, `PulseCategory`, and `firestoreProvider`. Consumed by `pulse_home_screen.dart`, `pulse_detail_screen.dart`, `pulse_card.dart`, `pulse_deck.dart`, and (for the map integration) `location_tile.dart`/`location_detail_screen.dart`.

## Notable behavior / gotchas
Filtering/search happens in memory to keep typing instant and avoid a Firestore read per keystroke. `homePulseHighlightsProvider` deliberately excludes updates without a location name, and caps at 6 so carousel dots stay readable.
