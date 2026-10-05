import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/app_notification.dart';
import '../../../widgets/async_value_view.dart';
import '../../../widgets/state_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/notification_providers.dart';

/// The in-app inbox.
///
/// Nothing writes to it yet — notifications are created by a Cloud Function,
/// which needs the Blaze plan. The empty state says so outright rather than
/// showing a cheerful "you're all caught up", which would be a lie about a
/// feature that is not running (§40: no fake states).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider);
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _markAllRead(context, ref),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: AsyncValueView<List<AppNotification>>(
        value: inbox,
        onRetry: () => ref.invalidate(inboxProvider),
        isEmpty: (items) => items.isEmpty,
        empty: (_) => const EmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'Nothing here yet',
          message: 'Updates about your print orders and Lost & Found claims will '
              'appear here. Delivery is not switched on yet — it runs on the '
              'server, which needs a paid Firebase plan.',
        ),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: Gap.sm),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => _NotificationRow(
            notification: items[i],
            onTap: () => _open(context, ref, items[i]),
          ),
        ),
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(notificationRepositoryProvider).markAllRead(uid);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeFailure(e))));
    }
  }

  Future<void> _open(BuildContext context, WidgetRef ref, AppNotification n) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final destination = n.route;

    if (!n.read) {
      // Marking read must not block opening it — a failed write here is
      // cosmetic, and the stream will correct the badge either way.
      try {
        await ref.read(notificationRepositoryProvider).markRead(n.id);
      } catch (_) {}
    }

    if (destination == null) {
      // No payload to open. Saying so beats navigating somewhere arbitrary.
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing more to show for this one')),
      );
      return;
    }
    router.push(destination);
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.read;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: unread
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          _iconFor(notification.type.category),
          size: 20,
          color: unread ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
      ),
      title: Text(
        notification.title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        notification.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: notification.createdAt == null
          ? null
          : Text(
              Fmt.relative(notification.createdAt!),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
            ),
    );
  }

  static IconData _iconFor(NotificationCategory category) => switch (category) {
        NotificationCategory.print => Icons.print_outlined,
        NotificationCategory.lostFound => Icons.search_rounded,
        NotificationCategory.pulse => Icons.campaign_outlined,
        NotificationCategory.other => Icons.notifications_none_rounded,
      };
}

/// The bell, with an unread dot. Shown in the Pulse header per §36.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return IconButton(
      onPressed: onTap ?? () => context.push(Routes.notifications),
      tooltip: unread == 0 ? 'Notifications' : '$unread unread notifications',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded),
          if (unread > 0)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                height: 10,
                width: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
