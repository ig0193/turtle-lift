#!/usr/bin/env bash
# Generated Dart data lives in assets/ next to its generator, but Dart can only
# import from lib/. This copies it across. Never hand-edit either copy: change
# the generator in assets/body-diagrams/, re-run it, then run this.
#
#   tool/sync_generated.sh          copy assets/ -> lib/
#   tool/sync_generated.sh --check  fail if the two have drifted (for CI)
set -euo pipefail
cd "$(dirname "$0")/.."
FILES=(muscle_taxonomy.dart body_paths.dart)
SRC=assets/body-diagrams
DST=lib/src/data/generated

case "${1:-}" in
  ""|--check) ;;
  *) echo "usage: tool/sync_generated.sh [--check]" >&2; exit 2 ;;
esac

if [[ "${1:-}" == "--check" ]]; then
  status=0
  for f in "${FILES[@]}"; do
    if ! diff -q "$SRC/$f" "$DST/$f" >/dev/null; then
      echo "drift: $DST/$f differs from $SRC/$f -- run tool/sync_generated.sh" >&2
      status=1
    fi
  done
  exit $status
fi

for f in "${FILES[@]}"; do
  cp "$SRC/$f" "$DST/$f"
  echo "synced $DST/$f"
done
