# lib/features/profile/screens/profile_screen.dart

## Purpose
Single combined profile and settings screen: account info, notification toggles, theme selection, offline map management, and sign-out.

## Key members
- `ProfileScreen` — top-level `ConsumerWidget`; shows a loading spinner until the user profile loads, then a scrollable list of sections.
- `_Header` — avatar, name, email, role badge.
- `_GuestUpgradeCard` — shown to guest users, explains data is device-only and links to registration.
- `_VerifyEmailCard` — shown to signed-in, unverified users; lets them resend the verification email.
- `_Tile` / `_ClassTile` — generic settings row; `_ClassTile` shows/edits the user's class section via `showSectionPicker`.
- `_NotificationSwitches` — three toggles (Lost & Found, Print orders, Campus alerts) that save prefs and request OS notification permission when turned on.
- `_ThemeSelector` — segmented control for System/Light/Dark theme mode.
- `_OfflineMapTile` — shows saved offline map tile count/size and opens `showMapDownloadSheet`.
- `_SignOutButton` — signs out, with an extra confirmation dialog for guests (whose data is unrecoverable).
- `ProfileErrorView` — fallback error view if the profile fails to load entirely.

## Dependencies & relationships
Uses `currentUserProvider`, `isGuestProvider`, `authControllerProvider` (auth), `messagingServiceProvider`/`tokenRegistrarProvider` (notifications), `allSectionsProvider` (timetable), `themeModeProvider` (app.dart), `TileCache` (core/services), `showEditNameSheet` (edit_name_sheet.dart), `showSectionPicker`, `showMapDownloadSheet`, `Routes.register` via go_router.

## Notable behavior / gotchas
- Turning a notification switch on requests OS permission only at that moment (not at first launch) since Android's prompt can only be shown once; the preference is still saved even if permission is denied.
- Granting permission invalidates `tokenRegistrarProvider` to register the FCM token immediately rather than waiting for next sign-in.
- Guest sign-out shows a blocking confirmation dialog warning that guest sessions can't be signed back into and their data will be lost.
- Sign-out passes the device's FCM token so it can be removed from the account first — otherwise the next person using the device would receive the previous user's notifications.
