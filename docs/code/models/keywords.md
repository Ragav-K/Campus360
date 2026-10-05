# lib/models/keywords.dart

## Purpose
Pure, testable tokenizer that turns free-text lost/found descriptions into a normalized, comparable set of keyword tokens used for matching lost and found reports.

## Key members
- `Keywords` class (private constructor, static-only) —
  - `_stopWords` — set of low-signal words stripped from input.
  - `_synonyms` — map of common variant spellings/terms to a canonical token (e.g. `mobile` → `phone`, `purse` → `wallet`).
  - `from(Iterable<String?> inputs, [ItemCategory? category])` — tokenizes and normalizes all inputs into a sorted, deduplicated `List<String>`, optionally adding the category name as a token.
  - `_normalise(String raw)` — lowercases, drops single letters and stop words, applies synonym mapping, and does crude plural stripping.

## Dependencies & relationships
Imports `enums/lost_found_enums.dart` (`ItemCategory`). Used by `found_item.dart` and `lost_item.dart` (`toCreateMap`) to populate the `keywords` field persisted to Firestore, which presumably backs the Lost & Found matching algorithm (`MatchBand` in `lost_found_enums.dart`).

## Notable behavior / gotchas
Deliberately has no stemming library or network dependency to stay fully unit-testable. Plural stripping is crude (strips trailing "s" when word length > 3 and doesn't end in "ss"), with synonym table handling exceptions like glass/glasses. Synonyms are restricted to true one-object equivalences, not loose synonyms, to avoid false matches.
