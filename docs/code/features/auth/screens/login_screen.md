# lib/features/auth/screens/login_screen.dart

## Purpose
The sign-in screen: email/password form, plus entry points to password reset, registration, and anonymous guest browsing.

## Key members
- `LoginScreen` / `_LoginScreenState` — form with email/password fields, show/hide password toggle, "Forgot password?" link, sign-in button, "Create an account" link, and a "Continue as guest" button with explanatory text.

## Dependencies & relationships
Uses `authControllerProvider` (`signIn`, `continueAsGuest`, `clearError`, `failure`), `AuthScaffold`, `Validators.email`/`Validators.required`, and `go_router`'s `context.push(Routes.forgotPassword)` / `context.push(Routes.register)`. On successful sign-in or guest entry, the app router's redirect logic (driven by `authStateProvider`) navigates to `/pulse` — this screen does not navigate itself.

## Notable behavior / gotchas
- Clears any error left by the shared `AuthController` from a previous screen on first frame.
- Email domain restriction is NOT enforced at sign-in (only at registration) — the inline comment on the validator call notes this explicitly.
- A failed sign-in or guest attempt calls `setState(() {})` with no state change purely to force a rebuild that surfaces the controller's error banner.
