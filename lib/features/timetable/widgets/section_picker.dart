import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../models/timetable.dart';
import '../../../widgets/state_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/timetable_providers.dart';

/// Sheet for choosing which class timetable to follow. Used from the timetable
/// screen and from Profile.
Future<void> showSectionPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SectionPickerSheet(),
  );
}

class _SectionPickerSheet extends ConsumerWidget {
  const _SectionPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(allSectionsProvider);
    final selected = ref.watch(userSectionProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your class', style: theme.textTheme.titleMedium),
              Gap.h4,
              Text(
                'Pick the section whose timetable you follow.',
                style: theme.textTheme.bodySmall,
              ),
              Gap.h16,
              Flexible(
                child: sections.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(Gap.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Couldn\'t load classes',
                    message: 'Check your connection and try again.',
                    compact: true,
                  ),
                  data: (list) => list.isEmpty
                      ? const EmptyState(
                          icon: Icons.school_outlined,
                          title: 'No classes set up yet',
                          message: 'Timetables haven\'t been added for this campus.',
                          compact: true,
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: list.length,
                          itemBuilder: (_, i) => _SectionTile(
                            section: list[i],
                            selected: list[i].id == selected,
                            onTap: () async {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .setSection(list[i].id);
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section, required this.selected, required this.onTap});

  final Timetable section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.class_outlined,
          size: 19,
          color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        ),
      ),
      title: Text(section.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: section.department.isEmpty
          ? null
          : Text('${section.department}${section.year > 0 ? ' · Year ${section.year}' : ''}'),
      trailing: selected ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
    );
  }
}
