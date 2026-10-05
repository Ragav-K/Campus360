# lib/core/constants/firestore_paths.dart

## Purpose
Single source of truth for Firestore collection/document names and Supabase/Storage path builders, to avoid string-literal typos.

## Key members
- `Paths` (abstract final class) — collection name constants (`users`, `campusLocations`, `pulseUpdates`, `lostItems`, `foundItems`, `matches`, `claims`, `printShops`, `printOrders`, `notifications`, `config`, `counters`), sub-collection names (`privateSub`, `reportsSub`), and well-known document ids (`appConfigDoc`, `otpDoc`, `secretDoc`).
- `StoragePaths` (abstract final class) — static functions building storage object paths: `lostItemPhoto`, `foundItemPhoto`, `pulseImage`, `printDoc`, `avatar`.

## Dependencies & relationships
No imports. Used across all Firestore repository/provider code (e.g. `firebase_providers.dart`) and anywhere storage paths are constructed.

## Notable behavior / gotchas
Explicit convention: never type a collection string literal elsewhere — a typo becomes a silent empty stream. `StoragePaths` paths look like Firebase Storage paths but note `document_storage.dart` actually targets Supabase, reusing a similar path shape.
