import 'enums/lost_found_enums.dart';
import 'keywords.dart';

/// A `lostItems/{id}` document — something a student has lost.
///
/// Note what is *not* here: `identifyingDetails`, the private fact only the
/// real owner should know ("there's a torn photo of a dog inside"). Firestore
/// rules apply per document, not per field, so keeping that secret requires a
/// separate document — `lostItems/{id}/private/secret`. Putting it on this
/// class would mean shipping it to every student who browses the list.
class LostItem {
  const LostItem({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.itemName,
    required this.category,
    this.description = '',
    this.photoUrl,
    this.locationId,
    this.locationName = '',
    this.lostAt,
    this.keywords = const [],
    this.status = LostItemStatus.active,
    this.resolvedFoundItemId,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String itemName;
  final ItemCategory category;
  final String description;
  final String? photoUrl;
  final String? locationId;
  final String locationName;

  /// Approximate — students rarely know the minute they lost something.
  final DateTime? lostAt;

  final List<String> keywords;
  final LostItemStatus status;
  final String? resolvedFoundItemId;
  final DateTime createdAt;

  bool get isOpen => status == LostItemStatus.active || status == LostItemStatus.claimPending;

  factory LostItem.fromMap(
    String id,
    Map<String, dynamic> map, {
    required DateTime? Function(Object?) toDate,
  }) =>
      LostItem(
        id: id,
        ownerId: (map['ownerId'] ?? '') as String,
        ownerName: (map['ownerName'] ?? '') as String,
        itemName: (map['itemName'] ?? '') as String,
        category: ItemCategory.parse(map['category'] as String?),
        description: (map['description'] ?? '') as String,
        photoUrl: map['photoUrl'] as String?,
        locationId: map['locationId'] as String?,
        locationName: (map['locationName'] ?? '') as String,
        lostAt: toDate(map['lostAt']),
        keywords: (map['keywords'] as List?)?.whereType<String>().toList() ?? const [],
        status: LostItemStatus.parse(map['status'] as String?),
        resolvedFoundItemId: map['resolvedFoundItemId'] as String?,
        createdAt: toDate(map['createdAt']) ?? DateTime.now(),
      );

  /// The fields a client is allowed to write. Server-owned fields (`status`
  /// transitions driven by claims, `resolvedFoundItemId`) are set elsewhere.
  Map<String, dynamic> toCreateMap() => {
        'ownerId': ownerId,
        'ownerName': ownerName,
        'itemName': itemName,
        'category': category.name,
        'description': description,
        'photoUrl': photoUrl,
        'locationId': locationId,
        'locationName': locationName,
        'keywords': Keywords.from([itemName, description, locationName], category),
        'status': LostItemStatus.active.name,
        'resolvedFoundItemId': null,
      };
}
