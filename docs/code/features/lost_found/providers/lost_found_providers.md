# lib/features/lost_found/providers/lost_found_providers.dart

## Purpose
Riverpod providers that wire the Lost & Found feature's repository, Firestore-backed streams, and the device-side matching engine together for UI consumption.

## Key members
- `lostFoundRepositoryProvider` — constructs `LostFoundRepository` from the shared Firestore instance.
- `openFoundItemsProvider` / `openLostItemsProvider` — streams of all open found/lost items (public board).
- `myLostItemsProvider` / `myFoundItemsProvider` / `myClaimsProvider` — per-user streams scoped to the signed-in uid; emit empty lists when signed out.
- `foundItemProvider` / `lostItemProvider` — `StreamProvider.family` for a single item by id.
- `matchesForLostItemProvider` — `Provider.family<List<ItemMatch>, LostItem>` running `ItemMatcher` against all open found items for one lost report.
- `myMatchesProvider` — aggregates up to 5 matches per open lost report across all of the user's lost items, sorted best-first; this is what the home screen's "Might be yours" section reads.

## Dependencies & relationships
Depends on `firebase_providers.dart` (Firestore), `LostFoundRepository`, the `Claim`/`FoundItem`/`LostItem` models, `auth_providers.dart` for the current uid, and `matching.dart` for `ItemMatcher`/`ItemMatch`. Consumed throughout the lost_found screens (home, detail, my reports, report).

## Notable behavior / gotchas
Matching providers are plain `Provider`s (not streams) that recompute from already-streamed data — see `matching.dart` for why this is client-side. All "my" streams guard against a null uid by returning `Stream.value(const [])` rather than erroring.
