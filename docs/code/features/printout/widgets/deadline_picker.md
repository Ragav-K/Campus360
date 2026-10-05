# lib/features/printout/widgets/deadline_picker.dart

## Purpose
Widget for choosing when a print order is needed, combining quick relative presets with an exact date/time picker.

## Key members
- `DeadlinePicker` (StatelessWidget) — renders a "No rush" chip plus preset chips ("In 30 min", "In 1 hour", "In 2 hours", "In 4 hours") and a "Pick a time" action chip; shows explanatory helper text below.
- `_matches(preset)` — determines whether the current `value` corresponds to a preset, tolerating up to 2 minutes of drift since "now" keeps moving while the form is open.
- `_pickExact` — chained `showDatePicker` (today to +14 days) then `showTimePicker` to build an exact `DateTime`.

## Dependencies & relationships
Pure presentation widget; used by `new_order_screen.dart` and driven by `OrderDraftController.setNeededBy`. Uses `Fmt.dateTime` for display formatting.

## Notable behavior / gotchas
The helper text explicitly states the deadline affects queue order at the shop ("the shop sees the most urgent jobs first") — this is called out in the doc comment as functionally significant, not cosmetic, specifically so students don't treat it as decoration.
