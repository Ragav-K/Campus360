import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/status_palette.dart';
import '../models/enums/pulse_enums.dart';

/// Colour + icon + **text** status pill.
///
/// The label is never optional: §7 requires status to be readable without
/// relying on colour, for colour-blind users and screen readers alike.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.dense = false,
    this.icon,
  });

  StatusChip.pulse(PulseStatus status, {super.key, this.dense = false, bool short = false})
      : label = short ? status.shortLabel : status.label,
        tone = status.tone,
        icon = null;

  final String label;
  final StatusTone tone;
  final bool dense;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final fg = StatusPalette.onSurfaceOf(tone, brightness);
    final bg = StatusPalette.surfaceOf(tone, brightness);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? Gap.sm : Gap.md, vertical: dense ? 4 : 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.pill,
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? StatusPalette.iconOf(tone), size: dense ? 13 : 15, color: fg),
          SizedBox(width: dense ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: dense ? 11.5 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small coloured dot for dense rows. Always paired with adjacent text by the
/// caller — never used as the only status indicator.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.tone, this.size = 9});

  final StatusTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(color: StatusPalette.colorOf(tone), shape: BoxShape.circle),
    );
  }
}
