# lib/features/timetable/screens/exam_schedule_screen.dart

## Purpose
Displays one department's exam timetable (papers per day/session) for a given assessment, attached to a calendar event.

## Key members
- `ExamScheduleScreen` (StatelessWidget, `schedule: ExamSchedule`) — shows title, department/year/semester subtitle, session times/portion/max-marks summary, and a per-day breakdown of exam slots; shows the pattern/source notes if present.
- `_byDay` — groups `ExamSlot`s by calendar day while preserving existing order.
- `_SessionTimes` — summary card for forenoon/afternoon times, portion, and max marks.
- `_DayBlock` — one day's card, highlighted if it is today.
- `_SlotRow` — renders a session slot: "No paper" when free, otherwise the paper(s) (with a "choice" note when the student picks one of several), plus any note and computed time.
- `_PatternCard` — shows the question paper pattern lines, if provided.

## Dependencies & relationships
Uses the `ExamSchedule`/`ExamSlot` models and `Fmt.date`. Reached from `timetable_screen.dart`'s calendar tab when a calendar event has a published exam schedule (`examScheduleForEventProvider`).

## Notable behavior / gotchas
Free half-days are shown explicitly ("No paper") rather than omitted — the doc comment explains this matters because, on a printed exam sheet, an explicit "NA" is the difference between a known free morning and an exam nobody told the student about.
