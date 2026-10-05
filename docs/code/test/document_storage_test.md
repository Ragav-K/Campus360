# test/document_storage_test.dart

## Purpose
Tests `lib/core/services/document_storage.dart` — `DocumentStorage.pathFor` (building storage paths for uploaded print documents) and `publicUrlFor` (building the public object URL).

## Test cases
- **pathFor**
  - "places the document under the owner and order" — path starts with `printDocs/<uid>/<order>/` and ends with the filename.
  - "is unguessable — the same inputs never repeat a path" — 500 calls with identical inputs produce 500 distinct paths (random segment).
  - "uses a 128-bit random segment" — the segment is 32 lowercase hex characters (16 bytes).
  - "a traversing filename cannot climb out of its folder" — a `../../etc/passwd` filename is neutralized; path retains exactly 5 segments.
  - "strips characters that would break the URL" — spaces/`#`/parentheses in the filename are replaced with underscores.
  - "an unnamed file still gets a name" — a filename that sanitizes to nothing becomes `document`.
- **publicUrlFor**: builds the full public Supabase/Storage-style object URL by combining `projectUrl`, `bucket`, and the given path.

## Dependencies & relationships
Exercises the static `DocumentStorage.pathFor` and instance method `publicUrlFor` directly. No mocks — purely deterministic string logic except the random path segment.

## Notable behavior / gotchas
The random segment is the entire privacy boundary for uploaded documents, so collision-freedom and 128-bit randomness are explicitly tested. Path traversal and URL-unsafe characters are sanitized defensively.
