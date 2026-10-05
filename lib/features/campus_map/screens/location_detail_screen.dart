import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/campus_location.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/c_button.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/status_chip.dart';
import '../../campus_pulse/providers/pulse_providers.dart';
import '../providers/location_providers.dart';

class LocationDetailScreen extends ConsumerWidget {
  const LocationDetailScreen({super.key, required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationDetailProvider(locationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Location')),
      body: AsyncValueView<CampusLocation?>(
        value: location,
        onRetry: () => ref.invalidate(locationDetailProvider(locationId)),
        isEmpty: (l) => l == null,
        empty: (_) => const EmptyState(
          icon: Icons.wrong_location_outlined,
          title: 'Location not found',
          message: 'This place has been removed from the campus directory.',
        ),
        data: (l) => _Body(location: l!),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.location});
  final CampusLocation location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pulse = ref.watch(locationPulseProvider(location.id)).valueOrNull;
    final openNow = location.isOpenAt(DateTime.now());
    ref.watch(clockTickProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        Row(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: Radii.md,
              ),
              child: Icon(location.category.icon, size: 26, color: theme.colorScheme.primary),
            ),
            Gap.w16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(location.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(location.category.label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),

        // Live status from Campus Pulse — the §8 map↔pulse connection.
        if (pulse != null) ...[
          Gap.h24,
          InkWell(
            onTap: () => context.push(Routes.pulseDetail(pulse.id)),
            borderRadius: Radii.md,
            child: Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: Radii.md,
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                children: [
                  StatusChip.pulse(pulse.status),
                  Gap.w12,
                  Expanded(
                    child: Text(
                      pulse.title,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],

        Gap.h24,
        if (location.description.isNotEmpty) ...[
          Text(location.description, style: theme.textTheme.bodyMedium),
          Gap.h24,
        ],

        if (location.building.isNotEmpty)
          _Row(icon: Icons.apartment_rounded, label: 'Building', value: location.building),
        if (location.floor.isNotEmpty)
          _Row(icon: Icons.stairs_outlined, label: 'Floor', value: location.floor),
        if (location.roomCode.isNotEmpty)
          _Row(icon: Icons.meeting_room_outlined, label: 'Room', value: location.roomCode),

        _Row(
          icon: Icons.schedule_rounded,
          label: 'Hours',
          // Never imply "closed" when hours simply aren't recorded.
          value: switch (openNow) {
            null => 'Not listed',
            true => 'Open now',
            false => 'Closed now',
          },
        ),

        if (location.openHours.isNotEmpty) ...[
          Gap.h8,
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: Radii.md,
            ),
            child: Column(
              children: [
                for (final h in location.openHours)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_weekday(h.day), style: theme.textTheme.bodySmall),
                        Text(
                          '${h.open} – ${h.close}',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        Gap.h24,
        if (location.hasCoordinates)
          CButton(
            label: 'Navigate here',
            icon: Icons.directions_walk_rounded,
            onPressed: () => context.push(Routes.navigate(location.id)),
          )
        else
          // No coordinates means no navigation — say so plainly rather than
          // offering a button that can only fail.
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: Radii.md,
            ),
            child: Row(
              children: [
                Icon(Icons.explore_off_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                Gap.w12,
                Expanded(
                  child: Text(
                    'This place hasn\'t had its position recorded yet, so it '
                    'can\'t be navigated to.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _weekday(int day) => switch (day) {
        DateTime.monday => 'Monday',
        DateTime.tuesday => 'Tuesday',
        DateTime.wednesday => 'Wednesday',
        DateTime.thursday => 'Thursday',
        DateTime.friday => 'Friday',
        DateTime.saturday => 'Saturday',
        _ => 'Sunday',
      };
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      child: Row(
        children: [
          Icon(icon, size: 19, color: theme.colorScheme.onSurfaceVariant),
          Gap.w16,
          Text(label, style: theme.textTheme.bodySmall),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
