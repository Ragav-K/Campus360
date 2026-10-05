import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../models/calendar_event.dart';
import '../../../models/exam_schedule.dart';
import '../../../models/timetable.dart';
import '../../../repositories/timetable_repository.dart';
import '../../auth/providers/auth_providers.dart';

final timetableRepositoryProvider = Provider<TimetableRepository>(
  (ref) => TimetableRepository(ref.watch(firestoreProvider)),
);

/// The section this user follows, or null if they haven't picked one.
final userSectionProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider).valueOrNull?.sectionId,
);

/// Every section, for the picker.
final allSectionsProvider = StreamProvider<List<Timetable>>(
  (ref) => ref.watch(timetableRepositoryProvider).watchAllSections(),
);

/// This user's timetable. Emits null when no section is chosen, so callers can
/// distinguish "not set up" from "still loading".
final myTimetableProvider = StreamProvider<Timetable?>((ref) {
  final sectionId = ref.watch(userSectionProvider);
  if (sectionId == null || sectionId.isEmpty) return Stream.value(null);
  return ref.watch(timetableRepositoryProvider).watchSection(sectionId);
});

final calendarProvider = StreamProvider<List<CalendarEvent>>(
  (ref) => ref.watch(timetableRepositoryProvider).watchCalendar(),
);

/// The department of the section this user follows, e.g. "CS". Exam sheets are
/// published per department, so this is what scopes them.
final userDepartmentProvider = Provider<String?>((ref) {
  final dept = ref.watch(myTimetableProvider).valueOrNull?.department;
  return (dept == null || dept.isEmpty) ? null : dept;
});

/// Exam sheets for this user's department, keyed by the calendar event they
/// belong to. Empty until a section (and so a department) is known.
final examSchedulesProvider = StreamProvider<Map<String, ExamSchedule>>((ref) {
  final dept = ref.watch(userDepartmentProvider);
  if (dept == null) return Stream.value(const {});
  return ref.watch(timetableRepositoryProvider).watchExamSchedules(dept).map(
        (list) => {for (final s in list) s.calendarEventId: s},
      );
});

/// The exam sheet attached to a calendar event, or null when none is published.
final examScheduleForEventProvider = Provider.family<ExamSchedule?, String>(
  (ref, eventId) => ref.watch(examSchedulesProvider).valueOrNull?[eventId],
);

/// Campus events covering today that apply to this user.
final todayEventsProvider = Provider<List<CalendarEvent>>((ref) {
  final events = ref.watch(calendarProvider).valueOrNull ?? const [];
  final section = ref.watch(userSectionProvider);
  final now = DateTime.now();
  return events
      .where((e) => e.coversDay(now) && e.appliesToSection(section))
      .toList();
});

/// The holiday in effect today, if any. A holiday suppresses the day's periods
/// rather than showing classes nobody will attend.
final todayHolidayProvider = Provider<CalendarEvent?>((ref) {
  final today = ref.watch(todayEventsProvider);
  return today.where((e) => e.type == CalendarEventType.holiday).firstOrNull;
});

/// Everything upcoming, soonest first.
final upcomingEventsProvider = Provider<List<CalendarEvent>>((ref) {
  final events = ref.watch(calendarProvider).valueOrNull ?? const [];
  final section = ref.watch(userSectionProvider);
  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);

  return events
      .where((e) => e.appliesToSection(section))
      .where((e) => !(e.endDate ?? e.date).isBefore(startOfToday))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
});

/// What the "Today" card should display.
///
/// Computed in one place so the card stays a dumb renderer and the rules about
/// holidays, breaks and end-of-day live somewhere testable.
class TodaySchedule {
  const TodaySchedule({
    required this.periods,
    this.current,
    this.next,
    this.holiday,
    this.hasSection = true,
    this.hasTimetable = true,
  });

  final List<Period> periods;
  final Period? current;
  final Period? next;
  final CalendarEvent? holiday;
  final bool hasSection;
  final bool hasTimetable;

  bool get isHoliday => holiday != null;
  bool get isWeekendOrEmpty => periods.isEmpty;
  bool get isDayOver => periods.isNotEmpty && current == null && next == null;
}

final todayScheduleProvider = Provider<TodaySchedule>((ref) {
  // Re-evaluates every minute so "ends in 12 min" and the rollover from one
  // period to the next stay truthful.
  final now = ref.watch(clockProvider);

  final sectionId = ref.watch(userSectionProvider);
  if (sectionId == null || sectionId.isEmpty) {
    return const TodaySchedule(periods: [], hasSection: false);
  }

  final timetable = ref.watch(myTimetableProvider).valueOrNull;
  if (timetable == null || timetable.isEmpty) {
    return const TodaySchedule(periods: [], hasTimetable: false);
  }

  final holiday = ref.watch(todayHolidayProvider);
  if (holiday != null) {
    return TodaySchedule(periods: const [], holiday: holiday);
  }

  return TodaySchedule(
    periods: timetable.todayFor(now),
    current: timetable.currentPeriod(now),
    next: timetable.nextPeriod(now),
  );
});

/// Ticks every 30s. Separate from the Pulse tick so the timetable can be used
/// without importing the Pulse feature.
final _clockStreamProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

/// Current time as a plain value, so consumers don't unwrap an AsyncValue just
/// to know what time it is.
final clockProvider = Provider<DateTime>(
  (ref) => ref.watch(_clockStreamProvider).valueOrNull ?? DateTime.now(),
);
