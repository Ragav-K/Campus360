// Campus360 — crowd counter & desk manager dashboard.

import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js';
import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-auth.js';
import {
  Timestamp,
  addDoc,
  collection,
  deleteDoc,
  doc,
  getFirestore,
  onSnapshot,
  query,
  runTransaction,
  serverTimestamp,
  updateDoc,
  where,
} from 'https://www.gstatic.com/firebasejs/10.13.2/firebase-firestore.js';

const firebaseConfig = {
  apiKey: 'AIzaSyB9yQhQJOsrk9NqXdUfsXYW0-Idifb6sps',
  authDomain: 'campus360-app.firebaseapp.com',
  projectId: 'campus360-app',
  storageBucket: 'campus360-app.firebasestorage.app',
  messagingSenderId: '729205136583',
  appId: '1:729205136583:web:2fb5eead5640119207f2e2',
};

const DATABASE_ID = 'default';
const DEFAULT_EMAIL_DOMAIN = 'kpriet.ac.in';
const FRESHNESS_HOURS = 3;

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
// The modular API's second argument is what actually selects a named database.
// The old compat call ignored the argument and silently targeted `(default)`.
const db = getFirestore(app, DATABASE_ID);

function statusFor(ratio) {
  if (ratio < 0.4) return 'low';
  if (ratio < 0.7) return 'moderate';
  if (ratio < 0.9) return 'high';
  return 'veryHigh';
}

function clampCount(count, capacity) {
  const safeCount = Number.isFinite(Number(count)) ? Number(count) : 0;
  return Math.min(Math.max(0, safeCount), capacity);
}

const STATUS_META = {
  low: { label: 'Quiet', tone: 'good', color: 'var(--good)' },
  moderate: { label: 'Moderate', tone: 'caution', color: 'var(--caution)' },
  high: { label: 'Busy', tone: 'caution', color: 'var(--caution)' },
  veryHigh: { label: 'Very crowded', tone: 'bad', color: 'var(--bad)' },
  closed: { label: 'Closed', tone: 'neutral', color: 'var(--neutral)' },
};

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

// Events & Alerts elements
const eventsEl = el('events-list');
const eventsEmptyEl = el('events-empty');
const eventsSummaryEl = el('events-summary');
const eventsBadgeEl = el('events-badge');
const eventFormCard = el('event-form-card');
const btnToggleEventForm = el('btn-toggle-event-form');
const btnCloseEventForm = el('btn-close-event-form');
const btnCancelEvent = el('btn-cancel-event');
const createEventForm = el('create-event-form');
const eventFormError = el('event-form-error');
const eventLocationSelect = el('event-location');
const btnSubmitEvent = el('btn-submit-event');

const DEFAULT_LOCATIONS = [
  { id: 'library-main', name: 'Central Library', building: 'Block C', capacity: 200 },
  { id: 'printshop-central', name: 'Central Print Shop', building: 'Block A', capacity: 25 },
  { id: 'dining-hall', name: 'Dining Hall', building: 'Block D', capacity: 180 },
  { id: 'canteen-main', name: 'Main Canteen', building: 'Block D', capacity: 150 },
];

const INITIAL_CROWD = [
  { locationId: 'library-main', count: 48, status: 'low' },
  { locationId: 'printshop-central', count: 24, status: 'veryHigh' },
  { locationId: 'dining-hall', count: 152, status: 'high' },
  { locationId: 'canteen-main', count: 96, status: 'moderate' },
];

let unsubscribeLocations = null;
let unsubscribeCrowd = null;
let unsubscribeOrders = null;
let unsubscribeEvents = null;
let locations = [...DEFAULT_LOCATIONS];
let orders = [];
let events = [];
let queueFilter = 'active';
let eventCategoryFilter = 'all';
const busyOrders = new Set();
const busyEvents = new Set();
const crowdDocs = new Map();
const pendingWrites = new Set();
let canWrite = true;

function initFallbackCounts() {
  INITIAL_CROWD.forEach((item) => {
    if (!crowdDocs.has(item.locationId)) {
      const loc = DEFAULT_LOCATIONS.find((l) => l.id === item.locationId);
      crowdDocs.set(item.locationId, {
        status: item.status,
        occupancy: { count: item.count, capacity: loc ? loc.capacity : 100, at: null },
      });
    }
  });
}
initFallbackCounts();

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

function friendlyAuthError(code, message) {
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
      return message ? `Sign-in failed: ${message}` : 'Sign-in failed. Please try again.';
  }
}

if (loginForm) {
  loginForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (loginError) loginError.hidden = true;

    const raw = el('username').value.trim();
    const password = el('password').value;
    const email = raw.includes('@') ? raw : `${raw}@${DEFAULT_EMAIL_DOMAIN}`;

    if (loginButton) {
      loginButton.disabled = true;
      loginButton.textContent = 'Signing in…';
    }

    try {
      if (!auth) throw new Error('Firebase Auth not initialized.');
      await signInWithEmailAndPassword(auth, email, password);
    } catch (err) {
      console.error('Sign in error:', err);
      if (loginError) {
        loginError.textContent = friendlyAuthError(err.code, err.message);
        loginError.hidden = false;
      }
    } finally {
      if (loginButton) {
        loginButton.disabled = false;
        loginButton.textContent = 'Sign in';
      }
    }
  });
}

const signoutBtn = el('signout-button');
if (signoutBtn) {
  signoutBtn.addEventListener('click', () => auth && signOut(auth));
}

if (auth) {
  onAuthStateChanged(auth, async (user) => {
    if (!user) {
      teardown();
      if (loginView) loginView.hidden = false;
      return;
    }

    if (loginView) loginView.hidden = true;
    if (appView) appView.hidden = false;
    if (signedInAsEl) signedInAsEl.textContent = user.email;

    try {
      const token = await user.getIdTokenResult(true);
      const role = token?.claims?.role;
      canWrite = role === 'crowdCounter' || role === 'printShopStaff' || role === 'admin' || !role;
      if (noPermission) noPermission.hidden = canWrite;
    } catch (err) {
      console.warn('Could not read token claims:', err);
      canWrite = true;
      if (noPermission) noPermission.hidden = true;
    }

    start();
  });
}

function teardown() {
  unsubscribeLocations?.();
  unsubscribeCrowd?.();
  unsubscribeOrders?.();
  unsubscribeEvents?.();
  unsubscribeLocations = null;
  unsubscribeCrowd = null;
  unsubscribeOrders = null;
  unsubscribeEvents = null;
  locations = [...DEFAULT_LOCATIONS];
  orders = [];
  events = [];
  crowdDocs.clear();
  initFallbackCounts();
  if (ordersEl) ordersEl.innerHTML = '';
  if (eventsEl) eventsEl.innerHTML = '';
  render();
}

function updateLocationSelectOptions() {
  if (!eventLocationSelect) return;
  const currentVal = eventLocationSelect.value;
  eventLocationSelect.innerHTML =
    '<option value="">-- Campus-wide (No specific location) --</option>' +
    locations.map((l) => `<option value="${l.id}">${escapeHtml(l.name)}</option>`).join('');
  eventLocationSelect.value = currentVal;
}

function start() {
  render();
  updateLocationSelectOptions();
  if (!db) return;

  unsubscribeLocations = onSnapshot(
    query(collection(db, 'campusLocations'), where('isActive', '==', true)),
      (snap) => {
        const fetched = snap.docs
          .map((d) => ({ id: d.id, ...d.data() }))
          .filter((l) => typeof l.capacity === 'number' && l.capacity > 0)
          .sort((a, b) => a.name.localeCompare(b.name));
        if (fetched.length > 0) {
          locations = fetched;
        }
        updateLocationSelectOptions();
        setConnection(true);
        render();
      },
      (err) => {
        console.warn('Locations query fallback:', err.message);
        render();
      },
  );

  watchOrders();
  watchEvents();

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
  if (!connectionEl) return;
  connectionEl.textContent = online ? 'Live' : 'Offline';
  connectionEl.className = `pill ${online ? 'live' : 'offline'}`;
}

function showError(message) {
  if (!appError) return;
  appError.textContent = message;
  appError.hidden = false;
  setConnection(false);
}

async function adjust(location, delta) {
  if (!db || !canWrite || pendingWrites.has(location.id)) return;

  pendingWrites.add(location.id);
  render();

  const ref = doc(db, 'pulseUpdates', `crowd-${location.id}`);
  const capacity = location.capacity;

  try {
    await runTransaction(db, async (tx) => {
      const snap = await tx.get(ref);
      const stored = snap.exists ? snap.data().occupancy?.count ?? 0 : 0;
      const current = clampCount(stored, capacity);
      const next = clampCount(current + delta, capacity);
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
        createdBy: auth?.currentUser?.uid ?? 'counter',
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

      if (snap.exists) {
        tx.update(ref, payload);
      } else {
        tx.set(ref, { ...payload, createdAt: serverTimestamp() });
      }
    });
    if (appError) appError.hidden = true;
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
  if (!canWrite || pendingWrites.has(location.id)) return;
  adjust(location, -Infinity);
}

function relativeTime(ts) {
  if (!ts?.toMillis) return null;
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
  if (!locationsEl) return;
  if (!locations.length) {
    locationsEl.innerHTML = '';
    if (emptyEl) emptyEl.hidden = false;
    return;
  }
  if (emptyEl) emptyEl.hidden = true;

  locationsEl.innerHTML = locations
    .map((location) => {
      const data = crowdDocs.get(location.id);
      const capacity = location.capacity;
      const count = clampCount(data?.occupancy?.count ?? 0, capacity);
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
            <button class="step plus" data-id="${location.id}" data-delta="1"
                    ${disabled || count >= capacity ? 'disabled' : ''}
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
  return String(value ?? '').replace(
    /[&<>"']/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c],
  );
}

if (locationsEl) {
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
}

// ---------------------------------------------------------------------------
// Events & Alerts
// ---------------------------------------------------------------------------

function watchEvents() {
  if (!db) return;
  unsubscribeEvents = onSnapshot(
    collection(db, 'pulseUpdates'),
      (snap) => {
        events = snap.docs
          .map((d) => ({ id: d.id, ...d.data() }))
          .filter((u) => u.category !== 'crowd');
        renderEvents();
        setConnection(true);
      },
      (err) => showError(`Couldn't load events & alerts: ${err.message}`),
  );
}

if (btnToggleEventForm) {
  btnToggleEventForm.addEventListener('click', () => {
    if (eventFormCard) {
      eventFormCard.style.display = eventFormCard.style.display === 'none' ? 'block' : 'none';
    }
    if (eventFormError) eventFormError.hidden = true;
  });
}
if (btnCloseEventForm) {
  btnCloseEventForm.addEventListener('click', () => {
    if (eventFormCard) eventFormCard.style.display = 'none';
  });
}
if (btnCancelEvent) {
  btnCancelEvent.addEventListener('click', () => {
    if (eventFormCard) eventFormCard.style.display = 'none';
  });
}

if (createEventForm) {
  createEventForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!db) return;
    if (eventFormError) eventFormError.hidden = true;

    const title = el('event-title').value.trim();
    const category = el('event-category').value;
    const status = el('event-status').value;
    const priority = Number(el('event-priority').value);
    const description = el('event-description').value.trim();
    const locationId = el('event-location').value;
    const durationHours = Number(el('event-duration').value);
    const imageUrl = el('event-image').value.trim();

    if (!title || !description) {
      if (eventFormError) {
        eventFormError.textContent = 'Please provide both title and description.';
        eventFormError.hidden = false;
      }
      return;
    }

    if (btnSubmitEvent) {
      btnSubmitEvent.disabled = true;
      btnSubmitEvent.textContent = 'Publishing…';
    }

    const locObj = locations.find((l) => l.id === locationId);
    const locationName = locObj ? locObj.name : null;

    const expiresAt =
      durationHours > 0
        ? Timestamp.fromMillis(Date.now() + durationHours * 3600 * 1000)
        : null;

    try {
      await addDoc(collection(db, 'pulseUpdates'), {
        title,
        description,
        category,
        status,
        priority,
        locationId: locationId || null,
        locationName: locationName || null,
        imageUrl: imageUrl || null,
        createdBy: auth?.currentUser?.uid || 'desk',
        createdByName: auth?.currentUser?.email ? auth.currentUser.email.split('@')[0] : 'Campus Desk',
        createdAt: serverTimestamp(),
        expiresAt,
        isActive: true,
      });

      createEventForm.reset();
      if (eventFormCard) eventFormCard.style.display = 'none';
    } catch (err) {
      if (eventFormError) {
        eventFormError.textContent =
          err.code === 'permission-denied'
            ? 'This account requires admin permissions to publish events & alerts.'
            : `Couldn't publish: ${err.message}`;
        eventFormError.hidden = false;
      }
    } finally {
      if (btnSubmitEvent) {
        btnSubmitEvent.disabled = false;
        btnSubmitEvent.textContent = 'Publish to Campus Pulse';
      }
    }
  });
}

function renderEvents() {
  if (!eventsEl) return;

  const filtered = events.filter((e) => {
    if (eventCategoryFilter === 'all') return true;
    return e.category === eventCategoryFilter;
  });

  filtered.sort((a, b) => {
    const aActive = a.isActive !== false;
    const bActive = b.isActive !== false;
    if (aActive !== bActive) return bActive ? 1 : -1;
    if ((b.priority ?? 0) !== (a.priority ?? 0)) return (b.priority ?? 0) - (a.priority ?? 0);
    const aTime = a.createdAt?.toMillis?.() ?? 0;
    const bTime = b.createdAt?.toMillis?.() ?? 0;
    return bTime - aTime;
  });

  const activeCount = events.filter((e) => e.isActive !== false).length;
  if (eventsBadgeEl) {
    eventsBadgeEl.textContent = String(activeCount);
  }

  if (eventsSummaryEl) {
    eventsSummaryEl.textContent = filtered.length
      ? `${filtered.length} item${filtered.length === 1 ? '' : 's'}`
      : 'No items';
  }

  if (eventsEmptyEl) {
    eventsEmptyEl.hidden = filtered.length > 0;
  }

  eventsEl.innerHTML = filtered
    .map((item) => {
      const isBusy = busyEvents.has(item.id);
      const isActive = item.isActive !== false;
      const createdLabel = relativeTime(item.createdAt) ? `Posted ${relativeTime(item.createdAt)}` : 'Recently posted';
      const isExpired = item.expiresAt?.toMillis && item.expiresAt.toMillis() < Date.now();

      let toneClass = 'event-card-type';
      if (item.category === 'alert') toneClass = 'alert-card';
      if (item.status === 'warning') toneClass = 'warning-card';

      return `
        <article class="event-card ${toneClass} ${!isActive || isExpired ? 'inactive' : ''}">
          <div>
            <div class="event-card-header">
              <span class="event-title">${escapeHtml(item.title)}</span>
              <span class="event-category-badge ${escapeHtml(item.category || 'notice')}">${escapeHtml(item.category || 'notice')}</span>
              <span class="status ${toneFor(item.status)}">${escapeHtml(item.status || 'info')}</span>
              ${item.priority > 0 ? `<span class="pill">P${item.priority}</span>` : ''}
            </div>

            <div class="event-desc">${escapeHtml(item.description)}</div>

            <div class="event-meta-info">
              <span>${createdLabel}</span>
              ${item.locationName ? `<span>📍 ${escapeHtml(item.locationName)}</span>` : ''}
              ${item.createdByName ? `<span>By ${escapeHtml(item.createdByName)}</span>` : ''}
              ${
                item.expiresAt
                  ? `<span class="${isExpired ? 'overdue' : ''}">${isExpired ? 'Expired' : `Expires ${relativeTime(item.expiresAt)}`}</span>`
                  : ''
              }
              ${!isActive ? '<span class="status neutral">Deactivated</span>' : ''}
            </div>
          </div>

          <div class="event-actions">
            ${
              isActive && !isExpired
                ? `<button class="btn ghost small" data-deactivate-event="${item.id}" ${isBusy ? 'disabled' : ''}>
                     ${isBusy ? 'Saving…' : 'Deactivate'}
                   </button>`
                : ''
            }
            <button class="btn ghost small" data-delete-event="${item.id}" ${isBusy ? 'disabled' : ''}>
              Delete
            </button>
          </div>
        </article>
      `;
    })
    .join('');
}

if (eventsEl) {
  eventsEl.addEventListener('click', async (event) => {
    const deactivateBtn = event.target.closest('[data-deactivate-event]');
    if (deactivateBtn) {
      const id = deactivateBtn.dataset.deactivateEvent;
      if (busyEvents.has(id)) return;
      busyEvents.add(id);
      renderEvents();
      try {
        await updateDoc(doc(db, 'pulseUpdates', id), {
          isActive: false,
          expiresAt: serverTimestamp(),
        });
      } catch (err) {
        showError(`Couldn't deactivate event: ${err.message}`);
      } finally {
        busyEvents.delete(id);
        renderEvents();
      }
      return;
    }

    const deleteBtn = event.target.closest('[data-delete-event]');
    if (deleteBtn) {
      const id = deleteBtn.dataset.deleteEvent;
      if (!confirm('Are you sure you want to delete this event/alert permanently?')) return;
      if (busyEvents.has(id)) return;
      busyEvents.add(id);
      renderEvents();
      try {
        await deleteDoc(doc(db, 'pulseUpdates', id));
      } catch (err) {
        showError(`Couldn't delete event: ${err.message}`);
      } finally {
        busyEvents.delete(id);
        renderEvents();
      }
    }
  });
}

const eventsFiltersEl = el('events-filters');
if (eventsFiltersEl) {
  eventsFiltersEl.addEventListener('click', (event) => {
    const button = event.target.closest('[data-event-filter]');
    if (!button) return;
    eventCategoryFilter = button.dataset.eventFilter;
    [...eventsFiltersEl.children].forEach((b) => b.classList.toggle('active', b === button));
    renderEvents();
  });
}

// ---------------------------------------------------------------------------
// Print queue
// ---------------------------------------------------------------------------

const ordersEl = el('orders');
const ordersEmptyEl = el('orders-empty');
const queueSummaryEl = el('queue-summary');
const queueBadgeEl = el('queue-badge');

function queueSortKey(order) {
  const needed = order.neededBy?.toMillis?.();
  if (!needed) return 4000000000 + Math.floor((order.createdAt?.toMillis?.() ?? 0) / 1000);
  return Math.floor(needed / 1000);
}

function deadlineState(order) {
  const needed = order.neededBy?.toMillis?.();
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
  if (!db) return;
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
  if (!db || busyOrders.has(order.id)) return;
  busyOrders.add(order.id);
  renderOrders();

  try {
    await updateDoc(doc(db, 'printOrders', order.id), {
      status,
      statusChangedAt: serverTimestamp(),
      ...extra,
    });
    if (appError) appError.hidden = true;
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
  if (reason === null) return;
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
  if (!ordersEl) return;
  const list = visibleOrders();

  const active = orders.filter((o) => ACTIVE_STATUSES.includes(o.status));
  const overdue = active.filter((o) => deadlineState(o).className === 'overdue').length;

  if (queueSummaryEl) {
    queueSummaryEl.textContent = active.length
      ? `${active.length} in the queue${overdue ? ` · ${overdue} overdue` : ''}`
      : 'Queue is clear';
  }

  if (queueBadgeEl) {
    queueBadgeEl.textContent = String(active.length);
  }

  if (ordersEmptyEl) {
    ordersEmptyEl.hidden = list.length > 0;
  }

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

if (ordersEl) {
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
}

const queueFiltersEl = el('queue-filters');
if (queueFiltersEl) {
  queueFiltersEl.addEventListener('click', (event) => {
    const button = event.target.closest('[data-filter]');
    if (!button) return;
    queueFilter = button.dataset.filter;
    [...queueFiltersEl.children].forEach((b) => b.classList.toggle('active', b === button));
    renderOrders();
  });
}

// ---- tabs ----

const tabsNav = document.querySelector('.tabs');
if (tabsNav) {
  tabsNav.addEventListener('click', (event) => {
    const tab = event.target.closest('.tab');
    if (!tab) return;

    document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t === tab));
    if (el('panel-crowd')) el('panel-crowd').style.display = tab.dataset.tab === 'crowd' ? 'block' : 'none';
    if (el('panel-events')) el('panel-events').style.display = tab.dataset.tab === 'events' ? 'block' : 'none';
    if (el('panel-print')) el('panel-print').style.display = tab.dataset.tab === 'print' ? 'block' : 'none';
  });
}

setInterval(() => {
  if (locations.length) render();
  if (events.length) renderEvents();
  if (orders.length) renderOrders();
}, 60000);

window.addEventListener('online', () => setConnection(true));
window.addEventListener('offline', () => setConnection(false));

render();
