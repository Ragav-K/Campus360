#!/usr/bin/env node
/**
 * Grants a Campus360 role to an account, creating the account if it doesn't exist.
 *
 *   DESK_ACCOUNT_PASSWORD=<strong-password> node tool/setRole.js
 *                                                        # provisions the desk counter account
 *   node tool/setRole.js someone@kpriet.ac.in admin
 *   node tool/setRole.js someone@kpriet.ac.in crowdCounter
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS to point at the admin key, e.g.
 *   GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/campus360-admin.json node tool/setRole.js
 *
 * Roles are written to BOTH places, per ARCHITECTURE.md §6:
 *   - a custom claim  -> what security rules actually trust
 *   - users/{uid}.role -> what the app reads for UI
 * Writing only one leaves the app and the rules disagreeing.
 */

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const PROJECT_ID = 'campus360-app';
const DATABASE_ID = 'default'; // named database — see SETUP.md

const VALID_ROLES = ['student', 'crowdCounter', 'printShopStaff', 'admin'];

// The shared desk account used by the crowd counter dashboard.
// The counter dashboard runs both the crowd counter and the print queue, so
// the desk account needs printShopStaff — firestore.rules treats that role as
// a counter operator too.
const DESK_ACCOUNT = {
  email: 'kpriet@kpriet.ac.in',
  password: process.env.DESK_ACCOUNT_PASSWORD,
  displayName: 'Campus Desk',
  role: 'printShopStaff',
};

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const auth = getAuth();
const db = getFirestore(DATABASE_ID);

async function upsertUser({ email, password, displayName }) {
  try {
    const existing = await auth.getUserByEmail(email);
    if (password) {
      await auth.updateUser(existing.uid, { password });
    }
    return { user: existing, created: false };
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
    const user = await auth.createUser({
      email,
      password,
      displayName,
      emailVerified: true, // a desk account has no inbox to verify from
    });
    return { user, created: true };
  }
}

async function main() {
  const [emailArg, roleArg] = process.argv.slice(2);

  const target = emailArg
    ? { email: emailArg, password: null, displayName: null, role: roleArg || 'crowdCounter' }
    : DESK_ACCOUNT;

  if (!emailArg && !target.password) {
    console.error('Set DESK_ACCOUNT_PASSWORD before provisioning the shared desk account.');
    process.exit(1);
  }

  if (!VALID_ROLES.includes(target.role)) {
    console.error(`Unknown role "${target.role}". Valid roles: ${VALID_ROLES.join(', ')}`);
    process.exit(1);
  }

  const { user, created } = await upsertUser(target);
  console.log(`${created ? 'Created' : 'Found'} account ${target.email} (${user.uid})`);

  // The claim is the security boundary; rules read request.auth.token.role.
  await auth.setCustomUserClaims(user.uid, { role: target.role });

  await db.doc(`users/${user.uid}`).set(
    {
      uid: user.uid,
      email: target.email,
      displayName: target.displayName || user.displayName || target.email.split('@')[0],
      role: target.role,
      disabled: false,
      createdAt: FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  // Print shop staff must appear in the shop's staffIds, because that is what
  // firestore.rules checks before letting them touch an order. Granting the
  // role without this leaves the account able to sign in and see nothing.
  if (target.role === 'printShopStaff') {
    const shops = await db.collection('printShops').get();
    if (shops.empty) {
      console.warn('  ! No printShops exist yet — run tool/seed.js, then re-run this.');
    }
    for (const shop of shops.docs) {
      await shop.ref.set({ staffIds: FieldValue.arrayUnion(user.uid) }, { merge: true });
    }
    console.log(`  added to ${shops.size} print shop(s) as staff`);
  }

  // Invalidate existing ID tokens so the new claim takes effect on next refresh
  // rather than up to an hour later.
  await auth.revokeRefreshTokens(user.uid);

  console.log(`Role "${target.role}" granted (custom claim + users/${user.uid}.role).`);
  if (target.password) {
    console.log(`Sign in at the dashboard with: ${target.email.split('@')[0]} / ${target.password}`);
  }
  console.log('If that account is already signed in somewhere, sign out and back in.');
  process.exit(0);
}

main().catch((err) => {
  console.error('\nFailed:', err.message);
  process.exit(1);
});
