# lib/features/profile/widgets/edit_name_sheet.dart

## Purpose
Modal bottom sheet for editing the signed-in user's display name, opened from the Profile screen.

## Key members
- `showEditNameSheet(context, ref, {required current})` — top-level function that opens the modal bottom sheet, padded to avoid the keyboard.
- `_EditNameSheet` / `_EditNameSheetState` — form with a single name field, Save and Cancel actions.

## Dependencies & relationships
Uses `authControllerProvider.updateName(...)` and `.failure` (auth_providers.dart), `Validators.name`, `CButton`. Invoked from `ProfileScreen`'s "Name" tile.

## Notable behavior / gotchas
- On save failure, shows a snackbar using the controller's parked `failure.message`, falling back to a generic message if null.
- Sheet does not close itself on failure (`_busy` resets to allow retry); it only pops on success.
