# Emtees App — Mobile App Handover (Flutter)

This document is for a developer taking over the **Emtees Academy mobile app** (teachers and students). The
backend and web portal live in a separate repository, `Emtees`, which has its own `HANDOVER.md`.

> **No secrets are written in this file.** The app signing key and its passwords come separately in the
> private bundle (`handover-private.zip`). See [Signing](#6-signing-private-files).

---

## 1. What the app does

- **Students:** schedule, join live classes and 1-to-1 sessions (video via Jitsi), **incoming-call prompt** when
  the teacher starts a session, chat, community, materials, attendance, fees/payments view, discipline,
  feedback, and their own **class report** (classes taken / pending, active or inactive, recent sessions).
- **Teachers:** today's classes, start group classes and 1-to-1 sessions, approve students into group classes,
  reschedule requests, and **My Reports**: *Today*, *Sessions* (per-session minutes and join/leave times),
  *Date range* (daily completed / pending / invalid / absent) and *Salary* (monthly earnings).
- **Admins / academic heads** do not use the app for reports: they see a "available on the web portal" message.
- **In-app updates:** the app checks the server for a newer APK and offers to install it
  (sidebar → *App Update*).

Android only is supported and tested. `ios/` exists but iOS has never been built or tested (see
[Known gaps](#10-known-gaps)).

## 2. Tech stack

| Area | Choice |
|---|---|
| Framework | Flutter 3.44.9 (stable), Dart 3.12.2 (`sdk: ^3.12.2`) |
| State management | `flutter_riverpod` |
| Navigation | `go_router` (routes in `lib/core/router.dart`) |
| HTTP | `dio` through `lib/core/api_client.dart` (adds the login token and `x-client-platform: mobile`) |
| Realtime | `socket_io_client` (`lib/features/realtime/socket_service.dart`) |
| Video calls | `jitsi_meet_flutter_sdk` (`lib/features/call/call_screen.dart`) |
| Storage | `flutter_secure_storage` (login token), `shared_preferences` |
| Package id | `com.emtees.emtees_app`, `minSdk 26` |

## 3. Code map

```
lib/
  main.dart
  core/            api_client, config (build-time URLs), router, theme, main_shell (drawer + tabs + incoming-call listener)
  models/          plain data classes (user, class_item, one_to_one_session, release_manifest, ...)
  features/
    auth/          login, token, current user
    classes/       home/schedule, class detail, join/start, reschedule requests, repository for class API
    call/          call_screen.dart (Jitsi), incoming_call_dialog.dart (full-screen "incoming class call")
    reports/       reports_screen.dart (teacher tabs + student report), reports_repository.dart
    realtime/      Socket.IO event stream
    updates/       in-app APK update (download + install)
    chat/ community/ materials/ discipline/ performance/ notifications/ profile/ me/
config/            dev.json, prod.json (build-time URLs, no secrets)
scripts/           publish_release.sh, collect-private-files.sh
```

The REST API the app calls is mounted on the backend at `/api/mobile` (see `server/src/routers/mobile.ts` in the
`Emtees` repo). Role rules are enforced on the server; the app only hides things.

## 4. Prerequisites (Windows)

1. **Flutter SDK 3.44.x stable** — https://docs.flutter.dev/get-started/install/windows. Check with `flutter --version`
   (the project expects Dart 3.12.2; a different Flutter channel/version may need small adjustments).
2. **Android Studio** (installs the Android SDK, platform tools and an emulator). In *SDK Manager* install an
   Android SDK Platform, Build-Tools and **Command-line Tools**, then run `flutter doctor --android-licenses`.
3. **JDK 17 or newer.** The previous developer used JDK 21. Android Studio's bundled JDK works.
4. **Git**.
5. Run `flutter doctor` until the Android toolchain shows green. VS Code or Android Studio as the editor.
6. For a real phone: enable *Developer options → USB debugging*.

## 5. Get the code and run

```powershell
git clone <emtees_app repo url>
cd emtees_app
flutter pub get
```

The backend address is chosen **at build time** with a JSON file (see `config/README.md`):

| File | Backend it points to | When to use |
|---|---|---|
| `config/prod.json` | `https://gecouncil.com` (the live system) | Testing against production; release builds |
| `config/dev.json` | `http://10.0.2.2:3000` (the Android **emulator's** name for your PC's localhost) | Emulator + backend running on your PC (`npm run dev` in the `Emtees` repo) |

```powershell
# Emulator or phone, against production
flutter run --dart-define-from-file=config/prod.json

# Emulator, against a backend on your own PC
flutter run --dart-define-from-file=config/dev.json
```

A **physical phone** cannot use `10.0.2.2`. Make a copy of `dev.json` (e.g. `config/local.json`) with your PC's
LAN address, e.g. `"API_BASE_URL": "http://192.168.1.10:3000/api/mobile"` and `"SOCKET_BASE_URL": "http://192.168.1.10:3000"`
(phone and PC on the same Wi-Fi, Windows firewall allowing port 3000). Plain `http` is only for development.

Video calls use the live Jitsi server (`JITSI_SERVER_URL`) in every profile.

**Test logins** are in the private bundle (`README-PRIVATE.txt`). Logging in against production creates real
records (attendance, notifications), so prefer a local backend for experiments.

## 6. Signing (private files)

Release APKs are signed with an **upload keystore** that is intentionally **not** on GitHub:

| File (from the private bundle) | Copy to |
|---|---|
| `android/key.properties` | `<repo>/android/key.properties` |
| `android/app/upload-keystore.jks` | `<repo>/android/app/upload-keystore.jks` |

`key.properties` has `storePassword`, `keyPassword`, `keyAlias` and `storeFile=upload-keystore.jks`
(the path is relative to `android/app/`, so it works on Windows unchanged).

> **Do not lose or replace the keystore.** Installed phones only accept an update signed with the same key. If
> it is lost, every user must uninstall and reinstall. Keep a private backup.

Without these files `android/app/build.gradle.kts` falls back to the **debug** key, so `flutter run --release`
and builds still work on a fresh checkout — but that APK cannot update the installed production app.

Some files are auto-generated and not in Git; Flutter recreates them on the first build:
`android/local.properties` (your SDK path), `.dart_tool/`, `build/`, `GeneratedPluginRegistrant`.
If `android/gradlew` is missing, run `flutter create --platforms=android .` once (it does not overwrite your code).

## 7. Build a release APK

```powershell
flutter build apk --release --dart-define-from-file=config/prod.json
```

Output: `build\app\outputs\flutter-apk\app-release.apk` (~143 MB, it contains the Jitsi native libraries).

**Version rule:** `pubspec.yaml → version: 1.0.14+15` — the part before `+` is the visible version, the number
after `+` is the build number. Phones only update to a **higher build number**, so always increase it.

## 8. Publish a release to users

The server holds the "latest" APK; installed apps find it through `GET /api/mobile/app-releases/latest`.

**Option A — script (Git Bash or macOS/Linux):** `./scripts/publish_release.sh 1.0.15 16 "Release notes"`.
It bumps the version, builds, publishes, verifies. It reads `RELEASE_PUBLISH_SECRET` from the server's `.env`
over SSH, and **that secret is not set yet**, so the script stops with a message. Set the secret on the server
first (instructions in the `Emtees` repo's `HANDOVER.md`), or use option B. Edit `PEM`/`HOST` at the top of the
script (or the `EMTEES_PEM` / `EMTEES_HOST` variables) for your machine; the host is currently `13.235.121.148`.

**Option B — manual (works today):** bump the version in `pubspec.yaml`, build, then:

```bash
curl -X POST https://gecouncil.com/api/mobile/app-releases/publish \
  -F platform=mobile -F versionName=1.0.15 -F versionCode=16 \
  -F "releaseNotes=What changed" \
  -F apk=@build/app/outputs/flutter-apk/app-release.apk
curl https://gecouncil.com/api/mobile/app-releases/latest      # must show the new version
```

(Add `-H "x-publish-secret: <secret>"` once `RELEASE_PUBLISH_SECRET` is configured.) Then commit the
`pubspec.yaml` change. Users see the update in the app sidebar → *App Update*; a web download page exists at
`/app` on the website.

## 9. How calls and attendance work (app side)

- Teacher taps **Start** → backend marks the class live and sends a realtime event.
  Students get a **full-screen incoming-call prompt** (`incoming_call_dialog.dart`) wherever they are in the app
  (hosted in `core/main_shell.dart`). It only shows while the app is open and connected.
- `call_screen.dart` joins the Jitsi room with a token fetched from the backend. When the call is joined, it
  calls `POST /one-to-one/:id/presence` or `/classes/:id/presence` with `join`, and with `leave` when the call
  ends or the screen closes. For 1-to-1 sessions it also sends a heartbeat every 60 s.
- The server uses these times to decide if the class is **valid (20 minutes minimum for both teacher and
  student)** and to build attendance, credits and salary. Details are in the `Emtees` handover.
- If the teacher's connection drops, the server waits 5 minutes for a rejoin before ending the class.

## 10. Known gaps

- **iOS is untested.** Building iOS needs a Mac, Xcode and an Apple developer account; the Jitsi iOS SDK and
  permissions have not been set up.
- **No push notifications.** Nothing rings the phone when the app is closed. This needs Firebase Cloud Messaging
  and a native call UI.
- **Video lag** was reported during calls; the cause is on the Jitsi server side (checks listed in the `Emtees`
  handover).
- **The attendance/report flow needs one real end-to-end test** (≈25-minute 1-to-1 session on app 1.0.14).
- Some Gradle/Kotlin warnings appear from the Jitsi plugin; they do not block builds.

## 11. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| "Unfortunately an error occurred, retrying…" when joining a call | Jitsi videobridge problem on the server (public IP in `jvb.conf` wrong, or no bridge). See Emtees handover §10. |
| My Reports shows an error / empty | App older than 1.0.13, or the backend is not deployed with the `/reports` routes. |
| Login fails on an emulator against your local backend | You used `prod.json`, or the backend isn't running on :3000. Use `dev.json`. |
| `Unable to locate Android SDK` | Install it via Android Studio and run `flutter config --android-sdk <path>`. |
| Installing an update does nothing | The phone must allow "Install unknown apps" for the Emtees app; keystore must be the same one as the installed version. |
| Release build is not signed with the real key | `android/key.properties` or the `.jks` is missing (see §6). |
