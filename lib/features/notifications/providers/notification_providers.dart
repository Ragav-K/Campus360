import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/services/messaging_service.dart';
import '../../../models/app_notification.dart';
import '../../../repositories/notification_repository.dart';
import '../../auth/providers/auth_providers.dart';

final messagingServiceProvider = Provider<MessagingService>((_) => const MessagingService());

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(firestoreProvider)),
);

/// The inbox for the signed-in user. Empty for a signed-out session rather than
/// an error — the bell simply has nothing to show.
final inboxProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watchInbox(uid);
});

final unreadCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(0);
  return ref.watch(notificationRepositoryProvider).watchUnreadCount(uid);
});

/// This device's push token, once permission has been granted.
final fcmTokenProvider = FutureProvider<String?>((ref) async {
  final messaging = ref.watch(messagingServiceProvider);
  if (!await messaging.hasPermission()) return null;
  return messaging.token();
});

/// Keeps `users/{uid}.fcmTokens` in step with this device.
///
/// Registration is deliberately fire-and-forget and failure-tolerant: push is
/// a delivery hint, so a token that cannot be written must never surface as an
/// error or block anything the user was doing.
///
/// Watch this from a widget that lives as long as the session — [ref.listen] on
/// it is enough; nothing needs to read its value.
final tokenRegistrarProvider = Provider<void>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return;

  final messaging = ref.watch(messagingServiceProvider);
  final repo = ref.watch(notificationRepositoryProvider);

  Future<void> register(String token) async {
    try {
      await repo.registerToken(uid, token);
    } catch (_) {
      // Deliberately swallowed — see the note above.
    }
  }

  unawaited(() async {
    if (!await messaging.hasPermission()) return;
    final token = await messaging.token();
    if (token != null) await register(token);
  }());

  // FCM rotates tokens on reinstall and restore. A rotation that isn't
  // re-registered silently stops delivery, with nothing to notice it by.
  final subscription = messaging.tokenRefreshes.listen(register);
  ref.onDispose(subscription.cancel);
});

/// Foreground pushes, for the in-app banner. Broadcast through a provider so
/// several listeners (banner, badge refresh) can share one subscription.
final foregroundMessageProvider = StreamProvider<AppNotification>(
  (ref) => ref.watch(messagingServiceProvider).foregroundMessages,
);

/// Taps on a system notification that opened or resumed the app.
final notificationTapProvider = StreamProvider<AppNotification>(
  (ref) => ref.watch(messagingServiceProvider).openedFromBackground,
);
