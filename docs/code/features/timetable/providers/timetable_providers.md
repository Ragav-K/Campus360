# lib/features/timetable/providers/timetable_providers.dart

## Purpose
Riverpod providers for the Timetable feature: section/timetable/calendar streams, derived "today" schedule logic, and exam schedule lookups.

## Key members
- `timetableRepositoryProvider` — builds `TimetableRepository` from Firestore.
- `userSectionProvider` — the signed-in user's chosen section id, or null.
- `allSectionsProvider` — stream of all sections, for the section picker.
- `myTimetableProvider` — the user's `Timetable`, null if no section chosen (distinguishing "not set up" from "loading").
- `calendarProvider` — stream of all `CalendarEvent`s.
- `userDepartmentProvider` — department derived from the user's timetable, used to scope exam schedules.
- `examSchedulesProvider` — department's exam schedules keyed by calendar event id.
- `examScheduleForEventProvider` — `Provider.family` returning the exam schedule attached to a given event id, if published.
- `todayEventsProvider` / `todayHolidayProvider` — events covering today, and the holiday in effect today (if any).
- `upcomingEventsProvider` — all future-or-today events for the user's section, soonest first.
- `TodaySchedule` — value object describing what the "Today" card should show: `periods`, `current`, `next`, `holiday`, `hasSection`, `hasTimetable`, plus derived `isHoliday`/`isWeekendOrEmpty`/`isDayOver`.
- `todayScheduleProvider` — builds `TodaySchedule` by layering: no section → no timetable → holiday → normal day (current/next period from `timetable.currentPeriod`/`nextPeriod`).
- `clockProvider` / `_clockStreamProvider` — a 30-second-ticking "now" value, kept separate from the Pulse feature's own clock so Timetable has no cross-feature dependency.

## Dependencies & relationships
Depends on `firebase_providers.dart`, `TimetableRepository`, `CalendarEvent`/`ExamSchedule`/`Timetable` models, and `auth_providers.dart`. Powers `timetable_screen.dart`, `exam_schedule_screen.dart` (via the event→schedule lookup), `section_picker.dart`, and `today_card.dart`.

## Notable behavior / gotchas
`todayScheduleProvider` re-evaluates every minute (via `clockProvider`) so "ends in N min" and period rollover stay accurate. A holiday suppresses the day's periods entirely rather than showing classes nobody will attend.
