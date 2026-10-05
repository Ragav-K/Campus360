import 'enums/print_enums.dart';

/// The document attached to an order.
class PrintDocument {
  const PrintDocument({
    required this.fileName,
    required this.storagePath,
    required this.downloadUrl,
    required this.mimeType,
    required this.sizeBytes,
    this.pageCount,
  });

  final String fileName;
  final String storagePath;
  final String downloadUrl;
  final String mimeType;
  final int sizeBytes;

  /// Null when the page count couldn't be read — the cost estimate then says
  /// so instead of guessing.
  final int? pageCount;

  bool get isPdf => mimeType == 'application/pdf';

  factory PrintDocument.fromMap(Map<String, dynamic> m) => PrintDocument(
        fileName: m['fileName'] as String? ?? 'document',
        storagePath: m['storagePath'] as String? ?? '',
        downloadUrl: m['downloadUrl'] as String? ?? '',
        mimeType: m['mimeType'] as String? ?? 'application/octet-stream',
        sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
        pageCount: (m['pageCount'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
        'fileName': fileName,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'pageCount': pageCount,
      };
}

/// How the student wants it printed (§18).
class PrintSettings {
  const PrintSettings({
    this.copies = 1,
    this.colour = PrintColour.bw,
    this.sides = PrintSides.single,
    this.paper = 'A4',
    this.pageRange,
    this.note = '',
  });

  final int copies;
  final PrintColour colour;
  final PrintSides sides;
  final String paper;

  /// Null means all pages; otherwise "2-7" or "1,3,5-9".
  final String? pageRange;

  final String note;

  bool get isAllPages => pageRange == null || pageRange!.trim().isEmpty;

  /// "2 copies · B&W · 2-sided · A4"
  String get summary => [
        '$copies ${copies == 1 ? 'copy' : 'copies'}',
        colour.shortLabel,
        sides.shortLabel,
        paper,
        if (!isAllPages) 'pages $pageRange',
      ].join(' · ');

  PrintSettings copyWith({
    int? copies,
    PrintColour? colour,
    PrintSides? sides,
    String? paper,
    String? pageRange,
    bool clearPageRange = false,
    String? note,
  }) =>
      PrintSettings(
        copies: copies ?? this.copies,
        colour: colour ?? this.colour,
        sides: sides ?? this.sides,
        paper: paper ?? this.paper,
        pageRange: clearPageRange ? null : (pageRange ?? this.pageRange),
        note: note ?? this.note,
      );

  factory PrintSettings.fromMap(Map<String, dynamic>? m) => PrintSettings(
        copies: (m?['copies'] as num?)?.toInt() ?? 1,
        colour: PrintColour.fromName(m?['colour'] as String?),
        sides: PrintSides.fromName(m?['sides'] as String?),
        paper: m?['paper'] as String? ?? 'A4',
        pageRange: m?['pageRange'] as String?,
        note: m?['note'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'copies': copies,
        'colour': colour.name,
        'sides': sides.name,
        'paper': paper,
        'pageRange': pageRange,
        'note': note,
      };
}

/// A `printOrders/{id}` document.
class PrintOrder {
  const PrintOrder({
    required this.id,
    required this.orderNumber,
    required this.studentId,
    required this.studentName,
    required this.shopId,
    required this.shopName,
    required this.document,
    required this.settings,
    required this.status,
    required this.createdAt,
    this.neededBy,
    this.estimatedCost,
    this.rejectionReason,
    this.statusChangedAt,
    this.studentPhone,
  });

  final String id;

  /// Human-facing number shown at the counter.
  final int orderNumber;

  final String studentId;
  final String studentName;
  final String? studentPhone;

  final String shopId;
  final String shopName;

  final PrintDocument document;
  final PrintSettings settings;
  final PrintOrderStatus status;

  final DateTime createdAt;
  final DateTime? statusChangedAt;

  /// When the student needs it ready. Null means "no rush" and sorts last.
  ///
  /// This is what orders the shop's queue: soonest deadline first, so a job
  /// needed in 20 minutes outranks one placed earlier but needed tomorrow.
  final DateTime? neededBy;

  final double? estimatedCost;
  final String? rejectionReason;

  bool get isActive => status.isActive;

  /// Time left until the deadline. Negative when already late.
  Duration? remainingTime([DateTime? now]) {
    final deadline = neededBy;
    if (deadline == null) return null;
    return deadline.difference(now ?? DateTime.now());
  }

  /// Past its deadline and still not ready — the case a shop must see first.
  bool isOverdue([DateTime? now]) {
    final left = remainingTime(now);
    if (left == null) return false;
    return left.isNegative &&
        status != PrintOrderStatus.readyForPickup &&
        status != PrintOrderStatus.collected;
  }

  /// Deadline within the next half hour.
  bool isUrgent([DateTime? now]) {
    final left = remainingTime(now);
    if (left == null) return false;
    return !left.isNegative && left.inMinutes <= 30;
  }

  /// Queue rank for the shop. Lower sorts first.
  ///
  /// Overdue jobs first, then by deadline, then undated jobs by age. Computed
  /// here rather than in the UI so the app and the counter dashboard cannot
  /// disagree about what "next" means.
  int get queueSortKey {
    final deadline = neededBy;
    if (deadline == null) {
      // No deadline: sort after everything dated, oldest first.
      return 4000000000 + (createdAt.millisecondsSinceEpoch ~/ 1000);
    }
    return deadline.millisecondsSinceEpoch ~/ 1000;
  }

  factory PrintOrder.fromMap(String id, Map<String, dynamic> d, {DateTime? Function(Object?)? toDate}) {
    DateTime? parse(Object? value) => toDate != null ? toDate(value) : null;

    return PrintOrder(
      id: id,
      orderNumber: (d['orderNumber'] as num?)?.toInt() ?? 0,
      studentId: d['studentId'] as String? ?? '',
      studentName: d['studentName'] as String? ?? '',
      studentPhone: d['studentPhone'] as String?,
      shopId: d['shopId'] as String? ?? '',
      shopName: d['shopName'] as String? ?? '',
      document: PrintDocument.fromMap((d['document'] as Map<String, dynamic>?) ?? const {}),
      settings: PrintSettings.fromMap(d['settings'] as Map<String, dynamic>?),
      status: PrintOrderStatus.fromName(d['status'] as String?),
      createdAt: parse(d['createdAt']) ?? DateTime.now(),
      statusChangedAt: parse(d['statusChangedAt']),
      neededBy: parse(d['neededBy']),
      estimatedCost: (d['estimatedCost'] as num?)?.toDouble(),
      rejectionReason: d['rejectionReason'] as String?,
    );
  }
}

/// Estimated cost. Deliberately an estimate — the shop confirms the real price.
double? estimateCost({
  required PrintSettings settings,
  required int? pageCount,
  required double? bwPerPage,
  required double? colourPerPage,
}) {
  if (pageCount == null || pageCount <= 0) return null;
  final rate = settings.colour == PrintColour.colour ? colourPerPage : bwPerPage;
  if (rate == null) return null;
  return pageCount * settings.copies * rate;
}
