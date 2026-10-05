import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/exam_schedule.dart';

/// The exam timetable behind a calendar entry — one department's papers for one
/// assessment.
///
/// Free half-days are shown rather than hidden: on a printed CIAT sheet an "NA"
/// is the difference between a free morning and a paper nobody told you about,
/// and a student scanning for their next exam needs to see the gaps.
class ExamScheduleScreen extends StatelessWidget {
  const ExamScheduleScreen({super.key, required this.schedule});

  final ExamSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slots = schedule.ordered;

    return Scaffold(
      appBar: AppBar(title: const Text('Exam timetable')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
        children: [
          Text(
            schedule.title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Gap.h4,
          Text(_subtitle(), style: theme.textTheme.bodySmall),
          Gap.h16,
          _SessionTimes(schedule: schedule),
          Gap.h16,
          if (slots.isEmpty)
            Text(
              'No papers listed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final day in _byDay(slots)) ...[
              _DayBlock(date: day.key, slots: day.value, schedule: schedule),
              Gap.h12,
            ],
          if (schedule.pattern.isNotEmpty) ...[
            Gap.h8,
            _PatternCard(schedule: schedule),
          ],
          if (schedule.source.isNotEmpty) ...[
            Gap.h16,
            Text(
              'From ${schedule.source}. Check with your department if anything '
              'looks wrong.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _subtitle() {
    final bits = [
      if (schedule.department.isNotEmpty) schedule.department,
      if (schedule.year > 0) 'Year ${schedule.year}',
      if (schedule.semester > 0) 'Semester ${schedule.semester}',
    ];
    return bits.join(' · ');
  }

  /// Groups slots by calendar day, preserving the ordering already applied.
  static List<MapEntry<DateTime, List<ExamSlot>>> _byDay(List<ExamSlot> slots) {
    final out = <DateTime, List<ExamSlot>>{};
    for (final s in slots) {
      final key = DateTime(s.date.year, s.date.month, s.date.day);
      out.putIfAbsent(key, () => []).add(s);
    }
    return out.entries.toList();
  }
}

class _SessionTimes extends StatelessWidget {
  const _SessionTimes({required this.schedule});

  final ExamSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = [
      if (schedule.fnTime.isNotEmpty) ('Forenoon', schedule.fnTime),
      if (schedule.anTime.isNotEmpty) ('Afternoon', schedule.anTime),
      if (schedule.portion.isNotEmpty) ('Portion', schedule.portion),
      if (schedule.maxMarks.isNotEmpty) ('Maximum marks', schedule.maxMarks),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: Radii.md,
      ),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 118,
                    child: Text(label, style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.date, required this.slots, required this.schedule});

  final DateTime date;
  final List<ExamSlot> slots;
  final ExamSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final isToday =
        date.year == today.year && date.month == today.month && date.day == today.day;
    final accent = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: Radii.md,
        border: Border.all(color: isToday ? accent : theme.colorScheme.outline),
      ),
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                Fmt.date(date),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isToday ? accent : null,
                ),
              ),
              if (isToday) ...[
                Gap.w8,
                Text(
                  'TODAY',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          Gap.h8,
          for (final slot in slots) _SlotRow(slot: slot, schedule: schedule),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.schedule});

  final ExamSlot slot;
  final ExamSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final time = schedule.timeFor(slot.session);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.session.shortLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: slot.isFree ? muted : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: slot.isFree
                ? Text('No paper', style: theme.textTheme.bodySmall?.copyWith(color: muted))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (slot.isChoice) ...[
                        Text(
                          'One of these — whichever you are enrolled in',
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                        Gap.h4,
                      ],
                      for (final paper in slot.papers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                paper.subject,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (paper.code.isNotEmpty)
                                Text(paper.code, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      if (slot.note.isNotEmpty)
                        Text(slot.note, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                      if (time.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(time, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.schedule});

  final ExamSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: Radii.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question paper pattern',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Gap.h4,
          for (final line in schedule.pattern)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(line, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
