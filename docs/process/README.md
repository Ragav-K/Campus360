# Campus 360 docs

Campus 360 is a Flutter smart-campus utility app built on Firebase. It gives
students (and campus visitors signed in as guests) one app for:

- **Pulse** — live campus notices, crowd/availability status, alerts.
- **Map** — a campus location directory with offline tile caching and
  walking-path navigation between two points.
- **Lost & Found** — reporting lost/found items, on-device match suggestions,
  and a claim/handover flow.
- **Printout** — placing print-shop orders with a document upload, tracking
  their status.
- **Timetable** — per-section class timetables, academic calendar, exam
  schedules.
- Plus Auth, Profile, Notifications, and an Admin area (campus survey tool
  for recording map coordinates/paths).

Stack: Flutter, `flutter_riverpod` (state), `go_router` (navigation),
Firebase (`firebase_auth`, `cloud_firestore`, `firebase_storage`,
`firebase_messaging`, `cloud_functions`), `flutter_map` + `geolocator` for
offline maps, `file_picker`/`image_picker` for uploads.

## How these docs are organized

- **`docs/process/`** (this folder) — process documentation: how the app is
  built, how it's structured, and how each feature's end-to-end flow works.
  - [`development-workflow.md`](development-workflow.md) — setup, running,
    testing, project layout and conventions.
  - [`architecture.md`](architecture.md) — layering, Firebase wiring,
    routing, offline support, error handling.
  - [`features/`](features/) — one file per feature describing its flow from
    the user's perspective, naming the actual screens/providers/repositories
    involved:
    - [`auth.md`](features/auth.md)
    - [`campus-pulse.md`](features/campus-pulse.md)
    - [`campus-map.md`](features/campus-map.md)
    - [`lost-found.md`](features/lost-found.md)
    - [`printout.md`](features/printout.md)
    - [`timetable.md`](features/timetable.md)
    - [`notifications.md`](features/notifications.md)
    - [`admin.md`](features/admin.md)

- **`docs/code/`** — per-file reference documentation mirroring `lib/` and
  `test/`, one Markdown file per source file (maintained separately from this
  process documentation). Use it when you need details about a specific
  class or function; use the files in `docs/process/` when you need to
  understand *why* something is structured the way it is, or how a feature
  behaves end-to-end.

## Orientation for a new contributor

1. Read `development-workflow.md` to get the app running and understand the
   folder layout.
2. Read `architecture.md` for the big picture: how a screen gets data from
   Firestore, how errors are surfaced, how routing and the offline map work.
3. Pick the feature file under `features/` that matches what you're working
   on, and cross-reference `docs/code/` for file-level detail as needed.
