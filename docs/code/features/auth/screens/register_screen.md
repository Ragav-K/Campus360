# lib/features/auth/screens/register_screen.dart

## Purpose
Account creation screen: name, email, password, confirm-password form that registers a new user (or upgrades a guest account).

## Key members
- `RegisterScreen` / `_RegisterScreenState` — form with name/email/password/confirm fields, password visibility toggle, submit button, and a link back to sign-in.

## Dependencies & relationships
Uses `authControllerProvider.register(...)`, `remoteConfigValueProvider` (for `enforcedDomains`, shown as a helper hint and used in email validation), `AuthScaffold`, `Validators.name`/`email`/`password`/`confirmPassword`. On success shows a snackbar about the verification email; actual navigation after account creation is handled by the router's redirect, not this screen.

## Notable behavior / gotchas
- Domain restriction shown client-side is re-enforced server-side by a Cloud Functions Auth `onCreate` trigger (per inline comment referencing "§26").
- Clears the shared `AuthController`'s stale error on entry, same pattern as other auth screens.
- Password helper text states the rule ("At least 8 characters, with a letter and a number") enforced by `Validators.password`.
