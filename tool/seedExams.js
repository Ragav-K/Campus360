#!/usr/bin/env node
/**
 * Seeds `examSchedules` — the per-department exam sheets that hang off an
 * `academicCalendar` entry.
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/campus360-admin.json node tool/seedExams.js
 *
 * Source: "UG (CIAT I ) - III Year - Sem V.pdf" (KPRIET, CIAT I timetable for
 * UG programme, academic year 2026-2027, semester 05). That sheet is one wide
 * table with a column per department; this seeds the CS column only. Add more
 * departments by appending to `schedules` — each needs its own document.
 *
 * `calendarEventId` must match an academicCalendar document id (see
 * tool/seedTimetable.js), which is how the app links the calendar entry to the
 * sheet.
 *
 * A slot with no papers and no note is a printed "NA" — a free half-day. Those
 * are seeded deliberately: the app shows them, because a gap in an exam week is
 * information.
 *
 * Safe to re-run: deterministic ids + merge.
 */

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const PROJECT_ID = 'campus360-app';
const DATABASE_ID = 'default'; // named database — see SETUP.md

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore(DATABASE_ID);

const d = (iso) => {
  const [y, m, day] = iso.split('-').map(Number);
  return Timestamp.fromDate(new Date(y, m - 1, day));
};

/** `P('U21CS501 - Web Technologies')` → { code, subject }. */
const P = (s) => {
  const i = s.indexOf(' - ');
  return i < 0 ? { code: '', subject: s } : { code: s.slice(0, i), subject: s.slice(i + 3) };
};

/** One row of the printed sheet. Omit `papers` for an "NA" half-day. */
const slot = (date, session, papers = [], note = '') => ({
  date: d(date),
  session,
  papers: papers.map(P),
  note,
});

const OPEN_ELECTIVES = [
  'U21BMX04 - Food as Medicine',
  'U21CAX01 - Entrepreneurship Development and Startup',
  'U21CBX03 - IT for Managers',
  'U21CEX04 - Waste Management',
  'U21CHX03 - Environmental Impact Assessment',
  'U21CHX04 - Industrial Wastewater Treatment',
  'U21CYX05 - Waste Management and Resource Recovery',
  'U21CYX07 - Food Engineering and Technology',
  'U21ECX04 - Electronic Waste Management and Sustainable Practices',
  'U21EEX04 - Home Automation',
  'U21ENX01 - Effective Public Speaking and Presentation Skills',
  'U21ENX02 - Emotional Intelligence',
  'U21GEX07 - Vertical Transportation Systems',
  'U21ITX04 - Human Resource Management',
  'U21MEX04 - Additive Manufacturing and 3D Printing',
  'U21MIX04 - Robotics Process Automation',
  'U21PHX04 - Modern Physics for Engineering Applications',
];

const schedules = [
  {
    id: 'ciat-1-cs-3',
    calendarEventId: 'cal-ciat-1',
    title: 'CIAT – I',
    department: 'CS',
    year: 3,
    semester: 5,
    fnTime: '09:00 AM – 10:30 AM',
    anTime: '02:30 PM – 04:00 PM',
    maxMarks: '60 marks',
    portion: '2.5 units',
    pattern: [
      'Part A — 10 × 1 = 10 marks',
      'Part B — 10 × 2 = 20 marks',
      'Part C — 2 × 12 = 24 marks & 1 × 6 = 6 marks',
    ],
    source: 'CIAT I timetable for UG programme, 2026–2027 semester 05',
    slots: [
      slot('2026-08-24', 'fn'),
      slot('2026-08-24', 'an', ['U21CS501 - Web Technologies']),
      slot('2026-08-25', 'fn'),
      slot('2026-08-25', 'an', ['U21CS502 - Compiler Design']),
      // Honour/minor papers sit in their own half-days.
      slot('2026-08-27', 'fn', [
        'U21CSP03 - Virtualization Techniques (H)',
        'U21CSP13 - Webservices and API Design (H)',
      ]),
      slot('2026-08-27', 'an', ['U21CS503 - Mobile Application Development']),
      slot('2026-08-28', 'fn', ['U21ITP03 - Wireless Sensor Network (H)']),
      slot('2026-08-28', 'an', ['U21CSG05 - Computer Networks']),
      slot('2026-08-29', 'fn', ['U21ADP07 - Time Series Analysis and Forecasting (H)']),
      slot('2026-08-29', 'an', ['U21MA501 - Linear Algebra and Number Theory']),
      slot('2026-08-31', 'fn'),
      slot('2026-08-31', 'an', OPEN_ELECTIVES, 'Open elective — whichever you registered for.'),
      // PE2 basket, matching the timetable's Professional Elective 2.
      slot('2026-09-01', 'fn', [
        'U21AMP05 - Computer Vision (PE)',
        'U21CSP12 - JavaScript Frameworks (PE)',
        'U21ITP05 - Cyber Security (PE)',
      ]),
      // PE1 basket.
      slot('2026-09-01', 'an', [
        'U21ADP05 - Exploratory Data Analysis and Visualization (PE)',
        'U21AMP03 - Deep Neural Networks (PE)',
        'U21CSP01 - Foundations of Cloud Computing (PE)',
      ]),
      slot(
        '2026-09-02',
        'fn',
        ['U21CAC01 - Graduate Aptitude Test in Engineering I'],
        'Conducted by the respective department.',
      ),
    ],
  },
];

async function main() {
  console.log(`Seeding examSchedules into ${PROJECT_ID} (database "${DATABASE_ID}")…\n`);

  const batch = db.batch();
  for (const { id, ...data } of schedules) {
    batch.set(db.doc(`examSchedules/${id}`), data, { merge: true });
    const papers = data.slots.filter((s) => s.papers.length || s.note).length;
    console.log(`  ${id} — ${data.slots.length} slots, ${papers} with papers`);
  }
  await batch.commit();

  console.log('\nDone.');
  process.exit(0);
}

main().catch((err) => {
  console.error('\nSeeding failed:', err.message);
  process.exit(1);
});
