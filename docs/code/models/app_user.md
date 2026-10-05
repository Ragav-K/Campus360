# lib/models/app_user.dart

## Purpose
Models the app's user roles, notification preferences, and the `users/{uid}` profile document.

## Key members
- `UserRole` enum — `student`, `guest`, `crowdCounter`, `printShopStaff`, `admin`; `fromName`, `isStaff`, `isAdmin`, `canCountCrowds`, `canAct`, `label`.
- `NotificationPrefs` class — per-module toggles (`lostFound`, `print`, `pulse`); `fromMap`/`toMap`/`copyWith`.
- `AppUser` class — fields `uid`, `email`, `displayName`, `role`, `photoUrl`, `shopId`, `notificationPrefs`, `emailVerified`, `disabled`, `createdAt`, `isAnonymous`, `phone`, `sectionId`.
- `AppUser.isGuest`, `needsIdentity`, `initials` getters.
- `AppUser.copyWith` — returns an updated copy.

## Dependencies & relationships
No imports — pure Dart. Maps to the `users/{uid}` Firestore document; Firestore (de)serialization is deliberately kept out of this class and lives in `repositories/dto/user_dto.dart`. Consumed by auth/user providers and repositories, and by role-gated screens/widgets throughout the app.

## Notable behavior / gotchas
`UserRole` is mirrored into Firebase Auth custom claims by a Cloud Function; security rules trust only the claim, not this enum directly. Guests (`isAnonymous`) exist only on-device and are lost if app data is cleared. `shopId` is only meaningful when `role == printShopStaff`. `copyWith` does not allow changing `uid`, `email`, `disabled`, `createdAt`, or `isAnonymous`.
