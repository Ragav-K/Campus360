import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/pulse_update.dart';
import '../../../widgets/status_chip.dart';

/// One update in the Pulse list.
class PulseCard extends StatelessWidget {
  const PulseCard({super.key, required this.update, this.onTap});

  final PulseUpdate update;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = update.tone;
    final accent = StatusPalette.colorOf(tone);
    final remaining = update.timeRemaining;

    return Semantics(
      button: onTap != null,
      label: '${update.title}. ${update.status.label}.'
          '${update.locationName == null ? '' : ' At ${update.locationName}.'}',
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: Radii.md,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: Radii.md,
              border: Border.all(color: theme.colorScheme.outline),
              // A subtle leading accent bar carries the status colour without
              // tinting the whole card, which would get noisy in a long list.
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.85), Colors.transparent],
                stops: const [0.006, 0.006],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.md, Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip.pulse(update.status, dense: true),
                    Gap.w8,
                    Flexible(
                      child: Text(
                        // Prefer the live headcount over the category label
                        // when one is available; null for density readings.
                        update.occupancyLabel ?? update.category.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: update.occupancyLabel != null ? FontWeight.w600 : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    Text(Fmt.relative(update.createdAt), style: theme.textTheme.bodySmall),
                  ],
                ),
                Gap.h12,
                Text(
                  update.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (update.description.isNotEmpty) ...[
                  Gap.h4,
                  Text(
                    update.description,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (update.locationName != null || remaining != null) ...[
                  Gap.h12,
                  Row(
                    children: [
                      if (update.locationName != null) ...[
                        Icon(Icons.place_outlined, size: 15, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            update.locationName!,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (update.locationName != null && remaining != null) Gap.w12,
                      if (remaining != null)
                        Text(
                          Fmt.expiresIn(remaining),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: remaining.inMinutes < 30 ? accent : null,
                            fontWeight: remaining.inMinutes < 30 ? FontWeight.w600 : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
