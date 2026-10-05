# lib/models/remote_config.dart

## Purpose
Models the app's server-driven remote configuration (allowed email domains, upload limits, feature flags, map tile source) so campus-specific policy can change without a new build.

## Key members
- `RemoteConfig` class — fields `allowedEmailDomains`, `requireCollegeEmail`, `maxDocumentBytes`, `functionsEnabled`, `tileUrlTemplate`, `campusCenterLat`, `campusCenterLng`.
- `enforcedDomains` getter — returns `allowedEmailDomains` only when `requireCollegeEmail` is true, else empty.
- `fallback` static const — default config built from `AppConfig` constants.
- `RemoteConfig.fromMap(Map?)` factory — falls back to `fallback` on null/missing fields, and converts `maxUploadMb` to bytes.

## Dependencies & relationships
Imports `../core/constants/app_config.dart` (`AppConfig`). Maps to the `config/app` Firestore document, publicly readable and admin-writable. Consumed wherever remote config is read: sign-up/email validation, upload size checks, feature-flag gating (OTP/matching/notifications per §40), and the Map feature's tile URL/campus center.

## Notable behavior / gotchas
`functionsEnabled: false` is meant to make the app explicitly show an "unavailable" state for OTP/matching/notification features rather than faking them client-side. `maxDocumentBytes` is derived from a `maxUploadMb` field in the raw map (default 20 MB) rather than stored directly in bytes.
