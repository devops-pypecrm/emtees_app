#!/usr/bin/env bash
# Build the Android APK and publish it to the Emtees server (shows up on /app and in-app "App Update").
#
# Usage:   ./scripts/publish_release.sh [versionName] [buildNumber] ["release notes"]
# Example: ./scripts/publish_release.sh 1.0.11 12 "Reports, salary, reschedule requests, App Update in sidebar"
#
# Needs: Flutter SDK + Android SDK on this machine, the EC2 key, and ssh access to the server.
# The publish secret is read from the server's .env over SSH, so you never type or store it locally.
set -euo pipefail

VERSION_NAME="${1:-1.0.11}"
BUILD_NUMBER="${2:-12}"
NOTES="${3:-Reports and salary for teachers, class report for students, reschedule requests, App Update in the sidebar.}"

PEM="${EMTEES_PEM:-$HOME/Projects/Emtees/emtees.pem}"
HOST="${EMTEES_HOST:-ubuntu@13.235.19.185}"
REMOTE_ENV="${EMTEES_REMOTE_ENV:-/home/ubuntu/emtees-api/server/.env}"
API="${EMTEES_API:-https://gecouncil.com}"
SSH="ssh -i $PEM -o StrictHostKeyChecking=no $HOST"

cd "$(dirname "$0")/.."

echo "=== 1/5 Setting version ${VERSION_NAME}+${BUILD_NUMBER} ==="
current=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
current_build="${current##*+}"
if [ "$BUILD_NUMBER" -le "$current_build" ] && [ "$current" != "${VERSION_NAME}+${BUILD_NUMBER}" ]; then
  echo "Build number $BUILD_NUMBER must be higher than current $current_build (devices only update to a higher build)." >&2
  exit 1
fi
sed -i.bak -E "s/^version: .*/version: ${VERSION_NAME}+${BUILD_NUMBER}/" pubspec.yaml && rm -f pubspec.yaml.bak

echo "=== 2/5 Building release APK ==="
flutter pub get
flutter build apk --release --dart-define-from-file=config/prod.json
APK="build/app/outputs/flutter-apk/app-release.apk"
[ -f "$APK" ] || { echo "APK not found at $APK" >&2; exit 1; }

echo "=== 3/5 Reading publish secret from the server (SSH) ==="
SECRET=$($SSH "grep -E '^RELEASE_PUBLISH_SECRET=' $REMOTE_ENV | cut -d= -f2- | tr -d '\"\r'" || true)
if [ -z "$SECRET" ]; then
  echo "RELEASE_PUBLISH_SECRET is not set in $REMOTE_ENV on the server."
  echo "Add it (e.g. RELEASE_PUBLISH_SECRET=$(openssl rand -hex 24)), then: pm2 restart emtees-api --update-env"
  exit 1
fi

echo "=== 4/5 Publishing to $API ==="
curl --fail-with-body -sS -X POST "$API/api/mobile/app-releases/publish" \
  -H "x-publish-secret: $SECRET" \
  -F platform=mobile \
  -F versionName="$VERSION_NAME" \
  -F versionCode="$BUILD_NUMBER" \
  -F "releaseNotes=$NOTES" \
  -F apk=@"$APK"
echo

echo "=== 5/5 Verifying ==="
curl -sS "$API/api/mobile/app-releases/latest?platform=mobile"
echo
echo "Done. Commit the version bump:  git add pubspec.yaml && git commit -m 'Release ${VERSION_NAME}+${BUILD_NUMBER}' && git push"
