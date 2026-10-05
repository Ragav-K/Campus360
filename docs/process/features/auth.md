# Auth

Screens: `lib/features/auth/screens/{splash_screen,login_screen,register_screen,forgot_password_screen}.dart`
Providers: `lib/features/auth/providers/auth_providers.dart`
Repository: `lib/repositories/auth_repository.dart`
Model: `lib/models/app_user.dart` (`AppUser`, `UserRole`, `NotificationPrefs`)
Firestore: `users/{uid}` (profile doc)

## Flow

1. **Cold start → Splash.** `SplashScreen` is shown only while
   `authStateProvider` (a `StreamProvider<User?>` wrapping
   `AuthRepository.authStateChanges()`) is still resolving. The router's
   `redirect` holds the user on `/splash` until it knows whether a session
   exists, specifically to avoid a login-screen flash on cold start with a
   cached session.
2. **Signed out → Login.** Once auth state resolves to no user, the router
   redirects to `/login`. `LoginScreen` drives `AuthController.signIn(email,
   password)`, which calls `AuthRepository.signIn` with
   `allowedDomains` read live from `remoteConfigValueProvider` — so the
   campus can restrict sign-in to certain email domains without a new build.
3. **Register.** `RegisterScreen` drives `AuthController.register(...)`.
   - If the current Firebase Auth user is already an anonymous guest, this
     calls `AuthRepository.linkGuestToEmail(...)` instead of creating a new
     account, so the guest's existing lost/found reports and print orders
     carry over to the new email account rather than being orphaned.
   - Otherwise it creates a fresh account via `AuthRepository.register`.
4. **Continue as guest.** `AuthController.continueAsGuest()` calls
   `AuthRepository.signInAsGuest()` (Firebase anonymous auth). A guest has
   the same `canAct` abilities as a student (can report items, place print
   orders) by product decision, but the account only exists on that device —
   clearing app data loses it. `AppUser.needsIdentity` flags a guest who
   hasn't given a name yet, and `AuthController.setGuestIdentity(name,
   phone)` records it.
5. **Forgot password.** `ForgotPasswordScreen` drives
   `AuthController.sendPasswordReset(email)`.
6. **Profile repair on first read.** `currentUserProvider` watches
   `users/{uid}` via `AuthRepository.watchUser`. If the Auth account exists
   but its profile document is missing (possible if the write at
   registration failed), it calls `AuthRepository.ensureUserDocument(auth)`
   exactly once per stream lifetime to recreate it, rather than leaving the
   user permanently profile-less.
7. **Signed in → tab shell.** Once `authStateProvider` has a user and the
   router isn't on an auth screen, `redirect` sends the user to `/pulse`,
   the first tab of `AppShell`.
8. **Role-gated routes.** `currentRoleProvider` (derived from
   `currentUserProvider.role`, defaulting to `UserRole.student` while the
   profile loads) is checked by the router: `/admin/**` requires
   `UserRole.admin`, `/staff/**` requires `role.isStaff`
   (`printShopStaff` or `admin`). This is a UX guard only — Firestore rules
   are the real enforcement, and server-side custom claims (set by a Cloud
   Function from the `role` field) are what the rules actually trust.
9. **Sign out.** `AuthController.signOut(fcmToken: ...)` — the FCM token is
   passed so the device's push token can be removed from
   `users/{uid}.fcmTokens` on the way out, so the next person using the
   device doesn't get the previous user's notifications.

## Errors

All of the above go through `AuthController._run`, which parks any thrown
error as an `AppFailure` in the controller's `AsyncValue` state (mapped from
Firebase codes by `FailureMapper._auth`, e.g. `wrong-password` → "Incorrect
email or password."). `AuthController.clearError()` is called when
switching between login/register/forgot-password screens so an error from
one form doesn't bleed into another.
