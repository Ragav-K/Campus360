import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../models/app_notification.dart';

/// Push messaging: permission, this device's token, and messages that arrive
/// while the app is running.
///
/// Deliberately thin. Per ARCHITECTURE.md §7 the Firestore inbox is the source
/// of truth and push is a best-effort hint, so nothing here is load-bearing:
/// if permission is refused, the token never registers, or FCM is unreachable,
/// the user still sees everything in the inbox with a correct unread count.
///
/// **Nothing sends these yet.** Sending happens in a Cloud Function, which
/// needs the Blaze plan. This is the receiving half, built so that the day the
/// function is deployed the app already registers tokens and routes taps.
///
/// Deliberately absent: a background message handler. It is only needed for
/// data-only pushes arriving while the app is terminated — the system tray
/// renders ordinary notification messages by itself — and a handler written
/// now would be an untestable guess at a payload no function emits yet. Add one
/// alongside the function that sends them.
class MessagingService {
  const MessagingService();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// Asks for notification permission.
  ///
  /// Returns whether it was granted rather than throwing: a refusal is a normal
  /// choice, not an error, and the app is fully usable without it.
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// This device's token, or null if one can't be obtained.
  ///
  /// Null is expected and survivable: iOS without APNs configured, an emulator
  /// with no Play Services, or a user who declined permission all land here.
  Future<String?> token() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Fires when FCM rotates the token — which it does on reinstall, restore
  /// from backup, and occasionally on its own. A token that is not re-registered
  /// on rotation silently stops receiving anything.
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  /// Messages delivered while the app is in the foreground. The OS shows
  /// nothing for these — the app is expected to surface them itself.
  Stream<AppNotification> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(_toNotification);

  /// Taps on a system-tray notification that resumed the app.
  Stream<AppNotification> get openedFromBackground =>
      FirebaseMessaging.onMessageOpenedApp.map(_toNotification);

  /// The tap that cold-started the app, if any. Delivered once — a second call
  /// returns null, so the caller must not drop it.
  Future<AppNotification?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _toNotification(message);
  }

  static AppNotification _toNotification(RemoteMessage message) =>
      AppNotification.fromMessageData(
        id: message.messageId ?? 'fcm-${DateTime.now().microsecondsSinceEpoch}',
        data: message.data,
        title: message.notification?.title,
        body: message.notification?.body,
      );
}
