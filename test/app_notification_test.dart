import 'package:campus360/models/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _n(NotificationType type, Map<String, String> data) => AppNotification(
      id: 'x',
      userId: 'u1',
      type: type,
      title: 'Title',
      body: 'Body',
      data: data,
    );

void main() {
  group('NotificationType', () {
    test('maps every wire value from the design document', () {
      expect(NotificationType.fromWire('print.ready'), NotificationType.printReady);
      expect(NotificationType.fromWire('lostfound.claimRequest'),
          NotificationType.lostFoundClaimRequest);
      expect(NotificationType.fromWire('pulse.alert'), NotificationType.pulseAlert);
    });

    test('an unrecognised type degrades instead of throwing', () {
      // The sender is a Cloud Function deployed independently of installed
      // app versions. A client that threw on an unknown type would break every
      // older install the day a new notification type shipped.
      expect(NotificationType.fromWire('print.somethingNew'), NotificationType.unknown);
      expect(NotificationType.fromWire(null), NotificationType.unknown);
    });

    test('categories group the modules the preference switches use', () {
      expect(NotificationType.printReady.category, NotificationCategory.print);
      expect(NotificationType.printRejected.category, NotificationCategory.print);
      expect(NotificationType.lostFoundMatch.category, NotificationCategory.lostFound);
      expect(NotificationType.pulseAlert.category, NotificationCategory.pulse);
      expect(NotificationType.unknown.category, NotificationCategory.other);
    });
  });

  group('deep links', () {
    test('every print type opens the order it is about', () {
      for (final type in NotificationType.values
          .where((t) => t.category == NotificationCategory.print)) {
        expect(_n(type, {'orderId': '1042'}).route, '/print/order/1042',
            reason: '${type.wire} should open its order');
      }
    });

    test('lost & found types open the match or claim', () {
      expect(_n(NotificationType.lostFoundMatch, {'matchId': 'm7'}).route, '/lostfound/match/m7');
      expect(_n(NotificationType.lostFoundClaimApproved, {'claimId': 'c3'}).route,
          '/lostfound/claim/c3');
      expect(_n(NotificationType.lostFoundReturned, {'claimId': 'c3'}).route,
          '/lostfound/claim/c3');
    });

    test('a pulse alert opens the update', () {
      expect(_n(NotificationType.pulseAlert, {'pulseId': 'p1'}).route, '/pulse/p1');
    });

    test('a payload missing its id routes nowhere rather than guessing', () {
      // Opening the wrong screen is worse than opening none: the user acts on
      // what they are shown.
      expect(_n(NotificationType.printReady, const {}).route, isNull);
      expect(_n(NotificationType.lostFoundMatch, const {}).route, isNull);
      expect(_n(NotificationType.lostFoundMatch, {'orderId': '1042'}).route, isNull);
      expect(_n(NotificationType.unknown, {'orderId': '1042'}).route, isNull);
    });
  });

  group('fromMessageData', () {
    test('builds a displayable notification from an FCM payload', () {
      final n = AppNotification.fromMessageData(
        id: 'msg-1',
        data: {'type': 'print.ready', 'orderId': '1042'},
        title: 'Ready for pickup',
        body: 'Order #1042 is ready.',
      );

      expect(n.type, NotificationType.printReady);
      expect(n.title, 'Ready for pickup');
      expect(n.route, '/print/order/1042');
      expect(n.read, isFalse);
    });

    test('falls back to the data payload when the message carries no notification block', () {
      // A data-only push (what the function sends when the app is foregrounded)
      // has no title/body of its own.
      final n = AppNotification.fromMessageData(
        id: 'msg-2',
        data: {'type': 'pulse.alert', 'title': 'Water cut', 'body': 'Block C, until 4pm'},
      );

      expect(n.title, 'Water cut');
      expect(n.body, 'Block C, until 4pm');
    });

    test('non-string payload values are coerced rather than dropped', () {
      // FCM delivers everything as strings, but the local construction path and
      // future senders may not.
      final n = AppNotification.fromMessageData(
        id: 'msg-3',
        data: {'type': 'print.ready', 'orderId': 1042},
      );

      expect(n.route, '/print/order/1042');
    });
  });
}
