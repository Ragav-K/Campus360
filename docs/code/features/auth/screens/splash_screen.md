# lib/features/auth/screens/splash_screen.dart

## Purpose
Simple branded loading screen shown only while Firebase auth state is still resolving at app startup.

## Key members
- `SplashScreen` — stateless widget showing the `BrandMark`, app name, tagline, and a spinner on a primary-color background.

## Dependencies & relationships
Uses `BrandMark` widget, `AppConfig.appName`, `AppColors.primary`. The app's `routerProvider` is responsible for redirecting away from this screen as soon as auth state resolves (noted in the class doc comment); this screen has no navigation logic of its own.

## Notable behavior / gotchas
None noted — purely presentational, no interactivity or state.
