import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/enums/pulse_enums.dart';
import '../../../models/pulse_update.dart';
import '../../../widgets/state_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../../timetable/widgets/today_card.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../providers/pulse_providers.dart';
import '../widgets/home_header.dart';
import '../widgets/pulse_card.dart';
import '../widgets/pulse_deck.dart';

/// The Pulse tab, which doubles as the app's home surface (§36).
///
/// Laid out to the sketched design: greeting, a search field that is always
/// visible rather than hidden behind an icon, then the card deck as the main
/// body. Quick actions, today's timetable and the full feed follow below on
/// scroll, so nothing that existed was lost to the simplification.
class PulseHomeScreen extends ConsumerStatefulWidget {
  const PulseHomeScreen({super.key});

  @override
  ConsumerState<PulseHomeScreen> createState() => _PulseHomeScreenState();
}

class _PulseHomeScreenState extends ConsumerState<PulseHomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    ref.read(pulseSearchProvider.notifier).state = '';
    ref.read(pulseCategoryFilterProvider.notifier).state = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final updates = ref.watch(filteredPulseProvider);
    final filterActive = ref.watch(pulseFilterActiveProvider);
    final selected = ref.watch(pulseCategoryFilterProvider);
    final searching = ref.watch(pulseSearchProvider).trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(activePulseProvider),
          child: CustomScrollView(
            slivers: [
              // ---- header: name + profile ----
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(child: HomeGreeting(name: user?.displayName ?? '')),
                      const NotificationBell(),
                      IconButton(
                        tooltip: 'Profile',
                        icon: const Icon(Icons.account_circle_outlined, size: 30),
                        onPressed: () => context.push(Routes.profile),
                      ),
                    ],
                  ),
                ),
              ),

              // ---- search, always visible ----
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
                sliver: SliverToBoxAdapter(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search campus updates',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: searching
                          ? IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: _clearFilters,
                            )
                          : null,
                    ),
                    onChanged: (v) {
                      ref.read(pulseSearchProvider.notifier).state = v;
                      setState(() {});
                    },
                  ),
                ),
              ),

              // ---- the deck: main body ----
              // Hidden while searching: a deck of "top" cards makes no sense
              // when the user is looking for one specific thing.
              if (!searching)
                const SliverPadding(
                  padding: EdgeInsets.only(top: Gap.lg),
                  sliver: SliverToBoxAdapter(child: PulseDeck()),
                ),

              // ---- everything else, below the fold ----
              if (!searching) ...[
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, 0),
                  sliver: SliverToBoxAdapter(child: TodayCard()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
                  sliver: SliverToBoxAdapter(child: QuickActions()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xl, Gap.lg, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text('Happening now', style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
              ],

              SliverPadding(
                padding: EdgeInsets.only(top: searching ? Gap.lg : Gap.md),
                sliver: SliverToBoxAdapter(
                  child: _CategoryFilterRow(
                    selected: selected,
                    onSelect: (c) => ref.read(pulseCategoryFilterProvider.notifier).state = c,
                  ),
                ),
              ),

              _PulseSliverList(
                updates: updates,
                filterActive: filterActive,
                onClearFilters: _clearFilters,
                onRetry: () => ref.invalidate(activePulseProvider),
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: Gap.xxl)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow({required this.selected, required this.onSelect});

  final PulseCategory? selected;
  final ValueChanged<PulseCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        children: [
          _Chip(label: 'All', selected: selected == null, onTap: () => onSelect(null)),
          for (final category in PulseCategory.values) ...[
            Gap.w8,
            _Chip(
              label: category.label,
              selected: selected == category,
              onTap: () => onSelect(selected == category ? null : category),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: selected ? scheme.onPrimary : scheme.onSurface,
        ),
      ),
    );
  }
}

class _PulseSliverList extends StatelessWidget {
  const _PulseSliverList({
    required this.updates,
    required this.filterActive,
    required this.onClearFilters,
    required this.onRetry,
  });

  final AsyncValue<List<PulseUpdate>> updates;
  final bool filterActive;
  final VoidCallback onClearFilters;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return updates.when(
      skipLoadingOnRefresh: true,
      loading: () => SliverPadding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
        sliver: SliverList.separated(
          itemCount: 3,
          separatorBuilder: (_, __) => Gap.h12,
          itemBuilder: (_, __) => const SkeletonCard(),
        ),
      ),
      error: (e, s) => SliverToBoxAdapter(
        child: ErrorStateView(
          failure: e is AppFailure ? e : FailureMapper.map(e, s),
          onRetry: onRetry,
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: filterActive
                ? EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No updates match that',
                    message: 'Try a different category or search term.',
                    actionLabel: 'Clear filters',
                    onAction: onClearFilters,
                    compact: true,
                  )
                : const EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Nothing important right now',
                    message: 'Campus is quiet. Updates appear here as soon as '
                        'something changes.',
                    compact: true,
                  ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => Gap.h12,
            itemBuilder: (context, i) => PulseCard(
              update: items[i],
              onTap: () => context.push(Routes.pulseDetail(items[i].id)),
            ),
          ),
        );
      },
    );
  }
}
