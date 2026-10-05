# lib/features/auth/providers/auth_providers.dart

## Purpose
Central Riverpod providers for authentication state and a shared controller that drives all auth-related form actions (sign in, register, guest flow, password reset, profile updates).

## Key members
- `authRepositoryProvider` — builds the `AuthRepository` from Firebase Auth and Firestore.
- `authStateProvider` — raw `StreamProvider<User?>` of Firebase auth state; the router listens to this for redirects.
- `currentUserProvider` — streams the signed-in user's Firestore profile (`AppUser?`); self-heals by creating a missing profile document once.
- `currentRoleProvider` — convenience `UserRole` (defaults to student while loading).
- `isSignedInProvider`, `isGuestProvider` — booleans derived from auth state.
- `AuthController` (`AsyncNotifier<void>`) — exposes `signIn`, `register`, `continueAsGuest`, `setGuestIdentity`, `setSection`, `sendPasswordReset`, `resendVerification`, `signOut`, `updateName`, `updateNotificationPrefs`, `clearError`, and a `failure` getter.
- `authControllerProvider` — the `AsyncNotifierProvider` for `AuthController`, shared across all auth screens.

## Dependencies & relationships
Depends on `AuthRepository`, `firebaseAuthProvider`/`firestoreProvider` (`firebase_providers.dart`), `AppUser`/`UserRole` model, `AppFailure`/`FailureMapper`. Consumed by login/register/forgot-password/profile screens and `edit_name_sheet.dart`. `register` reads `remoteConfigValueProvider.enforcedDomains` for domain enforcement.

## Notable behavior / gotchas
- `register` links a guest (anonymous) account to email/password instead of creating a new account, preserving the guest's existing data.
- `_run` wraps every controller action, setting loading/data/error state and returning a success bool so callers can gate navigation.
- `clearError` must be called by each screen on entry (since the controller is shared) to avoid showing a stale error from a different screen.
- `failure` getter maps a non-`AppFailure` error to `AppFailure.unknown`.
