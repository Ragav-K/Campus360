# lib/features/timetable/widgets/today_card.dart

## Purpose
Home-surface (Pulse) card summarizing today's schedule at a glance: current period with time remaining, then what's next.

## Key members
- `TodayCard` (ConsumerWidget) — reads `todayScheduleProvider` and branches on its state: no section chosen → `_PickSectionCard`; section but no timetable uploaded → `_NoTimetableCard`; holiday → message with holiday icon; weekend/empty → "No classes today"; day over → "Classes are done for today"; otherwise → `_Now`.
- `_Now` — shows the current period (via `_PeriodRow`, highlighted, with "ending now"/"N min left") and, if any, the next period; shows `_BetweenRow` ("Free until …" or "No class right now") when nothing is currently running.
- `_PeriodRow` — reusable leading-label/subject/time row used for both "Now" and "Next".
- `_Message` — generic icon+title+subtitle row used by all the non-schedule states.
- `_PickSectionCard`, `_NoTimetableCard` — specific empty-state variants.

## Dependencies & relationships
Uses `timetable_providers.dart`'s `todayScheduleProvider`/`TodaySchedule`, `Timetable`/`Period` models, `StatusTone`/`StatusPalette` for state coloring, and `Routes.timetable` for tap-through navigation (every state is tappable).

## Notable behavior / gotchas
Every card variant is tappable and routes to the full Timetable screen. The "No timetable yet" state deliberately says so plainly rather than inventing periods, per its inline comment.
