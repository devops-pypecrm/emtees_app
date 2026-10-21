#!/usr/bin/env bash
# Build the Android release APK and publish it to the Emtees server
# (users then get it via the in-app "App Update" and the /app download page).
#
# Usage:
#   ./scripts/publish_release.sh <versionName> <buildNumber> "<release notes>" [--skip-build] [--dry-run]
#
# Examples:
#   ./scripts/publish_release.sh 1.0.16 17 "Fixed the call screen"      # bump version, build, publish
#   ./scripts/publish_release.sh 1.0.16 17 "Fixed the call screen" --dry-run   # only run the safety checks
#   ./scripts/publish_release.sh 1.0.16 17 "Fixed the call screen" --skip-build  # publish the APK already built
#
# The buildNumber MUST be higher than the one currently published (phones only update to a higher number).
#
# Needs: Flutter + Android SDK (unless --skip-build), the server SSH key, and the signing files
#        android/key.properties + android/app/upload-keystore.jks (see HANDOVER.md).
#        The publish password is read from the server's .env over SSH, so you never type or store it.
#
# Settings (environment variables, all optional):
#   EMTEES_KEY       path to the SSH key (default: first of ../Emtees/emtees.pem, ~/Projects/Emtees/emtees.pem, ~/.ssh/emtees.pem)
#   EMTEES_HOST      server host      (default: gecouncil.com)
#   EMTEES_USER      SSH user         (default: ubuntu)
#   EMTEES_API       public base URL  (default: https://gecouncil.com)
#   EMTEES_REMOTE_ENV  server .env path (default: /home/ubuntu/emtees-api/server/.env)
set -euo pipefail

SKIP_BUILD=false; DRY_RUN=false; ARGS=()
for a in "$@"; do
  case "$a" in
    --skip-build) SKIP_BUILD=true ;;
    --dry-run)    DRY_RUN=true ;;
    -h|--help)    sed -n 2,22p "$0"; exit 0 ;;
    *)            ARGS+=("$a") ;;
  esac
done
if [ "${#ARGS[@]}" -lt 3 ]; then
  echo "Usage: $0 <versionName> <buildNumber> \"<release notes>\" [--skip-build] [--dry-run]" >&2
  echo "Example: $0 1.0.16 17 \"What changed\"" >&2
  exit 1
fi
VERSION_NAME="${ARGS[0]}"; BUILD_NUMBER="${ARGS[1]}"; NOTES="${ARGS[2]}"
case "$BUILD_NUMBER" in ''|*[!0-9]*) echo "buildNumber must be a whole number, got '$BUILD_NUMBER'" >&2; exit 1 ;; esac

HOST="${EMTEES_HOST:-gecouncil.com}"
USER_="${EMTEES_USER:-ubuntu}"
API="${EMTEES_API:-https://gecouncil.com}"
REMOTE_ENV="${EMTEES_REMOTE_ENV:-/home/ubuntu/emtees-api/server/.env}"

cd "$(dirname "$0")/.."
REPO="$(pwd)"

# --- locate the SSH key ---
KEY="${EMTEES_KEY:-}"
if [ -z "$KEY" ]; then
  for c in "$REPO/../Emtees/emtees.pem" "$HOME/Projects/Emtees/emtees.pem" "$HOME/.ssh/emtees.pem"; do
    [ -f "$c" ] && { KEY="$c"; break; }
  done
fi
[ -n "$KEY" ] && [ -f "$KEY" ] || { echo "SSH key not found. Set EMTEES_KEY=/path/to/emtees.pem" >&2; exit 1; }
SSH="ssh -i $KEY -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new $USER_@$HOST"

APK="build/app/outputs/flutter-apk/app-release.apk"
current_local=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')

echo "=== 1/6 Pre-flight checks ($API, server $USER_@$HOST) ==="
published=$(curl -fsS -m 20 "$API/api/mobile/app-releases/latest?platform=mobile" 2>/dev/null || true)
published_code=$(printf '%s' "$published" | grep -o '"versionCode":[0-9]*' | head -1 | cut -d: -f2 || true)
published_name=$(printf '%s' "$published" | grep -o '"versionName":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
[ -n "$published_code" ] && echo "Currently published: ${published_name} (build ${published_code})" || echo "Could not read the currently published release (continuing)."
if [ -n "$published_code" ]; then
  if [ "$BUILD_NUMBER" -lt "$published_code" ] || { [ "$BUILD_NUMBER" -eq "$published_code" ] && ! $SKIP_BUILD; }; then
    echo "Build number $BUILD_NUMBER must be HIGHER than the published $published_code (use --skip-build to re-publish the same one)." >&2
    exit 1
  fi
fi
if ! $SKIP_BUILD; then
  command -v flutter >/dev/null || { echo "flutter not found in PATH" >&2; exit 1; }
  [ -f android/key.properties ] && [ -f android/app/upload-keystore.jks ] || {
    echo "Signing files missing (android/key.properties, android/app/upload-keystore.jks)." >&2
    echo "Without them the APK is signed with a debug key and CANNOT update installed apps. See HANDOVER.md." >&2
    exit 1; }
fi
SECRET=$($SSH "grep -E '^RELEASE_PUBLISH_SECRET=' $REMOTE_ENV | cut -d= -f2- | tr -d '\"\r'" || true)
if [ -z "$SECRET" ]; then
  echo "If you saw 'REMOTE HOST IDENTIFICATION HAS CHANGED', the server was replaced. If you expect that, run: ssh-keygen -R $HOST" >&2
  echo "RELEASE_PUBLISH_SECRET is not set in $REMOTE_ENV on the server (or SSH failed)." >&2
  echo "Fix: ssh in, add RELEASE_PUBLISH_SECRET=<random> to that file, then: pm2 restart emtees-api --update-env" >&2
  exit 1
fi
echo "OK: SSH works, publish password found on the server, key = $KEY"

if $DRY_RUN; then
  echo "DRY RUN: would set version ${VERSION_NAME}+${BUILD_NUMBER}, $($SKIP_BUILD && echo 'use the existing APK' || echo 'build the release APK'), publish, and verify. Nothing changed."
  exit 0
fi

echo "=== 2/6 Version ${VERSION_NAME}+${BUILD_NUMBER} ==="
if $SKIP_BUILD; then
  [ "$current_local" = "${VERSION_NAME}+${BUILD_NUMBER}" ] || { echo "--skip-build: pubspec.yaml says $current_local but you asked for ${VERSION_NAME}+${BUILD_NUMBER}; the existing APK would be mislabelled." >&2; exit 1; }
  [ -f "$APK" ] || { echo "No APK at $APK to publish." >&2; exit 1; }
  echo "Using the existing APK ($(du -h "$APK" | cut -f1))."
else
  sed -i.bak -E "s/^version: .*/version: ${VERSION_NAME}+${BUILD_NUMBER}/" pubspec.yaml && rm -f pubspec.yaml.bak
  echo "pubspec.yaml -> ${VERSION_NAME}+${BUILD_NUMBER}"

  echo "=== 3/6 Building release APK ==="
  flutter pub get
  flutter build apk --release --dart-define-from-file=config/prod.json
  [ -f "$APK" ] || { echo "APK not found at $APK" >&2; exit 1; }
fi

echo "=== 4/6 Publishing to $API ==="
curl --fail-with-body -sS -m 900 -X POST "$API/api/mobile/app-releases/publish" \
  -H "x-publish-secret: $SECRET" \
  -F platform=mobile \
  -F versionName="$VERSION_NAME" \
  -F versionCode="$BUILD_NUMBER" \
  -F "releaseNotes=$NOTES" \
  -F apk=@"$APK"
echo

echo "=== 5/6 Verifying ==="
latest=$(curl -fsS -m 20 "$API/api/mobile/app-releases/latest?platform=mobile")
echo "$latest" | head -c 200; echo
echo "$latest" | grep -q "\"versionCode\":${BUILD_NUMBER}" || { echo "VERIFY FAILED: server does not report build ${BUILD_NUMBER}" >&2; exit 1; }
size=$(curl -sI -m 20 "$API/api/mobile/app-releases/download/mobile" | tr -d '\r' | awk -F': ' 'tolower($1)=="content-length"{print $2}')
echo "Download size reported by server: ${size:-unknown} bytes"

echo "=== 6/6 Done ==="
echo "Published ${VERSION_NAME} (build ${BUILD_NUMBER}). Commit the version bump:"
echo "  git add pubspec.yaml && git commit -m 'Release ${VERSION_NAME}+${BUILD_NUMBER}' && git push"
