import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/enums/print_enums.dart';
import '../../../models/print_order.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/c_button.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/status_chip.dart';
import '../providers/print_providers.dart';

/// Tracks one order through the shop.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Print order')),
      body: AsyncValueView<PrintOrder?>(
        value: order,
        onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        isEmpty: (o) => o == null,
        empty: (_) => const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Order not found',
          message: 'This order no longer exists.',
        ),
        data: (o) => _Body(order: o!),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.order});
  final PrintOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final overdue = order.isOverdue();

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        Row(
          children: [
            StatusChip(
              label: order.status.studentLabel,
              tone: order.status.tone,
              icon: order.status.icon,
            ),
            const Spacer(),
            Text('Order #${order.orderNumber}', style: theme.textTheme.bodySmall),
          ],
        ),
        Gap.h16,
        Text(order.document.fileName, style: theme.textTheme.headlineSmall),
        Gap.h8,
        Text(order.settings.summary, style: theme.textTheme.bodyMedium),

        if (order.status == PrintOrderStatus.rejected && order.rejectionReason != null) ...[
          Gap.h16,
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.10),
              borderRadius: Radii.md,
              border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, size: 19, color: theme.colorScheme.error),
                Gap.w12,
                Expanded(
                  child: Text(order.rejectionReason!, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ],

        Gap.h24,
        _Progress(status: order.status),

        Gap.h24,
        _Row(icon: Icons.storefront_outlined, label: 'Print shop', value: order.shopName),
        if (order.neededBy != null)
          _Row(
            icon: overdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
            label: 'Needed by',
            value: Fmt.dateTime(order.neededBy!),
            valueColor: overdue ? theme.colorScheme.error : null,
          ),
        _Row(
          icon: Icons.upload_file_rounded,
          label: 'Placed',
          value: '${Fmt.relative(order.createdAt)} · ${Fmt.dateTime(order.createdAt)}',
        ),
        _Row(
          icon: Icons.insert_drive_file_outlined,
          label: 'File',
          value: Fmt.fileSize(order.document.sizeBytes),
        ),
        if (order.estimatedCost != null)
          _Row(
            icon: Icons.payments_outlined,
            label: 'Estimated cost',
            value: '₹${order.estimatedCost!.toStringAsFixed(2)} (shop confirms)',
          ),

        if (order.status == PrintOrderStatus.readyForPickup) ...[
          Gap.h24,
          Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              color: StatusPalette.surfaceOf(order.status.tone, theme.brightness),
              borderRadius: Radii.md,
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: StatusPalette.colorOf(order.status.tone)),
                Gap.w12,
                Expanded(
                  child: Text(
                    'Ready to collect at ${order.shopName}. Show your order '
                    'number at the counter.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],

        if (order.status.isCancellableByStudent) ...[
          Gap.h32,
          _CancelButton(order: order),
        ],
      ],
    );
  }
}

/// The §20 pipeline, with everything after the current step dimmed.
class _Progress extends StatelessWidget {
  const _Progress({required this.status});
  final PrintOrderStatus status;

  static const _steps = [
    PrintOrderStatus.received,
    PrintOrderStatus.accepted,
    PrintOrderStatus.printing,
    PrintOrderStatus.readyForPickup,
    PrintOrderStatus.collected,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // A rejected or cancelled order never walks the pipeline; showing it would
    // imply progress that will never happen.
    if (status == PrintOrderStatus.rejected || status == PrintOrderStatus.cancelled) {
      return const SizedBox.shrink();
    }

    final currentIndex = _steps.indexOf(status);

    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    i <= currentIndex ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 20,
                    color: i <= currentIndex
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  if (i < _steps.length - 1)
                    Container(
                      width: 2,
                      height: 26,
                      color: i < currentIndex
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                ],
              ),
              Gap.w16,
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  _steps[i].label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: i == currentIndex ? FontWeight.w700 : FontWeight.w400,
                    color: i <= currentIndex ? null : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _CancelButton extends ConsumerStatefulWidget {
  const _CancelButton({required this.order});
  final PrintOrder order;

  @override
  ConsumerState<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends ConsumerState<_CancelButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return CButton(
      label: 'Cancel this order',
      variant: CButtonVariant.outlined,
      danger: true,
      loading: _busy,
      onPressed: () async {
        // Grabbed before any await: `context` here belongs to build(), so
        // reaching through it afterwards is what the analyzer objects to.
        final messenger = ScaffoldMessenger.of(context);

        final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Cancel this order?'),
                content: const Text(
                  'The shop will stop work on it. You can place a new order at '
                  'any time.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel order')),
                ],
              ),
            ) ??
            false;
        if (!confirmed) return;

        setState(() => _busy = true);
        try {
          await ref.read(printRepositoryProvider).cancelOrder(widget.order.id);
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(SnackBar(content: Text(describeFailure(e))));
          }
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value, this.valueColor});

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
        ],
      ),
    );
  }
}
