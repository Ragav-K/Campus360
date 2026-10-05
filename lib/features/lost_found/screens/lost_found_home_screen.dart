import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/found_item.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/state_views.dart';
import '../providers/lost_found_providers.dart';
import '../widgets/found_item_card.dart';
import '../widgets/match_card.dart';

/// The Lost & Found tab.
///
/// Leads with suggestions when there are any: a student who has reported a loss
/// wants to know "has anyone handed it in?" before they want to browse.
class LostFoundHomeScreen extends ConsumerWidget {
  const LostFoundHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final found = ref.watch(openFoundItemsProvider);
    final matches = ref.watch(myMatchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lost & Found'),
        actions: [
          IconButton(
            tooltip: 'My reports',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => context.push(Routes.myReports),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(Routes.profile),
          ),
          Gap.w4,
        ],
      ),
      floatingActionButton: _ReportMenu(),
      body: AsyncValueView<List<FoundItem>>(
        value: found,
        onRetry: () => ref.invalidate(openFoundItemsProvider),
        empty: (_) => _EmptyBoard(),
        isEmpty: (items) => items.isEmpty && matches.isEmpty,
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(openFoundItemsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 140),
            children: [
              if (matches.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Might be yours',
                  subtitle: matches.length == 1
                      ? '1 item looks like something you reported'
                      : '${matches.length} items look like things you reported',
                ),
                Gap.h12,
                for (final match in matches.take(5)) ...[
                  MatchCard(
                    match: match,
                    onTap: () => context.push(Routes.foundDetail(match.foundItem.id)),
                  ),
                  Gap.h12,
                ],
                Gap.h16,
              ],
              _SectionHeader(
                title: 'Handed in recently',
                subtitle: items.isEmpty ? null : '${items.length} waiting to be collected',
              ),
              Gap.h12,
              if (items.isEmpty)
                const EmptyState(
                  icon: Icons.inbox_rounded,
                  title: 'Nothing handed in yet',
                  message: 'When someone reports finding something, it appears here.',
                  compact: true,
                )
              else
                for (final item in items) ...[
                  FoundItemCard(
                    item: item,
                    onTap: () => context.push(Routes.foundDetail(item.id)),
                  ),
                  Gap.h12,
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        if (subtitle != null)
          Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
      ],
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const EmptyState(
        icon: Icons.travel_explore_rounded,
        title: 'Nothing here yet',
        message: 'Lost something, or found something lying around? '
            'Report it and it shows up here for everyone on campus.',
      );
}

/// Two actions that must not be confused with each other, so they are labelled
/// rather than hidden behind one ambiguous "+".
class _ReportMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'report-found',
          onPressed: () => context.push(Routes.reportFound),
          icon: const Icon(Icons.volunteer_activism_outlined),
          label: const Text('I found something'),
        ),
        Gap.h12,
        FloatingActionButton.extended(
          heroTag: 'report-lost',
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
          onPressed: () => context.push(Routes.reportLost),
          icon: const Icon(Icons.search_rounded),
          label: const Text('I lost something'),
        ),
      ],
    );
  }
}
