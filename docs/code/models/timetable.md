# lib/models/timetable.dart

## Purpose
Models a class section's weekly timetable: individual periods (theory/lab/break/lunch) and lookups for "what's on now / next".

## Key members
- `Period` class — fields `day` (1-7, `DateTime.weekday`), `index`, `start`/`end` ("HH:mm"), `subject`, `code`, `staff`, `room`, `type` (`PeriodType`).
  - `startMinutes`/`endMinutes`, `containsTime(DateTime)`, `remainingAt(DateTime)`, `timeRange`; `fromMap`/`toMap`.
- `PeriodType` enum — `theory`, `lab`, `breakTime`, `lunch`; `fromName`, `isClass` (true for theory/lab only), `label`.
- `Timetable` class — fields `id`, `name`, `department`, `year`, `periods`.
  - `forDay(weekday)`, `todayFor(now)`, `currentPeriod(now)`, `nextPeriod(now)` (today only, does not roll to tomorrow), `isEmpty`; `fromMap(id, d)` factory.

## Dependencies & relationships
No imports. Maps to the `timetables/{sectionId}` Firestore collection. Consumed by the Timetable feature's "current/next class" widgets and the weekly schedule view; `sectionId` on `AppUser` (in `app_user.dart`) selects which `Timetable` document to load.

## Notable behavior / gotchas
`nextPeriod` deliberately does not roll over to the following day — at 8pm Friday it returns null rather than "Monday 9am", and the caller is expected to show a "done for the day" state instead. No `toMap` on `Timetable` itself (only on `Period`), suggesting timetables are read-only on the client.
