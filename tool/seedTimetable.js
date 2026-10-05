#!/usr/bin/env node
/**
 * Seeds `timetables` and `academicCalendar` with the real KPRIET data.
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/campus360-admin.json node tool/seedTimetable.js
 *   node tool/seedTimetable.js --check     # validate the grids, write nothing
 *
 * Source documents (Aug 2026):
 *   - Class Time Table, Dept. of CS, III/S5 (Odd), Section C, w.e.f. 01.07.2026
 *   - KPRIET Odd Semester Academic Schedule 2026 – 2027
 *
 * Per period we need: day (1=Mon … 6=Sat), index, start, end, subject.
 * Optional but useful: code, staff, room, type ("theory" | "lab" | "breakTime"
 * | "lunch").
 *
 * Safe to re-run: deterministic ids + merge, so re-seeding updates in place.
 */

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const PROJECT_ID = 'campus360-app';
const DATABASE_ID = 'default'; // named database — see SETUP.md

// Constructing these does no I/O; the first read or write is where a missing
// key surfaces. That keeps `--check` usable with no credentials configured.
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore(DATABASE_ID);

// ---------------------------------------------------------------------------
// Period grid (identical every working day)
//
// Mentor hour runs 08:45–08:55 before period 1 on all working days; it is a
// standing 10-minute slot rather than a scheduled class, so it is not seeded
// as a period. Tea/lunch carry indices 8 and 9 so the printed period numbers
// 1–7 stay intact — `index` is only ever used for identity, never displayed.
// ---------------------------------------------------------------------------

const SLOTS = {
  1: { start: '08:55', end: '09:50' },
  2: { start: '09:50', end: '10:45' },
  3: { start: '11:05', end: '12:00' },
  4: { start: '12:00', end: '12:55' },
  5: { start: '13:45', end: '14:35' },
  6: { start: '14:35', end: '15:25' },
  7: { start: '15:25', end: '16:15' },
};

const TEA = { index: 8, start: '10:45', end: '11:05', subject: 'Tea break', type: 'breakTime' };
const LUNCH = { index: 9, start: '12:55', end: '13:45', subject: 'Lunch break', type: 'lunch' };

const ROOM = 'III CS C';

/** Course catalogue — keyed by the code printed in the grid. */
const COURSES = {
  U21MA501: { subject: 'Linear Algebra and Number Theory', staff: '' },
  U21CS501: { subject: 'Web Technologies', staff: 'Mr Rajesh Kumar S' },
  U21CS502: { subject: 'Compiler Design', staff: 'Dr Priya V' },
  U21CSG05: { subject: 'Computer Networks', staff: 'Dr Manoj Kumar' },
  U21CS503: { subject: 'Mobile Application Development', staff: 'Ms Avani Chandran' },
  U21CS504: { subject: 'Web Technologies Laboratory', staff: 'Mr Rajesh Kumar S' },
  U21CSP16: { subject: 'DevOps', staff: '' },
};

/** A catalogued course in a normal theory slot. */
const C = (code, extra = {}) => ({ code, ...COURSES[code], room: ROOM, ...extra });

/** Lab sitting in a catalogued course's slot. */
const LAB = (code, extra = {}) => C(code, { type: 'lab', room: `${ROOM} lab`, ...extra });

/**
 * Elective baskets. Students take one of the listed courses, so the slot names
 * the basket and lists the options — picking one per student is a later
 * feature, and showing a single guessed course would be worse than showing all.
 */
// Options — PE1: Foundations of Cloud Computing / Exploratory Data Analysis /
// Deep Neural Network. PE2: Cyber Security / Java Script Frameworks /
// Computer Vision.
const PE1 = {
  subject: 'Professional Elective 1',
  code: 'U21CSP01 / U21ADP05 / U21AMP03',
  staff: '',
  room: '',
};
const PE2 = {
  subject: 'Professional Elective 2',
  code: 'U21ITP05 / U21CSP12 / U21AMP05',
  staff: '',
  room: '',
};
const OE = { subject: 'Open Elective', code: 'OE', staff: '', room: '' };
const GC = { subject: 'GATE Coaching', code: 'GC', staff: '', room: ROOM };
const GC_MAT = { subject: 'GATE Coaching — Mathematics', code: 'GC', staff: '', room: ROOM };
const HM = { subject: 'Honour / Minor — DevOps', code: 'U21CSP16', staff: '', room: '' };
const MH = { subject: 'Mentor hour', code: 'MH', staff: '', room: ROOM };
const ACTIVITY = { subject: 'Activity', code: '', staff: '', room: '' };

/** Expands `{ periodIndex: entry }` for one day against the grid. */
function day(dayNumber, entries) {
  const periods = [];
  for (const slot of [TEA, LUNCH]) {
    periods.push({ day: dayNumber, code: '', staff: '', room: '', ...slot });
  }
  for (const [index, entry] of Object.entries(entries)) {
    const slot = SLOTS[index];
    periods.push({
      day: dayNumber,
      index: Number(index),
      start: slot.start,
      end: slot.end,
      subject: entry.subject,
      code: entry.code ?? '',
      staff: entry.staff ?? '',
      room: entry.room ?? '',
      type: entry.type ?? 'theory',
    });
  }
  return periods;
}

const sections = [
  {
    id: 'cse-3c',
    name: 'III CSE C',
    department: 'CS',
    year: 3,
    periods: [
      // Monday
      ...day(1, {
        1: C('U21CS501'),
        2: C('U21MA501'),
        3: C('U21CS503'),
        4: C('U21CS502'),
        5: OE,
        6: C('U21CS503'),
        7: GC,
      }),
      // Tuesday — CN lab occupies periods 3–4.
      ...day(2, {
        1: C('U21CSG05'),
        2: C('U21CS501'),
        3: LAB('U21CSG05', { subject: 'Computer Networks Lab' }),
        4: LAB('U21CSG05', { subject: 'Computer Networks Lab' }),
        5: PE2,
        6: PE1,
        7: HM,
      }),
      // Wednesday — WT lab occupies periods 6–7.
      ...day(3, {
        1: C('U21CS503'),
        2: C('U21CS502'),
        3: C('U21CSG05'),
        4: C('U21MA501'),
        5: OE,
        6: LAB('U21CS504'),
        7: LAB('U21CS504'),
      }),
      // Thursday — MAD lab occupies periods 3–4.
      ...day(4, {
        1: C('U21CSG05'),
        2: C('U21CS501'),
        3: LAB('U21CS503', { subject: 'Mobile Application Development Lab' }),
        4: LAB('U21CS503', { subject: 'Mobile Application Development Lab' }),
        5: HM,
        6: GC_MAT,
        7: PE1,
      }),
      // Friday
      ...day(5, {
        1: C('U21CS502'),
        2: HM,
        3: PE2,
        4: PE1,
        5: OE,
        6: C('U21MA501'),
        7: GC,
      }),
      // Saturday — half day; Activity runs across periods 5–7.
      ...day(6, {
        1: C('U21MA501'),
        2: PE2,
        3: MH,
        5: ACTIVITY,
        6: ACTIVITY,
        7: ACTIVITY,
      }),
    ],
  },
];

// ---------------------------------------------------------------------------
// Academic calendar — Odd semester 2026–27
// ---------------------------------------------------------------------------

/** Local midnight, so "today" comparisons in the app line up with the date. */
const d = (iso) => {
  const [y, m, day] = iso.split('-').map(Number);
  return Timestamp.fromDate(new Date(y, m - 1, day));
};

const schedule = [
  ['sem-registration', 'Course registration', 'event', '2026-06-25', '2026-07-01'],
  ['sem-commencement', 'Classes commence', 'event', '2026-07-01', null],
  ['ciat-1', 'CIAT – I (2.5 units, 60 marks)', 'exam', '2026-08-24', '2026-08-31'],
  ['block-teaching', 'Block teaching', 'event', '2026-09-01', '2026-09-05'],
  ['lab-test', 'Lab test', 'exam', '2026-10-12', '2026-10-16'],
  ['ciat-2', 'CIAT – II (2.5 units, 60 marks)', 'exam', '2026-10-22', '2026-10-29'],
  ['revision', 'Revision / optional test', 'exam', '2026-10-30', '2026-11-05'],
  ['last-working-day', 'Last working day', 'event', '2026-10-31', null],
  ['attendance-submission', 'Attendance submission — CoE office', 'event', '2026-11-03', null],
  ['practical-exam', 'End semester practical exam', 'exam', '2026-11-10', '2026-11-16'],
  ['internal-marks', 'Internal marks submission — CoE office', 'event', '2026-11-12', null],
  ['theory-exam', 'End semester theory exam begins', 'exam', '2026-11-18', null],
  ['sem-vacation', 'Odd semester vacation', 'event', '2026-11-23', '2026-12-19'],
  ['internship', 'Internship / in-plant / placement training', 'event', '2026-12-07', '2026-12-26'],
  ['reopening', 'Reopening (semesters 4, 6, 8)', 'event', '2026-12-28', null],
];

/** Placement training slots for III year — the section this timetable serves. */
const placementSlots = [
  ['2026-07-06', '2026-07-10'],
  ['2026-07-20', '2026-07-24'],
  ['2026-08-04', '2026-08-07'],
  ['2026-09-07', '2026-09-11'],
  ['2026-09-21', '2026-09-25'],
];

const projectReviews = [
  ['2026-07-16', '2026-07-18'],
  ['2026-09-05', '2026-09-08'],
  ['2026-10-08', '2026-10-10'],
];

const holidays = [
  ['2026-07-11', 'Holiday'],
  ['2026-07-25', 'Holiday'],
  ['2026-08-03', 'Adi Perukku'],
  ['2026-08-08', 'Holiday'],
  ['2026-08-15', 'Independence Day'],
  ['2026-08-26', 'Milad-un-Nabi'],
  ['2026-09-04', 'Krishna Jayanthi'],
  ['2026-09-12', 'Holiday'],
  ['2026-09-14', 'Vinayakar Chathurthi'],
  ['2026-09-26', 'Holiday'],
  ['2026-10-02', 'Gandhi Jayanthi'],
  ['2026-10-17', 'Holiday'],
  ['2026-10-19', 'Ayutha Pooja'],
  ['2026-10-20', 'Vijaya Dhasami'],
  ['2026-11-07', 'Holiday'],
  ['2026-11-08', 'Deepavali'],
  ['2026-11-09', 'Holiday'],
  ['2026-11-28', 'Holiday'],
  ['2026-12-12', 'Holiday'],
  ['2026-12-25', 'Christmas'],
  ['2026-12-26', 'Holiday'],
];

const calendar = [
  ...schedule.map(([id, title, type, start, end]) => ({
    id: `cal-${id}`,
    title,
    type,
    date: d(start),
    endDate: end ? d(end) : null,
  })),
  ...placementSlots.map(([start, end], i) => ({
    id: `cal-placement-${i + 1}`,
    title: `Placement training — slot ${i + 1}`,
    type: 'event',
    date: d(start),
    endDate: d(end),
    description: 'III year placement training.',
  })),
  ...projectReviews.map(([start, end], i) => ({
    id: `cal-project-review-${i + 1}`,
    title: `Project review — phase 1, review ${i + 1}`,
    type: 'event',
    date: d(start),
    endDate: d(end),
  })),
  ...holidays.map(([date, title]) => ({
    id: `cal-holiday-${date}`,
    title,
    type: 'holiday',
    date: d(date),
    endDate: null,
  })),
];

// ---------------------------------------------------------------------------
// Validation
//
// Six more grids will be typed in from printed sheets, and the mistakes that
// makes are quiet ones: a period keyed twice silently keeps the last entry, a
// mistyped code produces a period with no subject, a lab that lost its second
// half looks like an ordinary class. None of those fail at seed time, and none
// look wrong in Firestore — they show up as a student staring at a blank
// Tuesday. So check before writing, and refuse to write if anything is broken.
// ---------------------------------------------------------------------------

const DAY_NAMES = { 1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat' };
const BREAK_INDICES = new Set([TEA.index, LUNCH.index]);
const VALID_TYPES = new Set(['theory', 'lab', 'breakTime', 'lunch']);

/** A single course code, as printed. Elective baskets list several, so they are
 *  matched separately rather than looked up. */
// Both printed shapes: U21CS501 (2 letters, 3 digits) and U21CSG05 (3, 2).
const SINGLE_CODE = /^U21[A-Z]{2,3}\d{2,3}$/;

/**
 * Checks the expanded sections.
 *
 * Returns `{ errors, warnings }` — errors block the seed, warnings are printed
 * and continue. The split is deliberate: a free period is normal and must not
 * stop a seed, while a period claiming to be at a time the grid doesn't have is
 * always a typo.
 */
function validateSections(sectionList, { courses = COURSES, slots = SLOTS } = {}) {
  const errors = [];
  const warnings = [];

  const seenIds = new Set();

  for (const section of sectionList) {
    const where = section.id || '(section with no id)';

    if (!section.id) errors.push('A section has no id.');
    else if (seenIds.has(section.id)) errors.push(`${where}: duplicate section id.`);
    seenIds.add(section.id);

    if (!section.name) warnings.push(`${where}: no display name; the picker will show the id.`);

    const periods = section.periods || [];
    if (periods.length === 0) {
      errors.push(`${where}: no periods at all.`);
      continue;
    }

    const byKey = new Map();
    const byDay = new Map();

    for (const p of periods) {
      const at = `${where} ${DAY_NAMES[p.day] ?? `day ${p.day}`} period ${p.index}`;

      if (!DAY_NAMES[p.day]) {
        errors.push(`${at}: day must be 1 (Mon) to 6 (Sat).`);
      }

      const isBreak = BREAK_INDICES.has(p.index);
      if (!isBreak && !slots[p.index]) {
        errors.push(`${at}: no such period in the grid.`);
      }

      // A duplicate key is the dangerous one — the object literal keeps the
      // last value, so the grid on screen and the grid on paper differ with
      // nothing to show for it.
      const key = `${p.day}:${p.index}`;
      if (byKey.has(key)) errors.push(`${at}: defined twice.`);
      byKey.set(key, p);

      if (!byDay.has(p.day)) byDay.set(p.day, []);
      byDay.get(p.day).push(p);

      if (!p.subject) errors.push(`${at}: no subject.`);
      if (!VALID_TYPES.has(p.type)) {
        errors.push(`${at}: type "${p.type}" is not one of ${[...VALID_TYPES].join(', ')}.`);
      }

      // Times must match the grid, or the "what's on now" card highlights the
      // wrong row.
      const slot = isBreak
        ? (p.index === TEA.index ? TEA : LUNCH)
        : slots[p.index];
      if (slot && (p.start !== slot.start || p.end !== slot.end)) {
        errors.push(
          `${at}: times ${p.start}–${p.end} don't match the grid's ${slot.start}–${slot.end}.`,
        );
      }

      // An uncatalogued single code means C('…') returned undefined fields.
      if (p.code && SINGLE_CODE.test(p.code) && !courses[p.code]) {
        errors.push(`${at}: code ${p.code} is not in COURSES.`);
      }
      if (!isBreak && p.code && courses[p.code] && !p.staff) {
        warnings.push(`${at}: ${p.code} has no staff name.`);
      }
    }

    // Labs run in pairs here. A lab appearing alone is usually the second half
    // left out, and it would show a student one hour for a two-hour session.
    for (const [dayNumber, dayPeriods] of byDay) {
      const labs = dayPeriods.filter((p) => p.type === 'lab');
      const bySubject = new Map();
      for (const lab of labs) {
        if (!bySubject.has(lab.subject)) bySubject.set(lab.subject, []);
        bySubject.get(lab.subject).push(lab.index);
      }

      for (const [subject, indices] of bySubject) {
        const sorted = [...indices].sort((a, b) => a - b);
        const at = `${where} ${DAY_NAMES[dayNumber] ?? `day ${dayNumber}`}`;

        if (sorted.length === 1) {
          warnings.push(`${at}: "${subject}" is a lab in a single period — is its other half missing?`);
          continue;
        }
        for (let i = 1; i < sorted.length; i++) {
          if (sorted[i] !== sorted[i - 1] + 1) {
            errors.push(
              `${at}: lab "${subject}" occupies non-consecutive periods ${sorted.join(', ')}.`,
            );
            break;
          }
        }
      }

      // Free periods are normal, so this is only ever a warning — but a day
      // that is entirely missing is worth saying out loud.
      const teaching = dayPeriods.filter((p) => !BREAK_INDICES.has(p.index));
      if (teaching.length === 0) {
        warnings.push(`${where} ${DAY_NAMES[dayNumber]}: no classes at all.`);
      }
    }

    for (const dayNumber of Object.keys(DAY_NAMES).map(Number)) {
      if (!byDay.has(dayNumber)) {
        warnings.push(`${where}: nothing for ${DAY_NAMES[dayNumber]}.`);
      }
    }
  }

  return { errors, warnings };
}

/** Calendar entries are `[id, title, type, startDate, endDate]`. */
function validateCalendar(rows) {
  const errors = [];
  const seen = new Set();

  for (const [id, title, , start, end] of rows) {
    if (seen.has(id)) errors.push(`Calendar: duplicate id ${id}.`);
    seen.add(id);

    if (!title) errors.push(`Calendar ${id}: no title.`);
    if (end && start && end < start) {
      errors.push(`Calendar ${id}: ends ${end}, before it starts ${start}.`);
    }
  }

  return { errors, warnings: [] };
}

/** Sample docs from the pre-launch seed; removed so the picker shows real data only. */
const stale = [
  'timetables/cse-3a',
  'timetables/cse-3b',
  'academicCalendar/cal-holiday-soon',
  'academicCalendar/cal-model-exams',
  'academicCalendar/cal-symposium',
];

async function main() {
  const checkOnly = process.argv.includes('--check');

  const results = [validateSections(sections), validateCalendar(schedule)];
  const errors = results.flatMap((r) => r.errors);
  const warnings = results.flatMap((r) => r.warnings);

  for (const w of warnings) console.warn(`  warn   ${w}`);
  for (const e of errors) console.error(`  ERROR  ${e}`);

  if (errors.length > 0) {
    // Refuse rather than write a broken grid: a seeded timetable is what a
    // student trusts to know where to be, and a half-correct one is worse than
    // the old one it replaced.
    console.error(`\n${errors.length} problem(s) — nothing written. Fix the grid and re-run.`);
    process.exit(1);
  }

  console.log(
    `Validated ${sections.length} section(s), ${schedule.length} calendar entries` +
      `${warnings.length > 0 ? ` (${warnings.length} warning(s))` : ''}.\n`,
  );

  if (checkOnly) {
    // Validation is pure, so --check needs no credentials — usable while
    // typing grids in, long before anyone runs the real seed.
    console.log('--check: nothing written.');
    process.exit(0);
  }

  console.log(`Seeding timetables into ${PROJECT_ID} (database "${DATABASE_ID}")…\n`);

  let batch = db.batch();
  for (const { id, ...data } of sections) {
    batch.set(db.doc(`timetables/${id}`), data, { merge: true });
    console.log(`  ${id} — ${data.periods.length} periods`);
  }
  await batch.commit();

  batch = db.batch();
  for (const { id, ...data } of calendar) {
    batch.set(db.doc(`academicCalendar/${id}`), { endDate: null, appliesTo: null, description: '', ...data }, { merge: true });
  }
  await batch.commit();
  console.log(`  academicCalendar — ${calendar.length} entries`);

  batch = db.batch();
  for (const path of stale) batch.delete(db.doc(path));
  await batch.commit();
  console.log(`  removed ${stale.length} sample documents`);

  console.log('\nDone.');
  process.exit(0);
}

// Only seed when run directly, so tool/testSeedTimetable.js can exercise the
// validators without credentials.
if (require.main === module) {
  main().catch((err) => {
    console.error('\nSeeding failed:', err.message);
    process.exit(1);
  });
}

module.exports = { validateSections, validateCalendar, SLOTS, COURSES, TEA, LUNCH, day, sections };
