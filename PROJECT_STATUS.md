# Campus360 — Project Status

> **Living document.** Update this file at the end of every working session:
> move items between "Done" and "Pending", and add a line to the changelog at the bottom.
> Last updated: **2026-08-20** (session 6)

---

## 1. What this project is

**Campus360** is a Flutter + Firebase campus utility app for **KPR Institute of Engineering and
Technology (KPRIET)**, built as a Mobile Application Development academic project.

It answers everyday campus questions that currently have no single home: *how busy is the library
right now?*, *where is that block?*, *has anyone found my ID card?*, *is my printout ready?*

### Modules

| Module | Purpose |
|---|---|
| **Campus Pulse** | Live crowd levels + campus notices, as a swipeable card deck |
| **Campus Map** | Offline map with real turn-by-turn walking navigation |
| **Smart Lost & Found** | Report, match and claim lost items, with two-sided handover |
| **Printout Service** | Upload a document, **schedule when you need it**, track it to collection |

Plus two additions made during development, both deliberate departures from the original brief:

- **Guest mode** — visitors use all four tabs without an account
- **Timetable + academic calendar** — per class/section

### Companion web app

A separate **counter dashboard** (`dashboard/`, Firebase Hosting) run by campus desk staff:

- **Crowd counter tab** — increment/decrement headcount for exactly four places: library, main
  canteen, dining hall, print shop
- **Print queue tab** — the shop's work queue, sorted by student deadline

Live at **https://campus360-app.web.app** · sign in `kpriet` / `123456`

> The manual counter is a **stand-in**. The real feeds will be the library's ID-card gate (an exact
> count) and cameras at the canteen/print shop (crowd *intensity*, not a headcount). The ingest
> contract already carries `mode: count|density` and `source: manual|idCard|camera` so those feeds
> can be plugged in without touching the app.

### Tech

Flutter 3.44.9 / Dart 3.12.2 · Riverpod 2 · go_router · Firebase Auth / Firestore /
Hosting · **Supabase Storage** for uploaded files · flutter_map + custom tile cache ·
A* pathfinding (pure Dart) · Android Gradle Plugin **pinned to 8.9.1**

---

## 2. Completed

### Foundation
- [x] 10-section design document — `ARCHITECTURE.md`
- [x] Flutter toolchain installed; app builds and runs on a real Android device
- [x] Theme, routing (`StatefulShellRoute` + redirect guards), error model
      (`AppFailure` / `FailureMapper`), `AsyncValueView` for loading/error/empty states
- [x] Hand-written immutable models — no `build_runner`, no generated files
- [x] Firestore security rules with custom-claim roles; **proven by attack**, not assertion
      (student write → 403, counter editing an admin notice → 403, fake emergency → 403)
- [x] `flutter analyze` **0 issues** · `flutter test` **97 passing**

### Auth & profile
- [x] Email/password sign-up and sign-in
- [x] **Login restricted to `@kpriet.ac.in`** — three layers: config flag, sign-in gate that ejects
      non-college accounts, and a security rule blocking profile creation
- [x] Guest mode (anonymous auth), including upgrade to a real account keeping the same uid
- [x] Profile screen — logout, display name, section, settings
- [x] `ensureUserDocument` self-heal for accounts left without a profile
- [x] Account deletion **removed** at the user's request

### Notifications (receiving half)
- [x] `notifications/{id}` inbox — model, repository, providers, screen, and a bell with an unread
      dot in the Pulse header
- [x] FCM token kept in `users/{uid}.fcmTokens`: registered on session start, re-registered on
      rotation (FCM rotates on reinstall/restore, and a missed rotation silently kills delivery),
      removed on sign-out so the next person on a shared phone doesn't get the previous user's
      notifications
- [x] Permission asked when a notification switch is turned **on**, not at first launch — Android
      only allows the prompt once, and it lands with the reason visible
- [x] Foreground pushes shown as an in-app banner (the OS suppresses them), taps deep-linked via
      `data.type` + id; an unrecognised type degrades to the inbox rather than crashing older
      installs when a new type ships
- [x] Rules: read your own, **create denied outright** (a client that can write notifications can
      forge "your claim was approved"), update restricted to the `read` flag alone
- [x] `POST_NOTIFICATIONS` added to the manifest — without it Android 13+ drops everything silently
- [x] 10 tests on type mapping, deep-link routing and payload parsing, plus **8 widget tests** on
      the inbox and bell — the first rendering tests in the project. They work without a
      fake-Firebase harness because the screens read from providers that the test overrides;
      the repository is only touched on tap.

### Campus Pulse
- [x] Card-deck UI matching the hand-drawn sketch — greeting header, search bar, stacked card
      edges visible on the right, swipe left to advance
- [x] Backward-swipe animation fixed (previous card slides in over a stationary current card)
- [x] Live crowd levels fed by the counter dashboard, visible to students within a second

### Campus Map
- [x] Real offline map — `flutter_map` with a custom caching tile provider
- [x] Tile-fetch reliability fixed: shared HTTP client, 6-concurrency cap, 3 retries with backoff
- [x] A* walking navigation with haversine heuristic, pure Dart
- [x] GPS works without network (satellites, not cell towers)
- [x] Admin survey screen (`/admin/survey`) for capturing real building coordinates
- [x] **Path editing on the map** — the survey's Paths tab draws the walking network over the
      tiles instead of listing coordinates. Tap a point to select it (its connections light up in
      amber); join two points, break a connection, continue the walk from an earlier point, or
      delete one. Deletion states how many connections go with it, because removing a mid-path
      point splits the path and silently kills routing across it
- [x] **12 widget tests** on the Paths tab — the delete warning, the join flow writing nothing
      until the second point is chosen, and the graph each action actually saves. Rendering a map
      screen in a test needed `tileCacheProvider` (see Traps)

### Smart Lost & Found
- [x] Report something lost or found — one screen for both, camera or gallery photo, category
      chips, place, approximate date
- [x] **Ownership secret** kept in a `private` subdocument, unreadable by anyone browsing —
      Firestore rules are per-document, so field-level secrecy needs the split
- [x] **On-device matching** — category gate, keyword overlap (Jaccard), place and time decay;
      shows *reasons* rather than a percentage
- [x] Claim flow: claimant describes a detail not in the photo → finder judges → approve or
      decline with a reason
- [x] **Two-sided handover confirmation** instead of a pickup OTP (an OTP the client can read is
      security theatre; both parties confirming is the honest equivalent without a server)
- [x] Security rules **attack-tested against the deployed rules — 15 checks, all correct**
      (`tool/testLostFoundRules.js`)
- [x] 31 tests covering matching and keyword normalisation

### Printout Service
- [x] **Document storage on Supabase, not Firebase** — Firebase Storage requires the Blaze plan,
      which this project does not have. Supabase's free tier gives an equivalent bucket
      (`print-docs`, Mumbai region) with no card. Everything else stays on Firebase.
- [x] PDF/image upload to storage; order lifecycle received → accepted → printing → ready → collected
- [x] **Deadline scheduling** — quick chips (30 min / 1 h / 2 h / 4 h) or an exact date-time,
      default "No rush"
- [x] Priority queue — `queueSortKey` sorts by deadline, not arrival; no-deadline orders sort last.
      Mirrored in Dart and JS with a comment that the two must agree.
- [x] Student may cancel only *before* printing starts; cannot mark their own order ready
- [x] 17 unit tests, including the decisive case: an order placed later but needed sooner sorts first

### Counter dashboard
- [x] Crowd counter, restricted to the four countable locations
- [x] Print queue tab — Active / Ready / Completed filters, unread badge, overdue in red,
      under 30 min in amber, Accept → Start → Ready → Collected, Reject with a mandatory reason
- [x] Verified end-to-end against live security rules (order #1000 New → Accepted, no error)

### Tooling
- [x] `tool/seed.js`, `tool/setRole.js`, `tool/seedTimetable.js`, `tool/seedOrders.js`
- [x] `tool/seedPaths.js` — builds `campusPaths/graph` from a traced GeoJSON file, so the walking
      network can be laid out at a desk instead of only by walking the campus with `/admin/survey`.
      Welds vertices within 4 m (two lines traced to one junction must actually connect, or A*
      sees separate networks), warns on disconnected components, and flags any `campusLocation`
      with no path point within 40 m. `--merge` re-welds against the stored graph; `--dry-run`
      touches Firestore not at all, so a trace can be checked with no credentials configured
- [x] `tool/seedTimetable.js --check` — validates the grids and writes nothing, no credentials
      needed. Refuses to seed on a real error (period defined twice, unknown period index, times
      that disagree with the grid, missing subject, code not in `COURSES`, lab across
      non-consecutive periods, duplicate section id); warns without blocking on the legal-but-odd
      (free day, single-period lab, missing staff name). `tool/testSeedTimetable.js` — **25
      checks**, which caught a code-pattern bug that let mistyped `U21CS501`-style codes through
- [x] `tool/testSeedPaths.js` — **29 checks** on the graph builder, no credentials or network
      needed. Covers the failure that is invisible on screen: a junction that doesn't weld leaves
      two networks that both look fine and cannot be routed between

---

## 3. Pending

### Blocked on the user
- [ ] **Enable Anonymous auth** in the Firebase console — guest mode is fully built but currently
      fails with `ADMIN_ONLY_OPERATION`
      → https://console.firebase.google.com/project/campus360-app/authentication/providers
- [ ] **Survey the campus** — no location has coordinates yet, so the map shows no pins and nothing
      is navigable. Two routes now: walk it with `/admin/survey`, or trace the footpaths in
      geojson.io and run `node tool/seedPaths.js <file>.geojson`. Building coordinates still have
      to come from the survey screen — only the walking network can be traced from a desk.
- [ ] Run `node tool/seedTimetable.js` to push the **real III CSE C timetable** and the odd-semester
      2026–27 academic calendar (the script also deletes the old "(sample)" sections). Other sections
      still need their grids added to `sections` in that file — run `--check` after typing each
      one in; it catches the copying mistakes that otherwise surface as a student's blank Tuesday.
- [ ] Tap the map's download button once on Wi-Fi, then run the airplane-mode test

### Next up
- [ ] Finish verifying the **print-order flow on device** — everything up to the upload was
      confirmed working before storage moved to Supabase. Re-run end to end and watch the order
      land in the dashboard queue.
- [ ] Verify **Lost & Found on device** — built and rules-tested, but never run on hardware
- [ ] Verify the **profile screen** on device
- [ ] Clear the demo orders afterwards: `node tool/seedOrders.js --clear`

- [ ] **Push notifications — client half built, server half blocked.** The receiving side is done
      and wired: inbox, unread bell, FCM token registration/rotation/removal-on-logout, permission
      prompt, foreground banner, and deep-linking from a tapped notification. **Nothing writes a
      notification yet** — that is a Cloud Function trigger, which needs Blaze. Until then the
      inbox stays empty and says so. When the plan is upgraded, write the functions from §7's
      trigger table and add a background handler for data-only pushes.

### Known limits (documented, not bugs)
- **Print documents are protected by an unguessable URL, not by an access check.** With no server
  (Cloud Functions also need Blaze), the app must carry the Supabase `anon` key, and the bucket is
  public-read. Anyone holding a document's link can open it. Two things keep this honest, both
  verified by attack: the key can only **insert** (delete, overwrite and cross-bucket writes all
  return 400), and **listing the bucket returns nothing**, so paths cannot be enumerated. Each
  document gets a 128-bit `Random.secure()` path segment. This is the same shape as the Firebase
  design it replaced — `getDownloadURL()` also returns a public token URL that bypasses rules.
- An outsider can still *create* a Firebase Auth account on any email through the public API — that
  endpoint isn't ours to gate. They can create no profile and touch no data, and the sign-in gate
  ejects them. Closing it fully needs a `beforeUserCreated` blocking trigger, which requires Blaze.
- Demo orders show "document unavailable" — deliberate; no real file backs them.
- Push notifications and the OTP handover flow are designed in `ARCHITECTURE.md` but not built.

---

## 4. Traps worth remembering

- **Firestore database is named `default`, not `(default)`.** `FirebaseFirestore.instance` targets
  `(default)`, which does not exist here and fails with `NOT_FOUND`. All access goes through
  `firestoreProvider` / `campus360Firestore`. See `SETUP.md`.
- **AGP is pinned to 8.9.1 on purpose.** `file_picker` needs `android.builtInKotlin=true`;
  `cloud_firestore` fails when it is on. Under AGP 9 no setting satisfies both. Reasoning is in
  `android/settings.gradle.kts` — don't "fix" it back.
- **Dashboard cache** — bump `?v=N` on `style.css` / `app.js` after editing, or Hosting serves the
  old file for five minutes.
- **Never `listen()` to a Firebase `UploadTask` without `onError`.** A failed upload errors that
  stream too, and an unhandled stream error escapes as an uncaught zone error — sailing straight
  past the caller's `try/catch`, so the user sees *nothing at all*. This is exactly how the print
  upload failed silently.
- **Map screens need `tileCacheProvider` to be testable.** `TileCache.instance()` asks
  `path_provider` for a directory over a plugin channel that doesn't exist in a widget test, so
  the future never completes and the screen sits on its spinner forever. Override the provider
  with `TileCache.forDirectory(...)` instead.
- **Don't `pumpAndSettle` a screen with a map** — the tile provider keeps retrying fetches that
  can't succeed in a test, so there is never an idle frame and it times out. Pump fixed frames.
- **flutter_map markers can't be tapped by `tester.tap`.** Its layer transform makes render
  geometry and hit testing disagree, so a tap at a marker's visible centre lands nowhere. Tests
  invoke the dot's `onTap` directly; the gesture itself is only proven on a device.
- **Two `pumpWidget` calls in one test reuse the ProviderScope container**, so a second set of
  overrides silently has no effect. Split into separate tests.
- **Role changes cut both ways** — giving the desk account `printShopStaff` once silently disabled
  every crowd +/− button, because the JS `canWrite` check only knew about `crowdCounter`.

---

## 5. Changelog

| Date | Work |
|---|---|
| 2026-08-20 (6) | Added `tool/seedPaths.js` so the walking network can be traced as GeoJSON rather than walked point by point; vertex welding, connectivity check and an unreachable-location warning against the live `campusLocations`. Then made the network **editable on the map** in the survey screen — select, join, disconnect, delete — with the graph operations as pure `CampusGraph` methods so they could be tested rather than only tapped. Added `tool/testSeedPaths.js` (29 checks) and a validation pass on the timetable seed with `--check` + `tool/testSeedTimetable.js` (25 checks). Built the **receiving half of push notifications** — inbox, bell, token lifecycle, permission prompt, deep-linked taps, rules denying client writes; sending still needs Blaze. `flutter analyze` 0 issues, `flutter test` **146 passing** (39 new) |
| 2026-08-13 (5) | Built **Phase 3, Smart Lost & Found**: models, on-device matcher, repository, rules, and screens. Matching moved client-side because Cloud Functions need Blaze; pickup OTP replaced with two-sided handover confirmation. 15/15 rules attacks correct, 97 tests passing |
| 2026-08-13 (4) | Firebase Storage needs Blaze, so moved print documents to **Supabase Storage** (free, no card, Mumbai region). New `DocumentStorage` uploader over the REST API — no new dependency. Verified upload + public read-back of a real PDF, and attack-tested the bucket policy (delete/overwrite/list/cross-bucket all blocked). 6 new tests; sanitiser hardened after two of them failed |
| 2026-08-13 (3) | Drove the print flow on device as a signed-in student: confirmed `file_picker` works under the AGP 8.9.1 pin, deadline picker and shop selection work, orders list renders. Found Firebase Storage is not provisioned at all (0 buckets) — the real cause of upload failure. Fixed an unhandled `snapshotEvents` stream error that made upload failures vanish silently, and corrected the misleading `object-not-found` message |
| 2026-08-13 (2) | APK installed and launched on the SM S911B; fixed a stale auth error banner carrying between sign-in / register / forgot-password; fixed a `use_build_context_synchronously` lint in the order-detail cancel button |
| 2026-08-13 | Print deadline scheduling + priority queue; print-queue tab in the counter dashboard; AGP pinned to 8.9.1; this status file created |
| earlier | Profile section; `@kpriet.ac.in` login restriction; offline map + A* navigation; guest mode + timetable; Pulse card-deck redesign; crowd counter dashboard; Phase 1 & 2 |
