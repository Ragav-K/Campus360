# Campus360 — Setup (Phase 1)

## ✅ Already done

- **Flutter 3.44.9** (Dart 3.12.2) installed and available on `PATH`
- **Android SDK platform 36** installed (build-tools 36.1.0 and licences were
  already in place) — `flutter doctor` Android check passes
- Native `android/` and `ios/` folders generated
- `flutter pub get` resolved; `flutter analyze` clean apart from the Firebase
  config below; `flutter test` — 8/8 passing

`flutter doctor` status: Flutter ✓ · Android ✓ · Chrome ✓ · Devices ✓ ·
**Xcode ✗** (see "iOS" at the bottom — not needed for Android development)

## ⚠️ This project uses a NAMED Firestore database

The database is named **`default`** — *not* Firestore's conventional
**`(default)`** (with parentheses). They are different database IDs.

Consequences, both already handled:

- `FirebaseFirestore.instance` targets `(default)`, which **does not exist**
  here and fails every call with `NOT_FOUND`. All Firestore access must go
  through `firestoreProvider` / `campus360Firestore` in
  `lib/core/services/firebase_providers.dart`, which binds to the named
  database. Never use `FirebaseFirestore.instance` directly.
- `firebase.json` sets `"firestore": { "database": "default" }` so rules and
  indexes deploy to the right place.

To switch to the conventional `(default)` later you would delete this database
and create `(default)` — creating a *second* database requires the Blaze plan.

## 1. Firebase project ← **done**

The only thing blocking the app from running. `flutterfire_cli` is installed.

Sign in to the Firebase CLI with an account that can access the project:

```bash
firebase logout && firebase login
```

Then create and wire up the project:

```bash
flutterfire configure
```

Choose **"Create a new project"**, name it `campus360`, and select the
**android** and **ios** platforms when prompted.

This generates `lib/firebase_options.dart`, which `main.dart` already imports.
**The app will not compile until this file exists** — that is the only
remaining `flutter analyze` error, and it is expected.

In the Firebase console, enable:
- **Authentication** → Sign-in method → Email/Password
- **Cloud Firestore** → create database (production mode)
- **Storage** → create bucket
- **Cloud Messaging** (no setup needed yet; used in Phase 3)

## 2. Deploy the rules

```bash
firebase deploy --only firestore:rules
```

The Phase 1 rules deny everything except `users/{uid}` (self) and `config/*`
(public read). This is intentional — each module opens its own paths as it is
built, so an unfinished feature is never publicly writable.

## 3. Seed the config document

Create `config/app` in Firestore:

```jsonc
{
  "allowedEmailDomains": ["yourcollege.edu"],
  "requireCollegeEmail": false,     // flip to true once you've confirmed the domain
  "maxUploadMb": 20,
  "functionsEnabled": false         // no Cloud Functions deployed yet
}
```

Leaving `requireCollegeEmail` false lets you register test accounts with any
address while developing. The app reads this live — no rebuild needed to change it.

## 4. Run

```bash
flutter run
```

## iOS (optional, later)

Xcode is not fully installed, so iOS builds are unavailable. Android is
unaffected. When you want iOS:

1. Install Xcode from the App Store (~15 GB — note this Mac is at 94% disk usage,
   so free space first)
2. `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
3. `sudo xcodebuild -runFirstLaunch`
4. `sudo gem install cocoapods`

Steps 2–4 need your admin password, so you'll have to run them yourself.

## What works right now (Phase 1)

- Splash → login / register / forgot-password, with real validation and
  plain-language error messages for every Firebase auth error code
- Registration creates `users/{uid}` with `role: student` and sends a
  verification email
- Session persists across restarts; the router holds on splash until auth
  state resolves (no login-screen flash)
- Four-tab shell with light + dark theme following the system setting
- Sign-out clears the session

The four tabs currently show an honest "not built yet — arrives in Phase N"
state. They are not mocks and contain no dead buttons.

## Not yet built

Pulse, Map, Lost & Found, Printout, notifications, profile, admin/staff
dashboards, Cloud Functions (OTP, matching, notifications). See
[ARCHITECTURE.md](ARCHITECTURE.md) §10 for the phase plan.

## Print documents live in Supabase, not Firebase Storage

Firebase Storage requires the **Blaze** plan, which this project does not have — the console shows
"To use Storage, upgrade your project's pricing plan" and no bucket can be created. Print documents
therefore go to **Supabase Storage** (free tier, no card). Everything else — Auth, Firestore,
Hosting — is still Firebase.

- Project: `https://hbiydchrsbhekqwzcwcs.supabase.co`
- Bucket: `print-docs`, **public**, Mumbai region
- Code: `lib/core/services/document_storage.dart`

The bucket's only write policy:

```sql
create policy "campus360 upload print docs"
on storage.objects for insert to anon
with check (bucket_id = 'print-docs');
```

Insert only — no update, no delete, no other bucket. Verified by attack (all return 400), and
listing the bucket returns `[]`, so object paths cannot be enumerated. Privacy rests on the
128-bit `Random.secure()` segment in each path; see the class docs for the full reasoning.

The `anon` key is committed on purpose: it ships in every APK regardless, and the policy above is
what actually constrains it. The **`service_role`** key must never appear in this repo.
