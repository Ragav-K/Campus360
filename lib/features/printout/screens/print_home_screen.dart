import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/print_order.dart';
import '../../../widgets/c_button.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/status_chip.dart';
import '../providers/print_providers.dart';

/// The Printout tab: current orders, past orders, and a way to place one.
class PrintHomeScreen extends ConsumerWidget {
  const PrintHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    final active = ref.watch(activeOrdersProvider);
    final past = ref.watch(pastOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printout'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(Routes.profile),
          ),
          Gap.w4,
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newPrintOrder),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New order'),
      ),
      body: orders.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(Gap.lg),
          itemCount: 3,
          separatorBuilder: (_, __) => Gap.h12,
          itemBuilder: (_, __) => const SkeletonCard(),
        ),
        error: (e, s) => ErrorStateView(
          failure: describeAsFailure(e),
          onRetry: () => ref.invalidate(myOrdersProvider),
        ),
        data: (all) {
          if (all.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Gap.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmptyState(
                      icon: Icons.print_outlined,
                      title: 'You don\'t have any print orders',
                      message: 'Send a document to a campus print shop and pick '
                          'it up when it\'s ready.',
                      compact: true,
                    ),
                    Gap.h8,
                    CButton(
                      label: 'New print order',
                      icon: Icons.add_rounded,
                      expand: false,
                      onPressed: () => context.push(Routes.newPrintOrder),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 96),
            children: [
              if (active.isNotEmpty) ...[
                Text('Current orders', style: Theme.of(context).textTheme.titleMedium),
                Gap.h12,
                for (final order in active) ...[
                  OrderCard(order: order, onTap: () => context.push(Routes.printOrder(order.id))),
                  Gap.h12,
                ],
              ],
              if (past.isNotEmpty) ...[
                Gap.h8,
                Text('Previous orders', style: Theme.of(context).textTheme.titleMedium),
                Gap.h12,
                for (final order in past) ...[
                  OrderCard(order: order, onTap: () => context.push(Routes.printOrder(order.id))),
                  Gap.h12,
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.onTap});

  final PrintOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = order.isOverdue();
    final accent = StatusPalette.colorOf(order.status.tone);

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
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: 0.85), Colors.transparent],
              stops: const [0.006, 0.006],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.md, Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusChip(
                    label: order.status.studentLabel,
                    tone: order.status.tone,
                    dense: true,
                    icon: order.status.icon,
                  ),
                  const Spacer(),
                  Text('#${order.orderNumber}', style: theme.textTheme.bodySmall),
                ],
              ),
              Gap.h12,
              Text(
                order.document.fileName,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Gap.h4,
              Text(
                '${order.shopName} · ${order.settings.summary}',
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (order.neededBy != null) ...[
                Gap.h12,
                Row(
                  children: [
                    Icon(
                      overdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
                      size: 15,
                      color: overdue ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                    ),
                    Gap.w8,
                    Text(
                      overdue
                          ? 'Was needed by ${Fmt.time(order.neededBy!)}'
                          : 'Needed by ${Fmt.time(order.neededBy!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: overdue ? theme.colorScheme.error : null,
                        fontWeight: overdue ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
