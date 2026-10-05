import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../models/enums/pulse_enums.dart';
import '../models/pulse_update.dart';

/// Reads and writes `pulseUpdates`.
///
/// Students read; only admins write (enforced by rules, not by this class).
class PulseRepository {
  PulseRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(Paths.pulseUpdates);

  /// All currently-active updates, highest priority first.
  ///
  /// Expired-but-not-yet-swept documents are filtered client-side via
  /// [PulseUpdate.isLive]. Querying on `expiresAt > now` server-side would
  /// force `expiresAt` to be the first orderBy and lose priority ordering, so
  /// the filter happens here instead — the active set is small.
  Stream<List<PulseUpdate>> watchActive({int limit = 60}) {
    return _col
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _fromDoc(d.id, d.data())).where((u) => u.isLive).toList())
        .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));
  }

  Stream<PulseUpdate?> watchOne(String id) => _col.doc(id).snapshots().map(
        (snap) => snap.exists ? _fromDoc(snap.id, snap.data()!) : null,
      );

  /// The most recent live update for a location, used to show a location's
  /// current status on the Map (§8).
  Stream<PulseUpdate?> watchForLocation(String locationId) {
    return _col
        .where('isActive', isEqualTo: true)
        .where('locationId', isEqualTo: locationId)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .map((snap) {
      final live = snap.docs.map((d) => _fromDoc(d.id, d.data())).where((u) => u.isLive);
      return live.isEmpty ? null : live.first;
    });
  }

  // ---- admin writes --------------------------------------------------------

  Future<String> create({
    required String title,
    required String description,
    required PulseCategory category,
    required PulseStatus status,
    required int priority,
    required String createdBy,
    required String createdByName,
    String? locationId,
    String? locationName,
    String? imageUrl,
    DateTime? expiresAt,
  }) =>
      FailureMapper.guard(() async {
        final ref = await _col.add({
          'title': title.trim(),
          'description': description.trim(),
          'category': category.name,
          'status': status.name,
          'priority': priority,
          'locationId': locationId,
          'locationName': locationName,
          'imageUrl': imageUrl,
          'createdBy': createdBy,
          'createdByName': createdByName,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
          'isActive': true,
        });
        return ref.id;
      });

  Future<void> update(String id, Map<String, dynamic> changes) =>
      FailureMapper.guard(() => _col.doc(id).update(changes));

  /// Soft-delete: expiring keeps the record for audit rather than destroying it.
  Future<void> expireNow(String id) => FailureMapper.guard(
        () => _col.doc(id).update({
          'isActive': false,
          'expiresAt': FieldValue.serverTimestamp(),
        }),
      );

  Future<void> delete(String id) => FailureMapper.guard(() => _col.doc(id).delete());

  /// A student flagging an update as out of date (§6). One report per user per
  /// update — re-reporting overwrites rather than spamming the moderation queue.
  Future<void> reportStale({required String pulseId, required String uid, required String reason}) =>
      FailureMapper.guard(() async {
        await _col.doc(pulseId).collection(Paths.reportsSub).doc(uid).set({
          'reason': reason.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

  Future<bool> hasReported({required String pulseId, required String uid}) => FailureMapper.guard(() async {
        final snap = await _col.doc(pulseId).collection(Paths.reportsSub).doc(uid).get();
        return snap.exists;
      });

  PulseUpdate _fromDoc(String id, Map<String, dynamic> d) => PulseUpdate(
        id: id,
        title: d['title'] as String? ?? '',
        description: d['description'] as String? ?? '',
        category: PulseCategory.fromName(d['category'] as String?),
        status: PulseStatus.fromName(d['status'] as String?),
        locationId: d['locationId'] as String?,
        locationName: d['locationName'] as String?,
        imageUrl: d['imageUrl'] as String?,
        priority: (d['priority'] as num?)?.toInt() ?? 0,
        createdBy: d['createdBy'] as String? ?? '',
        createdByName: d['createdByName'] as String? ?? '',
        // serverTimestamp() is null locally until the write round-trips, so
        // fall back to now rather than crashing on a freshly-created document.
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
        isActive: d['isActive'] as bool? ?? true,
        // Absent on ordinary notices and on documents written before the
        // occupancy contract existed — both must keep working.
        occupancy: Occupancy.fromMap(_occupancyMap(d['occupancy'])),
      );

  /// Normalises the nested map, converting the Firestore [Timestamp] to a
  /// [DateTime] so the model stays free of Firebase types.
  static Map<String, dynamic>? _occupancyMap(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final at = map['at'];
    map['at'] = at is Timestamp ? at.toDate() : null;
    return map;
  }
}

/// Thrown when a pulse document referenced by id has been removed.
const pulseNotFound = AppFailure(
  kind: FailureKind.notFound,
  message: 'This update is no longer available. It may have expired.',
  isRetryable: false,
);
