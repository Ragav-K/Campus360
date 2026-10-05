# Campus360 — Architecture & Design Document

Version 1.0 · Flutter + Firebase · Modules: Campus Pulse, Campus Map, Smart Lost & Found, Printout Service

---

## 1. Complete Project Architecture

### 1.1 Layering

```
┌──────────────────────────────────────────────┐
│  PRESENTATION   screens/ + widgets/          │  Flutter widgets, no business logic
├──────────────────────────────────────────────┤
│  STATE          Riverpod providers           │  AsyncValue, controllers/notifiers
├──────────────────────────────────────────────┤
│  DOMAIN         models/ + repository ifaces  │  Pure Dart, no Firebase imports
├──────────────────────────────────────────────┤
│  DATA           repositories/ impls          │  Firestore / Storage / FCM / Functions
├──────────────────────────────────────────────┤
│  CORE           services, errors, theme      │  DI, failure mapping, design system
└──────────────────────────────────────────────┘
```

Rules enforced by convention:
- `models/` never imports `cloud_firestore`. Firestore (de)serialisation lives in
  `*_dto.dart` mappers inside `repositories/`. This keeps the domain testable and lets the
  backend be swapped.
- Screens never call a repository directly — always through a provider.
- Every repository method returns a value or throws an `AppFailure` (never a raw
  `FirebaseException`). Mapping happens in `core/errors/failure_mapper.dart`.

### 1.2 State management

**Riverpod 2 (`flutter_riverpod` + `riverpod_annotation`)**. Chosen over Bloc because the app is
overwhelmingly stream-of-Firestore-documents shaped, which `StreamProvider` models in one line,
and over Provider because it gives compile-safe DI and auto-disposal of listeners (important:
Firestore listeners cost money if leaked).

- Read models → `StreamProvider` / `FutureProvider` (auto-dispose + `.family` for ids).
- Write flows (multi-step forms: report lost, place print order) → `AsyncNotifier` controllers
  holding a draft object, exposing `AsyncValue<void>` for button loading state.

### 1.3 Navigation

**`go_router`** with declarative redirect-based auth+role gating. One router, typed route
constants in `core/constants/routes.dart`, `ShellRoute` for the bottom nav so tab state
survives navigation.

### 1.4 Why some logic is server-side

Three operations are **not trustable on the client** and live in Cloud Functions:

| Operation | Reason |
|---|---|
| Pickup OTP generation | Client must never know how OTPs are made, nor be able to write one. |
| Pickup OTP verification | Must be constant-time-ish, rate-limited, single-use, atomic. |
| Print order status transitions | Students must not be able to set `readyForPickup`. |
| Lost/Found match generation | Needs to read *other users'* lost items, which rules forbid the client. |
| Claim approval | Must atomically flip claim + lostItem + foundItem states. |

Everything else (creating a report, uploading a photo, reading pulse) is direct client→Firestore
under security rules. This keeps latency low where it matters and authority server-side where it
matters.

### 1.5 Folder structure

```
lib/
├── main.dart
├── app.dart                          # MaterialApp.router, theme, locale
├── bootstrap.dart                    # Firebase.initializeApp, error zone, FCM init
│
├── core/
│   ├── constants/
│   │   ├── app_config.dart           # allowed email domains (configurable), limits
│   │   ├── firestore_paths.dart      # single source of truth for collection names
│   │   └── routes.dart
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   ├── app_spacing.dart
│   │   ├── app_theme.dart            # light + dark ThemeData
│   │   └── status_palette.dart       # maps domain status -> colour + label + icon
│   ├── errors/
│   │   ├── app_failure.dart          # sealed failure hierarchy
│   │   └── failure_mapper.dart       # FirebaseException -> AppFailure
│   ├── services/
│   │   ├── firebase_service.dart
│   │   ├── auth_service.dart
│   │   ├── storage_service.dart      # upload w/ progress + compression
│   │   ├── messaging_service.dart    # FCM token, foreground handler
│   │   ├── functions_service.dart    # callable wrappers
│   │   ├── connectivity_service.dart
│   │   └── image_service.dart        # compress/resize before upload
│   ├── utils/
│   │   ├── validators.dart
│   │   ├── formatters.dart           # relative time, file size, page counts
│   │   └── debouncer.dart
│   └── router/
│       ├── app_router.dart
│       └── route_guards.dart
│
├── models/                           # pure Dart, freezed + json_serializable
│   ├── app_user.dart
│   ├── campus_location.dart
│   ├── pulse_update.dart
│   ├── lost_item.dart
│   ├── found_item.dart
│   ├── item_match.dart
│   ├── claim.dart
│   ├── print_shop.dart
│   ├── print_order.dart
│   ├── print_settings.dart
│   ├── app_notification.dart
│   └── enums/                        # PulseStatus, PrintOrderStatus, ClaimStatus, ...
│
├── repositories/
│   ├── auth_repository.dart
│   ├── user_repository.dart
│   ├── location_repository.dart
│   ├── pulse_repository.dart
│   ├── lost_found_repository.dart
│   ├── claim_repository.dart
│   ├── print_repository.dart
│   ├── notification_repository.dart
│   └── dto/                          # Firestore <-> model mappers
│
├── features/
│   ├── auth/          {screens, widgets, providers}
│   ├── home/
│   ├── campus_pulse/
│   ├── campus_map/
│   ├── lost_found/
│   ├── printout/
│   ├── notifications/
│   ├── profile/
│   └── admin/         {admin dashboard, shop dashboard}
│
└── widgets/                          # shared design-system components
    ├── c_scaffold.dart
    ├── c_card.dart
    ├── c_button.dart                 # handles loading + disabled states
    ├── c_text_field.dart
    ├── status_chip.dart
    ├── empty_state.dart
    ├── error_state.dart
    ├── skeleton.dart
    ├── async_value_view.dart         # loading/error/empty/data in one widget
    └── confirm_dialog.dart

functions/                            # Cloud Functions (TypeScript)
├── src/
│   ├── index.ts
│   ├── otp/{generate.ts,verify.ts}
│   ├── print/{onOrderCreate.ts,updateStatus.ts}
│   ├── lostfound/{onFoundItemCreate.ts,matching.ts,claims.ts}
│   ├── pulse/expirePulse.ts          # scheduled
│   └── lib/{notify.ts,auth.ts,hash.ts}

firestore.rules
storage.rules
firestore.indexes.json
```

### 1.6 `AsyncValueView` — how every state requirement is met once

Rather than hand-writing loading/error/empty in 30 screens, one widget:

```dart
AsyncValueView<List<PulseUpdate>>(
  value: ref.watch(activePulseProvider),
  skeleton: () => const PulseSkeletonList(),
  empty: (_) => const EmptyState(icon: ..., title: 'Nothing important right now'),
  error: (f, retry) => ErrorState(failure: f, onRetry: retry),
  data: (items) => PulseList(items),
)
```

This is why §31–33 (error/empty/loading states) are structurally guaranteed, not per-screen effort.

---

## 2. Feature Breakdown

### Module 1 — Campus Pulse
| Feature | Client / Server | Notes |
|---|---|---|
| View active updates | Client stream | `where(isActive)` + `expiresAt > now`, ordered by priority then time |
| Category filter, search | Client | Local filter over the (small) active set; avoids extra reads |
| Update detail + location link | Client | Deep-links into Map |
| Report stale info | Client write | Appends to `pulseUpdates/{id}/reports` — admin moderates |
| Auto-expiry | Server (scheduled fn, hourly) | Also filtered client-side so UI is correct between runs |
| Create/edit/delete | Admin only | Enforced by rules |

### Module 2 — Campus Map
| Feature | Notes |
|---|---|
| Interactive map | `google_maps_flutter`; campus bounds + initial camera from remote config doc |
| Markers by category | Custom marker icons per category, clustered when dense |
| Search + category filter | Locations cached locally (they change rarely) — see §37 |
| Location detail sheet | Name, building, floor, description, hours, **live Pulse status** |
| Pulse ↔ Map link | `pulseUpdates.locationId` join; a location shows its most recent active update |
| Graceful degradation | Without a Maps API key the module renders a searchable list + detail; the map tile area shows an explicit "Map unavailable — API key not configured" state, not a fake map |

### Module 3 — Smart Lost & Found
| Feature | Client / Server |
|---|---|
| Report lost / found (photo, category, location, time) | Client write + Storage upload |
| Match generation | **Server** — on found-item create and on lost-item create |
| View possible matches | Client read of `matches` where user is participant |
| "This Might Be Mine" | Client write → creates `claim` (pending) |
| Owner sees found photo, Yes/Not mine | Client update of claim |
| Ownership verification challenge | Client submits answer; **server** scores + finder/admin approves |
| Approve / reject claim | Server callable (finder or admin) |
| Mark returned | Server callable (finder or admin) |
| Notifications at each step | Server |

### Module 4 — Printout Service
| Feature | Client / Server |
|---|---|
| Upload document (PDF/JPG/PNG) | Client → Storage, with progress + size/type validation |
| Configure print settings | Client (pure UI over a `PrintSettings` value object) |
| Select shop, see status + wait | Client read of `printShops` |
| Place order | Client write (`status: submitted` only — rules pin this) |
| Accept/reject/printing/ready | **Server callable**, staff-only |
| OTP generate | **Server**, on transition to `readyForPickup` |
| OTP verify + mark collected | **Server callable**, staff-only, atomic |
| Order tracking + history | Client stream |
| Notifications | Server, on status change |

### Cross-cutting
Auth & roles · notifications inbox · profile "My Activity" · settings (theme, notification prefs) ·
offline/error handling · admin dashboards.

**Explicitly out of scope** (§1): attendance, fees, academics, timetable, food ordering,
marketplace, chat, social feeds.

---

## 3. Screen & Navigation Structure

### 3.1 Route tree

```
/splash                                  (decides: onboarding | login | home)
/login
/register
/forgot-password

ShellRoute  ── bottom nav, 4 tabs, persistent ──────────────────
  /pulse                                  📡 Pulse (tab 0, also the home surface)
    /pulse/:id
  /map                                    🗺️ Map (tab 1)
    /map/location/:id
  /lostfound                              🔎 Lost & Found (tab 2)
    /lostfound/lost/:id
    /lostfound/found/:id
    /lostfound/report-lost
    /lostfound/report-found
    /lostfound/match/:id
    /lostfound/claim/:id
    /lostfound/claim/:id/verify
    /lostfound/mine
  /print                                  🖨️ Printout (tab 3)
    /print/new            → wizard: upload → settings → shop → review
    /print/order/:id      → tracking
    /print/order/:id/otp  → pickup OTP
    /print/history
────────────────────────────────────────────────────────────────

Top bar (from any tab):
  /notifications
  /profile
  /profile/activity
  /settings

Staff (role: printShopStaff):
  /staff                                  order queue
  /staff/order/:id
  /staff/verify-otp

Admin (role: admin):
  /admin
  /admin/pulse            (list/create/edit/expire)
  /admin/locations
  /admin/lostfound        (moderation queue)
  /admin/shops
  /admin/users
  /admin/analytics
```

### 3.2 Home experience (§36)

The Pulse tab **is** the home surface — this satisfies "check Campus Pulse immediately after
opening" without adding a fifth module. Its scroll order:

```
Greeting ("Good morning 👋", name)  +  notification bell w/ unread dot
─────────────────────────────────────────────────────────────
Campus Pulse   [See all →]     ← top 3–5 highest-priority active updates
─────────────────────────────────────────────────────────────
Quick Actions  (2×2 grid)      ← Find Location · Report Lost · Report Found · New Print Order
─────────────────────────────────────────────────────────────
Recent         ← your active print order + any open L&F match/claim, max 3
─────────────────────────────────────────────────────────────
All Pulse updates (filter chips: All · Crowd · Availability · Notice · Alert · Event)
```

### 3.3 Speed targets (§35)

- **Report lost in 30–60s**: single screen, camera-first. Photo → category chips → location
  picker (defaults to nearest known campus location) → date/time defaulted to now → one free-text
  field. Everything except photo+name is optional. One "Post" button, no confirm screen.
- **Print order in a few steps**: 4-step wizard with a persistent bottom bar showing progress and
  a single primary action; shop and settings remember your last choice.
- **Find a location**: search field is on the Map screen itself, focused by the Quick Action.

---

## 4. Firestore Data Model

Conventions: ids are auto-ids unless stated. Timestamps are `Timestamp`. Denormalised fields are
marked ⧉ and are written only by trusted code paths or by the owner at create time.

### `users/{uid}`
```jsonc
{
  "uid": "…",
  "email": "s2101@college.edu",
  "displayName": "Ragav",
  "photoUrl": null,
  "role": "student",              // student | printShopStaff | admin
  "shopId": null,                 // set when role == printShopStaff
  "fcmTokens": ["…"],             // array, multi-device; pruned server-side on send failure
  "notificationPrefs": { "lostFound": true, "print": true, "pulse": false },
  "createdAt": ts,
  "lastSeenAt": ts,
  "disabled": false
}
```
Role is **never** writable by the user (rules). Also mirrored into custom claims by a Cloud
Function so rules can check `request.auth.token.role` without an extra read.

### `campusLocations/{id}`
```jsonc
{
  "name": "Central Print Shop",
  "category": "printShop",        // academicBlock|department|classroom|lab|library|canteen|
                                  // printShop|parking|sports|medical|admin|other
  "building": "Block A", "floor": "Ground", "roomCode": "A-012",
  "description": "…",
  "geo": { "lat": 12.97, "lng": 77.59 },
  "openHours": [{"day":1,"open":"09:00","close":"17:00"}],
  "searchTokens": ["central","print","shop","block","a"],   // ⧉ lowercase prefix tokens
  "isActive": true
}
```

### `pulseUpdates/{id}`
```jsonc
{
  "title": "Main Canteen very crowded",
  "description": "…",
  "category": "crowd",            // crowd|availability|notice|alert|event
  "status": "veryHigh",           // see §7 status system
  "locationId": "…", "locationName": "Main Canteen",   // ⧉
  "imageUrl": null,
  "priority": 2,                  // 0 info … 3 emergency; drives ordering + home picks
  "createdBy": "uid", "createdByName": "Admin Office",  // ⧉
  "createdAt": ts,
  "expiresAt": ts,
  "isActive": true                // set false by scheduled expiry fn
}
```
Sub-collection `pulseUpdates/{id}/reports/{uid}` — `{reason, createdAt}` for "report outdated".

### `lostItems/{id}`
```jsonc
{
  "ownerId": "uid", "ownerName": "…",   // ⧉
  "itemName": "Black Leather Wallet",
  "category": "wallet",           // wallet|phone|keys|idCard|bag|book|electronics|clothing|
                                  // bottle|jewellery|other
  "description": "Black leather wallet with a small scratch on the front.",
  "identifyingDetails": "Has a torn photo of a dog inside.",   // NEVER shown publicly — §14
  "photoUrl": "…", "photoPath": "…",
  "locationId": "…", "locationName": "Library",   // ⧉
  "lostAt": ts,                   // approximate date+time
  "keywords": ["black","leather","wallet"],       // ⧉ normalised tokens for matching
  "status": "active",             // active|matched|claimPending|resolved|closed
  "resolvedFoundItemId": null,
  "createdAt": ts, "updatedAt": ts
}
```
`identifyingDetails` is the verification secret. Security rules deny reading it to anyone but the
owner and admins — enforced by storing it in a **subdocument** `lostItems/{id}/private/secret`
(Firestore rules are per-document, not per-field, so field-level secrecy requires this split).

### `foundItems/{id}`
```jsonc
{
  "finderId": "uid", "finderName": "…",   // ⧉
  "category": "wallet",
  "description": "…",
  "photoUrl": "…", "photoPath": "…",
  "imageHash": "a1f3…",           // 64-bit perceptual hash, hex — see §8
  "locationId": "…", "locationName": "Library",
  "foundAt": ts,
  "handoverNote": "Left at library desk",
  "keywords": [...],
  "status": "active",             // active|claimPending|returned|closed
  "returnedToUserId": null,
  "createdAt": ts, "updatedAt": ts
}
```

### `matches/{id}`
Created only by Cloud Functions.
```jsonc
{
  "lostItemId": "…", "foundItemId": "…",
  "ownerId": "…",   "finderId": "…",     // participants — used by security rules
  "score": 0.92,                          // 0..1
  "band": "likely",                       // possible <0.55 | related | likely >0.8
  "signals": { "image": 0.88, "category": 1, "text": 0.61, "location": 1, "time": 0.9 },
  "state": "open",                        // open | claimed | dismissed | closed
  "createdAt": ts
}
```

### `claims/{id}`
```jsonc
{
  "matchId": "…", "lostItemId": "…", "foundItemId": "…",
  "claimantId": "…",  "finderId": "…",
  "status": "pending",   // pending | ownerConfirmed | verificationSubmitted |
                         // approved | rejected | awaitingCollection | returned | closed
  "ownerConfirmedAt": null,
  "verification": {
      "question": "Describe a unique identifying feature of the item.",
      "answer": "…",              // readable by finder+admin only (subdoc, see rules)
      "autoScore": 0.72,          // server-computed similarity vs identifyingDetails
      "submittedAt": ts
  },
  "decidedBy": null, "decidedAt": null, "rejectionReason": null,
  "returnedAt": null,
  "createdAt": ts, "updatedAt": ts
}
```

### `printShops/{id}`
```jsonc
{
  "name": "Central Print Shop",
  "locationId": "…", "locationName": "Block A",
  "isOpen": true,
  "status": "open",               // open | busy | closed
  "estimatedWaitMinutes": 10,
  "services": { "colour": true, "duplex": true, "paperSizes": ["A4","A3"], "binding": false },
  "pricing": { "bwPerPage": 1.0, "colourPerPage": 5.0, "currency": "INR" },
  "staffIds": ["uid"],
  "queueCount": 4                 // ⧉ maintained by Cloud Function
}
```

### `printOrders/{id}`
```jsonc
{
  "orderNumber": 1024,            // human-facing, from a counter doc, server-assigned
  "studentId": "uid", "studentName": "…",
  "shopId": "…", "shopName": "…",
  "document": {
     "fileName": "unit3-notes.pdf", "storagePath": "printDocs/{uid}/{orderId}/…",
     "downloadUrl": "…", "mimeType": "application/pdf",
     "sizeBytes": 842113, "pageCount": 12
  },
  "settings": {
     "copies": 2, "pageSelection": "all",      // all | range | custom
     "pageRange": null,                         // "2-7" when range
     "colour": "bw",                            // bw | colour
     "sides": "double",                         // single | double
     "paper": "A4",
     "note": "Staple please"
  },
  "estimatedCost": 24.0,
  "status": "submitted",
  // submitted|received|accepted|rejected|printing|readyForPickup|collected|cancelled
  "statusHistory": [{ "status": "submitted", "at": ts, "by": "uid" }],
  "rejectionReason": null,
  "createdAt": ts, "updatedAt": ts
}
```
`printOrders/{id}/private/otp` (**server-only**, client read denied):
```jsonc
{ "hash": "sha256(orderId|otp|pepper)", "expiresAt": ts, "usedAt": null, "attempts": 0 }
```
The plaintext OTP is returned once to the student via a callable and re-fetchable by the student
only (`getMyPickupOtp`), which re-issues from the same hash record only while unexpired.
It is never stored in plaintext anywhere. See §9.

### `notifications/{id}`
```jsonc
{
  "userId": "uid",
  "type": "print.ready",   // pulse.alert | lostfound.match | lostfound.claimRequest |
                           // lostfound.claimApproved | lostfound.returned |
                           // print.received | print.printing | print.ready |
                           // print.rejected | print.collected
  "title": "…", "body": "…",
  "data": { "orderId": "…" },   // used for deep-link routing on tap
  "read": false,
  "createdAt": ts
}
```

### `counters/printOrders`
`{ "next": 1025 }` — incremented in a transaction server-side.

### `config/app`
Public read: `{ "allowedEmailDomains": ["college.edu"], "requireCollegeEmail": true,
"campusCenter": {...}, "campusBounds": {...}, "maxUploadMb": 20 }`. Makes §26's domain rule
configurable rather than hardcoded.

### Required composite indexes
```
pulseUpdates:   isActive ASC, priority DESC, createdAt DESC
pulseUpdates:   isActive ASC, category ASC, createdAt DESC
lostItems:      ownerId ASC, createdAt DESC
lostItems:      status ASC, category ASC, createdAt DESC
foundItems:     finderId ASC, createdAt DESC
foundItems:     status ASC, category ASC, foundAt DESC
matches:        ownerId ASC, state ASC, score DESC
matches:        finderId ASC, state ASC, score DESC
claims:         claimantId ASC, createdAt DESC
claims:         finderId ASC, status ASC, createdAt DESC
printOrders:    studentId ASC, createdAt DESC
printOrders:    shopId ASC, status ASC, createdAt ASC
notifications:  userId ASC, createdAt DESC
notifications:  userId ASC, read ASC, createdAt DESC
campusLocations: isActive ASC, category ASC, name ASC
```

---

## 5. Firebase Storage Structure

```
lostItems/{uid}/{lostItemId}/photo.jpg          ≤ 1600px long edge, JPEG q80, ≤ 2 MB
foundItems/{uid}/{foundItemId}/photo.jpg        same
pulse/{pulseId}/image.jpg                       admin-written
printDocs/{uid}/{orderId}/{fileName}            PDF/JPEG/PNG, ≤ 20 MB (from config/app)
avatars/{uid}/avatar.jpg                        ≤ 512px
```

Rules summary:
- Write allowed only to your own `{uid}` prefix, with `request.resource.size` and
  `contentType` checks in the rule itself (so an oversized upload is rejected by the server, not
  just by client validation).
- `printDocs/**` read: the owning student, staff of the order's shop, admins. Because Storage
  rules can't join to Firestore cheaply, staff read is granted via a **short-lived signed URL
  minted by a Cloud Function** after verifying the staff↔shop↔order relationship. Direct
  unauthenticated read is denied. This is the one place worth the extra hop — print documents are
  private student coursework.
- Firestore stores only paths + download URLs + metadata, never bytes (§29).

---

## 6. Authentication & Role Design

### Sign-up / sign-in
Email + password via Firebase Auth. On register:
1. Validate the domain against `config/app.allowedEmailDomains` (client, for UX) **and** in the
   `onCreate` Auth trigger (server, for enforcement) — if it fails server-side the account is
   deleted and the client is told why.
2. Send verification email; `emailVerified` gates writing (reading Pulse/Map is allowed
   unverified so the app isn't a dead end).
3. Create `users/{uid}` with `role: "student"` — the only role a client-triggered path can set.
4. Set custom claim `role=student`.

Password reset via `sendPasswordResetEmail`. Logout clears the local FCM token from
`users/{uid}.fcmTokens` before signing out (otherwise the next user on that device gets someone
else's notifications).

### Roles
| Role | Granted by | Claim |
|---|---|---|
| `student` | automatic on register | `role: student` |
| `printShopStaff` | admin, via admin console → callable `setUserRole` | `role: printShopStaff`, `shopId` |
| `admin` | bootstrap script / existing admin | `role: admin` |

Roles live in **both** `users/{uid}.role` (for UI) and **custom claims** (for security rules and
callables). The callable that changes a role writes both, then forces token refresh. Rules trust
only the claim.

### Route guarding
`go_router.redirect` reads `authStateProvider` + `currentUserProvider`:
unauthenticated → `/login`; authenticated at `/login` → `/pulse`;
`/staff/**` requires claim `printShopStaff` or `admin`; `/admin/**` requires `admin`.
The guard is a convenience — the rules are the actual security boundary.

---

## 7. Notification Flow

```
   Domain event (Firestore write / callable)
                │
                ▼
   Cloud Function trigger
                │
    ┌───────────┴────────────┐
    ▼                        ▼
 write notifications/{id}   send FCM to users/{uid}.fcmTokens
 (in-app inbox, durable)    (push, best-effort)
                                  │
                                  ▼
                     device: onMessage (foreground)  → in-app banner
                             onMessageOpenedApp      → deep link via data.type
                             background handler      → system tray
```

Design decisions:
- **The Firestore doc is the source of truth**, FCM is a best-effort delivery hint. If push fails
  (token stale, permission denied, no network) the user still sees it in the inbox, and unread
  count is correct. §31's "notification failure" is therefore non-fatal by construction.
- **Token pruning**: on `messaging/registration-token-not-registered`, the function removes that
  token via `arrayRemove`.
- **Anti-spam (§22)**: notifications are only emitted on the transitions listed below; a
  `notifiedFor` set on the order/claim prevents duplicates on function retry (Cloud Functions are
  at-least-once, so this matters).

| Trigger | Recipient | Type |
|---|---|---|
| order → received | student | `print.received` |
| order → printing | student | `print.printing` |
| order → readyForPickup | student | `print.ready` (includes OTP availability, not the OTP) |
| order → rejected | student | `print.rejected` |
| order → collected | student | `print.collected` |
| match created (score ≥ threshold) | lost-item owner | `lostfound.match` |
| claim created | finder | `lostfound.claimRequest` |
| claim approved | claimant | `lostfound.claimApproved` |
| claim rejected | claimant | `lostfound.claimRejected` |
| item returned | claimant | `lostfound.returned` |
| pulse alert w/ priority ≥ 3 | topic `campus-alerts` | `pulse.alert` |

Per-user `notificationPrefs` are honoured server-side before sending push (inbox entry is still
written).

**Not** notified: order → accepted (redundant with "received"), match dismissed, own actions.

---

## 8. Lost & Found Matching Flow

```
Found item created ──┐                        ┌── Lost item created
                     ▼                        ▼
        Cloud Function onFoundItemCreate / onLostItemCreate
                     │
                     │ 1. Candidate query (cheap, indexed):
                     │    opposite collection, status == active,
                     │    same category OR category == other,
                     │    |foundAt - lostAt| ≤ 21 days
                     │
                     │ 2. Score each candidate (weighted sum, all 0..1):
                     │       image      0.40   Hamming distance of 64-bit pHash
                     │       text       0.25   token Jaccard(name+description+keywords)
                     │       location   0.15   1.0 same locationId; 0.6 same building;
                     │                         0.3 otherwise
                     │       time       0.10   1.0 within 24h → 0 at 21d (linear)
                     │       category   0.10   1.0 exact; 0.4 if either is "other"
                     │
                     │    Hard gate: image ≥ 0.5 OR text ≥ 0.4 — prevents "everything
                     │    matches everything" when only weak signals agree.
                     │
                     │ 3. Keep top 5 with score ≥ 0.45. Write matches/{id}.
                     ▼
        Notify lost-item owner ("A possible match was found")
```

**Image similarity — what is actually implemented.** A 64-bit **perceptual hash (dHash)** computed
**on-device at upload time** (`package:image`, ~10 lines: greyscale → 9×8 resize → adjacent-pixel
gradient bits) and stored as `imageHash`. The function compares by Hamming distance:
`imageScore = 1 - hamming/64`. This is real, runs offline, costs nothing, and genuinely catches
"same wallet, different photo" for similar framing. It is **not** a CNN embedding and it will miss
very different angles or lighting — so the score is presented as a *possible/likely* match and
never as certainty (§11).

The scorer sits behind one interface so it can be upgraded without touching anything else:

```ts
interface ImageSimilarity { compare(a: ImageDescriptor, b: ImageDescriptor): number }
// v1: PerceptualHashSimilarity  (shipping)
// v2: VisionEmbeddingSimilarity (Vertex AI multimodal embeddings + cosine) — drop-in
```

Bands shown in UI: `≥0.80 Likely Match` · `0.60–0.79 Possible Match` · `0.45–0.59 Related Item`.
Percentages are shown as "92% match" per your spec but always beside the word *possible/likely* —
never "confirmed".

### Claim & verification flow (§12–15)

```
Owner taps [ This Might Be Mine ]   ← labelled with a subtitle: "You'll need to confirm
        │                             details before it's released to you."
        ▼
claims/{id}  status = pending           → notify finder
        │
        ▼
Owner views found photo → [Yes, this is mine] / [Not mine]
        │                        │
        │  Not mine ──────────►  match.state = dismissed, claim closed. Done.
        ▼
status = ownerConfirmed
        │
        ▼
VERIFICATION (§14) — owner answers:
   "Describe a unique identifying feature of this item."
   Server compares the answer against lostItems/{id}/private/secret.identifyingDetails
   (token-overlap similarity) → autoScore. The answer + score go to the finder/admin.
   autoScore is advisory only; a human always decides. Photos alone are never sufficient.
        │
        ▼
status = verificationSubmitted          → notify finder
        │
   finder or admin decides
        ├── reject → status = rejected, match reopened   → notify claimant
        ▼
status = approved                        → notify claimant
        ▼
status = awaitingCollection    (lostItem.status = claimPending, foundItem.status = claimPending)
        ▼
finder/admin taps [Mark as Returned]
        ▼
status = returned  →  lostItem.status = resolved, foundItem.status = returned
                      other open matches on both items → closed
                                          → notify claimant "Your item has been returned"
        ▼
status = closed
```

All state transitions above run in a **single Firestore transaction inside a callable**, so a
double-tap or a race between two claimants cannot produce two approved claims for one found item.

---

## 9. Printout + OTP Flow

### Order lifecycle

```
STUDENT                          SYSTEM                         STAFF
───────                          ──────                         ─────
pick file (PDF/JPG/PNG)
  ├ validate type + size
  ├ compress if image
  └ upload → Storage (progress)
configure settings
select shop (open shops only)
review (cost estimate)
place order ──────────────► printOrders{status:submitted}
                            onCreate fn:
                              · assign orderNumber (txn)
                              · status → received
                              · notify student ────────────────► appears in shop queue
                                                              staff opens doc (signed URL)
                                                              [Accept] / [Reject+reason]
                            callable updateOrderStatus ◄──────────────┘
                              · verify staff ∈ shop.staffIds
                              · verify legal transition
                            accepted ──────────────────────► [Start printing]
                            printing → notify student
                                                              [Mark ready]
                            readyForPickup:
                              · generate OTP (see below)
                              · notify "ready for pickup"
open order → [Show pickup code]
  callable getMyPickupOtp ───► returns plaintext OTP
  (only owner; only while                                     staff enters 6-digit OTP
   status==readyForPickup                                     callable verifyPickupOtp ◄──┘
   and OTP unexpired)                                           · order exists, status ok
                                                                · not used, not expired
                                                                · attempts < 5
                                                                · timing-safe hash compare
                                                             VERIFIED ✅ [Mark as Collected]
                            status → collected
                              · OTP marked used → invalid
                              · notify student
```

### OTP design (§23–24)

| Requirement | Implementation |
|---|---|
| Generated securely | `crypto.randomInt(0, 1_000_000)` (CSPRNG), zero-padded to 6 digits. **Server only** — the client has no code path that can produce an OTP. |
| Bound to one order | Stored at `printOrders/{orderId}/private/otp`; the hash includes the orderId, so an OTP from order A cannot validate order B even on collision. |
| Expires | `expiresAt = now + 24h`. Expired → new one is minted on next `getMyPickupOtp` (status still `readyForPickup`). |
| Single use | `usedAt` set inside the same transaction as `status → collected`. |
| Invalid after verify | Any later verify sees `usedAt != null` → rejected. |
| Never reused | New random value per generation; old hash overwritten. |
| Not leakable | Only the hash is stored: `sha256(orderId + ":" + otp + ":" + PEPPER)`, pepper from Functions config. Firestore rules deny **all** client access to the `private` subcollection, so even a rules bypass on the parent doc leaks nothing. |
| Brute force | 5 attempts per order, then locked until staff requests re-issue; plus per-staff rate limit. 10⁶ space with 5 attempts = 5×10⁻⁶ per order. |
| Anti-spoof | Verification is a **callable**, authenticated as staff, checked against `shop.staffIds`. There is **no client-side OTP check anywhere** (§40). |

### Cost estimate
`pages(document) × copies × (colour ? colourPerPage : bwPerPage) ÷ (sides==double ? 1 : 1)`
— sides affect sheets, not page price, so it's shown as an estimate labelled
"Final price is confirmed by the shop."
Page count comes from the PDF client-side (`pdfx`/`syncfusion_flutter_pdf`); images = 1 page.

---

## 10. Development Roadmap

| Phase | Scope | Exit criteria |
|---|---|---|
| **1 — Foundation** | Flutter project, pubspec, design system (colours/type/spacing/theme, light+dark), shared widgets, `AppFailure` + mapper, Firebase init, Riverpod scope, go_router + shell + guards, auth (splash/login/register/forgot), user doc + role claim | Can register, log in, land on an empty shelled Pulse tab, log out. Dark mode works. |
| **2 — Pulse + Map** | Pulse models/repo/providers/screens (list, filters, search, detail, report-stale), status system, admin pulse CRUD, campusLocations repo + cache, map screen w/ markers + search + filters + detail sheet, Pulse↔Map join, scheduled expiry function | Pulse renders live data with real empty/loading/error states; map finds "Central Print Shop"; expiry works. |
| **3 — Lost & Found** | Report lost/found (photo capture, compression, pHash, upload w/ progress), lists + detail, matching function, matches UI w/ bands, "This Might Be Mine", owner confirm, verification, approve/reject, mark returned, notifications end-to-end, My Reports | Full §15 flow runs on a device with 2 accounts; notifications land. |
| **4 — Printout** | File pick + validate + upload, page count, settings wizard, shop selection, review + cost, place order, tracking, order history, staff queue + accept/reject/printing/ready, OTP generate/show/verify, mark collected, notifications | An order goes submitted → collected across a student and a staff device using a real OTP. |
| **5 — Hardening** | Firestore + Storage rules with an emulator rules test-suite, admin dashboards + analytics, full error/empty/loading pass, offline behaviour, pagination, image caching, accessibility (contrast, 48dp targets, semantics labels), widget + unit tests, seed script, README + demo script | Rules tests green; no screen without all four states; app usable in airplane mode with clear messaging. |

**Dependencies between phases**: 3 and 4 both depend on 1; 3 depends on 2 only for the location
picker (can stub). 5 is continuous but gated at the end.

### Known constraints, stated honestly
- **Google Maps needs an API key** (iOS + Android) that I can't provision. Until one is added the
  Map module runs in list mode with an explicit "map unavailable" state — not a fake map (§40).
- **Cloud Functions need the Blaze plan.** Without it, OTP generation/verification, matching, and
  notifications cannot run server-side, and the honest fallback is to **disable those features
  with a visible "unavailable" state** rather than fake them on the client (§40). The rest of the
  app (Pulse, Map, reporting, uploading, order placement, tracking) works on Spark.
- **Flutter SDK is not installed on this machine**, so nothing here has been compiled or run yet.
```
