# lib/models/lost_item.dart

## Purpose
Models a lost-item report in the Lost & Found feature — something a student has lost and is hoping to recover.

## Key members
- `LostItem` class — fields `id`, `ownerId`, `ownerName`, `itemName`, `category` (`ItemCategory`), `description`, `photoUrl`, `locationId`, `locationName`, `lostAt`, `keywords`, `status` (`LostItemStatus`), `resolvedFoundItemId`, `createdAt`.
- `isOpen` getter — active or claim-pending.
- `LostItem.fromMap(id, map, {required toDate})` factory.
- `toCreateMap()` — client-writable creation payload with derived `keywords`.

## Dependencies & relationships
Imports `enums/lost_found_enums.dart` and `keywords.dart`. Maps to the `lostItems/{id}` Firestore collection. Consumed by the Lost & Found repository/provider and the lost-items board/matching UI.

## Notable behavior / gotchas
Deliberately excludes `identifyingDetails` (the private verifying fact, e.g. "torn photo of a dog inside") — since Firestore rules apply per-document rather than per-field, that secret must live in a separate `lostItems/{id}/private/secret` document rather than on this public-readable model, otherwise it would ship to every browsing student. `lostAt` is approximate by design. `toCreateMap` excludes server-owned fields (`status` transitions, `resolvedFoundItemId`).
