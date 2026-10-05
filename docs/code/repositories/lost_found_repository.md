# lib/repositories/lost_found_repository.dart

## Purpose
Manages lost item reports, found item reports, and the claims that connect a claimant to a found item, including photo upload and two-sided handover confirmation.

## Key members
- `LostFoundRepository(FirebaseFirestore, {DocumentStorage? documents})` — touches `lostItems`, `foundItems`, `claims` collections.
- `watchOpenFoundItems` / `watchOpenLostItems` — active/claim-pending items, newest first.
- `watchMyLostItems(uid)` / `watchMyFoundItems(uid)` — a user's own reports.
- `watchFoundItem(id)` / `watchLostItem(id)` — single-document streams.
- `watchMyClaims(uid)` — merges two queries (claimant and finder) client-side since Firestore has no cross-field OR.
- `reportLost({item, identifyingDetails, photo})` — uploads photo via `DocumentStorage`, writes `lostItems` doc, optionally writes a `private/secret` subdocument with the ownership secret.
- `reportFound({item, photo})` — uploads photo, writes `foundItems` doc.
- `claimFoundItem(...)` — creates a pending `claims` doc with a proof string.
- `decideClaim` / `withdrawClaim` — finder approves/rejects, or claimant withdraws.
- `confirmHandover({claim, uid})` — records one side's confirmation; when both sides agree, batbatch-updates both `foundItems` and (if linked) `lostItems` to resolved/returned.
- `closeLostItem` / `closeFoundItem` — manual close.

## Dependencies & relationships
Imports `failure_mapper.dart`, `DocumentStorage` (Firebase Storage wrapper), and the `Claim`/`FoundItem`/`LostItem` models plus `lost_found_enums.dart`. Consumed by the Lost & Found feature's providers/screens (report forms, board, claim flow).

## Notable behavior / gotchas
- Collection names (`lostItems`, `foundItems`, `claims`) are hardcoded strings rather than using `Paths` constants, unlike most other repositories.
- Handover confirmation is intentionally two-sided client-side logic rather than a server-generated OTP — comment explains a client-mintable OTP would be insecure without Cloud Functions.
- `_uploadPhoto` uploads before the Firestore write; if upload fails the order is never created, avoiding unprintable/unlinked documents.
