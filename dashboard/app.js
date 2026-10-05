// Campus360 — crowd counter dashboard.
//
// Writes the occupancy ingest contract documented in ARCHITECTURE.md: one
// `pulseUpdates/crowd-{locationId}` document per countable location, updated in
// place. The Flutter app already streams that collection, so a tap here shows
// on every student's phone within a second.
//
// This file is today's only writer. The library ID-card feed and the canteen
// camera will write the same document shape with a different `source` (and, for
// the camera, mode "density"), so nothing downstream has to change.

import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js';
import {
  getAuth,
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-auth.js';
import {
  getFirestore,
  collection,
  doc,
  query,
  where,
  onSnapshot,
  runTransaction,
  serverTimestamp,
  updateDoc,
  Timestamp,
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-firestore.js';

const firebaseConfig = {
  apiKey: 'AIzaSyB9yQhQJOsrk9NqXdUfsXYW0-Idifb6sps',
  authDomain: 'campus360-app.firebaseapp.com',
  projectId: 'campus360-app',
  storageBucket: 'campus360-app.firebasestorage.app',
  messagingSenderId: '729205136583',
  appId: '1:729205136583:web:2fb5eead5640119207f2e2',
};

// This project uses a NAMED Firestore database, not "(default)". See SETUP.md.
const DATABASE_ID = 'default';

// Desk operators type a bare username; Firebase Auth needs an email.
const DEFAULT_EMAIL_DOMAIN = 'kpriet.ac.in';

// How long a count stays trustworthy without a fresh tap. Past this the app's
// `isLive` check drops it, so an abandoned desk goes quiet instead of lying.
const FRESHNESS_HOURS = 3;

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app, DATABASE_ID);

// ---------------------------------------------------------------------------
// Status bands — the single place occupancy becomes a status.
//
// Every writer computes `status` before writing and the app only ever reads it,
// so a future camera service (likely Python) never has to reimplement this.
// ---------------------------------------------------------------------------

function statusFor(ratio) {
  if (ratio < 0.4) return 'low';
  if (ratio < 0.7) return 'moderate';
  if (ratio < 0.9) return 'high';
  return 'veryHigh';
}

const STATUS_META = {
  low: { label: 'Quiet', tone: 'good', color: 'var(--good)' },
  moderate: { label: 'Moderate', tone: 'caution', color: 'var(--caution)' },
  high: { label: 'Busy', tone: 'caution', color: 'var(--caution)' },
  veryHigh: { label: 'Very crowded', tone: 'bad', color: 'var(--bad)' },
  closed: { label: 'Closed', tone: 'neutral', color: 'var(--neutral)' },
};

// ---------------------------------------------------------------------------
// Elements
// ---------------------------------------------------------------------------

const el = (id) => document.getElementById(id);
const loginView = el('login-view');
const appView = el('app-view');
const loginForm = el('login-form');
const loginButton = el('login-button');
const loginError = el('login-error');
const appError = el('app-error');
const noPermission = el('no-permission');
const locationsEl = el('locations');
const emptyEl = el('empty');
const connectionEl = el('connection');
const signedInAsEl = el('signed-in-as');

let unsubscribeLocations = null;
let unsubscribeCrowd = null;
let locations = [];
const crowdDocs = new Map(); // locationId -> { count, status, updatedAt }
const pendingWrites = new Set(); // locationId currently being written
let canWrite = false;

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

function friendlyAuthError(code) {
  switch (code) {
    case 'auth/invalid-email':
      return 'That username looks wrong.';
    case 'auth/user-not-found':
    case 'auth/wrong-password':
    case 'auth/invalid-credential':
      return 'Incorrect username or password.';
    case 'auth/too-many-requests':
      return 'Too many attempts. Wait a minute and try again.';
    case 'auth/network-request-failed':
      return "Can't reach the server. Check the connection.";
    default:
      return 'Sign-in failed. Please try again.';
  }
}

loginForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  loginError.hidden = true;

  const raw = el('username').value.trim();
  const password = el('password').value;
  const email = raw.includes('@') ? raw : `${raw}@${DEFAULT_EMAIL_DOMAIN}`;

  loginButton.disabled = true;
  loginButton.textContent = 'Signing in…';
  try {
    await signInWithEmailAndPassword(auth, email, password);
  } catch (err) {
    loginError.textContent = friendlyAuthError(err.code);
    loginError.hidden = false;
  } finally {
    loginButton.disabled = false;
    loginButton.textContent = 'Sign in';
  }
});

el('signout-button').addEventListener('click', () => signOut(auth));

onAuthStateChanged(auth, async (user) => {
  if (!user) {
    teardown();
    loginView.hidden = false;
    appView.hidden = true;
    return;
  }

  loginView.hidden = true;
  appView.hidden = false;
  signedInAsEl.textContent = user.email;

  // Roles live in a custom claim. Reading it here only decides whether to
  // disable the buttons — the security rules are the actual gate.
  const token = await user.getIdTokenResult(true);
  const role = token.claims.role;

  // Must mirror isCounter() in firestore.rules. printShopStaff is included
  // because one person at one counter runs both the crowd counter and the
  // print queue — omitting it silently disables every +/- button.
  canWrite = role === 'crowdCounter' || role === 'printShopStaff' || role === 'admin';
  noPermission.hidden = canWrite;

  start();
});

function teardown() {
  unsubscribeLocations?.();
  unsubscribeCrowd?.();
  unsubscribeOrders?.();
  unsubscribeLocations = null;
  unsubscribeCrowd = null;
  unsubscribeOrders = null;
  locations = [];
  orders = [];
  crowdDocs.clear();
  locationsEl.innerHTML = '';
  ordersEl.innerHTML = '';
}

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

function start() {
  locationsEl.innerHTML = '<div class="skeleton"></div><div class="skeleton"></div>';

  // Only locations with a capacity are countable.
  unsubscribeLocations = onSnapshot(
    query(collection(db, 'campusLocations'), where('isActive', '==', true)),
    (snap) => {
      locations = snap.docs
        .map((d) => ({ id: d.id, ...d.data() }))
        .filter((l) => typeof l.capacity === 'number' && l.capacity > 0)
        .sort((a, b) => a.name.localeCompare(b.name));
      setConnection(true);
      render();
    },
    (err) => showError(`Couldn't load locations: ${err.message}`),
  );

  watchOrders();

  unsubscribeCrowd = onSnapshot(
    query(collection(db, 'pulseUpdates'), where('category', '==', 'crowd')),
    (snap) => {
      crowdDocs.clear();
      snap.docs.forEach((d) => {
        const data = d.data();
        if (data.locationId) crowdDocs.set(data.locationId, data);
      });
      setConnection(true);
      render();
    },
    (err) => showError(`Couldn't load counts: ${err.message}`),
  );
}

function setConnection(online) {
  connectionEl.textContent = online ? 'Live' : 'Offline';
  connectionEl.className = `pill ${online ? 'live' : 'offline'}`;
}

function showError(message) {
  appError.textContent = message;
  appError.hidden = false;
  setConnection(false);
}

/**
 * Applies a delta to a location's count.
 *
 * Runs in a transaction so two desks tapping at the same moment can't overwrite
 * each other — read-modify-write on a shared counter is exactly the case where
 * a plain `set` silently loses increments.
 */
async function adjust(location, delta) {
  if (!canWrite || pendingWrites.has(location.id)) return;

  pendingWrites.add(location.id);
  render();

  const ref = doc(db, 'pulseUpdates', `crowd-${location.id}`);
  const capacity = location.capacity;

  try {
    await runTransaction(db, async (tx) => {
      const snap = await tx.get(ref);
      const current = snap.exists() ? snap.data().occupancy?.count ?? 0 : 0;

      // Clamp at zero — a negative headcount is nonsense. Allow exceeding
      // capacity, because rooms genuinely do overfill and hiding that would
      // misreport reality.
      const next = Math.max(0, current + delta);
      const status = statusFor(next / capacity);

      const payload = {
        title: `${location.name} — ${STATUS_META[status].label.toLowerCase()}`,
        description: `${next} of about ${capacity} people right now.`,
        category: 'crowd',
        status,
        priority: status === 'veryHigh' ? 2 : 1,
        locationId: location.id,
        locationName: location.name,
        imageUrl: null,
        createdBy: auth.currentUser?.uid ?? 'counter',
        createdByName: 'Campus desk',
        isActive: true,
        expiresAt: Timestamp.fromMillis(Date.now() + FRESHNESS_HOURS * 3600 * 1000),
        occupancy: {
          mode: 'count',
          source: 'manual',
          count: next,
          capacity,
          level: null,
          at: serverTimestamp(),
        },
      };

      if (snap.exists()) {
        tx.update(ref, payload);
      } else {
        tx.set(ref, { ...payload, createdAt: serverTimestamp() });
      }
    });
    appError.hidden = true;
  } catch (err) {
    showError(
      err.code === 'permission-denied'
        ? "This account isn't allowed to change counts."
        : `Couldn't save that change: ${err.message}`,
    );
  } finally {
    pendingWrites.delete(location.id);
    render();
  }
}

async function reset(location) {
  const current = crowdDocs.get(location.id)?.occupancy?.count ?? 0;
  if (current === 0) return;
  if (!confirm(`Reset ${location.name} to zero?`)) return;
  await adjust(location, -current);
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

function relativeTime(ts) {
  if (!ts?.toMillis) return null; // caller renders "Not counted yet"
  const mins = Math.floor((Date.now() - ts.toMillis()) / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins} min ago`;
  const hours = Math.floor(mins / 60);
  return hours < 24 ? `${hours} h ago` : `${Math.floor(hours / 24)} d ago`;
}

function updatedLabel(ts) {
  const relative = relativeTime(ts);
  return relative ? `Updated ${relative}` : 'Not counted yet';
}

function render() {
  if (!locations.length) {
    locationsEl.innerHTML = '';
    emptyEl.hidden = false;
    return;
  }
  emptyEl.hidden = true;

  locationsEl.innerHTML = locations
    .map((location) => {
      const data = crowdDocs.get(location.id);
      const count = data?.occupancy?.count ?? 0;
      const capacity = location.capacity;
      const ratio = capacity ? count / capacity : 0;
      const status = data?.status && STATUS_META[data.status] ? data.status : statusFor(ratio);
      const meta = STATUS_META[status];
      const busy = pendingWrites.has(location.id);
      const disabled = !canWrite || busy;

      return `
        <article class="loc">
          <div class="loc-head">
            <div>
              <div class="loc-name">${escapeHtml(location.name)}</div>
              <div class="count-sub">${escapeHtml(location.building || '')}</div>
            </div>
            <span class="status ${meta.tone}">${meta.label}</span>
          </div>

          <div class="counter">
            <button class="step minus" data-id="${location.id}" data-delta="-1"
                    ${disabled || count === 0 ? 'disabled' : ''}
                    aria-label="One person left ${escapeHtml(location.name)}">−</button>
            <div>
              <div class="count">${count}</div>
              <div class="count-sub">of about ${capacity}</div>
            </div>
            <button class="step plus" data-id="${location.id}" data-delta="1" ${disabled ? 'disabled' : ''}
                    aria-label="One person entered ${escapeHtml(location.name)}">+</button>
          </div>

          <div class="bar">
            <span style="width:${Math.min(100, ratio * 100).toFixed(1)}%;background:${meta.color}"></span>
          </div>

          <div class="loc-foot">
            <span>${busy ? 'Saving…' : updatedLabel(data?.occupancy?.at)}</span>
            <button class="link-btn" data-reset="${location.id}" ${disabled || count === 0 ? 'disabled' : ''}>
              Reset
            </button>
          </div>
        </article>`;
    })
    .join('');
}

function escapeHtml(value) {
  return String(value).replace(
    /[&<>"']/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c],
  );
}

// Delegated so the buttons survive every re-render.
locationsEl.addEventListener('click', (event) => {
  const step = event.target.closest('.step');
  if (step) {
    const location = locations.find((l) => l.id === step.dataset.id);
    if (location) adjust(location, Number(step.dataset.delta));
    return;
  }

  const resetButton = event.target.closest('[data-reset]');
  if (resetButton) {
    const location = locations.find((l) => l.id === resetButton.dataset.reset);
    if (location) reset(location);
  }
});

// ---------------------------------------------------------------------------
// Print queue
//
// Orders are sorted by the deadline the student chose, soonest first, so a job
// needed in 20 minutes is printed before one placed earlier but needed
// tomorrow. That ordering is the whole point of letting students schedule.
// ---------------------------------------------------------------------------

const ordersEl = el('orders');
const ordersEmptyEl = el('orders-empty');
const queueSummaryEl = el('queue-summary');
const queueBadgeEl = el('queue-badge');

let orders = [];
let unsubscribeOrders = null;
let queueFilter = 'active';
const busyOrders = new Set();

const ACTIVE_STATUSES = ['received', 'accepted', 'printing'];
const STATUS_LABEL = {
  received: 'New',
  accepted: 'Accepted',
  printing: 'Printing',
  readyForPickup: 'Ready',
  collected: 'Collected',
  rejected: 'Rejected',
  cancelled: 'Cancelled',
};

/** Mirrors PrintOrder.queueSortKey in the Flutter app — they must agree. */
function queueSortKey(order) {
  const needed = order.neededBy?.toMillis?.();
  if (!needed) return 4000000000 + Math.floor((order.createdAt?.toMillis?.() ?? 0) / 1000);
  return Math.floor(needed / 1000);
}

function deadlineState(order) {
  const needed = order.neededBy?.toMillis?.();
  // `prefix: false` so the caller renders "No deadline", not "Needed No rush".
  if (!needed) return { label: 'No deadline', className: '', prefix: false };

  const minutes = Math.round((needed - Date.now()) / 60000);
  const done = order.status === 'readyForPickup' || order.status === 'collected';

  if (minutes < 0 && !done) {
    const late = Math.abs(minutes);
    return {
      label: late < 60 ? `${late} min late` : `${Math.floor(late / 60)} h late`,
      className: 'overdue',
    };
  }
  if (minutes <= 30 && !done) return { label: `in ${Math.max(minutes, 0)} min`, className: 'urgent' };
  if (minutes < 60) return { label: `in ${minutes} min`, className: '' };
  if (minutes < 60 * 24) return { label: `in ${Math.floor(minutes / 60)} h`, className: '' };
  return { label: new Date(needed).toLocaleString(), className: '' };
}

function watchOrders() {
  unsubscribeOrders = onSnapshot(
    collection(db, 'printOrders'),
    (snap) => {
      orders = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      renderOrders();
      setConnection(true);
    },
    (err) => showError(`Couldn't load print orders: ${err.message}`),
  );
}

async function setOrderStatus(order, status, extra = {}) {
  if (busyOrders.has(order.id)) return;
  busyOrders.add(order.id);
  renderOrders();

  try {
    await updateDoc(doc(db, 'printOrders', order.id), {
      status,
      statusChangedAt: serverTimestamp(),
      ...extra,
    });
    appError.hidden = true;
  } catch (err) {
    showError(
      err.code === 'permission-denied'
        ? "This account isn't allowed to update print orders."
        : `Couldn't update the order: ${err.message}`,
    );
  } finally {
    busyOrders.delete(order.id);
    renderOrders();
  }
}

function rejectOrder(order) {
  const reason = prompt(`Why can't order #${order.orderNumber} be printed?`, '');
  if (reason === null) return; // cancelled
  const trimmed = reason.trim();
  if (!trimmed) {
    alert('Please give a reason — the student sees it.');
    return;
  }
  setOrderStatus(order, 'rejected', { rejectionReason: trimmed });
}

function nextAction(order) {
  switch (order.status) {
    case 'received':
      return { label: 'Accept', status: 'accepted' };
    case 'accepted':
      return { label: 'Start printing', status: 'printing' };
    case 'printing':
      return { label: 'Mark ready', status: 'readyForPickup' };
    case 'readyForPickup':
      return { label: 'Mark collected', status: 'collected' };
    default:
      return null;
  }
}

function visibleOrders() {
  const filtered = orders.filter((o) => {
    if (queueFilter === 'active') return ACTIVE_STATUSES.includes(o.status);
    if (queueFilter === 'ready') return o.status === 'readyForPickup';
    return ['collected', 'rejected', 'cancelled'].includes(o.status);
  });
  return filtered.sort((a, b) => queueSortKey(a) - queueSortKey(b));
}

function renderOrders() {
  const list = visibleOrders();

  const active = orders.filter((o) => ACTIVE_STATUSES.includes(o.status));
  const overdue = active.filter((o) => deadlineState(o).className === 'overdue').length;

  queueSummaryEl.textContent = active.length
    ? `${active.length} in the queue${overdue ? ` · ${overdue} overdue` : ''}`
    : 'Queue is clear';

  queueBadgeEl.textContent = String(active.length);
  queueBadgeEl.hidden = active.length === 0;

  ordersEmptyEl.hidden = list.length > 0;

  ordersEl.innerHTML = list
    .map((order) => {
      const deadline = deadlineState(order);
      const action = nextAction(order);
      const busy = busyOrders.has(order.id);
      const settings = order.settings ?? {};
      const document_ = order.document ?? {};

      const rowClass = [
        'order',
        deadline.className,
        order.status === 'readyForPickup' ? 'ready' : '',
      ]
        .filter(Boolean)
        .join(' ');

      const meta = [
        escapeHtml(order.studentName || 'Unknown student'),
        `${settings.copies ?? 1} × ${settings.colour === 'colour' ? 'Colour' : 'B&W'}`,
        settings.sides === 'double' ? '2-sided' : '1-sided',
        escapeHtml(settings.paper ?? 'A4'),
        settings.pageRange ? `pages ${escapeHtml(settings.pageRange)}` : '',
      ]
        .filter(Boolean)
        .join(' · ');

      return `
        <article class="${rowClass}">
          <div>
            <div class="order-title">
              <span>${escapeHtml(document_.fileName || 'document')}</span>
              <span class="order-num">#${order.orderNumber ?? '—'}</span>
              <span class="status ${toneFor(order.status)}">${STATUS_LABEL[order.status] ?? order.status}</span>
            </div>
            <div class="order-meta">${meta}</div>
            ${settings.note ? `<div class="order-meta">Note: ${escapeHtml(settings.note)}</div>` : ''}
            <div class="order-meta">
              <span class="deadline ${deadline.className}">${
                deadline.prefix === false ? '' : 'Needed '
              }${deadline.label}</span>
              ${
                document_.downloadUrl
                  ? ` · <a class="doc-link" href="${escapeHtml(document_.downloadUrl)}"
                         target="_blank" rel="noopener">Open document ↗</a>`
                  : ' · <span>document unavailable</span>'
              }
            </div>
          </div>
          <div class="order-actions">
            ${
              action
                ? `<button class="btn primary small" data-order="${order.id}"
                     data-status="${action.status}" ${busy ? 'disabled' : ''}>
                     ${busy ? 'Saving…' : action.label}
                   </button>`
                : ''
            }
            ${
              ACTIVE_STATUSES.includes(order.status)
                ? `<button class="btn ghost small" data-reject="${order.id}" ${busy ? 'disabled' : ''}>
                     Reject
                   </button>`
                : ''
            }
          </div>
        </article>`;
    })
    .join('');
}

function toneFor(status) {
  if (status === 'readyForPickup' || status === 'collected') return 'good';
  if (status === 'rejected') return 'bad';
  if (status === 'cancelled') return 'neutral';
  if (status === 'printing' || status === 'accepted') return 'caution';
  return 'caution';
}

ordersEl.addEventListener('click', (event) => {
  const advance = event.target.closest('[data-status]');
  if (advance) {
    const order = orders.find((o) => o.id === advance.dataset.order);
    if (order) setOrderStatus(order, advance.dataset.status);
    return;
  }

  const reject = event.target.closest('[data-reject]');
  if (reject) {
    const order = orders.find((o) => o.id === reject.dataset.reject);
    if (order) rejectOrder(order);
  }
});

el('queue-filters').addEventListener('click', (event) => {
  const button = event.target.closest('[data-filter]');
  if (!button) return;
  queueFilter = button.dataset.filter;
  [...el('queue-filters').children].forEach((b) => b.classList.toggle('active', b === button));
  renderOrders();
});

// ---- tabs ----

document.querySelector('.tabs').addEventListener('click', (event) => {
  const tab = event.target.closest('.tab');
  if (!tab) return;

  document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t === tab));
  el('panel-crowd').hidden = tab.dataset.tab !== 'crowd';
  el('panel-print').hidden = tab.dataset.tab !== 'print';
});

// Keep relative times ("in 20 min", "12 min late") and "updated N min ago"
// honest without re-reading Firestore.
setInterval(() => {
  if (appView.hidden) return;
  if (locations.length) render();
  if (orders.length) renderOrders();
}, 60000);

window.addEventListener('online', () => setConnection(true));
window.addEventListener('offline', () => setConnection(false));
