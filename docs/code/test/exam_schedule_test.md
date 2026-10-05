# test/exam_schedule_test.dart

## Purpose
Tests `lib/models/exam_schedule.dart` — `ExamSlot`, `ExamSchedule`, and `ExamSession`, covering slot "free"/"choice" semantics, ordering, span calculation, and session time lookup.

## Test cases
- **ExamSlot**
  - "a slot with neither papers nor a note is a free half-day" — `isFree` true when empty.
  - "a note alone is enough to make a slot meaningful" — a note alone makes `isFree` false.
  - "several papers in one slot is a choice, one is not" — `isChoice` true only with 2+ papers.
- **ExamSchedule.ordered**
  - "sorts by date, then forenoon before afternoon" — slots order by date then FN before AN.
  - "keeps free slots in the ordering but out of papersOnly" — `ordered` includes free slots, `papersOnly` excludes them, `isEmpty` false if any papers exist.
  - "a sheet of nothing but free slots counts as empty" — `isEmpty` true.
- **ExamSchedule.span**
  - "runs from the first paper to the last, ignoring free days" — span is the (first, last) dated paper, not free slots.
  - "is null when nothing is scheduled" — span is null with no papers.
- **timeFor**: picks the FN/AN time string correctly from the schedule's configured times.
- **ExamSession.fromName**: unknown or null session name falls back to `fn`; `'an'` parses correctly.

## Dependencies & relationships
Exercises `ExamSlot`, `ExamSchedule`, `ExamPaper`, `ExamSession` directly via helper builders `_slot()`/`_schedule()`. No mocks.

## Notable behavior / gotchas
Unknown/null session names fall back to forenoon (`fn`) rather than throwing, consistent with the app's general philosophy of graceful degradation on unrecognized enum values.
