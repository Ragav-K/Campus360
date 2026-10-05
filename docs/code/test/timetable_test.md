# test/timetable_test.dart

## Purpose
Tests `lib/models/timetable.dart` (`Timetable`, `Period`) and `lib/models/calendar_event.dart` (`CalendarEvent`) — day filtering, current/next period lookup, remaining time countdown, and calendar event day/section coverage.

## Test cases
- **Timetable.forDay**: returns only the requested weekday's periods in time order; a day with nothing scheduled returns empty (not an error).
- **currentPeriod**: finds the period in progress; boundary is inclusive of start minute and exclusive of end minute (tested at exactly 09:50); returns null before the day starts / after it ends; returns null on a day with no classes.
- **nextPeriod**: returns the next period later today; before the day begins, returns the first period; after the last period, returns null rather than rolling over to tomorrow.
- **Period.remainingAt**: counts down minutes remaining within an active period; returns null when the period isn't currently running.
- **CalendarEvent.coversDay**: single-day event covers only its date; multi-day event covers both endpoints and days between; days outside the range are excluded; time-of-day is ignored when comparing.
- **CalendarEvent.appliesToSection**: a campus-wide event (no `appliesTo`) applies to any section including null; a section-specific event applies only to that exact section.

## Dependencies & relationships
Exercises `Timetable`, `Period`, `PeriodType`, `CalendarEvent`, `CalendarEventType` directly via a fixed `_monday()` fixture (two classes + a break on Monday, one class on Tuesday) and a `_mon(hour, minute)` time helper. No mocks.

## Notable behavior / gotchas
`nextPeriod` deliberately does not roll over to the next day once today's schedule is finished — showing "next: Tuesday 9am" at 6pm Monday is considered noise, per the test's own comment.
