# Timetable

Screens: `lib/features/timetable/screens/{timetable_screen,exam_schedule_screen}.dart`
Widgets: `lib/features/timetable/widgets/{section_picker,today_card}.dart`
Providers: `lib/features/timetable/providers/timetable_providers.dart`
Repository: `lib/repositories/timetable_repository.dart`
Models: `lib/models/{timetable,exam_schedule,calendar_event}.dart`
Firestore: `timetables/{sectionId}`, `academicCalendar/{id}`, `examSchedules/{id}`

Timetable is reached as a full-screen route above the tab shell
(`Routes.timetable`, `/timetable`) — typically from the Pulse tab's "Today"
card, and all three backing collections are admin-curated, read-only for
everyone else (enforced by Firestore rules, not by the repository).

## Viewing a timetable by section

1. **Choosing a section.** A user's `sectionId` lives on their `AppUser`
   profile (`users/{uid}.sectionId`, e.g. `"cse-3a"`), set via
   `AuthController.setSection(sectionId)`. `section_picker.dart` lists every
   section via `allSectionsProvider` (`TimetableRepository.watchAllSections()`).
2. **The user's timetable.** `myTimetableProvider` watches
   `userSectionProvider` (derived from the profile) and streams
   `timetables/{sectionId}` via `TimetableRepository.watchSection`, emitting
   `null` explicitly when no section is chosen yet — so the UI can
   distinguish "not set up" from "still loading".
3. **"Today" card.** `todayScheduleProvider` assembles a `TodaySchedule`
   (current period, next period, today's full period list, or a holiday) by
   combining `myTimetableProvider` with `todayHolidayProvider` (today's
   `academicCalendar` entries of type `holiday`, which suppress the day's
   periods entirely rather than showing classes nobody will attend) and a
   30-second clock tick (`clockProvider`) so "ends in 12 min" stays accurate
   without the widget needing its own timer.
4. **Academic calendar.** `calendarProvider` streams `academicCalendar`
   from 30 days before now onward (`TimetableRepository.watchCalendar`);
   `todayEventsProvider`/`upcomingEventsProvider` filter it to events that
   apply to the user's section (`CalendarEvent.appliesToSection`).

## Exam schedule

5. Exam sheets are published **per department**, not per section — a
   student can act on their department's sheet, and the whole-campus sheet
   is many departments wide. `userDepartmentProvider` derives the
   department from the user's timetable.
6. `examSchedulesProvider` streams `examSchedules` filtered to that
   department (`TimetableRepository.watchExamSchedules(dept)`), keyed by the
   `calendarEventId` each sheet is attached to.
7. `examScheduleForEventProvider.family(eventId)` looks up the exam sheet
   for a specific calendar event (e.g. tapping a "Mid-semester exams" entry
   on the calendar opens `ExamScheduleScreen` with that event's sheet: FN/AN
   timing, max marks, portion, question pattern, and per-date `ExamSlot`s).
