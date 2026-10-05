# lib/features/lost_found/matching.dart

## Purpose
Implements client-side scoring that pairs lost-item reports with found-item reports and ranks the results, without any server-side matching logic.

## Key members
- `MatchSignals` — holds per-signal scores (category, keywords, location, time) and derives human-readable `reasons` (e.g. "Same category", "Around the same time") so the UI can explain a match instead of showing a bare score.
- `ItemMatch` — a scored pairing of a `LostItem` and `FoundItem`, with `score` and a `band` (via `MatchBand.forScore`).
- `ItemMatcher` — the matching engine:
  - `matchesFor(lost, candidates, {limit})`: filters out the owner's own finds and closed found items, scores remaining candidates, drops those below `minimumScore` (0.25), sorts descending, and returns the top `limit` (default 20).
  - `score(lost, found)`: computes the match. Category is a hard gate via `_categoryScore` — equal categories score 1, either side being `ItemCategory.other` scores 0.6 (discount, not disqualification), any other mismatch scores 0 and short-circuits (returns null). If category passes, the final score is `categoryScore * (keywordScore*0.5 + locationScore*0.3 + timeScore*0.2)` — keywords weigh most, then location, then time.
  - `_locationScore`: 1 if location IDs match or names match case-insensitively; 0.5 (neutral, not negative) if either side has no location set; 0 otherwise.
  - `_timeScore`: 1 if found within 1 day of the lost date (gap is absolute, not directional), linearly decaying to 0 at 21 days; 0.5 if either date is unknown.
  - `jaccard(a, b)`: static helper computing token-set overlap (intersection size / union size) between two keyword lists, used for the keyword signal.

## Dependencies & relationships
Imports `LostItem`, `FoundItem`, and `ItemCategory` from the models layer. Consumed by `lost_found_providers.dart` (`matchesForLostItemProvider`, `myMatchesProvider`), which feed `MatchCard` on the Lost & Found home screen. No repository or Firestore dependency — it operates purely on in-memory lists already fetched by providers.

## Notable behavior / gotchas
Matching runs on-device rather than via a Cloud Function because the project lacks Firebase's Blaze plan; this is explicitly documented in the file's doc comment as a deliberate trade-off (no push notification on a new match, recomputation per device, acceptable at current scale of "a few hundred" items). Category acts as a gate, not a weight, so a lost wallet can never match a found umbrella. `other` category pairs with anything at a 0.6 discount rather than failing outright.
