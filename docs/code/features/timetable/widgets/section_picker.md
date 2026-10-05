# lib/features/timetable/widgets/section_picker.dart

## Purpose
Modal bottom sheet for choosing which class section's timetable to follow, shared between the Timetable screen and Profile.

## Key members
- `showSectionPicker(context, ref)` — top-level function opening the sheet via `showModalBottomSheet`.
- `_SectionPickerSheet` (ConsumerWidget) — lists all sections (`allSectionsProvider`), showing loading/error/empty states, with the currently selected section (`userSectionProvider`) checked.
- `_SectionTile` — one section row; tapping calls `authController.setSection(id)` and closes the sheet.

## Dependencies & relationships
Uses `timetable_providers.dart` (`allSectionsProvider`, `userSectionProvider`) and `auth_providers.dart`'s `authControllerProvider` to persist the chosen section against the user profile. Invoked from `timetable_screen.dart` and the Profile screen.

## Notable behavior / gotchas
None noted.
