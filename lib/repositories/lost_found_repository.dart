import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/failure_mapper.dart';
import '../core/services/document_storage.dart';
import '../models/claim.dart';
import '../models/enums/lost_found_enums.dart';
import '../models/found_item.dart';
import '../models/lost_item.dart';

/// Lost reports, found reports, and the claims that connect them.
class LostFoundRepository {
  LostFoundRepository(this._db, {DocumentStorage? documents})
      : _documents = documents ?? DocumentStorage();

  final FirebaseFirestore _db;
  final DocumentStorage _documents;

  CollectionReference<Map<String, dynamic>> get _lost => _db.collection('lostItems');
  CollectionReference<Map<String, dynamic>> get _found => _db.collection('foundItems');
  CollectionReference<Map<String, dynamic>> get _claims => _db.collection('claims');

  static DateTime? _toDate(Object? v) => v is Timestamp ? v.toDate() : null;

  // ---- reading -------------------------------------------------------------

  /// Everything still open, newest first — the browsable board.
  Stream<List<FoundItem>> watchOpenFoundItems({int limit = 100}) => _found
      .where('status', whereIn: [FoundItemStatus.active.name, FoundItemStatus.claimPending.name])
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => FoundItem.fromMap(d.id, d.data(), toDate: _toDate)).toList())
      .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));

  Stream<List<LostItem>> watchOpenLostItems({int limit = 100}) => _lost
      .where('status', whereIn: [LostItemStatus.active.name, LostItemStatus.claimPending.name])
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => LostItem.fromMap(d.id, d.data(), toDate: _toDate)).toList())
      .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));

  Stream<List<LostItem>> watchMyLostItems(String uid) => _lost
      .where('ownerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => LostItem.fromMap(d.id, d.data(), toDate: _toDate)).toList())
      .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));

  Stream<List<FoundItem>> watchMyFoundItems(String uid) => _found
      .where('finderId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => FoundItem.fromMap(d.id, d.data(), toDate: _toDate)).toList())
      .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));

  Stream<FoundItem?> watchFoundItem(String id) => _found.doc(id).snapshots().map(
        (d) => d.exists ? FoundItem.fromMap(d.id, d.data()!, toDate: _toDate) : null,
      );

  Stream<LostItem?> watchLostItem(String id) => _lost.doc(id).snapshots().map(
        (d) => d.exists ? LostItem.fromMap(d.id, d.data()!, toDate: _toDate) : null,
      );

  /// Claims where the signed-in user is the claimant or the finder. Two queries
  /// because Firestore has no OR across different fields.
  Stream<List<Claim>> watchMyClaims(String uid) {
    final asClaimant = _claims.where('claimantId', isEqualTo: uid).snapshots();
    final asFinder = _claims.where('finderId', isEqualTo: uid).snapshots();

    return asClaimant.asyncMap((mine) async {
      final theirs = await asFinder.first;
      final all = {
        for (final d in [...mine.docs, ...theirs.docs])
          d.id: Claim.fromMap(d.id, d.data(), toDate: _toDate),
      }.values.toList();
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all;
    }).handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));
  }

  // ---- reporting -----------------------------------------------------------

  /// Reports a lost item. [identifyingDetails] is the ownership secret and goes
  /// into a subdocument only the owner can read — see [LostItem].
  Future<String> reportLost({
    required LostItem item,
    String identifyingDetails = '',
    File? photo,
  }) =>
      FailureMapper.guard(() async {
        final ref = _lost.doc();
        final photoUrl = await _uploadPhoto(photo, item.ownerId, ref.id);

        await ref.set({
          ...item.toCreateMap(),
          'photoUrl': photoUrl,
          'lostAt': item.lostAt == null ? null : Timestamp.fromDate(item.lostAt!),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (identifyingDetails.trim().isNotEmpty) {
          await ref.collection('private').doc('secret').set({
            'identifyingDetails': identifyingDetails.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        return ref.id;
      });

  Future<String> reportFound({required FoundItem item, File? photo}) =>
      FailureMapper.guard(() async {
        final ref = _found.doc();
        final photoUrl = await _uploadPhoto(photo, item.finderId, ref.id);

        await ref.set({
          ...item.toCreateMap(),
          'photoUrl': photoUrl,
          'foundAt': item.foundAt == null ? null : Timestamp.fromDate(item.foundAt!),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return ref.id;
      });

  Future<String?> _uploadPhoto(File? photo, String uid, String itemId) async {
    if (photo == null) return null;
    final path = DocumentStorage.pathFor(uid, itemId, 'photo.jpg', prefix: 'lostFound');
    return _documents.upload(file: photo, path: path, mimeType: 'image/jpeg');
  }

  // ---- claims --------------------------------------------------------------

  /// "This might be mine." Creates a pending claim for the finder to judge.
  Future<String> claimFoundItem({
    required FoundItem foundItem,
    required String claimantId,
    required String claimantName,
    String? lostItemId,
    required String proof,
  }) =>
      FailureMapper.guard(() async {
        final ref = _claims.doc();
        await ref.set({
          'foundItemId': foundItem.id,
          'lostItemId': lostItemId,
          'claimantId': claimantId,
          'claimantName': claimantName,
          'finderId': foundItem.finderId,
          'itemName': foundItem.itemName,
          // What only the real owner would know. The finder reads this to
          // judge; it is why a claim is more than a button press.
          'proof': proof.trim(),
          'status': ClaimStatus.pending.name,
          'decidedAt': null,
          'rejectionReason': null,
          'claimantConfirmedHandover': false,
          'finderConfirmedHandover': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return ref.id;
      });

  Future<void> decideClaim({
    required String claimId,
    required bool approve,
    String? rejectionReason,
  }) =>
      FailureMapper.guard(() => _claims.doc(claimId).update({
            'status': approve ? ClaimStatus.approved.name : ClaimStatus.rejected.name,
            'rejectionReason': approve ? null : rejectionReason,
            'decidedAt': FieldValue.serverTimestamp(),
          }));

  Future<void> withdrawClaim(String claimId) =>
      FailureMapper.guard(() => _claims.doc(claimId).update({
            'status': ClaimStatus.withdrawn.name,
            'decidedAt': FieldValue.serverTimestamp(),
          }));

  /// One side says the item changed hands.
  ///
  /// ARCHITECTURE.md specifies a server-generated pickup OTP here. That needs
  /// Cloud Functions (Blaze), and an OTP the client can mint or read is
  /// security theatre — the claimant could simply read it and "verify" alone.
  /// Two-sided confirmation gives the same guarantee honestly: the item is only
  /// marked returned once *both* people say so, and neither can fake the other.
  Future<void> confirmHandover({
    required Claim claim,
    required String uid,
  }) =>
      FailureMapper.guard(() async {
        final isClaimant = claim.claimantId == uid;
        final bothAgree = isClaimant ? claim.finderConfirmedHandover : claim.claimantConfirmedHandover;

        await _claims.doc(claim.id).update({
          if (isClaimant) 'claimantConfirmedHandover': true,
          if (!isClaimant) 'finderConfirmedHandover': true,
          if (bothAgree) 'status': ClaimStatus.returned.name,
        });

        if (!bothAgree) return;

        // Both confirmed: close the underlying reports so they leave the board.
        final batch = _db.batch();
        batch.update(_found.doc(claim.foundItemId), {
          'status': FoundItemStatus.returned.name,
          'returnedToUserId': claim.claimantId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (claim.lostItemId != null) {
          batch.update(_lost.doc(claim.lostItemId!), {
            'status': LostItemStatus.resolved.name,
            'resolvedFoundItemId': claim.foundItemId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      });

  Future<void> closeLostItem(String id) => FailureMapper.guard(
        () => _lost.doc(id).update({
          'status': LostItemStatus.closed.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );

  Future<void> closeFoundItem(String id) => FailureMapper.guard(
        () => _found.doc(id).update({
          'status': FoundItemStatus.closed.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
}
