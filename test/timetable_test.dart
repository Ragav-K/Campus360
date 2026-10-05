import 'package:campus360/models/calendar_event.dart';
import 'package:campus360/models/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monday schedule: two classes with a break between them.
Timetable _monday() => const Timetable(
      id: 'cse-3a',
      name: 'CSE 3A',
      periods: [
        Period(day: 1, index: 1, start: '09:00', end: '09:50', subject: 'Operating Systems'),
        Period(day: 1, index: 2, start: '09:50', end: '10:40', subject: 'Networks'),
        Period(
          day: 1,
          index: 3,
          start: '10:40',
          end: '11:00',
          subject: 'Break',
          type: PeriodType.breakTime,
        ),
        Period(day: 1, index: 4, start: '11:00', end: '11:50', subject: 'DBMS'),
        // Tuesday, to prove day filtering works.
        Period(day: 2, index: 1, start: '09:00', end: '09:50', subject: 'Maths'),
      ],
    );

/// A Monday at the given time.
DateTime _mon(int hour, int minute) => DateTime(2026, 8, 10, hour, minute);

void main() {
  group('Timetable.forDay', () {
    test('returns only that weekday, in time order', () {
      final periods = _monday().forDay(DateTime.monday);
      expect(periods.length, 4);
      expect(periods.first.subject, 'Operating Systems');
      expect(periods.last.subject, 'DBMS');
    });

    test('a day with nothing scheduled is empty, not an error', () {
      expect(_monday().forDay(DateTime.sunday), isEmpty);
    });
  });

  group('currentPeriod', () {
    test('finds the period in progress', () {
      expect(_monday().currentPeriod(_mon(9, 20))?.subject, 'Operating Systems');
    });

    test('is inclusive of the start minute and exclusive of the end', () {
      // At exactly 09:50 the first period has ended and the second has begun —
      // the boundary must not report both or neither.
      expect(_monday().currentPeriod(_mon(9, 50))?.subject, 'Networks');
      expect(_monday().currentPeriod(_mon(9, 0))?.subject, 'Operating Systems');
    });

    test('returns null before the day starts and after it ends', () {
      expect(_monday().currentPeriod(_mon(8, 30)), isNull);
      expect(_monday().currentPeriod(_mon(18, 0)), isNull);
    });

    test('returns null on a day with no classes', () {
      expect(_monday().currentPeriod(DateTime(2026, 8, 16, 10, 0)), isNull); // Sunday
    });
  });

  group('nextPeriod', () {
    test('returns the next one later today', () {
      expect(_monday().nextPeriod(_mon(9, 20))?.subject, 'Networks');
    });

    test('before the day begins, the next period is the first', () {
      expect(_monday().nextPeriod(_mon(7, 0))?.subject, 'Operating Systems');
    });

    test('after the last period there is no next — it does not roll to tomorrow', () {
      // Deliberate: "next: Maths, Tuesday 9am" shown at 6pm Monday is noise.
      expect(_monday().nextPeriod(_mon(18, 0)), isNull);
    });
  });

  group('Period.remainingAt', () {
    test('counts down within the period', () {
      final period = _monday().forDay(1).first;
      expect(period.remainingAt(_mon(9, 30))?.inMinutes, 20);
    });

    test('is null when the period is not running', () {
      final period = _monday().forDay(1).first;
      expect(period.remainingAt(_mon(12, 0)), isNull);
    });
  });

  group('CalendarEvent.coversDay', () {
    final single = CalendarEvent(
      id: 'a',
      title: 'Pongal',
      date: DateTime(2026, 1, 14),
      type: CalendarEventType.holiday,
    );

    final span = CalendarEvent(
      id: 'b',
      title: 'Model exams',
      date: DateTime(2026, 3, 2),
      endDate: DateTime(2026, 3, 6),
      type: CalendarEventType.exam,
    );

    test('single-day event covers only its own day', () {
      expect(single.coversDay(DateTime(2026, 1, 14, 23, 59)), isTrue);
      expect(single.coversDay(DateTime(2026, 1, 15)), isFalse);
    });

    test('multi-day event covers both endpoints and the days between', () {
      expect(span.coversDay(DateTime(2026, 3, 2)), isTrue);
      expect(span.coversDay(DateTime(2026, 3, 4)), isTrue);
      expect(span.coversDay(DateTime(2026, 3, 6)), isTrue);
      expect(span.coversDay(DateTime(2026, 3, 7)), isFalse);
      expect(span.coversDay(DateTime(2026, 3, 1)), isFalse);
    });

    test('ignores the time of day when comparing', () {
      expect(span.coversDay(DateTime(2026, 3, 6, 18, 30)), isTrue);
    });
  });

  group('CalendarEvent.appliesToSection', () {
    test('a campus-wide event applies to everyone', () {
      final event = CalendarEvent(
        id: 'c',
        title: 'Sports day',
        date: DateTime(2026, 2, 1),
        type: CalendarEventType.event,
      );
      expect(event.appliesToSection('cse-3a'), isTrue);
      expect(event.appliesToSection(null), isTrue);
    });

    test('a section-specific event applies only to that section', () {
      final event = CalendarEvent(
        id: 'd',
        title: 'CSE industrial visit',
        date: DateTime(2026, 2, 1),
        type: CalendarEventType.event,
        appliesTo: 'cse-3a',
      );
      expect(event.appliesToSection('cse-3a'), isTrue);
      expect(event.appliesToSection('ece-2b'), isFalse);
    });
  });
}
