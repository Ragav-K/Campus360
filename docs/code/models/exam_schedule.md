# lib/models/exam_schedule.dart

## Purpose
Models a transcribed exam timetable (one department/year's papers for one assessment such as CIAT-I, CIAT-II, end semester), linked to an academic calendar event.

## Key members
- `ExamSession` enum — `fn` (forenoon), `an` (afternoon); `fromName`, `label`, `shortLabel`.
- `ExamPaper` class — `code`, `subject`; `fromMap`/`toMap`.
- `ExamSlot` class — one date+session row: `date`, `session`, `papers` (list, supports elective/choice baskets), `note`; `isFree`, `isChoice` getters; `fromMap(m, date)` factory.
- `ExamSchedule` class — fields `id`, `title`, `calendarEventId`, `department`, `year`, `semester`, `fnTime`, `anTime`, `maxMarks`, `portion`, `pattern` (question paper pattern lines), `source`, `slots`.
- `ordered`, `papersOnly`, `isEmpty`, `span` getters; `timeFor(ExamSession)`.

## Dependencies & relationships
No imports. Maps to the `examSchedules/{id}` Firestore collection, linked via `calendarEventId` to an `academicCalendar` document (see `calendar_event.dart`) so tapping an exam on the calendar opens the matching schedule. Consumed by Timetable/Calendar exam-detail screens.

## Notable behavior / gotchas
`papers` is a list (not a single value) because a slot can legitimately hold multiple courses (elective baskets, honour/minor courses) printed in one cell — the UI shows all and lets the student recognize their own. `isFree` represents a printed "NA" slot — kept rather than omitted so the schedule mirrors the original sheet. No `ExamSchedule.fromMap`/`toMap` present in this file.
