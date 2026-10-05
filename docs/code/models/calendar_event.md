# lib/models/calendar_event.dart

## Purpose
Models an academic calendar entry (holiday, exam, or general event) shown on the campus calendar.

## Key members
- `CalendarEventType` enum — `holiday`, `exam`, `event`; `fromName`, `label`, `icon` (Material `IconData`), `tone` (reuses `StatusTone` from pulse enums).
- `CalendarEvent` class — fields `id`, `title`, `date`, `endDate`, `type`, `description`, `appliesTo` (sectionId or null for whole campus).
- `isMultiDay` getter, `coversDay(DateTime)` — inclusive range check, `appliesToSection(String?)`.

## Dependencies & relationships
Imports `flutter/material.dart` (for `IconData`) and `enums/pulse_enums.dart` (for `StatusTone`). Maps to the `academicCalendar/{id}` Firestore collection. Likely consumed by a calendar repository/provider and the calendar screen's event list/detail UI; referenced by `exam_schedule.dart` via `calendarEventId`.

## Notable behavior / gotchas
`appliesTo == null` means campus-wide; a non-null value is a sectionId filter. `coversDay` normalizes to date-only comparison, ignoring time components. No `fromMap`/`toMap`/`fromJson` present in this file — serialization presumably lives elsewhere (e.g. a DTO/repository).
