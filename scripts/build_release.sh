#!/usr/bin/env bash
# Builds the signed release AAB (for Play) and APK (for sideload testing).
#
#   bash scripts/build_release.sh
#
# Signing: app/android/key.properties -> .secrets/moduleup-upload.keystore (both gitignored).
# Gates: R&W and Math content validate, only checked/approved items ship, 10 papers per section present, release ad ids
# are the real ones, tests pass, APK signed with the HomiLabs upload key (not the debug key).
# Follows ~/.claude/heavy-jobs.md: needs >= 4 GiB available memory; stops the Gradle daemon after.
set -euo pipefail
cd "$(dirname "$0")/.."

avail=$(free -g | awk '/^Mem:/{print $7}')
[ "$avail" -ge 4 ] || { echo "Only ${avail} GiB available; a release build needs 4 GiB. Close something first."; exit 1; }
[ -f app/android/key.properties ] || { echo "Missing app/android/key.properties (see .secrets/README.txt)"; exit 1; }

python3 pipeline/validate.py --quiet
python3 pipeline/validate_math.py --quiet
python3 pipeline/build_packs.py
forms=$(python3 -c "import json;print(json.load(open('app/assets/data/manifest.json'))['forms'])")
[ "$forms" -ge 10 ] || { echo "FAIL: only $forms releasable papers in the pack (need 10)"; exit 1; }
mforms=$(python3 -c "import json;print(len(json.load(open('app/assets/data/math_bank.json'))['forms']))")
[ "$mforms" -ge 10 ] || { echo "FAIL: only $mforms releasable Math papers in the pack (need 10)"; exit 1; }
bash scripts/check-release-ad-ids.sh

cd app
flutter test --exclude-tags preview
VERSION="$(sed -n 's/^version: //p' pubspec.yaml)"
OUT="../releases/v${VERSION/+/-}"
flutter build appbundle --release
flutter build apk --release
mkdir -p "$OUT"
cp build/app/outputs/bundle/release/app-release.aab "$OUT/moduleup-${VERSION/+/-}.aab"
cp build/app/outputs/flutter-apk/app-release.apk "$OUT/moduleup-${VERSION/+/-}.apk"

APKSIGNER="$(ls -d "$HOME"/Android/Sdk/build-tools/*/ | tail -1)apksigner"
CERT="$("$APKSIGNER" verify --print-certs "$OUT/moduleup-${VERSION/+/-}.apk")"
grep -q "CN=HomiLabs" <<<"$CERT" || { echo "FAIL: release APK is not signed with the HomiLabs upload key"; exit 1; }
if grep -q "CN=Android Debug" <<<"$CERT"; then echo "FAIL: release APK is signed with the debug key"; exit 1; fi
(cd android && ./gradlew --stop >/dev/null 2>&1 || true)
ls -la "$OUT"
echo "Release ready in $OUT"
