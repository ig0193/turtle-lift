#!/usr/bin/env bash
# Drives flow 11: an update from the last published build keeps the user's
# data and runs the v6 and v7 migrations.
#
#   .maestro/scripts/11_upgrade_from_v5.sh <udid> <out-dir>
#
# test/fixtures/schema_v5_from_5fcae5f.sqlite was written by commit 5fcae5f's
# own stores (schema 5): three saved workouts across all four load types, one
# open workout, two custom templates, a training plan, two weigh-ins and a
# body diagram choice. It is copied into the installed app's Documents as its
# database, with the app stopped, and the flow launches the current build on
# it -- what an App Store update does to a user's container.
#
# Proven once by hand with the real old binary as well (QA second pass): the
# 5fcae5f app was installed, read this file and wrote a title through its UI,
# then this build was installed over it without uninstalling.
set -uo pipefail
cd "$(dirname "$0")/../.."
export PATH="$HOME/.maestro/bin:$PATH"
udid=$1
out=$2
name=11_upgrade_from_v5
bundle=dev.indresh.turtleLift
mkdir -p "$out/junit" "$out/artifacts/$name"

xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
data=$(xcrun simctl get_app_container "$udid" "$bundle" data) || exit 1
mkdir -p "$data/Documents"
rm -f "$data/Documents/turtle_lift.sqlite" "$data/Documents/turtle_lift.sqlite-wal" \
  "$data/Documents/turtle_lift.sqlite-shm"
cp test/fixtures/schema_v5_from_5fcae5f.sqlite "$data/Documents/turtle_lift.sqlite"

maestro --device "$udid" test ".maestro/flows/$name.yaml" \
  --format junit --output "$out/junit/$name.xml" \
  --test-output-dir "$out/artifacts/$name"
