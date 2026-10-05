# lib/widgets/status_chip.dart

## Purpose
Reusable colour-coded status indicators (a labeled pill and a small dot) used to show item/order/pulse status consistently and accessibly.

## Key members
- `StatusChip` (StatelessWidget) — default constructor params: `label` (required), `tone` (`StatusTone`, required), `dense`, `icon`. Named constructor `StatusChip.pulse(PulseStatus status, {dense, short})` derives label/tone/icon from a `PulseStatus`.
- `StatusDot` (StatelessWidget) — params: `tone` (required), `size` (default 9). A small coloured circle with no text.

## Dependencies & relationships
Imports `app_spacing.dart` (`Gap`, `Radii`), `status_palette.dart` (`StatusPalette`, `StatusTone`), and `pulse_enums.dart` (`PulseStatus`). Used across feature screens that display status (Pulse feed, print orders, lost & found, claims) wherever a `StatusTone`/`PulseStatus` needs a visible chip.

## Notable behavior / gotchas
- `StatusChip`'s label is never optional — the component's doc comment states colour alone must never carry status meaning (accessibility requirement for colour-blind users and screen readers).
- `StatusDot` is documented as only ever being paired with adjacent text by the caller; it must never be used as the sole status indicator.
- Colours/icons are resolved by `brightness` via `StatusPalette`, so light/dark theming is handled automatically.
