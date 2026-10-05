import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/calendar_event.dart';
import '../../../models/timetable.dart';
import '../../../widgets/state_views.dart';
import '../providers/timetable_providers.dart';
import '../widgets/section_picker.dart';
import 'exam_schedule_screen.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sectionId = ref.watch(userSectionProvider);
    final timetable = ref.watch(myTimetableProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        actions: [
          IconButton(
            tooltip: 'Change class',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: () => showSectionPicker(context, ref),
          ),
          Gap.w4,
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Week'), Tab(text: 'Calendar')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          if (sectionId == null || sectionId.isEmpty)
            EmptyState(
              icon: Icons.school_outlined,
              title: 'Pick your class',
              message: 'Choose your class section to see its weekly timetable.',
              actionLabel: 'Choose class',
              onAction: () => showSectionPicker(context, ref),
            )
          else
            timetable.when(
              loading: () => const _WeekSkeleton(),
              error: (_, __) => const EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Couldn\'t load the timetable',
                message: 'Check your connection and try again.',
              ),
              data: (t) => (t == null || t.isEmpty)
                  ? EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: 'No timetable yet',
                      message: 'Nobody has added a schedule for this class. '
                          'Once an admin uploads it, it appears here.',
                      actionLabel: 'Choose a different class',
                      onAction: () => showSectionPicker(context, ref),
                    )
                  : _WeekView(timetable: t),
            ),
          const _CalendarView(),
        ],
      ),
    );
  }
}

/// Weekday-by-weekday list. A vertical list per day rather than a scrolling
/// grid — on a phone a 7×8 grid is unreadable, and students look up one day at
/// a time.
class _WeekView extends ConsumerStatefulWidget {
  const _WeekView({required this.timetable});

  final Timetable timetable;

  @override
  ConsumerState<_WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<_WeekView> {
  late int _day = _todayOrMonday();

  static int _todayOrMonday() {
    final today = DateTime.now().weekday;
    return today == DateTime.sunday ? DateTime.monday : today;
  }

  static const _labels = {
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
    DateTime.saturday: 'Sat',
  };

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider);
    final periods = widget.timetable.forDay(_day);
    final isToday = _day == now.weekday;
    final current = isToday ? widget.timetable.currentPeriod(now) : null;

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            children: [
              for (final entry in _labels.entries) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: Gap.sm),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _day == entry.key,
                      onSelected: (_) => setState(() => _day = entry.key),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _day == entry.key
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: periods.isEmpty
              ? const EmptyState(
                  icon: Icons.weekend_rounded,
                  title: 'No classes',
                  message: 'Nothing scheduled on this day.',
                  compact: true,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
                  itemCount: periods.length,
                  separatorBuilder: (_, __) => Gap.h8,
                  itemBuilder: (_, i) => _PeriodTile(
                    period: periods[i],
                    isNow: current != null && current.index == periods[i].index,
                  ),
                ),
        ),
      ],
    );
  }
}

class _PeriodTile extends StatelessWidget {
  const _PeriodTile({required this.period, this.isNow = false});

  final Period period;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final isBreak = !period.type.isClass;

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: isNow ? accent.withValues(alpha: 0.10) : theme.colorScheme.surface,
        borderRadius: Radii.md,
        border: Border.all(color: isNow ? accent : theme.colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.start,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isNow ? accent : null,
                  ),
                ),
                Text(period.end, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Gap.w12,
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: isBreak ? theme.colorScheme.outline : (isNow ? accent : theme.colorScheme.primary),
              borderRadius: Radii.pill,
            ),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        period.subject,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isBreak ? theme.colorScheme.onSurfaceVariant : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isNow) ...[
                      Gap.w8,
                      Text(
                        'NOW',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: accent,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                if (period.staff.isNotEmpty || period.room.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (period.room.isNotEmpty) period.room,
                      if (period.staff.isNotEmpty) period.staff,
                      if (period.code.isNotEmpty) period.code,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Upcoming holidays, exams and events.
class _CalendarView extends ConsumerWidget {
  const _CalendarView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(upcomingEventsProvider);
    final loading = ref.watch(calendarProvider).isLoading;

    if (loading && events.isEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(Gap.lg),
        itemCount: 4,
        separatorBuilder: (_, __) => Gap.h12,
        itemBuilder: (_, __) => const SkeletonCard(lines: 1),
      );
    }

    if (events.isEmpty) {
      return const EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Nothing on the calendar',
        message: 'Holidays, exams and campus events appear here once they\'re added.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      itemCount: events.length,
      separatorBuilder: (_, __) => Gap.h12,
      itemBuilder: (_, i) => _EventTile(event: events[i]),
    );
  }
}

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tone = event.type.tone;
    final color = StatusPalette.colorOf(tone);
    final isToday = event.coversDay(DateTime.now());

    // Exams carry a department exam sheet when one has been published; the rest
    // of the calendar has nothing further to show, so it stays inert.
    final schedule = ref.watch(examScheduleForEventProvider(event.id));

    final card = Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: Radii.md,
        border: Border.all(color: isToday ? color : theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: StatusPalette.surfaceOf(tone, theme.brightness),
              borderRadius: Radii.sm,
            ),
            child: Icon(event.type.icon, size: 21, color: color),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        event.title,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isToday) ...[
                      Gap.w8,
                      Text(
                        'TODAY',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w800, color: color, fontSize: 11),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  event.isMultiDay
                      ? '${Fmt.date(event.date)} – ${Fmt.date(event.endDate!)}'
                      : Fmt.date(event.date),
                  style: theme.textTheme.bodySmall,
                ),
                if (event.description.isNotEmpty) ...[
                  Gap.h4,
                  Text(event.description, style: theme.textTheme.bodySmall, maxLines: 2),
                ],
                if (schedule != null) ...[
                  Gap.h4,
                  Text(
                    '${schedule.papersOnly.length} papers · tap to see the timetable',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (schedule != null) ...[
            Gap.w8,
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
          ],
        ],
      ),
    );

    if (schedule == null) return card;

    return InkWell(
      borderRadius: Radii.md,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExamScheduleScreen(schedule: schedule),
        ),
      ),
      child: card,
    );
  }
}

class _WeekSkeleton extends StatelessWidget {
  const _WeekSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(Gap.lg),
      itemCount: 5,
      separatorBuilder: (_, __) => Gap.h8,
      itemBuilder: (_, __) => const SkeletonCard(lines: 1),
    );
  }
}
