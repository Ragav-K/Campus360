# lib/models/claim.dart

## Purpose
Models a claim document in the Lost & Found flow — a student asserting ownership of a found item, through finder approval and two-sided handover confirmation.

## Key members
- `Claim` class — fields `id`, `foundItemId`, `lostItemId` (nullable), `claimantId`, `claimantName`, `finderId`, `itemName`, `proof`, `status` (`ClaimStatus`), `rejectionReason`, `claimantConfirmedHandover`, `finderConfirmedHandover`, `createdAt`.
- `isSettled`, `awaitingHandover` getters.
- `hasConfirmed(String uid)` — looks up the right confirmation flag for a given user.
- `Claim.fromMap(id, map, {required toDate})` factory.

## Dependencies & relationships
Imports `enums/lost_found_enums.dart` (`ClaimStatus`). Maps to the `claims/{id}` Firestore collection. Consumed by a Lost & Found repository (referenced comment: `LostFoundRepository.confirmHandover`) and claim-detail/approval screens; linked to `FoundItem`/`LostItem` via their ids.

## Notable behavior / gotchas
No server-generated OTP exists for handover, so both `claimantConfirmedHandover` and `finderConfirmedHandover` must independently be true before the handover is considered complete (`awaitingHandover`). `lostItemId` is commonly null since claimants often spot the item on the board without having filed a lost report. No `toMap`/`toCreateMap` present in this file.
