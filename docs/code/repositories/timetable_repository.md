# lib/repositories/timetable_repository.dart

## Purpose
Reads admin-curated, read-only timetable data: per-section class timetables, the academic calendar, and department exam schedules.

## Key members
- `TimetableRepository(FirebaseFirestore)` — touches `timetables`, `academicCalendar`, `examSchedules` collections.
- `watchSection(sectionId)` — one section's timetable; emits null if none exists (UI must handle explicitly).
- `watchAllSections()` — all sections ordered by name, for a section picker.
- `watchCalendar({from, limit})` — calendar entries from a start date, widening the window 30 days back by default to catch multi-day events already in progress.
- `watchExamSchedules(department)` — exam sheets scoped to one department.
- `_fromDoc` / `_examFromDoc` — Firestore map to `CalendarEvent`/`ExamSchedule` conversion, including nested `ExamSlot` list parsing.

## Dependencies & relationships
Imports `failure_mapper.dart` and `CalendarEvent`/`ExamSchedule`/`Timetable` models. Consumed by the Timetable feature's schedule, calendar, and exam screens.

## Notable behavior / gotchas
- Collection names are hardcoded strings, not sourced from `Paths` constants.
- `watchCalendar` cannot express "date <= today <= endDate" in a single Firestore query, so it queries by start date only and compensates by widening the lower bound.
- All three collections are read-only for non-admins; writes are not exposed by this class at all.
