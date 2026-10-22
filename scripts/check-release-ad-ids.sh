#!/usr/bin/env bash
# Fails if the release ad configuration would ship Google's sample ids or ids that differ from config/admob.json.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CFG="$ROOT/config/admob.json"
DART="$ROOT/app/lib/data/ads_service.dart"
MANIFEST="$ROOT/app/android/app/src/main/AndroidManifest.xml"
SAMPLE="ca-app-pub-3940256099942544"
fail=0
app_id=$(python3 -c "import json;print(json.load(open('$CFG'))['app']['app_id'])")
grep -q "$app_id" "$MANIFEST" || { echo "FAIL: manifest app id is not $app_id"; fail=1; }
grep -q "$SAMPLE" "$MANIFEST" && { echo "FAIL: manifest uses the sample app id"; fail=1; }
for key in home_banner:_bannerReal break_interstitial:_interstitialReal challenge_rewarded:_rewardedReal; do
  unit=${key%%:*}; const=${key##*:}
  want=$(python3 -c "import json;print(json.load(open('$CFG'))['ad_units']['$unit']['id'])")
  grep -q "$const = '$want'" "$DART" || { echo "FAIL: $const is not $want"; fail=1; }
  case "$want" in $SAMPLE*) echo "FAIL: $unit in admob.json is a sample id"; fail=1;; esac
done
grep -q "kReleaseMode ? _bannerReal" "$DART" || { echo "FAIL: release builds do not select the real banner id"; fail=1; }
[ $fail = 0 ] && echo "OK: release ad ids match config/admob.json"
exit $fail
