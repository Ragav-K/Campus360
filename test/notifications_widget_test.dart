import 'package:campus360/features/notifications/providers/notification_providers.dart';
import 'package:campus360/features/notifications/screens/notifications_screen.dart';
import 'package:campus360/models/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the notification surfaces.
///
/// These render without Firebase by overriding the two providers the screens
/// actually watch — the repository is only touched on tap, which these do not
/// do. That is the whole reason the inbox reads from providers rather than
/// calling the repository inline.

AppNotification _n({
  String id = 'n1',
  NotificationType type = NotificationType.printReady,
  String title = 'Ready for pickup',
  String body = 'Order #1042 is ready.',
  bool read = false,
}) =>
    AppNotification(
      id: id,
      userId: 'u1',
      type: type,
      title: title,
      body: body,
      data: const {'orderId': '1042'},
      read: read,
      createdAt: DateTime(2026, 8, 20, 10),
    );

Widget _harness(Widget child, {List<AppNotification> inbox = const [], int unread = 0}) =>
    ProviderScope(
      overrides: [
        inboxProvider.overrideWith((_) => Stream.value(inbox)),
        unreadCountProvider.overrideWith((_) => Stream.value(unread)),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  group('NotificationsScreen', () {
    testWidgets('an empty inbox says delivery is not switched on', (tester) async {
      await tester.pumpWidget(_harness(const NotificationsScreen()));
      await tester.pump();

      expect(find.text('Nothing here yet'), findsOneWidget);

      // The honest empty state (§40): not a cheerful "you're all caught up",
      // which would imply a feature that is not running.
      expect(
        find.textContaining('needs a paid Firebase plan'),
        findsOneWidget,
        reason: 'the empty state must not imply notifications are being delivered',
      );
    });

    testWidgets('renders each notification with its title and body', (tester) async {
      await tester.pumpWidget(_harness(
        const NotificationsScreen(),
        inbox: [
          _n(),
          _n(id: 'n2', type: NotificationType.lostFoundMatch, title: 'Possible match', body: 'For your ID card.'),
        ],
        unread: 2,
      ));
      await tester.pump();

      expect(find.text('Ready for pickup'), findsOneWidget);
      expect(find.text('Order #1042 is ready.'), findsOneWidget);
      expect(find.text('Possible match'), findsOneWidget);
    });

    // Two tests rather than one with a second pumpWidget: re-pumping reuses the
    // ProviderScope's container, so the new overrides never take effect and the
    // assertion silently measures the first state twice.
    testWidgets('"Mark all read" is hidden when everything is read', (tester) async {
      await tester.pumpWidget(_harness(
        const NotificationsScreen(),
        inbox: [_n(read: true)],
      ));
      await tester.pump();

      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('"Mark all read" appears when something is unread', (tester) async {
      await tester.pumpWidget(_harness(
        const NotificationsScreen(),
        inbox: [_n()],
        unread: 1,
      ));
      await tester.pump();

      expect(find.text('Mark all read'), findsOneWidget);
    });

    testWidgets('an unread entry is weighted more heavily than a read one', (tester) async {
      await tester.pumpWidget(_harness(
        const NotificationsScreen(),
        inbox: [_n(), _n(id: 'n2', title: 'Collected', read: true)],
        unread: 1,
      ));
      await tester.pump();

      final unreadTitle = tester.widget<Text>(find.text('Ready for pickup'));
      final readTitle = tester.widget<Text>(find.text('Collected'));

      expect(unreadTitle.style?.fontWeight, FontWeight.w700);
      expect(readTitle.style?.fontWeight, FontWeight.w500);
    });
  });

  group('NotificationBell', () {
    testWidgets('says how many are unread', (tester) async {
      await tester.pumpWidget(_harness(
        Scaffold(appBar: AppBar(actions: [NotificationBell(onTap: () {})])),
        unread: 3,
      ));
      await tester.pump();

      // The count lives in the tooltip rather than a number badge — the dot
      // shows there is something, and a screen reader gets the detail.
      final bell = tester.widget<IconButton>(find.byType(IconButton));
      expect(bell.tooltip, '3 unread notifications');
    });

    testWidgets('reads as plain "Notifications" when there is nothing', (tester) async {
      await tester.pumpWidget(_harness(
        Scaffold(appBar: AppBar(actions: [NotificationBell(onTap: () {})])),
      ));
      await tester.pump();

      final bell = tester.widget<IconButton>(find.byType(IconButton));
      expect(bell.tooltip, 'Notifications');
    });

    testWidgets('tapping it opens the inbox', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_harness(
        Scaffold(appBar: AppBar(actions: [NotificationBell(onTap: () => tapped = true)])),
        unread: 1,
      ));
      await tester.pump();

      await tester.tap(find.byType(IconButton));
      expect(tapped, isTrue);
    });
  });
}
