# Architecture & data flow

## Layering

```
┌─────────────────────────────────────────────────────┐
│  Screens / Widgets  (lib/features/*/screens, widgets) │
│     reads providers via ConsumerWidget / ref.watch     │
└───────────────────────▲─────────────────────────────┘
                         │ AsyncValue<T> / state
┌───────────────────────┴─────────────────────────────┐
│  Providers  (lib/features/*/providers)                │
│    StreamProvider / Provider / AsyncNotifier wiring    │
└───────────────────────▲─────────────────────────────┘
                         │ Stream<T> / Future<T>, throws AppFailure
┌───────────────────────┴─────────────────────────────┐
│  Repositories  (lib/repositories)                      │
│    one per Firestore area; FailureMapper.guard(...)    │
└───────────────────────▲─────────────────────────────┘
                         │ Firestore/Storage/Functions/Auth SDK calls
┌───────────────────────┴─────────────────────────────┐
│  Firebase  (Auth, Firestore, Storage, Messaging,       │
│             Functions) via lib/core/services            │
└─────────────────────────────────────────────────────┘
```

`lib/models/*` are plain-Dart value types used at every layer above
Firebase; they carry their own `fromMap`/`toMap` (de)serialization so
repositories stay thin translators rather than holding business logic
themselves (e.g. the Lost & Found matching score lives in
`lib/features/lost_found/matching.dart`, not in a repository).

## Firebase wiring

`lib/core/services/firebase_providers.dart` is the one place that constructs
Firebase SDK singletons as Riverpod providers (`firebaseAuthProvider`,
`firestoreProvider`, `storageProvider`, `functionsProvider`). Every
repository takes its Firebase dependency through its constructor, pulled
from these providers — this is what lets tests override them with
fakes/emulators without touching repository code.

Two things worth knowing:

- **Named Firestore database.** This project's Firestore is the named
  database `"default"`, not the conventional `(default)` database.
  `FirebaseFirestore.instance` targets `(default)` and would fail with
  `NOT_FOUND`, so the app always goes through `campus360Firestore =
  FirebaseFirestore.instanceFor(app: ..., databaseId: 'default')`. Keep
  `kFirestoreDatabaseId` in sync with `firebase.json` → `firestore.database`.
- **Offline persistence.** `main.dart` turns on unlimited-size Firestore
  disk persistence on `campus360Firestore` before `runApp`, so Pulse, Map
  data and order history remain readable without a connection.

`lib/core/constants/firestore_paths.dart` (`Paths`, `StoragePaths`) is the
single source of truth for collection names and storage path shapes — no
collection string literals should appear anywhere else.

Collections in use: `users`, `campusLocations`, `pulseUpdates`, `lostItems`,
`foundItems`, `matches` (name reserved; matching is actually computed
on-device, see Lost & Found doc), `claims`, `printShops`, `printOrders`,
`notifications`, `config/app` (remote config doc), `timetables`,
`academicCalendar`, `examSchedules`.

Cloud Functions (`cloud_functions`) are used for a handful of
server-mediated operations surfaced through `FailureMapper._functions`
(OTP-style domain errors like `otp/invalid`, `otp/expired`, order/claim
conflict codes) — the client calls these as callables and maps their
`details.code` into a user-facing `AppFailure`.

## Routing & navigation

`lib/core/router/app_router.dart` builds a single `GoRouter`:

- `redirect` reacts to `authStateProvider` (a `StreamProvider<User?>`) and
  `currentRoleProvider` to gate auth screens and `/admin/**`/`/staff/**`
  routes. This is a UX convenience; Firestore security rules are the actual
  boundary, called out explicitly in a code comment.
- The four bottom-nav tabs (Pulse, Map, Lost & Found, Printout) are declared
  as `StatefulShellBranch`es inside a `StatefulShellRoute.indexedStack`,
  rendered by `AppShell`. Each branch keeps its own navigation stack, so
  switching tabs doesn't lose where you were.
- `AppShell` also hosts session-lifetime side effects that have nowhere
  better to live: it watches `tokenRegistrarProvider` to keep the device's
  FCM token registered, and handles a cold-start push tap via
  `messagingService.initialMessage()`.

## Offline support for the map

Campus Map avoids `google_maps_flutter` specifically because Google's terms
forbid caching/storing tiles offline. Instead it uses `flutter_map` with a
hand-written `TileCache` (`lib/core/services/tile_cache.dart`):

- Tiles are stored as plain PNGs under the app's support directory
  (`<support>/map_tiles`), not via the GPL-3.0-licensed
  `flutter_map_tile_caching` package (avoided deliberately per the file's
  doc comment, to keep the app's licence clean).
- A single shared `http.Client` is reused across tile fetches, and
  concurrent downloads are capped at 6 in-flight requests (`_maxInFlight`) to
  avoid exhausting sockets or getting throttled by the tile server.
- `connectivity_plus` is used elsewhere in the app to detect online/offline
  state for UX purposes (e.g. deciding whether to attempt a tile download or
  serve straight from cache).
- `geolocator` is used for GPS positioning, which — unlike tile fetching —
  works fully offline since it talks to satellites, not the network. This
  powers both "find me on the map" and the admin Survey tool's
  coordinate-recording flow.

Navigation between two points is graph-based: `lib/repositories/path_repository.dart`
stores a single `CampusGraph` document (nodes + edges — walking paths
surveyed on foot) that `navigation_providers.dart` routes over to produce
turn-by-turn-ish directions between a start and destination location.

## Error handling

`lib/core/errors/app_failure.dart` defines `AppFailure` — the only exception
type that is allowed to reach the UI, carrying a plain-language `message`,
a `FailureKind`, and an optional `debug` string that is logged but never
shown.

`lib/core/errors/failure_mapper.dart` is the single translation point from
platform errors to `AppFailure`:

- `SocketException`/`TimeoutException` → `AppFailure.offline`.
- `FirebaseAuthException` → per-code messages (`invalid-email`,
  `wrong-password`, `email-already-in-use`, etc.).
- `FirebaseFunctionsException` → first checks a custom `details.code` domain
  error (e.g. `otp/invalid`, `otp/expired`, `otp/used`, `otp/locked`,
  `order/badStatus`, `claim/alreadyResolved`), then falls back to generic
  gRPC-style codes (`unauthenticated`, `permission-denied`, ...).
- `FirebaseException` (Firestore/Storage) → per-code messages, with a
  separate branch for `firebase_storage` plugin errors (`unauthorized`,
  `quota-exceeded`, `object-not-found`, ...).
- Anything else → `AppFailure.unknown`, with the original error text kept in
  `debug`.

Every repository method wraps its body in `FailureMapper.guard(() async {
...})`, so screens only ever need to handle `AppFailure` — via
`describeFailure(error)` for a one-line message, or the shared
`lib/widgets/async_value_view.dart` / `state_views.dart` widgets for a full
error state with retry.
