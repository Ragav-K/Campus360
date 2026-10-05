import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/pulse_update.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/c_button.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/status_chip.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/pulse_providers.dart';

class PulseDetailScreen extends ConsumerWidget {
  const PulseDetailScreen({super.key, required this.pulseId});

  final String pulseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(pulseDetailProvider(pulseId));
    ref.watch(clockTickProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Update')),
      body: AsyncValueView<PulseUpdate?>(
        value: update,
        onRetry: () => ref.invalidate(pulseDetailProvider(pulseId)),
        isEmpty: (u) => u == null,
        empty: (_) => const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Update not found',
          message: 'This update has been removed or has expired.',
        ),
        data: (u) => _Body(update: u!),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.update});
  final PulseUpdate update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final remaining = update.timeRemaining;
    final accent = StatusPalette.colorOf(update.tone);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        // An update past its expiry can still be opened from a stale list or a
        // deep link — say so plainly rather than presenting it as current.
        if (!update.isLive)
          Container(
            margin: const EdgeInsets.only(bottom: Gap.lg),
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: Radii.md,
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 18),
                Gap.w12,
                Expanded(
                  child: Text(
                    'This update is no longer active.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            StatusChip.pulse(update.status),
            Gap.w8,
            Text(update.category.label, style: theme.textTheme.bodySmall),
          ],
        ),
        Gap.h16,
        Text(update.title, style: theme.textTheme.headlineSmall),
        if (update.description.isNotEmpty) ...[
          Gap.h12,
          Text(update.description, style: theme.textTheme.bodyMedium),
        ],
        Gap.h24,
        _InfoRow(
          icon: Icons.schedule_rounded,
          label: 'Posted',
          value: '${Fmt.relative(update.createdAt)} · ${Fmt.dateTime(update.createdAt)}',
        ),
        if (update.expiresAt != null)
          _InfoRow(
            icon: Icons.hourglass_bottom_rounded,
            label: 'Expires',
            value: remaining == null || remaining == Duration.zero
                ? 'Expired'
                : '${Fmt.expiresIn(remaining)} · ${Fmt.dateTime(update.expiresAt!)}',
            valueColor: (remaining != null && remaining.inMinutes < 30) ? accent : null,
          ),
        if (update.createdByName.isNotEmpty)
          _InfoRow(icon: Icons.person_outline_rounded, label: 'Posted by', value: update.createdByName),
        if (update.locationName != null)
          _InfoRow(
            icon: Icons.place_outlined,
            label: 'Location',
            value: update.locationName!,
            onTap: update.locationId == null
                ? null
                : () => context.push(Routes.locationDetail(update.locationId!)),
          ),
        Gap.h32,
        _ReportStaleButton(update: update),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.sm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: theme.colorScheme.onSurfaceVariant),
            Gap.w16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// "Report outdated information" (§6). Records one report per user; the admin
/// moderation queue reads them.
class _ReportStaleButton extends ConsumerStatefulWidget {
  const _ReportStaleButton({required this.update});
  final PulseUpdate update;

  @override
  ConsumerState<_ReportStaleButton> createState() => _ReportStaleButtonState();
}

class _ReportStaleButtonState extends ConsumerState<_ReportStaleButton> {
  bool _sending = false;
  bool _sent = false;

  Future<void> _report() async {
    final uid = ref.read(authRepositoryProvider).uid;
    if (uid == null) return;

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ReportSheet(),
    );
    if (reason == null || !mounted) return;

    setState(() => _sending = true);
    try {
      await ref.read(pulseRepositoryProvider).reportStale(
            pulseId: widget.update.id,
            uid: uid,
            reason: reason,
          );
      if (mounted) {
        setState(() => _sent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks — we\'ve flagged this for review.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final failure = e is AppFailure ? e : AppFailure.unknown;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_rounded, size: 18),
          Gap.w8,
          Text('Reported', style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    return CButton(
      label: 'Report outdated info',
      icon: Icons.flag_outlined,
      variant: CButtonVariant.outlined,
      loading: _sending,
      onPressed: _report,
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _reasons = [
    'This is no longer accurate',
    'The status has changed',
    'This place is actually closed',
    'Something else',
  ];
  String _selected = _reasons.first;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What\'s wrong with this update?', style: Theme.of(context).textTheme.titleMedium),
            Gap.h8,
            // RadioGroup replaces the per-tile groupValue/onChanged pair,
            // deprecated after Flutter 3.32.
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final reason in _reasons)
                    RadioListTile<String>(
                      value: reason,
                      title: Text(reason),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            Gap.h16,
            CButton(label: 'Send report', onPressed: () => Navigator.pop(context, _selected)),
          ],
        ),
      ),
    );
  }
}
