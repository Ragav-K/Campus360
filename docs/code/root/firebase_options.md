# lib/firebase_options.dart

## Purpose
Auto-generated FlutterFire CLI file providing platform-specific `FirebaseOptions` (API keys, app IDs, project IDs) for initializing Firebase.

## Key members
- `DefaultFirebaseOptions` — class with a `currentPlatform` getter that dispatches by `defaultTargetPlatform`/`kIsWeb`.
- `DefaultFirebaseOptions.android` / `.ios` — const `FirebaseOptions` for each configured platform.

## Dependencies & relationships
Imports `firebase_core` and `flutter/foundation`. Consumed by `lib/main.dart` via `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.

## Notable behavior / gotchas
Generated file (`// ignore_for_file: type=lint`) — not meant to be hand-edited; regenerate via FlutterFire CLI. Throws `UnsupportedError` for web, macOS, windows, and linux, since only Android and iOS are configured. Contains real API keys/app IDs (standard for Firebase client config, not secret).
