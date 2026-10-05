# lib/features/campus_pulse/widgets/pulse_card.dart

## Purpose
A single list-row card for one `PulseUpdate`, used in the main Pulse feed.

## Key members
- `PulseCard` (`StatelessWidget`) — shows a status chip, occupancy label (or category label if no live headcount), relative post time, title, description (2-line clamp), and a footer row with location name and/or time-remaining-before-expiry.

## Dependencies & relationships
Uses `StatusPalette.colorOf` for the accent color, `StatusChip.pulse`, and `Fmt.relative`/`Fmt.expiresIn` formatters. Rendered by `pulse_home_screen.dart`'s `_PulseSliverList`.

## Notable behavior / gotchas
The accent color is drawn as a thin leading gradient bar (via a `LinearGradient` with a near-zero stop) rather than tinting the whole card, to avoid a noisy long list. Expiry text turns accent-colored and bold when under 30 minutes remain. Prefers a live `occupancyLabel` over the generic category label when available.
