/// A single scheduled period.
class Period {
  const Period({
    required this.day,
    required this.index,
    required this.start,
    required this.end,
    required this.subject,
    this.code = '',
    this.staff = '',
    this.room = '',
    this.type = PeriodType.theory,
  });

  /// 1 = Monday … 7 = Sunday, matching [DateTime.weekday].
  final int day;

  /// Period number within the day, 1-based.
  final int index;

  /// "09:00" / "09:50", 24-hour.
  final String start;
  final String end;

  final String subject;
  final String code;
  final String staff;
  final String room;
  final PeriodType type;

  int? get startMinutes => _toMinutes(start);
  int? get endMinutes => _toMinutes(end);

  static int? _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  bool containsTime(DateTime when) {
    final s = startMinutes, e = endMinutes;
    if (s == null || e == null) return false;
    final now = when.hour * 60 + when.minute;
    return now >= s && now < e;
  }

  /// Remaining time in this period, or null if it isn't running.
  Duration? remainingAt(DateTime when) {
    if (!containsTime(when)) return null;
    final now = when.hour * 60 + when.minute;
    return Duration(minutes: endMinutes! - now);
  }

  String get timeRange => '$start – $end';

  factory Period.fromMap(Map<String, dynamic> m) => Period(
        day: (m['day'] as num?)?.toInt() ?? 1,
        index: (m['index'] as num?)?.toInt() ?? 1,
        start: m['start'] as String? ?? '00:00',
        end: m['end'] as String? ?? '00:00',
        subject: m['subject'] as String? ?? '',
        code: m['code'] as String? ?? '',
        staff: m['staff'] as String? ?? '',
        room: m['room'] as String? ?? '',
        type: PeriodType.fromName(m['type'] as String?),
      );

  Map<String, dynamic> toMap() => {
        'day': day,
        'index': index,
        'start': start,
        'end': end,
        'subject': subject,
        'code': code,
        'staff': staff,
        'room': room,
        'type': type.name,
      };
}

enum PeriodType {
  theory,
  lab,
  breakTime,
  lunch;

  static PeriodType fromName(String? n) =>
      PeriodType.values.where((t) => t.name == n).firstOrNull ?? PeriodType.theory;

  /// Breaks and lunch are shown, but never announced as "current class".
  bool get isClass => this == PeriodType.theory || this == PeriodType.lab;

  String get label => switch (this) {
        PeriodType.theory => 'Theory',
        PeriodType.lab => 'Lab',
        PeriodType.breakTime => 'Break',
        PeriodType.lunch => 'Lunch',
      };
}

/// A `timetables/{sectionId}` document — one class section's weekly schedule.
class Timetable {
  const Timetable({
    required this.id,
    required this.name,
    required this.periods,
    this.department = '',
    this.year = 0,
  });

  final String id;
  final String name;
  final String department;
  final int year;
  final List<Period> periods;

  /// Periods for a weekday, in time order.
  List<Period> forDay(int weekday) {
    final list = periods.where((p) => p.day == weekday).toList()
      ..sort((a, b) => (a.startMinutes ?? 0).compareTo(b.startMinutes ?? 0));
    return list;
  }

  List<Period> todayFor(DateTime now) => forDay(now.weekday);

  /// The period running right now, or null between periods / outside hours.
  Period? currentPeriod(DateTime now) {
    for (final p in todayFor(now)) {
      if (p.containsTime(now)) return p;
    }
    return null;
  }

  /// The next period **later today**, or null once the day is over.
  ///
  /// Deliberately does not roll over to tomorrow: a card reading "next:
  /// Monday 9am" at 8pm on Friday is noise, and the caller shows a "done for
  /// the day" state instead.
  Period? nextPeriod(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    for (final p in todayFor(now)) {
      final start = p.startMinutes;
      if (start != null && start > minutes) return p;
    }
    return null;
  }

  bool get isEmpty => periods.isEmpty;

  factory Timetable.fromMap(String id, Map<String, dynamic> d) => Timetable(
        id: id,
        name: d['name'] as String? ?? id,
        department: d['department'] as String? ?? '',
        year: (d['year'] as num?)?.toInt() ?? 0,
        periods: (d['periods'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(Period.fromMap)
                .toList() ??
            const [],
      );
}
