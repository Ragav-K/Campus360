import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/failure_mapper.dart';
import '../models/calendar_event.dart';
import '../models/exam_schedule.dart';
import '../models/timetable.dart';

/// Reads `timetables`, `academicCalendar` and `examSchedules`. All three are
/// admin-curated and read-only for everyone else (enforced by rules, not by
/// this class).
class TimetableRepository {
  TimetableRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _timetables => _db.collection('timetables');
  CollectionReference<Map<String, dynamic>> get _calendar => _db.collection('academicCalendar');
  CollectionReference<Map<String, dynamic>> get _exams => _db.collection('examSchedules');

  /// One section's timetable. Null when the section has none yet — the UI must
  /// say so rather than render an empty grid.
  Stream<Timetable?> watchSection(String sectionId) => _timetables.doc(sectionId).snapshots().map(
        (snap) => snap.exists ? Timetable.fromMap(snap.id, snap.data()!) : null,
      );

  /// Every section, for the picker. Sections are few and change rarely.
  Stream<List<Timetable>> watchAllSections() => _timetables
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map((d) => Timetable.fromMap(d.id, d.data())).toList())
      .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));

  /// Calendar entries from [from] onward.
  ///
  /// Queries by start date only; multi-day events already in progress are
  /// caught by widening the window backwards, since Firestore cannot express
  /// "date <= today <= endDate" in one query.
  Stream<List<CalendarEvent>> watchCalendar({DateTime? from, int limit = 60}) {
    final start = from ?? DateTime.now().subtract(const Duration(days: 30));
    return _calendar
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('date')
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList())
        .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));
  }

  /// Every exam sheet published for [department], newest assessment last.
  ///
  /// Scoped to one department because that is what a student can act on, and
  /// because the whole-campus sheet is a dozen departments wide — the printed
  /// original is a single table, but only one column of it is ever theirs.
  Stream<List<ExamSchedule>> watchExamSchedules(String department) => _exams
      .where('department', isEqualTo: department)
      .snapshots()
      .map((snap) => snap.docs.map(_examFromDoc).toList())
      .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));

  ExamSchedule _examFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    return ExamSchedule(
      id: d.id,
      title: data['title'] as String? ?? '',
      calendarEventId: data['calendarEventId'] as String? ?? '',
      department: data['department'] as String? ?? '',
      year: (data['year'] as num?)?.toInt() ?? 0,
      semester: (data['semester'] as num?)?.toInt() ?? 0,
      fnTime: data['fnTime'] as String? ?? '',
      anTime: data['anTime'] as String? ?? '',
      maxMarks: data['maxMarks'] as String? ?? '',
      portion: data['portion'] as String? ?? '',
      pattern: (data['pattern'] as List?)?.whereType<String>().toList() ?? const [],
      source: data['source'] as String? ?? '',
      slots: (data['slots'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((m) {
                final date = (m['date'] as Timestamp?)?.toDate();
                return date == null ? null : ExamSlot.fromMap(m, date);
              })
              .whereType<ExamSlot>()
              .toList() ??
          const [],
    );
  }

  CalendarEvent _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    return CalendarEvent(
      id: d.id,
      title: data['title'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      type: CalendarEventType.fromName(data['type'] as String?),
      description: data['description'] as String? ?? '',
      appliesTo: data['appliesTo'] as String?,
    );
  }
}
