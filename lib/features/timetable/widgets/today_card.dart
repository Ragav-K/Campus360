import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/status_palette.dart';
import '../../../models/enums/pulse_enums.dart';
import '../../../models/timetable.dart';
import '../providers/timetable_providers.dart';

/// Today's schedule at a glance, on the Pulse home surface.
///
/// Shows the running period with time remaining, then what's next. Handles the
/// cases that actually occur: holidays, weekends, before the first period and
/// after the last one — each with its own honest message rather than a blank
/// card.
class TodayCard extends ConsumerWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(todayScheduleProvider);

    // Nothing to offer and nothing to set up — stay out of the way.
    if (!schedule.hasSection) return const _PickSectionCard();
    if (!schedule.hasTimetable) return const _NoTimetableCard();

    return _Shell(
      onTap: () => context.push(Routes.timetable),
      child: switch (schedule) {
        TodaySchedule(isHoliday: true, holiday: final holiday?) => _Message(
            icon: holiday.type.icon,
            tone: StatusTone.good,
            title: holiday.title,
            subtitle: 'No classes today',
          ),
        TodaySchedule(isWeekendOrEmpty: true) => const _Message(
            icon: Icons.weekend_rounded,
            tone: StatusTone.neutral,
            title: 'No classes today',
            subtitle: 'Enjoy the day',
          ),
        TodaySchedule(isDayOver: true) => const _Message(
            icon: Icons.done_all_rounded,
            tone: StatusTone.good,
            title: 'Classes are done for today',
            subtitle: 'Tap to see the full week',
          ),
        _ => _Now(schedule: schedule),
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          padding: const EdgeInsets.all(Gap.lg),
          child: child,
        ),
      ),
    );
  }
}

/// The normal case: what's on right now, and what follows.
class _Now extends StatelessWidget {
  const _Now({required this.schedule});

  final TodaySchedule schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = schedule.current;
    final next = schedule.next;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule_rounded, size: 18, color: theme.colorScheme.primary),
            Gap.w8,
            Text('Today', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              '${schedule.periods.length} periods',
              style: theme.textTheme.bodySmall,
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
        Gap.h16,
        if (current != null)
          _PeriodRow(
            period: current,
            leading: 'Now',
            highlight: true,
            trailing: _remainingLabel(current),
          )
        else
          _BetweenRow(next: next),
        if (next != null) ...[
          const Divider(height: Gap.xl),
          _PeriodRow(period: next, leading: 'Next', trailing: next.start),
        ],
      ],
    );
  }

  static String? _remainingLabel(Period period) {
    final left = period.remainingAt(DateTime.now());
    if (left == null) return null;
    return left.inMinutes < 1 ? 'ending now' : '${left.inMinutes} min left';
  }
}

/// Between two periods, or before the first one.
class _BetweenRow extends StatelessWidget {
  const _BetweenRow({required this.next});

  final Period? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.free_breakfast_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
        Gap.w12,
        Expanded(
          child: Text(
            next == null ? 'No class right now' : 'Free until ${next!.start}',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.period,
    required this.leading,
    this.trailing,
    this.highlight = false,
  });

  final Period period;
  final String leading;
  final String? trailing;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: highlight ? accent.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: Radii.sm,
          ),
          child: Text(
            leading,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight ? accent : null,
            ),
          ),
        ),
        Gap.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period.subject,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                [
                  period.timeRange,
                  if (period.room.isNotEmpty) period.room,
                  if (period.staff.isNotEmpty) period.staff,
                ].join(' · '),
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          Gap.w8,
          Text(
            trailing!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: highlight ? accent : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final StatusTone tone;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = StatusPalette.colorOf(tone);

    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: StatusPalette.surfaceOf(tone, theme.brightness),
            borderRadius: Radii.sm,
          ),
          child: Icon(icon, size: 21, color: color),
        ),
        Gap.w16,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
      ],
    );
  }
}

/// No section chosen yet — invite rather than show an empty grid.
class _PickSectionCard extends ConsumerWidget {
  const _PickSectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Shell(
      onTap: () => context.push(Routes.timetable),
      child: const _Message(
        icon: Icons.school_outlined,
        tone: StatusTone.info,
        title: 'See your timetable',
        subtitle: 'Pick your class to get started',
      ),
    );
  }
}

/// Section chosen, but nobody has uploaded that timetable yet. Says so plainly
/// instead of inventing periods.
class _NoTimetableCard extends StatelessWidget {
  const _NoTimetableCard();

  @override
  Widget build(BuildContext context) {
    return _Shell(
      onTap: () => context.push(Routes.timetable),
      child: const _Message(
        icon: Icons.event_busy_outlined,
        tone: StatusTone.neutral,
        title: 'No timetable yet',
        subtitle: 'Your class schedule hasn\'t been added',
      ),
    );
  }
}
