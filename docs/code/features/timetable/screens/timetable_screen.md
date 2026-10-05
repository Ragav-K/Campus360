# lib/features/timetable/screens/timetable_screen.dart

## Purpose
The Timetable tab, with a "Week" tab (daily period list) and a "Calendar" tab (upcoming holidays/exams/events).

## Key members
- `TimetableScreen` (ConsumerStatefulWidget) — two-tab `TabBarView`; prompts to pick a section when none is chosen, otherwise renders the week view or an empty/error/loading state.
- `_WeekView` (ConsumerStatefulWidget) — day-selector chips (Mon–Sat) plus a vertical list of periods for the selected day, defaulting to today (or Monday on Sunday); highlights the current period when viewing today.
- `_PeriodTile` — one period/break row, showing time range, subject, room/staff/code, and a "NOW" badge when active.
- `_CalendarView` (ConsumerWidget) — lists `upcomingEventsProvider` as `_EventTile`s, with loading skeletons and an empty state.
- `_EventTile` — event card showing icon/type-tone color, title, date range, description, and — if an exam schedule is attached — a tappable link into `ExamScheduleScreen`.
- `_WeekSkeleton` — loading placeholder for the week view.

## Dependencies & relationships
Uses `timetable_providers.dart` extensively (`userSectionProvider`, `myTimetableProvider`, `clockProvider`, `upcomingEventsProvider`, `calendarProvider`, `examScheduleForEventProvider`), `section_picker.dart`'s `showSectionPicker`, `StatusPalette` for event-type coloring, and `exam_schedule_screen.dart` for drill-down navigation.

## Notable behavior / gotchas
Week view intentionally uses a per-day vertical list rather than a 7-column grid, since the doc comment notes a grid is unreadable on a phone and students look up one day at a time. Only weekdays Mon–Sat are offered as day chips (no Sunday tab).
