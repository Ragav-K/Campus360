# lib/models/pulse_update.dart

## Purpose
Models a live campus information item in the Pulse feature, including the optional live occupancy reading attached to crowd updates.

## Key members
- `OccupancySource` enum — `manual`, `idCard`, `camera`; `fromName`.
- `OccupancyMode` enum — `count` (exact headcount) vs `density` (0..1 estimate); `fromName`.
- `Occupancy` class — `mode`, `source`, `count`, `capacity`, `level`, `at`; `ratio` (fraction of capacity or raw density), `label` (e.g. "128 / 200 people", null for density readings), `fromMap`.
- `PulseUpdate` class — fields `id`, `title`, `description`, `category` (`PulseCategory`), `status` (`PulseStatus`), `locationId`, `locationName`, `imageUrl`, `priority`, `createdBy`, `createdByName`, `createdAt`, `expiresAt`, `isActive`, `occupancy`.
  - `occupancyLabel`, `isLive` (client-side expiry check beyond the server flag), `hasExpiry`, `timeRemaining`, `tone`, `matches(query)`.

## Dependencies & relationships
Imports `enums/pulse_enums.dart`. Maps to the `pulseUpdates/{id}` Firestore collection — this is the read side of the ingest contract described in ARCHITECTURE.md; manual desk counters currently write `Occupancy`, with library ID-card gates/canteen cameras planned as future writers of the same contract. Consumed by the Pulse feed/detail screens and the home summary row (via `priority`).

## Notable behavior / gotchas
`Occupancy.label` deliberately returns null for `density` mode readings rather than fabricating a headcount a camera cannot produce. `isLive` re-checks `expiresAt` client-side because the scheduled expiry Cloud Function runs periodically and `isActive` can lag reality for a few minutes — UI must not trust the server flag alone.
