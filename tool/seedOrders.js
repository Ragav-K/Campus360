#!/usr/bin/env node
/**
 * Seeds a handful of DEMO print orders so the counter queue can be exercised
 * before real students start placing them.
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/campus360-admin.json \
 *     node tool/seedOrders.js [studentEmail]
 *
 * Kept out of tool/seed.js on purpose: orders are real user data, and the main
 * seed should not manufacture them every time it runs.
 *
 * Deadlines are deliberately staggered so the queue's sort order is visible:
 * the order placed *earliest* is needed *last*, so a correct queue does not
 * simply show them in creation order.
 *
 * Delete them again with:  node tool/seedOrders.js --clear
 */

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');

const PROJECT_ID = 'campus360-app';
const DATABASE_ID = 'default';

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const auth = getAuth();
const db = getFirestore(DATABASE_ID);

const minutesFromNow = (m) => Timestamp.fromMillis(Date.now() + m * 60 * 1000);
const minutesAgo = (m) => Timestamp.fromMillis(Date.now() - m * 60 * 1000);

const demoOrders = [
  {
    id: 'demo-order-overdue',
    fileName: 'sample-unit3-notes.pdf',
    placedMinutesAgo: 95,
    neededInMinutes: -20, // already late — must sort first
    status: 'received',
    settings: { copies: 1, colour: 'bw', sides: 'single', paper: 'A4', note: '' },
    pages: 12,
  },
  {
    id: 'demo-order-urgent',
    fileName: 'sample-lab-record.pdf',
    placedMinutesAgo: 10,
    neededInMinutes: 25, // soon — sorts above older work
    status: 'received',
    settings: { copies: 2, colour: 'bw', sides: 'double', paper: 'A4', note: 'Staple please' },
    pages: 24,
  },
  {
    id: 'demo-order-printing',
    fileName: 'sample-poster.png',
    placedMinutesAgo: 30,
    neededInMinutes: 90,
    status: 'printing',
    settings: { copies: 1, colour: 'colour', sides: 'single', paper: 'A3', note: '' },
    pages: 1,
  },
  {
    id: 'demo-order-relaxed',
    // Placed first but needed last: proves the queue sorts by deadline, not
    // by arrival.
    fileName: 'sample-assignment.pdf',
    placedMinutesAgo: 180,
    neededInMinutes: 60 * 20,
    status: 'received',
    settings: { copies: 3, colour: 'bw', sides: 'double', paper: 'A4', note: '' },
    pages: 8,
  },
  {
    id: 'demo-order-norush',
    fileName: 'sample-reference.pdf',
    placedMinutesAgo: 240,
    neededInMinutes: null, // no deadline — sorts last
    status: 'received',
    settings: { copies: 1, colour: 'bw', sides: 'single', paper: 'A4', note: '' },
    pages: 40,
  },
];

async function clear() {
  const batch = db.batch();
  for (const order of demoOrders) batch.delete(db.doc(`printOrders/${order.id}`));
  await batch.commit();
  console.log(`Removed ${demoOrders.length} demo orders.`);
}

async function main() {
  if (process.argv.includes('--clear')) return clear().then(() => process.exit(0));

  const email = process.argv[2] || '24cs157@kpriet.ac.in';
  let student;
  try {
    student = await auth.getUserByEmail(email);
  } catch {
    console.error(`No account for ${email}. Pass a different address as an argument.`);
    process.exit(1);
  }

  console.log(`Seeding demo orders for ${email}…\n`);

  const batch = db.batch();
  for (const order of demoOrders) {
    const rate = order.settings.colour === 'colour' ? 5.0 : 1.0;

    batch.set(db.doc(`printOrders/${order.id}`), {
      orderNumber: 1000 + demoOrders.indexOf(order),
      studentId: student.uid,
      studentName: student.displayName || email.split('@')[0],
      studentPhone: null,
      shopId: 'printshop-central',
      shopName: 'Central Print Shop',
      document: {
        fileName: order.fileName,
        storagePath: `printDocs/${student.uid}/${order.id}/${order.fileName}`,
        // No real file behind these; the dashboard shows "document
        // unavailable" rather than a link that 404s.
        downloadUrl: '',
        mimeType: order.fileName.endsWith('.png') ? 'image/png' : 'application/pdf',
        sizeBytes: 250000,
        pageCount: order.pages,
      },
      settings: order.settings,
      status: order.status,
      neededBy: order.neededInMinutes === null ? null : minutesFromNow(order.neededInMinutes),
      estimatedCost: order.pages * order.settings.copies * rate,
      createdAt: minutesAgo(order.placedMinutesAgo),
      statusChangedAt: minutesAgo(order.placedMinutesAgo),
    });

    const needed =
      order.neededInMinutes === null
        ? 'no deadline'
        : order.neededInMinutes < 0
          ? `${Math.abs(order.neededInMinutes)} min OVERDUE`
          : `needed in ${order.neededInMinutes} min`;
    console.log(`  ${order.fileName.padEnd(28)} ${needed}`);
  }

  await batch.commit();
  console.log('\nDone. Expected queue order: overdue → urgent → printing → relaxed → no deadline.');
  process.exit(0);
}

main().catch((err) => {
  console.error('\nFailed:', err.message);
  process.exit(1);
});
