# Build configuration profiles

Passed to Flutter via `--dart-define-from-file=config/<profile>.json`. Keys
must match `lib/core/config.dart`'s `String.fromEnvironment` names exactly:
`API_BASE_URL`, `SOCKET_BASE_URL`, `JITSI_SERVER_URL`.

- `dev.json` — Android emulator against a backend running on this machine
  (`10.0.2.2` is the emulator's alias for the host's `localhost`).
- `prod.json` — points at `https://gecouncil.com`, which nginx on the EC2
  box reverse-proxies to the Node server on `localhost:3000` (see
  `Emtees/DEPLOYMENT.md`). Real TLS, no cleartext exception needed.

Usage:
```
flutter run --dart-define-from-file=config/dev.json
flutter build apk --release --dart-define-from-file=config/prod.json
```
