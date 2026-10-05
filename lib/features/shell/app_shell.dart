import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/routes.dart';
import '../../models/app_notification.dart';
import '../notifications/providers/notification_providers.dart';

/// Four-tab shell (§4). Profile, notifications and settings live in the top
/// bar of each tab, deliberately keeping the bottom bar to four destinations.
///
/// Also the host for push plumbing: it is the one widget alive for the whole
/// signed-in session, so this is where the device's FCM token is kept current
/// and where a tapped notification is turned into navigation.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();

    // A tap that cold-started the app is delivered exactly once, and before
    // the first frame. Reading it after the shell exists means there is
    // somewhere to navigate to.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await ref.read(messagingServiceProvider).initialMessage();
      if (initial != null && mounted) _openNotification(initial);
    });
  }

  void _openNotification(AppNotification notification) {
    final destination = notification.route;
    // A push with no usable payload opens the inbox rather than guessing at a
    // screen — the entry is there either way.
    context.push(destination ?? Routes.notifications);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps users/{uid}.fcmTokens in step with this device for as long as the
    // shell is mounted. Nothing reads its value; watching is what starts it.
    ref.watch(tokenRegistrarProvider);

    // A push that arrives while the app is open shows nothing by itself — the
    // OS suppresses foreground notifications — so surface it in-app.
    ref.listen(foregroundMessageProvider, (_, next) {
      final notification = next.valueOrNull;
      if (notification == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notification.title.isEmpty
                ? notification.body
                : '${notification.title} — ${notification.body}',
          ),
          action: notification.route == null
              ? null
              : SnackBarAction(label: 'Open', onPressed: () => _openNotification(notification)),
        ),
      );
    });

    ref.listen(notificationTapProvider, (_, next) {
      final notification = next.valueOrNull;
      if (notification != null) _openNotification(notification);
    });

    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        onDestinationSelected: (i) =>
            widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors_rounded),
            label: 'Pulse',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.travel_explore_rounded),
            label: 'Lost & Found',
          ),
          NavigationDestination(
            icon: Icon(Icons.print_outlined),
            selectedIcon: Icon(Icons.print_rounded),
            label: 'Printout',
          ),
        ],
      ),
    );
  }
}
