# lib/features/lost_found/widgets/match_card.dart

## Purpose
Displays one suggested lost/found pairing (`ItemMatch`) along with the human-readable reasons it was suggested.

## Key members
- `MatchCard` (StatelessWidget) — shows a `_BandChip` (match strength), the lost item's name it's suggested for, the found item rendered via `FoundItemCard`, and a `Wrap` of reason chips from `match.signals.reasons`.
- `_BandChip` — colors itself by `MatchBand` (likely/related/possible) using the theme's primary/secondary/surface container colors.

## Dependencies & relationships
Imports `ItemMatch`/`MatchBand` from `matching.dart`, `ItemCategory` enums, and reuses `FoundItemCard`. Rendered by `lost_found_home_screen.dart`'s "Might be yours" section.

## Notable behavior / gotchas
The reasons list exists specifically so students can judge a suggestion themselves rather than trust an opaque score — explained in the file's doc comment as explaining away a seemingly "wrong" suggestion instead of looking broken.
