import 'package:campus360/models/exam_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

ExamSlot _slot(
  int day,
  ExamSession session, {
  List<String> papers = const [],
  String note = '',
}) =>
    ExamSlot(
      date: DateTime(2026, 8, day),
      session: session,
      papers: [for (final p in papers) ExamPaper(code: p, subject: p)],
      note: note,
    );

ExamSchedule _schedule(List<ExamSlot> slots) => ExamSchedule(
      id: 'ciat-1-cs-3',
      title: 'CIAT – I',
      calendarEventId: 'cal-ciat-1',
      department: 'CS',
      fnTime: '09:00 AM – 10:30 AM',
      anTime: '02:30 PM – 04:00 PM',
      slots: slots,
    );

void main() {
  group('ExamSlot', () {
    test('a slot with neither papers nor a note is a free half-day', () {
      expect(_slot(24, ExamSession.fn).isFree, isTrue);
    });

    test('a note alone is enough to make a slot meaningful', () {
      expect(_slot(24, ExamSession.fn, note: 'Aptitude test').isFree, isFalse);
    });

    test('several papers in one slot is a choice, one is not', () {
      expect(_slot(1, ExamSession.fn, papers: ['A']).isChoice, isFalse);
      expect(_slot(1, ExamSession.fn, papers: ['A', 'B']).isChoice, isTrue);
    });
  });

  group('ExamSchedule.ordered', () {
    test('sorts by date, then forenoon before afternoon', () {
      final s = _schedule([
        _slot(25, ExamSession.an, papers: ['late']),
        _slot(24, ExamSession.an, papers: ['b']),
        _slot(24, ExamSession.fn, papers: ['a']),
      ]);

      expect(
        s.ordered.map((e) => e.papers.first.code).toList(),
        ['a', 'b', 'late'],
      );
    });

    test('keeps free slots in the ordering but out of papersOnly', () {
      final s = _schedule([
        _slot(24, ExamSession.fn),
        _slot(24, ExamSession.an, papers: ['a']),
      ]);

      expect(s.ordered, hasLength(2));
      expect(s.papersOnly, hasLength(1));
      expect(s.isEmpty, isFalse);
    });

    test('a sheet of nothing but free slots counts as empty', () {
      expect(_schedule([_slot(24, ExamSession.fn)]).isEmpty, isTrue);
    });
  });

  group('ExamSchedule.span', () {
    test('runs from the first paper to the last, ignoring free days', () {
      final s = _schedule([
        _slot(24, ExamSession.fn),
        _slot(25, ExamSession.an, papers: ['a']),
        _slot(29, ExamSession.fn, papers: ['b']),
        _slot(31, ExamSession.an),
      ]);

      final span = s.span;
      expect(span, isNotNull);
      expect(span!.$1, DateTime(2026, 8, 25));
      expect(span.$2, DateTime(2026, 8, 29));
    });

    test('is null when nothing is scheduled', () {
      expect(_schedule([_slot(24, ExamSession.fn)]).span, isNull);
    });
  });

  test('timeFor picks the session the paper actually sits in', () {
    final s = _schedule(const []);
    expect(s.timeFor(ExamSession.fn), '09:00 AM – 10:30 AM');
    expect(s.timeFor(ExamSession.an), '02:30 PM – 04:00 PM');
  });

  test('an unknown session name falls back to forenoon rather than throwing', () {
    expect(ExamSession.fromName('evening'), ExamSession.fn);
    expect(ExamSession.fromName(null), ExamSession.fn);
    expect(ExamSession.fromName('an'), ExamSession.an);
  });
}
