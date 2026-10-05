# lib/features/auth/screens/forgot_password_screen.dart

## Purpose
Screen for requesting a password-reset email.

## Key members
- `ForgotPasswordScreen` / `_ForgotPasswordScreenState` — shows an email field and submit button; after a successful send, swaps to a confirmation "check your inbox" view with a button back to sign-in.

## Dependencies & relationships
Uses `authControllerProvider` (`sendPasswordReset`, `clearError`, `failure`) from `auth_providers.dart`, `AuthScaffold` for shared chrome, `Validators.email` for validation, and `go_router`'s `context.pop()` to return to the login screen. Reached via push from `LoginScreen`'s "Forgot password?" link.

## Notable behavior / gotchas
- Clears any stale error from the shared `AuthController` on first frame (controller is reused across auth screens).
- The confirmation message deliberately says "if an account exists" rather than confirming existence, avoiding account enumeration.
- Does not reveal whether the send actually succeeded against Firebase vs. silently no-op'd for a nonexistent account — same confirmation screen either way.
