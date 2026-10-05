#!/usr/bin/env node
/**
 * Attacks the Lost & Found security rules with two real student accounts.
 *
 * Rules that are only read, never exercised, are wishful thinking — this proves
 * each denial actually happens against the deployed rules.
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/campus360-admin.json \
 *     node tool/testLostFoundRules.js
 *
 * Creates two throwaway accounts, runs the checks, deletes everything.
 */

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

const PROJECT_ID = 'campus360-app';
const DATABASE_ID = 'default';
const API_KEY = 'AIzaSyDmizu_Xw6vL8gGEW0jgVYFDdMnsczddCY';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/${DATABASE_ID}/documents`;

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const auth = getAuth();
const db = getFirestore(DATABASE_ID);

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

async function idTokenFor(uid, email) {
  try {
    await auth.getUser(uid);
  } catch {
    await auth.createUser({ uid, email, password: 'test123456', emailVerified: true });
  }
  await auth.setCustomUserClaims(uid, { role: 'student' });
  await db.doc(`users/${uid}`).set(
    { uid, email, displayName: uid, role: 'student', disabled: false },
    { merge: true },
  );

  // Password sign-in rather than a custom token: minting custom tokens needs
  // the IAM Credentials API, which is not enabled on this project. Claims are
  // set above, so the freshly issued ID token carries them either way.
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: 'test123456', returnSecureToken: true }),
    },
  );
  const body = await res.json();
  if (!body.idToken) throw new Error(`token exchange failed: ${JSON.stringify(body)}`);
  return body.idToken;
}

const req = (token, method, path, body) =>
  fetch(`${BASE}/${path}`, {
    method,
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });

const str = (v) => ({ stringValue: v });

async function main() {
  console.log('Signing in two students…\n');
  const alice = await idTokenFor('rules-test-alice', 'rules-test-alice@kpriet.ac.in');
  const bob = await idTokenFor('rules-test-bob', 'rules-test-bob@kpriet.ac.in');

  const lostId = `rules-test-lost-${Date.now()}`;
  const foundId = `rules-test-found-${Date.now()}`;
  const claimId = `rules-test-claim-${Date.now()}`;

  console.log('Lost items');

  let r = await req(alice, 'PATCH', `lostItems/${lostId}`, {
    fields: {
      ownerId: str('rules-test-alice'),
      ownerName: str('Alice'),
      itemName: str('Black leather wallet'),
      category: str('wallet'),
      status: str('active'),
    },
  });
  check('Alice can report a lost item', r.status === 200, `(${r.status})`);

  r = await req(bob, 'GET', `lostItems/${lostId}`);
  check('Bob can browse it — recognising items is the feature', r.status === 200, `(${r.status})`);

  r = await req(bob, 'PATCH', `lostItems/${lostId}?updateMask.fieldPaths=itemName`, {
    fields: { itemName: str('hijacked') },
  });
  check("Bob CANNOT edit Alice's report", r.status === 403, `(expected 403, got ${r.status})`);

  r = await req(bob, 'DELETE', `lostItems/${lostId}`);
  check("Bob CANNOT delete Alice's report", r.status === 403, `(expected 403, got ${r.status})`);

  // Someone posting a report in another student's name.
  r = await req(bob, 'PATCH', `lostItems/rules-test-forged-${Date.now()}`, {
    fields: {
      ownerId: str('rules-test-alice'),
      itemName: str('forged'),
      status: str('active'),
    },
  });
  check('Bob CANNOT post a report as Alice', r.status === 403, `(expected 403, got ${r.status})`);

  // A report that starts life already resolved would skip the whole flow.
  r = await req(alice, 'PATCH', `lostItems/rules-test-status-${Date.now()}`, {
    fields: {
      ownerId: str('rules-test-alice'),
      itemName: str('sneaky'),
      status: str('resolved'),
    },
  });
  check('A report cannot be created already resolved', r.status === 403, `(expected 403, got ${r.status})`);

  console.log('\nThe ownership secret');

  r = await req(alice, 'PATCH', `lostItems/${lostId}/private/secret`, {
    fields: { identifyingDetails: str('Torn photo of a dog inside') },
  });
  check('Alice can store her identifying detail', r.status === 200, `(${r.status})`);

  r = await req(alice, 'GET', `lostItems/${lostId}/private/secret`);
  check('Alice can read her own secret', r.status === 200, `(${r.status})`);

  r = await req(bob, 'GET', `lostItems/${lostId}/private/secret`);
  check('Bob CANNOT read the secret — this is the whole point', r.status === 403, `(expected 403, got ${r.status})`);

  console.log('\nFound items and claims');

  r = await req(bob, 'PATCH', `foundItems/${foundId}`, {
    fields: {
      finderId: str('rules-test-bob'),
      finderName: str('Bob'),
      itemName: str('Black wallet'),
      category: str('wallet'),
      status: str('active'),
    },
  });
  check('Bob can report a found item', r.status === 200, `(${r.status})`);

  r = await req(bob, 'PATCH', `claims/rules-test-selfclaim-${Date.now()}`, {
    fields: {
      foundItemId: str(foundId),
      claimantId: str('rules-test-bob'),
      finderId: str('rules-test-bob'),
      status: str('pending'),
    },
  });
  check('Bob CANNOT claim his own find', r.status === 403, `(expected 403, got ${r.status})`);

  r = await req(alice, 'PATCH', `claims/${claimId}`, {
    fields: {
      foundItemId: str(foundId),
      claimantId: str('rules-test-alice'),
      claimantName: str('Alice'),
      finderId: str('rules-test-bob'),
      itemName: str('Black wallet'),
      proof: str('It has a torn photo of a dog inside'),
      status: str('pending'),
    },
  });
  check('Alice can claim it, with proof', r.status === 200, `(${r.status})`);

  r = await req(bob, 'GET', `claims/${claimId}`);
  check('Bob (the finder) can read the claim to judge it', r.status === 200, `(${r.status})`);

  // A third student must not be able to read someone's proof of ownership —
  // it is precisely the answer needed to steal the item.
  const mallory = await idTokenFor('rules-test-mallory', 'rules-test-mallory@kpriet.ac.in');
  r = await req(mallory, 'GET', `claims/${claimId}`);
  check('An outsider CANNOT read the claim proof', r.status === 403, `(expected 403, got ${r.status})`);

  r = await req(mallory, 'PATCH', `claims/${claimId}?updateMask.fieldPaths=status`, {
    fields: { status: str('approved') },
  });
  check('An outsider CANNOT approve a claim', r.status === 403, `(expected 403, got ${r.status})`);

  console.log('\nCleaning up…');
  for (const p of [`lostItems/${lostId}/private/secret`, `lostItems/${lostId}`, `foundItems/${foundId}`, `claims/${claimId}`]) {
    await db.doc(p).delete().catch(() => {});
  }
  const stale = await db.collection('lostItems').where('ownerId', 'in', ['rules-test-alice', 'rules-test-bob']).get();
  for (const d of stale.docs) await d.ref.delete();
  for (const uid of ['rules-test-alice', 'rules-test-bob', 'rules-test-mallory']) {
    await auth.deleteUser(uid).catch(() => {});
    await db.doc(`users/${uid}`).delete().catch(() => {});
  }

  console.log(`\n${pass} passed, ${fail} failed.`);
  process.exit(fail === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error('\nFailed:', e.message);
  process.exit(1);
});
