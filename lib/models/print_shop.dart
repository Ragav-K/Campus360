import 'enums/pulse_enums.dart';

/// A `printShops/{id}` document.
class PrintShop {
  const PrintShop({
    required this.id,
    required this.name,
    this.locationId,
    this.locationName = '',
    this.isOpen = true,
    this.estimatedWaitMinutes,
    this.supportsColour = true,
    this.supportsDuplex = true,
    this.paperSizes = const ['A4'],
    this.bwPerPage,
    this.colourPerPage,
    this.currency = '₹',
    this.staffIds = const [],
    this.queueCount = 0,
  });

  final String id;
  final String name;
  final String? locationId;
  final String locationName;

  final bool isOpen;

  /// Null when the shop hasn't published a wait — the UI then says nothing
  /// rather than inventing a number.
  final int? estimatedWaitMinutes;

  final bool supportsColour;
  final bool supportsDuplex;
  final List<String> paperSizes;

  final double? bwPerPage;
  final double? colourPerPage;
  final String currency;

  final List<String> staffIds;
  final int queueCount;

  bool get hasPricing => bwPerPage != null || colourPerPage != null;

  StatusTone get tone => isOpen ? StatusTone.good : StatusTone.neutral;
  String get statusLabel => isOpen ? 'Open' : 'Closed';

  factory PrintShop.fromMap(String id, Map<String, dynamic> d) {
    final services = d['services'] as Map<String, dynamic>?;
    final pricing = d['pricing'] as Map<String, dynamic>?;

    return PrintShop(
      id: id,
      name: d['name'] as String? ?? '',
      locationId: d['locationId'] as String?,
      locationName: d['locationName'] as String? ?? '',
      isOpen: d['isOpen'] as bool? ?? true,
      estimatedWaitMinutes: (d['estimatedWaitMinutes'] as num?)?.toInt(),
      supportsColour: services?['colour'] as bool? ?? true,
      supportsDuplex: services?['duplex'] as bool? ?? true,
      paperSizes:
          (services?['paperSizes'] as List?)?.map((e) => e.toString()).toList() ?? const ['A4'],
      bwPerPage: (pricing?['bwPerPage'] as num?)?.toDouble(),
      colourPerPage: (pricing?['colourPerPage'] as num?)?.toDouble(),
      currency: pricing?['currency'] as String? ?? '₹',
      staffIds: (d['staffIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      queueCount: (d['queueCount'] as num?)?.toInt() ?? 0,
    );
  }
}
