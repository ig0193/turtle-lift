#!/usr/bin/env bash
# The whole TurtleLift QA suite, in order, on two iOS simulators. See
# .claude/skills/turtle-qa/SKILL.md for what each step proves and how to
# report the result.
#
#   tool/qa.sh                      # everything, iPhone 17e + 17 Pro Max
#   tool/qa.sh --fast               # static + unit/widget only (no simulator)
#   SKIP="taste maestro" tool/qa.sh # skip steps by name
#   DEVICES="iPhone 17e" tool/qa.sh # other simulators, by name
#
# Steps: analyze, test, test-tz, generated, sync, drift, integration, maestro,
# taste.
# Every step runs even when an earlier one fails; the summary at the end
# (and build/qa/summary.txt) says which failed. Exit status is non-zero if
# any did.
set -uo pipefail
cd "$(dirname "$0")/.."

fast=""
[ "${1:-}" = "--fast" ] && fast=1
skip=" ${SKIP:-} "
[ -n "$fast" ] && skip+=" integration maestro taste "
IFS=',' read -r -a names <<< "${DEVICES:-iPhone 17e,iPhone 17 Pro Max}"

mkdir -p build/qa
summary=build/qa/summary.txt
: > "$summary"
failed=0

run() { # <name> <command...>
  local name=$1; shift
  if [[ "$skip" == *" $name "* ]]; then
    printf '%-12s SKIP\n' "$name" | tee -a "$summary"
    return
  fi
  echo "==== $name: $*"
  local log=build/qa/$name.log
  if ( "$@" ) >"$log" 2>&1; then
    printf '%-12s PASS\n' "$name" | tee -a "$summary"
  else
    printf '%-12s FAIL  (see %s)\n' "$name" "$log" | tee -a "$summary"
    tail -20 "$log"
    failed=1
  fi
}

udid_of() {
  xcrun simctl list devices available \
    | grep -E "^\s+$1 \(" | head -1 | grep -oE '[0-9A-F-]{36}'
}

generated() {
  # The same checks as the CI generated-data job, then a diff that fails if
  # any generator rewrote a committed file.
  (cd assets/body-diagrams && python3 generate_muscle_taxonomy.py && python3 generate_body_paths.py) &&
  (cd assets/exercises && python3 validate_exercise_library.py ../body-diagrams .) &&
  (cd assets/foods && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -q test_validate_food_catalogue &&
     PYTHONDONTWRITEBYTECODE=1 python3 validate_food_catalogue.py) &&
  git diff --exit-code -- assets
}

drift() {
  dart run build_runner build && git diff --exit-code -- lib/src/data/app_database.g.dart
}

integration() {
  local rc=0
  for name in "${names[@]}"; do
    local udid; udid=$(udid_of "$name") || { echo "no simulator '$name'"; return 1; }
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" >/dev/null
    for t in integration_test/*_test.dart; do
      [ "$(basename "$t")" = taste_shots_test.dart ] && continue  # its own step
      echo "-- $name: $t"
      flutter drive --driver=test_driver/integration_test.dart --target="$t" -d "$udid" || rc=1
    done
  done
  return $rc
}

maestro_all() {
  local udids=()
  for name in "${names[@]}"; do udids+=("$(udid_of "$name")"); done
  tool/maestro_run.sh "${udids[@]}"
}

taste() {
  # Maestro's XCTest driver leaves the simulator's accessibility on, so iOS
  # keeps Flutter's semantics enabled and the next integration test fails on
  # "A SemanticsHandle was active at the end of the test". A reboot clears it.
  local u
  for name in "${names[@]}"; do
    u=$(udid_of "$name")
    xcrun simctl shutdown "$u" 2>/dev/null || true
    xcrun simctl boot "$u" 2>/dev/null || true
    xcrun simctl bootstatus "$u" >/dev/null
  done
  tool/taste_shots.sh "${names[@]}" || return 1
  # The largest system text size on the first device; the app clamps at 1.3x.
  local udid; udid=$(udid_of "${names[0]}")
  xcrun simctl ui "$udid" content_size accessibility-extra-extra-extra-large
  TASTE_SHOTS_DIR="build/taste_shots/${names[0]// /-}-largetext" flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/taste_shots_test.dart -d "$udid"
  local rc=$?
  xcrun simctl ui "$udid" content_size large
  return $rc
}

run analyze     flutter analyze
run test        flutter test
# Again in a zone with daylight saving: a local day is 23 or 25 hours twice a
# year there, which a machine in IST never shows (test/qa_dst_label_test.dart).
run test-tz     env TZ=America/New_York flutter test
run generated   generated
run sync        tool/sync_generated.sh --check
run drift       drift
run integration integration
run maestro     maestro_all
run taste       taste

echo
echo "==== QA summary (build/qa/summary.txt)"
cat "$summary"
[ -d build/maestro ] && for f in build/maestro/*/report.html; do echo "maestro report: $f"; done
exit $failed
