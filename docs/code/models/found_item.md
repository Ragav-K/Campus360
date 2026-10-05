# lib/models/found_item.dart

## Purpose
Models a found-item report in the Lost & Found feature — something a student picked up and is holding for the owner.

## Key members
- `FoundItem` class — fields `id`, `finderId`, `finderName`, `itemName`, `category` (`ItemCategory`), `description`, `photoUrl`, `locationId`, `locationName`, `foundAt`, `handoverNote`, `keywords`, `status` (`FoundItemStatus`), `returnedToUserId`, `createdAt`.
- `isOpen` getter — active or claim-pending.
- `FoundItem.fromMap(id, map, {required toDate})` factory.
- `toCreateMap()` — builds the client-writable creation payload, including derived `keywords` via `Keywords.from`.

## Dependencies & relationships
Imports `enums/lost_found_enums.dart` and `keywords.dart`. Maps to the `foundItems/{id}` Firestore collection, publicly readable by signed-in students. Consumed by the Lost & Found repository/provider, the found-items board UI, and the matching logic (via `keywords`).

## Notable behavior / gotchas
`toCreateMap` only includes client-writable fields; server-owned fields like `status` transitions are set elsewhere. `handoverNote` ("handed in at the library desk") is often more useful to a claimant than the finder's name. Keywords are auto-derived from item name, description, and location name at creation time.
