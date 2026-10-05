import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/failure_mapper.dart';
import '../models/app_notification.dart';

/// Reads the in-app inbox and maintains this device's FCM token.
///
/// Nothing here creates a notification. Per ARCHITECTURE.md §7 they are written
/// by a Cloud Function reacting to a domain event, and the rules enforce that:
/// a client that could write its own notifications could also write them to
/// someone else's inbox.
class NotificationRepository {
  NotificationRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('notifications');
  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _db.collection('users').doc(uid);

  /// The inbox, newest first. Backed by the `userId ASC, createdAt DESC` index.
  Stream<List<AppNotification>> watchInbox(String uid, {int limit = 50}) => _col
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(AppNotification.fromDoc).toList())
      .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));

  /// Unread count for the bell badge.
  ///
  /// A count aggregation rather than streaming the documents: the badge needs a
  /// number, and the unread set can be large after a quiet week.
  Stream<int> watchUnreadCount(String uid) => _col
      .where('userId', isEqualTo: uid)
      .where('read', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length)
      .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));

  Future<void> markRead(String id) =>
      FailureMapper.guard(() => _col.doc(id).update({'read': true}));

  /// Marks everything unread as read, in batches.
  ///
  /// Firestore caps a batch at 500 writes, so a long-neglected inbox has to be
  /// chunked rather than committed in one go.
  Future<void> markAllRead(String uid) => FailureMapper.guard(() async {
        final unread = await _col.where('userId', isEqualTo: uid).where('read', isEqualTo: false).get();

        for (var i = 0; i < unread.docs.length; i += 400) {
          final batch = _db.batch();
          for (final doc in unread.docs.skip(i).take(400)) {
            batch.update(doc.reference, {'read': true});
          }
          await batch.commit();
        }
      });

  /// Records this device's push token against the account.
  ///
  /// An array, not a field: one person signs in on a phone and a lab machine,
  /// and overwriting would silently mute the other device. Server-side sending
  /// prunes tokens that come back `registration-token-not-registered`.
  Future<void> registerToken(String uid, String token) => FailureMapper.guard(
        () => _userDoc(uid).set({
          'fcmTokens': FieldValue.arrayUnion([token]),
        }, SetOptions(merge: true)),
      );

  /// Drops this device's token — on sign-out, so the next person to use the
  /// device doesn't receive the previous user's notifications.
  Future<void> removeToken(String uid, String token) => FailureMapper.guard(
        () => _userDoc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        }),
      );
}
