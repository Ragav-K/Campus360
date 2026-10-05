import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/routes.dart';

/// What a notification is about.
///
/// The wire value is the `type` string from ARCHITECTURE.md §7. An unknown
/// value maps to [unknown] rather than throwing: the sender is a Cloud Function
/// that will be deployed and updated independently of installed app versions,
/// so a client that crashes on a type it has never heard of would break every
/// old install the moment a new notification type ships.
enum NotificationType {
  printReceived('print.received'),
  printPrinting('print.printing'),
  printReady('print.ready'),
  printRejected('print.rejected'),
  printCollected('print.collected'),
  lostFoundMatch('lostfound.match'),
  lostFoundClaimRequest('lostfound.claimRequest'),
  lostFoundClaimApproved('lostfound.claimApproved'),
  lostFoundClaimRejected('lostfound.claimRejected'),
  lostFoundReturned('lostfound.returned'),
  pulseAlert('pulse.alert'),
  unknown('unknown');

  const NotificationType(this.wire);

  final String wire;

  static NotificationType fromWire(String? value) =>
      NotificationType.values.firstWhere((t) => t.wire == value, orElse: () => unknown);

  /// Which module this belongs to — used to honour the user's per-module
  /// notification preferences on the device as well as server-side.
  NotificationCategory get category => switch (this) {
        printReceived ||
        printPrinting ||
        printReady ||
        printRejected ||
        printCollected =>
          NotificationCategory.print,
        lostFoundMatch ||
        lostFoundClaimRequest ||
        lostFoundClaimApproved ||
        lostFoundClaimRejected ||
        lostFoundReturned =>
          NotificationCategory.lostFound,
        pulseAlert => NotificationCategory.pulse,
        unknown => NotificationCategory.other,
      };
}

enum NotificationCategory { print, lostFound, pulse, other }

/// An entry in the in-app inbox.
///
/// Per §7 the Firestore document is the source of truth and the push message is
/// a best-effort hint: if push never arrives, this is still here and the unread
/// count is still right. Nothing on the client ever creates one — the rules
/// forbid it — so this model is read-mostly by design.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;

  /// Free-form payload used to deep-link on tap, e.g. `{orderId: …}`.
  final Map<String, String> data;

  final bool read;
  final DateTime? createdAt;

  /// Where tapping this should take the user, or null when the payload doesn't
  /// identify anything to open.
  ///
  /// Returning null rather than a best guess matters: a notification that opens
  /// the wrong screen is worse than one that opens nothing.
  String? get route {
    final orderId = data['orderId'];
    final matchId = data['matchId'];
    final claimId = data['claimId'];
    final pulseId = data['pulseId'];

    // Every print.* type opens the same order screen, so it keys off the
    // category rather than listing five cases.
    if (type.category == NotificationCategory.print) {
      return orderId == null ? null : Routes.printOrder(orderId);
    }

    return switch (type) {
      NotificationType.lostFoundMatch when matchId != null => Routes.matchDetail(matchId),
      NotificationType.lostFoundClaimRequest ||
      NotificationType.lostFoundClaimApproved ||
      NotificationType.lostFoundClaimRejected ||
      NotificationType.lostFoundReturned
          when claimId != null =>
        Routes.claimDetail(claimId),
      NotificationType.pulseAlert when pulseId != null => Routes.pulseDetail(pulseId),
      _ => null,
    };
  }

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AppNotification(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      type: NotificationType.fromWire(d['type'] as String?),
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      data: {
        for (final entry in (d['data'] as Map<String, dynamic>? ?? const {}).entries)
          if (entry.value != null) entry.key: '${entry.value}',
      },
      read: d['read'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Builds one from an FCM payload, so a push that arrives while the app is
  /// open can be shown immediately without waiting for the Firestore snapshot.
  ///
  /// [id] is whatever the message carried; it may not match a document, so this
  /// is only ever used for display, never written back.
  factory AppNotification.fromMessageData({
    required String id,
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) =>
      AppNotification(
        id: id,
        userId: data['userId'] as String? ?? '',
        type: NotificationType.fromWire(data['type'] as String?),
        title: title ?? data['title'] as String? ?? '',
        body: body ?? data['body'] as String? ?? '',
        data: {
          for (final entry in data.entries)
            if (entry.value != null && entry.key != 'type') entry.key: '${entry.value}',
        },
        createdAt: DateTime.now(),
      );
}
