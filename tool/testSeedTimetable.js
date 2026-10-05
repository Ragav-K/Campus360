#!/usr/bin/env node
/**
 * Tests the timetable validators in `tool/seedTimetable.js`.
 *
 *   node tool/testSeedTimetable.js
 *
 * No credentials, no network. The point of the validators is to catch typos in
 * hand-copied grids, so what matters is that each specific mistake is caught —
 * and, just as much, that legitimate grids (free periods, elective baskets,
 * a half-day Saturday) are not flagged. A validator that cried wolf would be
 * turned off within a week.
 */

const {
  validateSections,
  validateCalendar,
  SLOTS,
  TEA,
  LUNCH,
  sections: realSections,
} = require('./seedTimetable.js');

let pass = 0;
let fail = 0;

function check(label, ok, detail = '') {
  if (ok) {
    pass++;
    console.log(`  PASS  ${label}`);
  } else {
    fail++;
    console.log(`  FAIL  ${label} ${detail}`);
  }
}

/** One period, correct by default; override to break exactly one thing. */
const period = (over = {}) => ({
  day: 1,
  index: 1,
  start: SLOTS[1].start,
  end: SLOTS[1].end,
  subject: 'Web Technologies',
  code: 'U21CS501',
  staff: 'Mr Rajesh Kumar S',
  room: 'III CS C',
  type: 'theory',
  ...over,
});

const breaks = (dayNumber) => [
  { day: dayNumber, code: '', staff: '', room: '', ...TEA },
  { day: dayNumber, code: '', staff: '', room: '', ...LUNCH },
];

const section = (periods, over = {}) => [
  { id: 'cse-3x', name: 'III CSE X', department: 'CS', year: 3, periods, ...over },
];

const errorsOf = (periods, over) => validateSections(section(periods, over)).errors;
const warningsOf = (periods, over) => validateSections(section(periods, over)).warnings;
const mentions = (list, text) => list.some((m) => m.toLowerCase().includes(text.toLowerCase()));

// ---------------------------------------------------------------------------

console.log('\nThe real grid');
{
  const { errors, warnings } = validateSections(realSections);

  check('III CSE C passes with no errors', errors.length === 0, `(got ${errors.join('; ')})`);
  check(
    'its only warnings are missing staff names',
    warnings.every((w) => w.includes('no staff name')),
    `(got ${warnings.filter((w) => !w.includes('no staff name')).join('; ')})`,
  );
  check(
    'a half-day Saturday with a free period is not an error',
    !mentions(errors, 'Sat'),
  );
}

console.log('\nMistakes that must be caught');
{
  // The dangerous one: an object literal keeps the last value silently, so the
  // seeded grid and the printed sheet differ with nothing to show for it.
  const duplicated = [...breaks(1), period(), period({ subject: 'Compiler Design' })];
  check('a period defined twice', mentions(errorsOf(duplicated), 'defined twice'));

  check(
    'a day outside Mon–Sat',
    mentions(errorsOf([period({ day: 7 })]), 'day must be'),
  );

  check(
    'a period index the grid does not have',
    mentions(errorsOf([period({ index: 11 })]), 'no such period'),
  );

  check(
    'times that disagree with the grid',
    mentions(errorsOf([period({ start: '09:00' })]), "don't match the grid"),
  );

  check('a period with no subject', mentions(errorsOf([period({ subject: '' })]), 'no subject'));

  check(
    'an unknown period type',
    mentions(errorsOf([period({ type: 'seminar' })]), 'is not one of'),
  );

  // C('U21CS999') returns undefined fields, so this is how a mistyped code
  // reaches Firestore as a period with no subject.
  check(
    'a course code missing from COURSES',
    mentions(errorsOf([period({ code: 'U21CS999' })]), 'not in COURSES'),
  );

  check(
    'a lab split across non-consecutive periods',
    mentions(
      errorsOf([
        period({ index: 3, type: 'lab', subject: 'CN Lab', start: SLOTS[3].start, end: SLOTS[3].end }),
        period({ index: 5, type: 'lab', subject: 'CN Lab', start: SLOTS[5].start, end: SLOTS[5].end }),
      ]),
      'non-consecutive',
    ),
  );

  const twoSections = [...section([period()]), ...section([period()])];
  check('two sections sharing an id', mentions(validateSections(twoSections).errors, 'duplicate section id'));

  check('a section with no periods', mentions(errorsOf([]), 'no periods'));
}

console.log('\nThings that are odd but legal — warnings, not errors');
{
  const loneLab = [
    ...breaks(1),
    period({ index: 3, type: 'lab', subject: 'CN Lab', start: SLOTS[3].start, end: SLOTS[3].end }),
  ];
  check('a single-period lab warns', mentions(warningsOf(loneLab), 'other half missing'));
  check('and does not block the seed', errorsOf(loneLab).length === 0);

  check('a missing weekday warns', mentions(warningsOf([period()]), 'nothing for Sat'));
  check('and does not block the seed', errorsOf([period()]).length === 0);

  const noName = validateSections(section([period()], { name: '' }));
  check('a section with no display name warns', mentions(noName.warnings, 'no display name'));
  check('and does not block the seed', noName.errors.length === 0);

  // Elective baskets carry several codes in one string and are deliberately
  // not looked up in COURSES.
  const elective = [period({ code: 'U21CSP01 / U21ADP05 / U21AMP03', subject: 'Professional Elective 1', staff: '' })];
  check('an elective basket is not treated as an unknown code', errorsOf(elective).length === 0);

  // Breaks legitimately sit at indices outside the 1–7 grid.
  check('tea and lunch are not flagged', errorsOf(breaks(1)).length === 0);
}

console.log('\nCalendar');
{
  const errors = validateCalendar([
    ['a', 'Model exams', 'exam', '2026-11-10', '2026-11-02'],
    ['b', '', 'event', '2026-07-01', null],
    ['a', 'Duplicate', 'event', '2026-07-01', null],
  ]);

  check('an entry that ends before it starts', mentions(errors.errors, 'before it starts'));
  check('an entry with no title', mentions(errors.errors, 'no title'));
  check('a duplicate calendar id', mentions(errors.errors, 'duplicate id'));

  const real = validateCalendar([['x', 'Classes commence', 'event', '2026-07-01', null]]);
  check('an open-ended entry is fine', real.errors.length === 0);
}

console.log(`\n${pass} passed, ${fail} failed.`);
process.exit(fail === 0 ? 0 : 1);
