# lib/features/printout/screens/new_order_screen.dart

## Purpose
Single-screen flow for placing a print order: pick a document, choose print settings, set a deadline, pick a shop, then submit.

## Key members
- `NewOrderScreen` (ConsumerStatefulWidget) — one scrolling screen rather than a wizard, chosen for speed over paging through steps.
- `_pickFile` — uses `file_picker`'s static `FilePicker.pickFiles` (noted as the v11 API, since `FilePicker.platform` was v8) restricted to pdf/jpg/jpeg/png; validates via `PrintRepository.validateDocument` against a remote-config max size before accepting.
- `_place` — calls `printRepository.placeOrder` with the draft's file/settings/shop/deadline, streaming upload progress into `uploadProgressProvider`; on success resets the draft and navigates to the order detail screen.
- `_FileCard`, `_SettingsCard`, `_Choice<T>`, `_ShopPicker`, `_ShopTile`, `_CostCard` — presentational sections for each step.

## Dependencies & relationships
Uses `print_providers.dart` (`orderDraftProvider`, `printShopsProvider`, `uploadProgressProvider`, `printRepositoryProvider`), `DeadlinePicker` widget, `PrintRepository` for validation/mime-type lookup, `remoteConfigValueProvider` for the max document size, and `auth_providers.dart` for the current user.

## Notable behavior / gotchas
Page count is intentionally left null when picking a file — the comment explains that real page counting needs a PDF parser not yet implemented, so the cost estimate honestly reports "not known" rather than guessing. Colour/duplex options are hidden entirely (not just disabled) when the selected shop doesn't support them. The estimated cost is explicitly labeled as an estimate since the shop confirms the final price.
