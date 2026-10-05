# lib/core/errors/failure_mapper.dart

## Purpose
Single translation point from platform/Firebase exceptions to the app's `AppFailure` type, so no screen has to interpret raw Firebase error codes.

## Key members
- `FailureMapper` (abstract final class) — `map(Object, [StackTrace?])` converts `SocketException`/`TimeoutException`, `FirebaseAuthException`, `FirebaseFunctionsException`, and generic `FirebaseException` into `AppFailure`; `guard<T>(Future<T> Function())` wraps an async call and rethrows any error as `AppFailure`.
- `_auth`, `_functions`, `_functionsByCode`, `_firebase` — private helpers mapping specific error codes to human-readable messages and `FailureKind`s (including Storage-specific codes and custom callable domain codes like `otp/invalid`, `otp/expired`, `otp/used`, `otp/locked`, `order/badStatus`, `claim/alreadyResolved`).

## Dependencies & relationships
Imports `dart:async`, `dart:io`, `cloud_functions`, `firebase_auth`, and `app_failure.dart`. Every repository is expected to funnel calls through `FailureMapper.guard`.

## Notable behavior / gotchas
Cloud Functions callables carry custom domain error codes inside `e.details['code']` (e.g. `otp/expired`) checked before falling back to generic Functions error codes. Storage errors are special-cased (`e.plugin == 'firebase_storage'`) before generic Firestore-style codes. `object-not-found` message is deliberately worded to be true whether it occurred on upload or download, since the mapper can't tell which direction triggered it.
