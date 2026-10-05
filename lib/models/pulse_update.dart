import 'enums/pulse_enums.dart';

/// How an occupancy reading was produced.
///
/// The manual desk counter is the only writer today; the library ID-card gate
/// and the canteen camera will write the same contract with a different source.
enum OccupancySource {
  manual,
  idCard,
  camera;

  static OccupancySource fromName(String? n) =>
      OccupancySource.values.where((s) => s.name == n).firstOrNull ?? OccupancySource.manual;
}

/// What kind of reading this is.
///
/// The distinction matters: a card gate yields an exact headcount, a camera
/// yields only an intensity. Conflating them would mean inventing numbers a
/// camera cannot produce.
enum OccupancyMode {
  /// Exact headcount — [Occupancy.count] and [Occupancy.capacity] are set.
  count,

  /// Density estimate — only [Occupancy.level] (0..1) is set.
  density;

  static OccupancyMode fromName(String? n) =>
      OccupancyMode.values.where((m) => m.name == n).firstOrNull ?? OccupancyMode.count;
}

/// The live occupancy reading attached to a crowd update.
///
/// This is the read side of the ingest contract in ARCHITECTURE.md — whatever
/// wrote it, the app treats it identically.
class Occupancy {
  const Occupancy({
    required this.mode,
    required this.source,
    this.count,
    this.capacity,
    this.level,
    this.at,
  });

  final OccupancyMode mode;
  final OccupancySource source;

  /// Set only when [mode] is [OccupancyMode.count].
  final int? count;
  final int? capacity;

  /// 0.0–1.0, set only when [mode] is [OccupancyMode.density].
  final double? level;

  final DateTime? at;

  /// Fraction of capacity, or the raw density level. Null when unknowable.
  double? get ratio {
    if (mode == OccupancyMode.density) return level;
    final c = count, cap = capacity;
    if (c == null || cap == null || cap <= 0) return null;
    return c / cap;
  }

  /// "128 / 200 people", or **null** for a density reading.
  ///
  /// Returning null is the point: a camera reports intensity, not a headcount,
  /// and rendering a number from it would fabricate precision the sensor never
  /// had. Callers show the status chip alone in that case.
  String? get label {
    if (mode != OccupancyMode.count) return null;
    final c = count, cap = capacity;
    if (c == null) return null;
    return cap == null ? '$c people' : '$c / $cap people';
  }

  static Occupancy? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    return Occupancy(
      mode: OccupancyMode.fromName(m['mode'] as String?),
      source: OccupancySource.fromName(m['source'] as String?),
      count: (m['count'] as num?)?.toInt(),
      capacity: (m['capacity'] as num?)?.toInt(),
      level: (m['level'] as num?)?.toDouble(),
      at: m['at'] is DateTime ? m['at'] as DateTime : null,
    );
  }
}

/// A `pulseUpdates/{id}` document — one piece of live campus information.
class PulseUpdate {
  const PulseUpdate({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.createdAt,
    this.locationId,
    this.locationName,
    this.imageUrl,
    this.priority = 0,
    this.createdBy = '',
    this.createdByName = '',
    this.expiresAt,
    this.isActive = true,
    this.occupancy,
  });

  final String id;
  final String title;
  final String description;
  final PulseCategory category;
  final PulseStatus status;

  final String? locationId;
  final String? locationName;
  final String? imageUrl;

  /// 0 info … 3 emergency. Drives ordering and which updates reach the home
  /// summary row.
  final int priority;

  final String createdBy;
  final String createdByName;

  final DateTime createdAt;
  final DateTime? expiresAt;

  /// Set false by the scheduled expiry function. Also checked client-side via
  /// [isLive], because between function runs the flag can lag reality.
  final bool isActive;

  /// Live occupancy reading, present on crowd updates fed by a counter, the
  /// ID-card gate or a camera. Null for ordinary notices.
  final Occupancy? occupancy;

  /// "128 / 200 people" when a headcount is known, else null.
  String? get occupancyLabel => occupancy?.label;

  /// True when this update should be shown right now.
  ///
  /// The server flag alone isn't enough: the expiry function runs periodically,
  /// so an update can be past [expiresAt] while `isActive` is still true. The
  /// UI must not show stale information for even a few minutes (§6).
  bool get isLive {
    if (!isActive) return false;
    final expiry = expiresAt;
    return expiry == null || expiry.isAfter(DateTime.now());
  }

  bool get hasExpiry => expiresAt != null;

  /// Remaining lifetime, null when the update doesn't expire.
  Duration? get timeRemaining {
    final expiry = expiresAt;
    if (expiry == null) return null;
    final left = expiry.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  StatusTone get tone => status.tone;

  /// Matches free-text search across the fields a student would type.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        (locationName?.toLowerCase().contains(q) ?? false) ||
        category.label.toLowerCase().contains(q) ||
        status.label.toLowerCase().contains(q);
  }
}
