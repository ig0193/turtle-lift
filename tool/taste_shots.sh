#!/usr/bin/env bash
# Screenshots TurtleLift's main screens on a small and a large iPhone simulator,
# for the `turtle-taste` design audit. The Flutter stand-in for the web taste
# skill's headless-Chrome checks at several widths.
#
#   tool/taste_shots.sh                 # iPhone 17e + iPhone 17 Pro Max
#   tool/taste_shots.sh "iPhone 17"     # any simulator names you pass
#
# Output: build/taste_shots/<device>/NN-<screen>.png
set -euo pipefail
cd "$(dirname "$0")/.."

devices=("$@")
[ ${#devices[@]} -eq 0 ] && devices=("iPhone 17e" "iPhone 17 Pro Max")

for name in "${devices[@]}"; do
  udid=$(xcrun simctl list devices available \
    | grep -E "^\s+${name} \(" | head -1 | grep -oE '[0-9A-F-]{36}' || true)
  if [ -z "$udid" ]; then
    echo "no available simulator named '$name'" >&2
    exit 1
  fi
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" >/dev/null

  out="build/taste_shots/${name// /-}"
  rm -rf "$out"
  echo "== $name ($udid) -> $out"
  TASTE_SHOTS_DIR="$out" flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/taste_shots_test.dart \
    -d "$udid"
done
