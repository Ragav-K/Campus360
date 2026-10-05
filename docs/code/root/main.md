# lib/main.dart

## Purpose
App entry point: initializes Firebase, configures Firestore offline persistence, sets up global error handling, and launches `Campus360App` inside a `ProviderScope`.

## Key members
- `main()` — async entry point wrapped in `runZonedGuarded` for uncaught zone errors; initializes Firebase with `DefaultFirebaseOptions.currentPlatform`, configures `campus360Firestore.settings` for offline persistence (unlimited cache), sets `FlutterError.onError`, and calls `runApp`.

## Dependencies & relationships
Imports `app.dart` (root widget), `core/services/firebase_providers.dart` (for `campus360Firestore`), and `firebase_options.dart`. Depends on `firebase_core`, `cloud_firestore`, `flutter_riverpod`.

## Notable behavior / gotchas
Comment notes Phase 5 will hook Crashlytics into the zone error handler — currently just debug-prints. Explicitly configures the *named* Firestore database instance (`campus360Firestore`) rather than `FirebaseFirestore.instance`, since this project uses a non-default database id.
