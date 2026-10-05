# lib/core/services/document_storage.dart

## Purpose
Uploads print documents to Supabase Storage (not Firebase Storage, which requires the paid Blaze plan) and returns a public download URL.

## Key members
- `DocumentStorage` — class wrapping an `http.Client`; holds `projectUrl`, `bucket`, `anonKey` (publishable Supabase key), `maxBytes` (20 MB).
- `DocumentStorage.pathFor(uid, orderId, fileName, {prefix})` — builds an unguessable object path with a 128-bit random hex token via `Random.secure()`.
- `DocumentStorage._safeName(fileName)` — sanitizes filenames against path traversal and hidden-file tricks.
- `publicUrlFor(path)` — builds the public Supabase object URL.
- `upload({file, path, mimeType, onProgress})` — streams the file via `http.StreamedRequest` POST, reports progress, maps failures to `AppFailure`.

## Dependencies & relationships
Imports `dart:io`, `dart:math`, `http`, and `core/errors/app_failure.dart`. Used by the printout feature's upload flow; paths follow the same shape as `StoragePaths` in `firestore_paths.dart` but target a different backend.

## Notable behavior / gotchas
Privacy model is documented at length: the bucket is public-read with a shipped anon key (unavoidable with no server), so privacy relies entirely on the unguessable random path segment plus Supabase policy restricting the anon key to insert-only and disabling bucket listing. `anonKey` is intentionally public/safe to ship. 4xx responses on upload are treated as service misconfiguration, not user error, and produce a distinct message pointing at the campus office.
