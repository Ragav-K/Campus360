/// What kind of update this is. Drives the filter chips on the Pulse screen.
enum PulseCategory {
  crowd,
  availability,
  notice,
  alert,
  event;

  static PulseCategory fromName(String? n) =>
      PulseCategory.values.where((c) => c.name == n).firstOrNull ?? PulseCategory.notice;

  String get label => switch (this) {
        PulseCategory.crowd => 'Crowd',
        PulseCategory.availability => 'Availability',
        PulseCategory.notice => 'Notice',
        PulseCategory.alert => 'Alert',
        PulseCategory.event => 'Event',
      };
}

/// The status values from §7, flattened into one enum.
///
/// One enum rather than three keeps Firestore documents simple and lets any
/// update carry any status; [PulseStatus.appliesTo] records which category a
/// status is *intended* for so the admin form can offer sensible choices.
enum PulseStatus {
  // Crowd
  low,
  moderate,
  high,
  veryHigh,
  // Availability
  available,
  limited,
  occupied,
  closed,
  // General
  information,
  warning,
  emergency;

  static PulseStatus fromName(String? n) =>
      PulseStatus.values.where((s) => s.name == n).firstOrNull ?? PulseStatus.information;

  /// Text label. Always rendered alongside colour so the UI stays accessible
  /// to colour-blind users and screen readers (§7).
  String get label => switch (this) {
        PulseStatus.low => 'Low crowd',
        PulseStatus.moderate => 'Moderate',
        PulseStatus.high => 'High crowd',
        PulseStatus.veryHigh => 'Very crowded',
        PulseStatus.available => 'Available',
        PulseStatus.limited => 'Limited',
        PulseStatus.occupied => 'Occupied',
        PulseStatus.closed => 'Closed',
        PulseStatus.information => 'Information',
        PulseStatus.warning => 'Warning',
        PulseStatus.emergency => 'Emergency',
      };

  /// Short form for dense surfaces like the home summary row.
  String get shortLabel => switch (this) {
        PulseStatus.low => 'Quiet',
        PulseStatus.moderate => 'Moderate',
        PulseStatus.high => 'Busy',
        PulseStatus.veryHigh => 'Very busy',
        _ => label,
      };

  PulseCategory get appliesTo => switch (this) {
        PulseStatus.low || PulseStatus.moderate || PulseStatus.high || PulseStatus.veryHigh => PulseCategory.crowd,
        PulseStatus.available ||
        PulseStatus.limited ||
        PulseStatus.occupied ||
        PulseStatus.closed =>
          PulseCategory.availability,
        _ => PulseCategory.notice,
      };

  static List<PulseStatus> forCategory(PulseCategory c) => switch (c) {
        PulseCategory.crowd => [low, moderate, high, veryHigh],
        PulseCategory.availability => [available, limited, occupied, closed],
        PulseCategory.alert => [warning, emergency, information],
        _ => [information, warning, emergency],
      };
}

/// Severity tone. Maps a status to one of five semantic colours so Pulse,
/// Lost & Found and Printout all speak the same visual language.
enum StatusTone { good, caution, bad, info, neutral }

extension PulseStatusTone on PulseStatus {
  StatusTone get tone => switch (this) {
        PulseStatus.low || PulseStatus.available => StatusTone.good,
        PulseStatus.moderate || PulseStatus.limited || PulseStatus.high || PulseStatus.warning => StatusTone.caution,
        PulseStatus.veryHigh || PulseStatus.emergency => StatusTone.bad,
        PulseStatus.occupied || PulseStatus.information => StatusTone.info,
        PulseStatus.closed => StatusTone.neutral,
      };
}
