import 'enums/location_enums.dart';

/// Opening hours for one weekday. [day] follows DateTime's convention
/// (1 = Monday … 7 = Sunday).
class OpenHours {
  const OpenHours({required this.day, required this.open, required this.close});

  final int day;
  final String open; // "09:00"
  final String close; // "17:00"

  factory OpenHours.fromMap(Map<String, dynamic> m) => OpenHours(
        day: (m['day'] as num?)?.toInt() ?? 1,
        open: m['open'] as String? ?? '00:00',
        close: m['close'] as String? ?? '23:59',
      );

  Map<String, dynamic> toMap() => {'day': day, 'open': open, 'close': close};

  static int? _minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  bool containsTime(DateTime t) {
    final open = _minutes(this.open);
    final close = _minutes(this.close);
    if (open == null || close == null) return false;
    final now = t.hour * 60 + t.minute;
    // A close time earlier than open means the window crosses midnight.
    return close >= open ? now >= open && now < close : now >= open || now < close;
  }
}

/// A `campusLocations/{id}` document.
class CampusLocation {
  const CampusLocation({
    required this.id,
    required this.name,
    required this.category,
    this.building = '',
    this.floor = '',
    this.roomCode = '',
    this.description = '',
    this.lat,
    this.lng,
    this.openHours = const [],
    this.isActive = true,
  });

  final String id;
  final String name;
  final LocationCategory category;
  final String building;
  final String floor;
  final String roomCode;
  final String description;
  final double? lat;
  final double? lng;
  final List<OpenHours> openHours;
  final bool isActive;

  bool get hasCoordinates => lat != null && lng != null;

  /// "Block A · Ground floor" — the line under the name in lists.
  String get subtitle {
    final parts = [
      if (building.isNotEmpty) building,
      if (floor.isNotEmpty) floor,
      if (roomCode.isNotEmpty) roomCode,
    ];
    return parts.isEmpty ? category.label : parts.join(' · ');
  }

  /// Null when hours aren't recorded — the UI must then say "Hours not
  /// listed" rather than implying the place is closed.
  bool? isOpenAt(DateTime when) {
    if (openHours.isEmpty) return null;
    final today = openHours.where((h) => h.day == when.weekday);
    if (today.isEmpty) return false;
    return today.any((h) => h.containsTime(when));
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        building.toLowerCase().contains(q) ||
        roomCode.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        category.label.toLowerCase().contains(q);
  }
}
