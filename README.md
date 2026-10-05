# Campus360

Campus360 is a Flutter application for everyday campus services at KPR Institute of Engineering and Technology. It combines live campus updates, offline navigation, lost-and-found matching, print-order tracking, timetables, exam schedules, and notifications in one mobile application.

## Features

- Campus Pulse updates and live crowd levels
- Offline campus map with A* walking navigation
- Lost-and-found reporting, matching, claims, and handover confirmation
- Print-document uploads, deadline-aware queues, and order tracking
- Timetables, academic-calendar events, and exam schedules
- Firebase Authentication with student, staff, counter, and administrator roles
- Notification inbox and Firebase Cloud Messaging client support
- Web dashboard for crowd counters and print-shop staff

## Technology

- Flutter and Dart
- Riverpod for state management
- `go_router` for navigation
- Firebase Authentication, Firestore, Cloud Messaging, and Hosting
- Supabase Storage for print documents
- `flutter_map` with an offline tile cache

## Getting started

1. Install a compatible Flutter SDK and run `flutter pub get`.
2. Install Node.js 20 or newer and run `npm install` for the administrative tools.
3. Configure Firebase for Android and/or iOS with FlutterFire.
4. Enable Email/Password authentication and create the named Firestore database `default`.
5. Deploy the Firestore rules and indexes described in [SETUP.md](SETUP.md).
6. Run `flutter run`.

The project intentionally uses a Firestore database named `default`, which is different from Firebase's conventional `(default)` database. Read [SETUP.md](SETUP.md) before changing Firebase configuration.

## Documentation

- [Project status](PROJECT_STATUS.md) — implemented functionality, pending setup, and known limits
- [Architecture](ARCHITECTURE.md) — original architecture and design rationale
- [Setup](SETUP.md) — Firebase configuration and deployment instructions
- [Developer documentation](docs/process/README.md) — feature and code documentation

## Validation

```bash
flutter analyze
flutter test
npm test
```

Some Firebase rule checks require project credentials and access to the configured Firebase project. Never commit service-account files or local environment files.

## Security notes

Authorization is enforced by Firestore and Storage rules rather than UI route guards. Firebase client configuration is intentionally present in the application, as required by Firebase clients; administrative credentials and service-account keys must remain outside the repository.

Print documents use public, unguessable Supabase object URLs because the current deployment does not include a trusted application server. See `PROJECT_STATUS.md` for the associated limitation.
