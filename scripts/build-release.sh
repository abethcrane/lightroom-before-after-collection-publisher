#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN="$ROOT/before-and-after.lrdevplugin"
PRESET="$ROOT/presets/Reset For Before.xmp"
DIST="$ROOT/dist"

VERSION="$(grep 'display' "$PLUGIN/Info.lua" | sed -n 's/.*display = "\([^"]*\)".*/\1/p')"
OUT="$DIST/before-and-after-export-${VERSION}.zip"

if [[ -z "$VERSION" ]]; then
  echo "Could not read version from Info.lua" >&2
  exit 1
fi

if [[ ! -d "$PLUGIN" ]] || [[ ! -f "$PRESET" ]]; then
  echo "Missing plugin or preset files" >&2
  exit 1
fi

mkdir -p "$DIST"
rm -f "$OUT"

(
  cd "$ROOT"
  zip -r "$OUT" \
    LICENSE \
    README.md \
    presets/ \
    before-and-after.lrdevplugin/ \
    -x "*.DS_Store" \
    -x "before-and-after.lrdevplugin/reports/*"
)

echo "Created $OUT"
