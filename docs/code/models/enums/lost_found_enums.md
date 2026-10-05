# lib/models/enums/lost_found_enums.dart

## Purpose
Enumerations backing the Lost & Found feature: item categories, lost/found item lifecycle statuses, claim lifecycle, and match confidence bands.

## Key members
- `ItemCategory` enum — closed list (`wallet`, `phone`, `keys`, `idCard`, `bag`, `book`, `electronics`, `clothing`, `bottle`, `jewellery`, `other`), each with a display `label` and `emoji`; `parse(String?)`.
- `LostItemStatus` enum — `active`, `claimPending`, `resolved`, `closed`, with labels; `parse(String?)`.
- `FoundItemStatus` enum — `active`, `claimPending`, `returned`, `closed`, with labels; `parse(String?)`.
- `ClaimStatus` enum — `pending`, `approved`, `rejected`, `returned`, `withdrawn`, with labels; `parse(String?)`.
- `MatchBand` enum — `possible`, `related`, `likely`; `forScore(double)` buckets a raw similarity score into a band.

## Dependencies & relationships
No imports. Consumed by `lost_item.dart`, `found_item.dart`, `claim.dart`, and `keywords.dart` (category token), plus the Lost & Found matching logic and UI (status chips, category pickers).

## Notable behavior / gotchas
`ItemCategory` is a deliberately closed list — comment notes free-text categories can't be matched reliably and category is the strongest matching signal. `ClaimStatus` two-step handover design is explained here as the alternative to a server-issued pickup OTP (no backend to mint one the client can't read). `MatchBand.forScore` thresholds: ≥0.8 likely, ≥0.55 related, else possible — shown as bands rather than raw percentages intentionally.
