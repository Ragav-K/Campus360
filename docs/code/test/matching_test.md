# test/matching_test.dart

## Purpose
Tests `lib/features/lost_found/matching.dart` (`ItemMatcher`) and `lib/models/keywords.dart` (`Keywords`) — the scoring/matching algorithm that pairs lost and found items, and the keyword extraction/normalization it depends on.

## Test cases
- **category gating**: a different category never matches regardless of textual similarity; `ItemCategory.other` matches anything but at a lower score than an exact category match.
- **scoring**: identical report in same place/time scores high (`MatchBand.likely`); differently-worded descriptions of the same object ("purse" vs "mobile") still match via keyword signal; wrong location and stale date both reduce score; an unknown time is neutral (`signals.time == 0.5`) rather than penalized; finding an item before it was reported lost isn't penalized (symmetric around the report time); time signal decays to 0 after three weeks.
- **matchesFor**: ranks better matches first; never matches a user's own lost item to their own found item; ignores found items already marked `returned`; drops results below `ItemMatcher.minimumScore`; respects a `limit` parameter.
- **reasons shown to the student**: a strong match includes human-readable reasons ("Same category", "Same place"); a weak match never fabricates a reason it doesn't satisfy.
- **jaccard**: identical sets score 1; disjoint sets score 0; an empty side scores 0 (no divide-by-zero); partial overlap computes correctly (1/3).
- **Keywords**: drops stop words and short noise tokens; normalizes synonyms (mobile→phone, purse→wallet, headphones→earphone); folds plurals to singular; adds category as a token (except `other`); is order-independent across input text.

## Dependencies & relationships
Exercises `ItemMatcher`, `Keywords`, `LostItem`, `FoundItem`, `ItemCategory`, `FoundItemStatus` directly. Local `lost()`/`found()` builders construct fixtures and mirror the app's own keyword-derivation step rather than hand-listing expected keywords, so tests don't drift from production behavior.

## Notable behavior / gotchas
Matching intentionally never matches a user against their own listings, and never claims a reason signal it did not actually detect — both are explicitly tested as anti-regressions.
