/// Which half of the day a paper sits in. The printed timetables only ever say
/// FN or AN, and the actual clock times are a property of the whole schedule
/// rather than of each paper.
enum ExamSession {
  fn,
  an;

  static ExamSession fromName(String? n) =>
      ExamSession.values.where((s) => s.name == n).firstOrNull ?? ExamSession.fn;

  String get label => switch (this) {
        ExamSession.fn => 'Forenoon',
        ExamSession.an => 'Afternoon',
      };

  String get shortLabel => switch (this) {
        ExamSession.fn => 'FN',
        ExamSession.an => 'AN',
      };
}

/// One row of an exam timetable: a date, a session, and what is being written.
///
/// [papers] is a list because a slot can legitimately hold several courses at
/// once — elective baskets and honour/minor courses are printed stacked in a
/// single cell, and which one a student sits is their own enrolment. Showing
/// all of them and letting the student recognise theirs is safer than guessing.
class ExamPaper {
  const ExamPaper({required this.code, required this.subject});

  final String code;
  final String subject;

  factory ExamPaper.fromMap(Map<String, dynamic> m) => ExamPaper(
        code: m['code'] as String? ?? '',
        subject: m['subject'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'code': code, 'subject': subject};
}

class ExamSlot {
  const ExamSlot({
    required this.date,
    required this.session,
    this.papers = const [],
    this.note = '',
  });

  final DateTime date;
  final ExamSession session;
  final List<ExamPaper> papers;

  /// Free text for slots the timetable annotates rather than names, e.g. the
  /// aptitude test conducted by the department.
  final String note;

  /// A printed "NA" — no paper for this department in that slot. Kept in the
  /// data rather than dropped so the schedule reads like the original sheet,
  /// where an empty half-day is information, not an omission.
  bool get isFree => papers.isEmpty && note.isEmpty;

  /// True when the slot lists alternatives rather than one fixed paper.
  bool get isChoice => papers.length > 1;

  factory ExamSlot.fromMap(Map<String, dynamic> m, DateTime date) => ExamSlot(
        date: date,
        session: ExamSession.fromName(m['session'] as String?),
        papers: (m['papers'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(ExamPaper.fromMap)
                .toList() ??
            const [],
        note: m['note'] as String? ?? '',
      );
}

/// An `examSchedules/{id}` document — one department-and-year's papers for one
/// assessment (CIAT-I, CIAT-II, end semester …).
///
/// Linked to the academic calendar by [calendarEventId] so tapping the exam on
/// the calendar opens the matching sheet.
class ExamSchedule {
  const ExamSchedule({
    required this.id,
    required this.title,
    required this.calendarEventId,
    required this.slots,
    this.department = '',
    this.year = 0,
    this.semester = 0,
    this.fnTime = '',
    this.anTime = '',
    this.maxMarks = '',
    this.portion = '',
    this.pattern = const [],
    this.source = '',
  });

  final String id;
  final String title;

  /// The `academicCalendar` document this belongs to.
  final String calendarEventId;

  final String department;
  final int year;
  final int semester;

  /// "09:00 AM – 10:30 AM" etc., printed once for the whole sheet.
  final String fnTime;
  final String anTime;

  final String maxMarks;
  final String portion;

  /// Question paper pattern, one line per part.
  final List<String> pattern;

  /// Where this was transcribed from, so a student can check the original.
  final String source;

  final List<ExamSlot> slots;

  /// Slots in date order, forenoon before afternoon.
  List<ExamSlot> get ordered {
    final list = [...slots]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.session.index.compareTo(b.session.index);
      });
    return list;
  }

  /// Slots that actually hold a paper.
  List<ExamSlot> get papersOnly => ordered.where((s) => !s.isFree).toList();

  bool get isEmpty => papersOnly.isEmpty;

  /// The first and last day carrying a paper, or null when there are none.
  (DateTime, DateTime)? get span {
    final list = papersOnly;
    if (list.isEmpty) return null;
    return (list.first.date, list.last.date);
  }

  String timeFor(ExamSession session) =>
      session == ExamSession.fn ? fnTime : anTime;
}
