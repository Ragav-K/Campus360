import 'package:flutter/material.dart';

import 'enums/pulse_enums.dart';

enum CalendarEventType {
  holiday,
  exam,
  event;

  static CalendarEventType fromName(String? n) =>
      CalendarEventType.values.where((t) => t.name == n).firstOrNull ?? CalendarEventType.event;

  String get label => switch (this) {
        CalendarEventType.holiday => 'Holiday',
        CalendarEventType.exam => 'Exam',
        CalendarEventType.event => 'Event',
      };

  IconData get icon => switch (this) {
        CalendarEventType.holiday => Icons.beach_access_rounded,
        CalendarEventType.exam => Icons.edit_note_rounded,
        CalendarEventType.event => Icons.celebration_rounded,
      };

  /// Reuses the app-wide status tones so the calendar matches Pulse.
  StatusTone get tone => switch (this) {
        CalendarEventType.holiday => StatusTone.good,
        CalendarEventType.exam => StatusTone.caution,
        CalendarEventType.event => StatusTone.info,
      };
}

/// An `academicCalendar/{id}` document.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    this.endDate,
    this.description = '',
    this.appliesTo,
  });

  final String id;
  final String title;
  final DateTime date;

  /// Inclusive last day for multi-day items (exam weeks, festivals).
  final DateTime? endDate;

  final CalendarEventType type;
  final String description;

  /// Null means the whole campus; otherwise a sectionId.
  final String? appliesTo;

  bool get isMultiDay => endDate != null && !_sameDay(endDate!, date);

  /// True when [day] falls inside this event, inclusive of both ends.
  bool coversDay(DateTime day) {
    final start = DateTime(date.year, date.month, date.day);
    final end = endDate == null
        ? start
        : DateTime(endDate!.year, endDate!.month, endDate!.day);
    final target = DateTime(day.year, day.month, day.day);
    return !target.isBefore(start) && !target.isAfter(end);
  }

  bool appliesToSection(String? sectionId) => appliesTo == null || appliesTo == sectionId;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
