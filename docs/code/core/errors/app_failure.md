# lib/core/errors/app_failure.dart

## Purpose
Defines the app's user-presentable error type and the taxonomy of failure kinds, so repositories throw a consistent, UI-safe error object rather than raw platform exceptions.

## Key members
- `AppFailure` (implements Exception) — holds `kind`, user-facing `message`, optional `debug` text (logged, never shown), and `isRetryable`; includes const constructors `offline`, `unknown`, `permission`, `notFound`.
- `describeFailure(Object)` — returns display text for any thrown object (falls back to `AppFailure.unknown.message`).
- `describeAsFailure(Object)` — narrows any thrown object to an `AppFailure`.
- `FailureKind` (enum) — network, auth, permission, notFound, validation, upload, fileTooLarge, unsupportedFile, otpInvalid, otpExpired, otpUsed, conflict, rateLimited, unknown.

## Dependencies & relationships
No imports. Used throughout repositories/services (`failure_mapper.dart`, `document_storage.dart`, `location_service.dart`) and UI error-rendering widgets.

## Notable behavior / gotchas
Design intent: raw Firebase/platform errors must never reach the user — `message` is always plain-language and actionable; `debug` carries the technical detail for logs only.
