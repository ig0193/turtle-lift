#!/usr/bin/env bash
# Drives flow 07: a diet reminder tap opens Profile -> Diet, warm and cold,
# and a training-day reminder tap opens the Workout tab (ADR 0008).
#
#   .maestro/scripts/07_reminder_deep_link.sh <udid> <out-dir>
#
# The notification is a local one in the app, scheduled for a real time of
# day, so a test cannot wait for it. Instead `xcrun simctl push` delivers a
# payload shaped like the plugin's own (flutter_local_notifications checks
# userInfo for NotificationId, presentAlert/Sound/Badge and payload before it
# routes a tap), carrying payload "diet/today" exactly as ReminderTarget does.
# What that proves: the app's tap routing, warm and cold, end to end through
# the plugin. What it does not: that iOS fires the scheduled local
# notification at 13:00 -- that needs a real device and a real clock.
#
# The banner is not in the accessibility tree and lasts less time than a
# fresh Maestro run takes to attach, so the push is requested from inside the
# tap sub-flow through push_server.py, and the banner is tapped by position.
set -uo pipefail
cd "$(dirname "$0")/../.."
export PATH="$HOME/.maestro/bin:$PATH"
udid=$1
out=$2
name=07_reminder_deep_link
apns=.maestro/scripts/diet_reminder.apns
mkdir -p "$out/junit" "$out/artifacts/$name"

# A localhost endpoint the tap sub-flow calls (Maestro JS http.post) to get
# a notification at the moment it is ready to tap the banner.
python3 -I .maestro/scripts/push_server.py "$udid" "$apns" 8765 \
  .maestro/scripts/training_reminder.apns &
server=$!
trap 'kill $server 2>/dev/null' EXIT
sleep 1

step() { # <label> <flow>
  local label=$1 flow=$2
  maestro --device "$udid" test "$flow" \
    --test-output-dir "$out/artifacts/$name/$label" >"$out/artifacts/$name/$label.log" 2>&1
  local rc=$?
  echo "   $label: $([ $rc -eq 0 ] && echo PASS || echo FAIL)"
  return $rc
}

failures=""
step setup .maestro/flows/$name.yaml || failures+="setup "
if [ -z "$failures" ]; then
  step warm .maestro/subflows/reminder_tap_banner.yaml || failures+="warm "
  step cold-prep .maestro/subflows/reminder_cold_prep.yaml || failures+="cold-prep "
  step cold .maestro/subflows/reminder_tap_banner.yaml || failures+="cold "
  step training .maestro/subflows/reminder_training_tap.yaml || failures+="training "
fi

# One JUnit case per leg, so the report shows warm and cold separately.
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo "<testsuite name=\"$name\" tests=\"3\">"
  for leg in warm cold training; do
    label="$leg start"
    [ "$leg" = training ] && label="training reminder opens Workout"
    echo "  <testcase name=\"07 Reminder tap deep link ($label)\">"
    if [[ " $failures" == *" setup "* || " $failures" == *" $leg "* || ( $leg == cold && " $failures" == *" cold-prep "* ) ]]; then
      echo "    <failure message=\"failed: ${failures}see artifacts/$name/*.log\"/>"
    fi
    echo "  </testcase>"
  done
  echo "</testsuite>"
} > "$out/junit/$name.xml"

[ -z "$failures" ]
