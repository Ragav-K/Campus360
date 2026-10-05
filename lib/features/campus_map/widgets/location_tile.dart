import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../models/campus_location.dart';
import '../../../widgets/status_chip.dart';
import '../../campus_pulse/providers/pulse_providers.dart';

/// A location row that also shows its **live Campus Pulse status** — the
/// Pulse↔Map connection required by §8 ("Library marker → current crowd
/// status").
class LocationTile extends ConsumerWidget {
  const LocationTile({super.key, required this.location, this.onTap, this.onShowOnMap});

  final CampusLocation location;
  final VoidCallback? onTap;

  /// Shown only for surveyed locations — an unmapped place has nowhere to go.
  final VoidCallback? onShowOnMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pulse = ref.watch(locationPulseProvider(location.id)).valueOrNull;
    final openNow = location.isOpenAt(DateTime.now());

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: Radii.md,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: Radii.md,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: Radii.sm,
                ),
                child: Icon(location.category.icon, size: 21, color: theme.colorScheme.primary),
              ),
              Gap.w16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location.subtitle,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (pulse != null || openNow != null) ...[
                      Gap.h8,
                      Row(
                        children: [
                          if (pulse != null) StatusChip.pulse(pulse.status, dense: true, short: true),
                          if (pulse != null && openNow != null) Gap.w8,
                          // Only claim open/closed when hours are recorded —
                          // silence is not the same as "closed".
                          if (openNow != null)
                            Text(
                              openNow ? 'Open now' : 'Closed now',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (onShowOnMap != null)
                IconButton(
                  tooltip: 'Show on map',
                  icon: const Icon(Icons.place_outlined),
                  color: theme.colorScheme.primary,
                  onPressed: onShowOnMap,
                )
              else
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
