#!/usr/bin/env bash
# Gathers the files that are NOT on GitHub (app signing key) into ./handover-private
# and zips them into ./handover-private.zip so you can send them to a colleague.
# Both are listed in .gitignore, so they can never be committed.
#
# Run from the emtees_app repo root:   ./scripts/collect-private-files.sh
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=handover-private
rm -rf "$OUT" "$OUT.zip"
mkdir -p "$OUT/android/app"

cp android/key.properties "$OUT/android/key.properties"
cp android/app/upload-keystore.jks "$OUT/android/app/upload-keystore.jks"

cat > "$OUT/README-PRIVATE.txt" <<'EOF'
EMTEES APP - PRIVATE FILES (do NOT commit, do NOT post publicly)
==============================================================
Copy each file to the matching place INSIDE the cloned emtees_app repo:

  android/key.properties            ->  <repo>/android/key.properties
      Passwords and alias of the release signing key.

  android/app/upload-keystore.jks   ->  <repo>/android/app/upload-keystore.jks
      The app's SIGNING KEY. Every release APK is signed with it, and installed
      phones only accept updates signed with the SAME key. If this file is lost,
      existing users cannot be updated (they would have to uninstall first).
      Keep a backup in a safe place. Never replace it with a different key.

Without these two files the app still builds (it falls back to a debug key),
but that APK cannot update the installed production app.
EOF

zip -qr "$OUT.zip" "$OUT"
echo "Done."
echo "Folder: $(pwd)/$OUT"
echo "Zip   : $(pwd)/$OUT.zip   <- send this one"
