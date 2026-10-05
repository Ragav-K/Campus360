#!/usr/bin/env node
/**
 * Seeds Campus360 demo data: config/app, campusLocations and pulseUpdates.
 *
 * Writes with the Admin SDK, which bypasses security rules — this is a
 * developer/admin tool, not something the app does.
 *
 *   node tool/seed.js
 *
 * Requires application-default credentials:
 *   gcloud auth application-default login      (or)
 *   GOOGLE_APPLICATION_CREDENTIALS=<service-account.json>
 *
 * Safe to re-run: every document uses a deterministic id and merge:true, so
 * re-seeding refreshes timestamps instead of creating duplicates.
 */

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');

const PROJECT_ID = 'campus360-app';
// NOTE: this project uses a *named* database, not Firestore's "(default)".
const DATABASE_ID = 'default';

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore(DATABASE_ID);

const minutesFromNow = (m) => Timestamp.fromMillis(Date.now() + m * 60 * 1000);
const minutesAgo = (m) => Timestamp.fromMillis(Date.now() - m * 60 * 1000);

const weekdayHours = (open, close) =>
  [1, 2, 3, 4, 5, 6].map((day) => ({ day, open, close }));

const locations = [
  {
    id: 'library-main',
    name: 'Central Library',
    category: 'library',
    building: 'Block C',
    floor: 'Ground & First',
    description: 'Reading halls, reference section and digital catalogue.',
    openHours: weekdayHours('08:30', '20:00'),
    capacity: 200, // countable — appears in the crowd counter dashboard
  },
  {
    id: 'canteen-main',
    name: 'Main Canteen',
    category: 'canteen',
    building: 'Block D',
    floor: 'Ground',
    description: 'Meals, snacks and beverages.',
    openHours: weekdayHours('07:30', '18:30'),
    capacity: 150,
  },
  {
    id: 'dining-hall',
    name: 'Dining Hall',
    category: 'canteen',
    building: 'Block D',
    floor: 'First',
    description: 'Seated dining hall above the main canteen.',
    openHours: weekdayHours('11:30', '15:00'),
    capacity: 180,
  },
  {
    id: 'printshop-central',
    name: 'Central Print Shop',
    category: 'printShop',
    building: 'Block A',
    floor: 'Ground',
    roomCode: 'A-012',
    description: 'Printing, photocopying, spiral binding and lamination.',
    openHours: weekdayHours('09:00', '17:00'),
    capacity: 25,
  },
  {
    id: 'printshop-annexe',
    name: 'Annexe Print Point',
    category: 'printShop',
    building: 'Block E',
    floor: 'First',
    description: 'Smaller print counter near the CSE department.',
    openHours: weekdayHours('09:30', '16:30'),
  },
  {
    id: 'cse-dept',
    name: 'Computer Science Department',
    category: 'department',
    building: 'Block E',
    floor: 'Second',
    description: 'Faculty rooms, HOD office and seminar hall.',
  },
  {
    id: 'lab-cs-1',
    name: 'Programming Lab 1',
    category: 'lab',
    building: 'Block E',
    floor: 'First',
    roomCode: 'E-104',
    description: '60-seat lab used for practical sessions.',
  },
  {
    id: 'auditorium',
    name: 'Main Auditorium',
    category: 'academicBlock',
    building: 'Block B',
    floor: 'Ground',
    description: 'Seats 800. Used for seminars, symposiums and events.',
  },
  {
    id: 'sports-basketball',
    name: 'Basketball Court',
    category: 'sports',
    building: 'Sports Complex',
    description: 'Outdoor full court with floodlights.',
    openHours: weekdayHours('06:00', '20:00'),
  },
  {
    id: 'medical-centre',
    name: 'Medical Centre',
    category: 'medical',
    building: 'Block A',
    floor: 'Ground',
    roomCode: 'A-003',
    description: 'Campus nurse and first aid. Doctor available 10:00–13:00.',
    openHours: weekdayHours('08:00', '17:00'),
  },
  {
    id: 'parking-main',
    name: 'Main Two-Wheeler Parking',
    category: 'parking',
    building: 'Near Gate 1',
    description: 'Covered parking for two-wheelers.',
  },
  {
    id: 'admin-office',
    name: 'Administrative Office',
    category: 'admin',
    building: 'Block A',
    floor: 'First',
    description: 'Admissions, records and general administration.',
    openHours: weekdayHours('09:00', '16:00'),
  },
];

// Crowd status is NOT seeded as free-text updates — it comes from the occupancy
// ingest contract, written by the counter dashboard (and later the ID-card gate
// and camera). These are starting values so the app has something to show
// before anyone taps a button.
//
// Status bands must match dashboard/app.js, which is the authoritative writer.
const statusFor = (ratio) => {
  if (ratio < 0.4) return 'low';
  if (ratio < 0.7) return 'moderate';
  if (ratio < 0.9) return 'high';
  return 'veryHigh';
};

const STATUS_WORD = {
  low: 'quiet',
  moderate: 'moderately busy',
  high: 'busy',
  veryHigh: 'very crowded',
};

// The only countable places. A location is countable purely by having a
// `capacity` — the dashboard and this file both derive the set from that, so
// there is one source of truth rather than two lists to keep in sync.
//
// Counts chosen to span all four status colours for a demo.
const initialCounts = [
  { locationId: 'library-main', count: 48 },        // 24% → low
  { locationId: 'canteen-main', count: 96 },        // 64% → moderate
  { locationId: 'dining-hall', count: 152 },        // 84% → high
  { locationId: 'printshop-central', count: 24 },   // 96% → veryHigh
];

// Print shops. `staffIds` is filled in by tool/setRole.js when an account is
// granted the printShopStaff role, so the security rules can tell which shop a
// counter operator works at.
const printShops = [
  {
    id: 'printshop-central',
    name: 'Central Print Shop',
    locationId: 'printshop-central',
    locationName: 'Block A',
    isOpen: true,
    estimatedWaitMinutes: 10,
    services: { colour: true, duplex: true, paperSizes: ['A4', 'A3'] },
    pricing: { bwPerPage: 1.0, colourPerPage: 5.0, currency: '₹' },
  },
  {
    id: 'printshop-annexe',
    name: 'Annexe Print Point',
    locationId: 'printshop-annexe',
    locationName: 'Block E',
    isOpen: true,
    estimatedWaitMinutes: 5,
    // Deliberately limited: the order form hides colour and duplex for this
    // shop rather than offering options it would have to reject.
    services: { colour: false, duplex: false, paperSizes: ['A4'] },
    pricing: { bwPerPage: 1.5, colourPerPage: null, currency: '₹' },
  },
];

const pulseUpdates = [
  {
    id: 'pulse-printshop-busy',
    title: 'Central Print Shop is busy',
    description: 'Around 10 orders in the queue. Roughly 15 minutes wait.',
    category: 'availability',
    status: 'limited',
    priority: 1,
    locationId: 'printshop-central',
    locationName: 'Central Print Shop',
    createdAt: minutesAgo(20),
    expiresAt: minutesFromNow(60),
  },
  {
    id: 'pulse-basketball-free',
    title: 'Basketball court available',
    description: 'Court is free until the evening practice session at 5 PM.',
    category: 'availability',
    status: 'available',
    priority: 0,
    locationId: 'sports-basketball',
    locationName: 'Basketball Court',
    createdAt: minutesAgo(45),
    expiresAt: minutesFromNow(120),
  },
  {
    id: 'pulse-auditorium-event',
    title: 'Symposium in progress at the Auditorium',
    description: 'Technical symposium until 4 PM. Entry limited to registered participants.',
    category: 'event',
    status: 'occupied',
    priority: 1,
    locationId: 'auditorium',
    locationName: 'Main Auditorium',
    createdAt: minutesAgo(90),
    expiresAt: minutesFromNow(150),
  },
  {
    id: 'pulse-water-notice',
    title: 'Water supply maintenance in Block E',
    description: 'Restrooms on the first floor of Block E are closed for maintenance this afternoon.',
    category: 'notice',
    status: 'warning',
    priority: 2,
    locationId: 'cse-dept',
    locationName: 'Computer Science Department',
    createdAt: minutesAgo(150),
    expiresAt: minutesFromNow(240),
  },
  {
    id: 'pulse-lab-closed',
    title: 'Programming Lab 1 closed for servicing',
    description: 'Systems are being reimaged. The lab reopens tomorrow morning.',
    category: 'availability',
    status: 'closed',
    priority: 1,
    locationId: 'lab-cs-1',
    locationName: 'Programming Lab 1',
    createdAt: minutesAgo(200),
    expiresAt: minutesFromNow(600),
  },
  {
    id: 'pulse-expired-demo',
    title: 'Morning shuttle delayed',
    description: 'This update has already expired and must NOT appear in the app.',
    category: 'notice',
    status: 'information',
    priority: 0,
    locationId: 'parking-main',
    locationName: 'Main Two-Wheeler Parking',
    createdAt: minutesAgo(400),
    expiresAt: minutesAgo(60), // deliberately in the past — verifies expiry filtering
  },
];

async function main() {
  console.log(`Seeding ${PROJECT_ID} (database "${DATABASE_ID}")…\n`);

  await db.doc('config/app').set(
    {
      allowedEmailDomains: ['kpriet.ac.in'],
      // Accounts must use a college address. Guests are exempt — they sign in
      // anonymously and have no email. Enforced for real in firestore.rules.
      requireCollegeEmail: true,
      maxUploadMb: 20,
      functionsEnabled: false, // no Cloud Functions deployed yet
      campusCenter: { lat: 11.0766, lng: 77.1421 }, // KPRIET, from OpenStreetMap
    },
    { merge: true },
  );
  console.log('  config/app');

  let batch = db.batch();
  for (const { id, ...data } of locations) {
    batch.set(
      db.doc(`campusLocations/${id}`),
      {
        ...data,
        isActive: true,
        // merge:true leaves untouched fields alone, so a location that used to
        // be countable would keep its old capacity and stay in the dashboard
        // forever. Delete it explicitly.
        ...(data.capacity === undefined ? { capacity: FieldValue.delete() } : {}),

        // Earlier seeds carried invented coordinates ~15 km from the real
        // campus. Wipe them so the map shows "not recorded yet" rather than a
        // confident pin in the wrong place; the survey screen fills them in.
        ...(data.geo === undefined ? { geo: FieldValue.delete() } : {}),
      },
      { merge: true },
    );
  }
  await batch.commit();

  const countable = locations.filter((l) => l.capacity > 0);
  console.log(`  campusLocations — ${locations.length} documents ` +
    `(${countable.length} countable: ${countable.map((l) => l.name).join(', ')})`);

  batch = db.batch();
  for (const { id, ...data } of printShops) {
    // merge keeps any staffIds already granted by tool/setRole.js.
    batch.set(db.doc(`printShops/${id}`), data, { merge: true });
  }
  await batch.commit();
  console.log(`  printShops — ${printShops.length} documents`);

  batch = db.batch();
  for (const { id, ...data } of pulseUpdates) {
    batch.set(
      db.doc(`pulseUpdates/${id}`),
      {
        ...data,
        imageUrl: null,
        createdBy: 'seed',
        createdByName: 'Campus Office',
        isActive: true,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
  await batch.commit();
  console.log(`  pulseUpdates — ${pulseUpdates.length} documents (1 deliberately expired)`);

  // Crowd documents follow the occupancy ingest contract. Deterministic ids
  // (`crowd-{locationId}`) mean the dashboard updates these in place rather
  // than creating new documents on every tap.
  batch = db.batch();
  for (const { locationId, count } of initialCounts) {
    const location = locations.find((l) => l.id === locationId);
    const capacity = location.capacity;
    const status = statusFor(count / capacity);

    batch.set(
      db.doc(`pulseUpdates/crowd-${locationId}`),
      {
        title: `${location.name} — ${STATUS_WORD[status]}`,
        description: `${count} of about ${capacity} people right now.`,
        category: 'crowd',
        status,
        priority: status === 'veryHigh' ? 2 : 1,
        locationId,
        locationName: location.name,
        imageUrl: null,
        createdBy: 'seed',
        createdByName: 'Campus desk',
        createdAt: minutesAgo(5),
        expiresAt: minutesFromNow(180),
        isActive: true,
        occupancy: {
          mode: 'count',
          source: 'manual',
          count,
          capacity,
          level: null,
          at: FieldValue.serverTimestamp(),
        },
      },
      { merge: true },
    );
  }
  await batch.commit();
  console.log(`  crowd counters — ${initialCounts.length} documents (low → veryHigh)`);

  // Earlier seeds wrote crowd status as free-text updates. They are superseded
  // by the `crowd-*` documents above and would otherwise show as duplicates.
  const legacyIds = ['pulse-library-crowd', 'pulse-canteen-crowd'];
  const legacy = db.batch();
  for (const id of legacyIds) legacy.delete(db.doc(`pulseUpdates/${id}`));
  await legacy.commit();
  console.log(`  removed ${legacyIds.length} superseded crowd documents`);

  // Drop crowd documents for places that are no longer counted, otherwise a
  // location removed from the dashboard keeps showing a frozen count in Pulse
  // forever — worse than showing nothing, because it looks live.
  const allowed = new Set(initialCounts.map((c) => c.locationId));
  const crowdDocs = await db.collection('pulseUpdates').where('category', '==', 'crowd').get();
  const stale = crowdDocs.docs.filter((d) => !allowed.has(d.data().locationId));

  if (stale.length) {
    const cleanup = db.batch();
    for (const doc of stale) cleanup.delete(doc.ref);
    await cleanup.commit();
    console.log(
      `  removed ${stale.length} crowd documents for uncounted places ` +
        `(${stale.map((d) => d.data().locationName || d.id).join(', ')})`,
    );
  }

  console.log('\nDone. Pull to refresh in the app.');
  process.exit(0);
}

main().catch((err) => {
  console.error('\nSeeding failed:', err.message);
  process.exit(1);
});
