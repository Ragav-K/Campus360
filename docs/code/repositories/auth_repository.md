# lib/repositories/auth_repository.dart

## Purpose
Owns Firebase Authentication and the `users/{uid}` profile document: sign-in/sign-up, guest (anonymous) auth, account linking, and profile field updates.

## Key members
- `AuthRepository(FirebaseAuth, FirebaseFirestore)` — wraps `users/{uid}` (via `Paths.users`).
- `authStateChanges()` / `currentAuthUser` / `uid` — auth session accessors.
- `watchUser(uid)` / `fetchUser(uid)` — stream/future the profile doc, mapped to `AppUser`.
- `signIn({email, password, allowedDomains})` — signs in, enforces campus email domain, calls `ensureUserDocument` and `_touchLastSeen`.
- `ensureUserDocument(User)` — recreates a missing profile doc (merge-only, never downgrades role); distinguishes guest vs student.
- `register(...)` — creates account, sets display name, sends verification email, writes profile with `role: student`.
- `signInAsGuest()` — anonymous sign-in + ensures profile doc.
- `linkGuestToEmail(...)` — upgrades an anonymous account to email/password, keeping the same uid.
- `setGuestIdentity`, `setSection`, `sendVerificationEmail`, `refreshEmailVerified`, `sendPasswordReset`, `signOut`, `updateProfile`, `updateNotificationPrefs`, `registerFcmToken` — profile/account maintenance writes, all on `users/{uid}`.
- `_fromDoc` — maps Firestore map to `AppUser`.

## Dependencies & relationships
Imports `firestore_paths.dart` (Paths.users), `app_failure.dart`/`failure_mapper.dart` for error handling, `validators.dart` for email domain checks, and the `AppUser`/`NotificationPrefs`/`UserRole` models. Likely consumed by an `authRepositoryProvider` and auth/profile screens/controllers across the app (login, register, profile, settings).

## Notable behavior / gotchas
- Roles are read-only here; role elevation happens only via a `setUserRole` Cloud Function callable (custom claims), per class doc comment.
- `ensureUserDocument` swallows errors silently (comment: never block sign-in on this).
- `signOut` best-effort removes the FCM token before signing out so the next device user doesn't get stale notifications.
- `_fromDoc` trusts the live Auth session over the stored `isAnonymous` flag during account linking races.
