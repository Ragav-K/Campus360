# lib/app.dart

## Purpose
Defines the root widget (`Campus360App`) that wires up MaterialApp.router with theme and routing, and a Riverpod controller for the persisted theme mode.

## Key members
- `ThemeModeController` (Notifier<ThemeMode>) — loads/saves the user's theme mode preference via SharedPreferences, defaults to `ThemeMode.system`.
- `themeModeProvider` — NotifierProvider exposing `ThemeModeController`.
- `Campus360App` (ConsumerWidget) — builds `MaterialApp.router` using `AppConfig.appName`, `AppTheme.light()/dark()`, `themeModeProvider`, and `routerProvider`; also clamps text scaling in its `builder`.

## Dependencies & relationships
Imports `core/constants/app_config.dart`, `core/router/app_router.dart`, `core/theme/app_theme.dart`, and uses `flutter_riverpod` and `shared_preferences`. Instantiated from `lib/main.dart` inside a `ProviderScope`.

## Notable behavior / gotchas
Text scale is clamped between 0.9x and 1.4x to protect fixed-height chrome while still honoring accessibility settings. Theme mode persistence is fire-and-forget (`_load()` called from `build()` without awaiting).
