# lib/core/services/firebase_providers.dart

## Purpose
Root dependency-injection point for Firebase SDK singletons (Auth, Firestore, Storage, Functions) as Riverpod providers, plus the app's remote (Firestore-backed) configuration.

## Key members
- `kFirestoreDatabaseId` — const `'default'`, the named Firestore database this project uses.
- `campus360Firestore` — the app's single `FirebaseFirestore` instance, created via `FirebaseFirestore.instanceFor(databaseId: kFirestoreDatabaseId)`.
- `firebaseAuthProvider`, `firestoreProvider`, `storageProvider`, `functionsProvider` — `Provider`s exposing the Firebase singletons for DI/testing overrides.
- `remoteConfigProvider` — `StreamProvider<RemoteConfig>` streaming `config/app` from Firestore, falling back to `RemoteConfig.fallback` on error.
- `remoteConfigValueProvider` — synchronous `Provider<RemoteConfig>` accessor for code that cannot await (validators, guards).

## Dependencies & relationships
Imports `cloud_firestore`, `firebase_core`, `cloud_functions`, `firebase_auth`, `firebase_storage`, `flutter_riverpod`, `core/constants/firestore_paths.dart`, `models/remote_config.dart`. `main.dart` configures `campus360Firestore.settings` for offline persistence directly on this instance. Virtually every repository depends on `firestoreProvider`/`remoteConfigProvider`.

## Notable behavior / gotchas
Critical gotcha explicitly called out in comments: this project's Firestore database is a *named* database (`"default"`), not Firestore's conventional `"(default)"` — using `FirebaseFirestore.instance` anywhere would fail with NOT_FOUND. `kFirestoreDatabaseId` must stay in sync with `firebase.json`'s `firestore.database` setting.
