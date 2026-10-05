# lib/repositories/pulse_repository.dart

## Purpose
Reads and writes the `pulseUpdates` collection — campus announcements/status updates ("Pulse" feature) — including admin CRUD and student stale-reporting.

## Key members
- `PulseRepository(FirebaseFirestore)` — targets `Paths.pulseUpdates`.
- `watchActive({limit})` — active updates ordered by priority then recency, filtered client-side for liveness (`PulseUpdate.isLive`) to preserve priority ordering.
- `watchOne(id)` — single update stream.
- `watchForLocation(locationId)` — most recent live update tied to a map location, for showing status on the Map.
- `create(...)` — admin write of a new pulse update.
- `update(id, changes)` — admin partial update.
- `expireNow(id)` — soft-delete by setting `isActive: false` and `expiresAt` to now, preserving the record.
- `delete(id)` — hard delete.
- `reportStale({pulseId, uid, reason})` / `hasReported({pulseId, uid})` — one report per user per update, stored under `{pulse}/reports/{uid}`.
- `_fromDoc` / `_occupancyMap` — map conversion, including nested `occupancy.at` Timestamp handling.
- Top-level const `pulseNotFound` — a canned `AppFailure` for a removed/expired pulse doc.

## Dependencies & relationships
Imports `firestore_paths.dart`, `app_failure.dart`/`failure_mapper.dart`, `PulseUpdate` model, `pulse_enums.dart`. Consumed by the Pulse feature's feed/detail screens and an admin pulse-management screen.

## Notable behavior / gotchas
- Only admins write; students read (enforced by Firestore rules, not this class).
- Expiry filtering is intentionally done client-side (`isLive`) rather than via a server-side `expiresAt > now` query, to avoid losing priority ordering (Firestore requires the first `orderBy` to match an inequality filter field).
- `_occupancyMap` keeps the `occupancy` field backward-compatible for docs written before that field existed (absent = null).
