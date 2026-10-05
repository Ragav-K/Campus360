import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';

/// "When do you need it?"
///
/// Quick presets first, because most orders are needed within a couple of
/// hours and picking a date on a phone is slow. The exact picker stays for the
/// "tomorrow before class" case.
///
/// The chosen time drives the shop's queue order, so it isn't cosmetic — the
/// helper text says so, otherwise students would treat it as decoration.
class DeadlinePicker extends StatelessWidget {
  const DeadlinePicker({super.key, required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  static const _presets = <String, Duration>{
    'In 30 min': Duration(minutes: 30),
    'In 1 hour': Duration(hours: 1),
    'In 2 hours': Duration(hours: 2),
    'In 4 hours': Duration(hours: 4),
  };

  bool _matches(Duration preset) {
    if (value == null) return false;
    final target = DateTime.now().add(preset);
    // Presets are relative to "now", which moves; treat within two minutes as
    // the same choice so the chip stays selected while the form is open.
    return value!.difference(target).abs() < const Duration(minutes: 2);
  }

  Future<void> _pickExact(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      helpText: 'Needed by',
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value ?? now.add(const Duration(hours: 1))),
      helpText: 'Needed by',
    );
    if (time == null) return;

    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: Radii.md,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              ChoiceChip(
                label: const Text('No rush'),
                selected: value == null,
                onSelected: (_) => onChanged(null),
              ),
              for (final entry in _presets.entries)
                ChoiceChip(
                  label: Text(entry.key),
                  selected: _matches(entry.value),
                  onSelected: (_) => onChanged(DateTime.now().add(entry.value)),
                ),
              ActionChip(
                avatar: const Icon(Icons.event_rounded, size: 17),
                label: const Text('Pick a time'),
                onPressed: () => _pickExact(context),
              ),
            ],
          ),
          Gap.h12,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                value == null ? Icons.schedule_rounded : Icons.event_available_rounded,
                size: 17,
                color: theme.colorScheme.primary,
              ),
              Gap.w8,
              Expanded(
                child: Text(
                  value == null
                      ? 'The shop will print it in the order it arrived.'
                      : 'Needed by ${Fmt.dateTime(value!)} — the shop sees the '
                          'most urgent jobs first.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
