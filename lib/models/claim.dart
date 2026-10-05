import 'enums/lost_found_enums.dart';

/// A `claims/{id}` document — one student saying a found item is theirs.
class Claim {
  const Claim({
    required this.id,
    required this.foundItemId,
    this.lostItemId,
    required this.claimantId,
    required this.claimantName,
    required this.finderId,
    required this.itemName,
    required this.proof,
    this.status = ClaimStatus.pending,
    this.rejectionReason,
    this.claimantConfirmedHandover = false,
    this.finderConfirmedHandover = false,
    required this.createdAt,
  });

  final String id;
  final String foundItemId;

  /// Null when someone claims an item they never filed a lost report for —
  /// common, since people often spot their thing on the board first.
  final String? lostItemId;

  final String claimantId;
  final String claimantName;
  final String finderId;
  final String itemName;

  /// What only the true owner should know. Read by the finder to judge.
  final String proof;

  final ClaimStatus status;
  final String? rejectionReason;

  final bool claimantConfirmedHandover;
  final bool finderConfirmedHandover;
  final DateTime createdAt;

  bool get isSettled =>
      status == ClaimStatus.returned ||
      status == ClaimStatus.rejected ||
      status == ClaimStatus.withdrawn;

  /// Approved, but still waiting on one side to confirm the handover happened.
  bool get awaitingHandover =>
      status == ClaimStatus.approved &&
      !(claimantConfirmedHandover && finderConfirmedHandover);

  bool hasConfirmed(String uid) =>
      uid == claimantId ? claimantConfirmedHandover : finderConfirmedHandover;

  factory Claim.fromMap(
    String id,
    Map<String, dynamic> map, {
    required DateTime? Function(Object?) toDate,
  }) =>
      Claim(
        id: id,
        foundItemId: (map['foundItemId'] ?? '') as String,
        lostItemId: map['lostItemId'] as String?,
        claimantId: (map['claimantId'] ?? '') as String,
        claimantName: (map['claimantName'] ?? '') as String,
        finderId: (map['finderId'] ?? '') as String,
        itemName: (map['itemName'] ?? '') as String,
        proof: (map['proof'] ?? '') as String,
        status: ClaimStatus.parse(map['status'] as String?),
        rejectionReason: map['rejectionReason'] as String?,
        claimantConfirmedHandover: (map['claimantConfirmedHandover'] ?? false) as bool,
        finderConfirmedHandover: (map['finderConfirmedHandover'] ?? false) as bool,
        createdAt: toDate(map['createdAt']) ?? DateTime.now(),
      );
}
