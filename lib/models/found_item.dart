import 'enums/lost_found_enums.dart';
import 'keywords.dart';

/// A `foundItems/{id}` document — something a student picked up.
///
/// Publicly readable to signed-in students, which is the whole point: people
/// have to be able to browse and recognise their own belongings.
class FoundItem {
  const FoundItem({
    required this.id,
    required this.finderId,
    required this.finderName,
    required this.itemName,
    required this.category,
    this.description = '',
    this.photoUrl,
    this.locationId,
    this.locationName = '',
    this.foundAt,
    this.handoverNote = '',
    this.keywords = const [],
    this.status = FoundItemStatus.active,
    this.returnedToUserId,
    required this.createdAt,
  });

  final String id;
  final String finderId;
  final String finderName;
  final String itemName;
  final ItemCategory category;
  final String description;
  final String? photoUrl;
  final String? locationId;
  final String locationName;
  final DateTime? foundAt;

  /// Where the finder left it — "handed in at the library desk". Often more
  /// useful than the finder's name.
  final String handoverNote;

  final List<String> keywords;
  final FoundItemStatus status;
  final String? returnedToUserId;
  final DateTime createdAt;

  bool get isOpen => status == FoundItemStatus.active || status == FoundItemStatus.claimPending;

  factory FoundItem.fromMap(
    String id,
    Map<String, dynamic> map, {
    required DateTime? Function(Object?) toDate,
  }) =>
      FoundItem(
        id: id,
        finderId: (map['finderId'] ?? '') as String,
        finderName: (map['finderName'] ?? '') as String,
        itemName: (map['itemName'] ?? '') as String,
        category: ItemCategory.parse(map['category'] as String?),
        description: (map['description'] ?? '') as String,
        photoUrl: map['photoUrl'] as String?,
        locationId: map['locationId'] as String?,
        locationName: (map['locationName'] ?? '') as String,
        foundAt: toDate(map['foundAt']),
        handoverNote: (map['handoverNote'] ?? '') as String,
        keywords: (map['keywords'] as List?)?.whereType<String>().toList() ?? const [],
        status: FoundItemStatus.parse(map['status'] as String?),
        returnedToUserId: map['returnedToUserId'] as String?,
        createdAt: toDate(map['createdAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toCreateMap() => {
        'finderId': finderId,
        'finderName': finderName,
        'itemName': itemName,
        'category': category.name,
        'description': description,
        'photoUrl': photoUrl,
        'locationId': locationId,
        'locationName': locationName,
        'handoverNote': handoverNote,
        'keywords': Keywords.from([itemName, description, locationName], category),
        'status': FoundItemStatus.active.name,
        'returnedToUserId': null,
      };
}
