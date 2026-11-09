#!/usr/bin/env bash
# Builds a debug simulator TurtleLift, installs it on one or more iOS
# simulators and runs every Maestro flow in .maestro/ against each.
#
#   tool/maestro_run.sh                       # iPhone 17e + iPhone 17 Pro Max
#   tool/maestro_run.sh <udid> [<udid> ...]   # any booted simulators
#   NO_BUILD=1 tool/maestro_run.sh ...        # reuse build/maestro/Runner.app
#   FLOWS="01 05" tool/maestro_run.sh ...     # only flows whose name has 01/05
#
# The build passes --dart-define=TURTLE_NO_SEED=true so a debug install starts
# empty (the debug sample seed would otherwise fill History and Diet), and
# every flow begins with `launchApp: clearState: true`.
#
# Two flows need the host shell between Maestro steps, which Maestro cannot
# run itself, so this script drives them as a sequence of sub-flows:
#   reminder deep link   -- `xcrun simctl push` a payload the notification
#                           plugin accepts, then a flow taps the banner.
#   relaunch persistence -- covered inside the flows by stopApp/launchApp.
#
# Output per device: build/maestro/<device>/
#   junit.xml      every flow, JUnit
#   report.html    the same, as a page
#   artifacts/     Maestro's screenshots and logs for failures
#   app.log        the app's log stream during the run (exceptions show here)
set -uo pipefail
cd "$(dirname "$0")/.."

export PATH="$HOME/.maestro/bin:$PATH"
command -v maestro >/dev/null || {
  echo "maestro not found; install: curl -fsSL https://get.maestro.mobile.dev | bash" >&2
  exit 2
}

BUNDLE=dev.indresh.turtleLift
# The unseeded build is kept as its own copy: `flutter drive` (integration
# tests, taste shots) rebuilds build/ios/iphonesimulator/Runner.app as a
# seeded test app, and NO_BUILD must never install that by mistake.
APP=build/maestro/Runner.app

udids=("$@")
if [ ${#udids[@]} -eq 0 ]; then
  for name in "iPhone 17e" "iPhone 17 Pro Max"; do
    u=$(xcrun simctl list devices available \
      | grep -E "^\s+${name} \(" | head -1 | grep -oE '[0-9A-F-]{36}' || true)
    [ -n "$u" ] && udids+=("$u")
  done
fi
[ ${#udids[@]} -eq 0 ] && { echo "no simulators found" >&2; exit 2; }

if [ -z "${NO_BUILD:-}" ]; then
  flutter build ios --simulator --debug --dart-define=TURTLE_NO_SEED=true || exit 1
  mkdir -p build/maestro && rm -rf "$APP" && cp -R build/ios/iphonesimulator/Runner.app "$APP"
fi
[ -d "$APP" ] || { echo "no $APP; run without NO_BUILD" >&2; exit 2; }

# Flows that run as plain Maestro flows, in name order.
flows=()
for f in .maestro/flows/*.yaml; do
  if [ -n "${FLOWS:-}" ]; then
    keep=""
    for pat in $FLOWS; do [[ "$(basename "$f")" == *"$pat"* ]] && keep=1; done
    [ -z "$keep" ] && continue
  fi
  flows+=("$f")
done

overall=0
for udid in "${udids[@]}"; do
  name=$(xcrun simctl list devices | grep "$udid" | sed -E 's/^ +//; s/ \(.*//' | head -1)
  out="build/maestro/${name// /-}"
  rm -rf "$out"; mkdir -p "$out/artifacts" "$out/junit"
  echo "== $name ($udid) -> $out"

  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" >/dev/null
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged \
    --batteryLevel 100 --cellularBars 4 --wifiBars 3 2>/dev/null || true
  xcrun simctl uninstall "$udid" "$BUNDLE" 2>/dev/null || true
  xcrun simctl install "$udid" "$APP" || { overall=1; continue; }

  # The app's own log, so a Flutter exception during a flow is on record
  # even when the flow itself passes.
  xcrun simctl spawn "$udid" log stream --level debug \
    --predicate 'process == "Runner"' > "$out/app.log" 2>&1 &
  logpid=$!

  for f in "${flows[@]}"; do
    base=$(basename "$f" .yaml)
    echo "-- $base"
    # Notification permission is reset per flow so the opt-in flow always
    # meets the system prompt; flows that need it granted grant it.
    xcrun simctl privacy "$udid" reset all "$BUNDLE" 2>/dev/null || true
    if [ -x ".maestro/scripts/$base.sh" ]; then
      ".maestro/scripts/$base.sh" "$udid" "$out" || overall=1
    else
      maestro --device "$udid" test "$f" \
        --format junit --output "$out/junit/$base.xml" \
        --test-output-dir "$out/artifacts/$base" || overall=1
      # A flow that fails to parse writes no JUnit; record it as a failure
      # rather than letting it vanish from the report.
      [ -s "$out/junit/$base.xml" ] || cat > "$out/junit/$base.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="$base" tests="1"><testcase name="$base"><failure message="no result: the flow did not run (parse error?) - see artifacts/$base"/></testcase></testsuite>
EOF
    fi
  done

  kill "$logpid" 2>/dev/null
  xcrun simctl status_bar "$udid" clear 2>/dev/null || true
  python3 -I tool/maestro_report.py "$out" || overall=1
  grep -nE "EXCEPTION CAUGHT|Unhandled Exception|FlutterError|RenderFlex overflowed" \
    "$out/app.log" > "$out/app-exceptions.txt" && {
      echo "!! app logged exceptions on $name, see $out/app-exceptions.txt"
      overall=1
    }
done
exit $overall
