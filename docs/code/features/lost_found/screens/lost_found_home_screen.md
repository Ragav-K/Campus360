# lib/features/lost_found/screens/lost_found_home_screen.dart

## Purpose
The main Lost & Found tab: a board of open found items, led by any personal match suggestions.

## Key members
- `LostFoundHomeScreen` (ConsumerWidget) — watches `openFoundItemsProvider` and `myMatchesProvider`; renders a "Might be yours" section (top 5 matches via `MatchCard`) above a "Handed in recently" list (`FoundItemCard` per item). Shows an empty board state when there is nothing at all.
- `_ReportMenu` — two labelled FABs ("I found something" / "I lost something") instead of one ambiguous add button, navigating to `Routes.reportFound` / `Routes.reportLost`.
- `_SectionHeader`, `_EmptyBoard` — presentational helpers.

## Dependencies & relationships
Uses `lost_found_providers.dart` for data, `found_item_card.dart` and `match_card.dart` for list items, go_router's `Routes` for navigation to report/detail/my-reports/profile screens, and shared `AsyncValueView`/`EmptyState` widgets.

## Notable behavior / gotchas
Deliberately prioritizes match suggestions above the general board, per the file's doc comment: a student who lost something wants to know "has anyone handed it in?" first. Pull-to-refresh invalidates `openFoundItemsProvider`.
