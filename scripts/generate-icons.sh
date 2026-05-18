#!/usr/bin/env bash
# Regenerate Tally's AppIcon PNG set and MenuBarIcon PDF from the SVG sources in
# docs/system-design/assets/.
#
# Requirements:
#   - rsvg-convert (brew install librsvg)
#
# Outputs:
#   Tally/Resources/Assets.xcassets/AppIcon.appiconset/icon_*.png
#   Tally/Resources/Assets.xcassets/MenuBarIcon.imageset/MenuBarIcon.pdf
#
# Run this whenever the source SVGs change. The committed PNGs/PDF are what the
# build consumes; this script just refreshes them.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "error: rsvg-convert not found. Install via: brew install librsvg" >&2
  exit 1
fi

LOGO_SRC="docs/system-design/assets/logo-mark.svg"
MENUBAR_SRC="docs/system-design/assets/menubar-icon.svg"
APPICON_DIR="Tally/Resources/Assets.xcassets/AppIcon.appiconset"
MENUBAR_DIR="Tally/Resources/Assets.xcassets/MenuBarIcon.imageset"

mkdir -p "$APPICON_DIR" "$MENUBAR_DIR"

render_appicon() {
  local size=$1
  local outfile="$APPICON_DIR/icon_${size}.png"
  rsvg-convert -w "$size" -h "$size" "$LOGO_SRC" -o "$outfile"
  echo "  $outfile"
}

echo "Rendering AppIcon PNGs from $LOGO_SRC..."
for size in 16 32 64 128 256 512 1024; do
  render_appicon "$size"
done

echo "Rendering MenuBarIcon PDF from $MENUBAR_SRC..."
rsvg-convert -f pdf "$MENUBAR_SRC" -o "$MENUBAR_DIR/MenuBarIcon.pdf"
echo "  $MENUBAR_DIR/MenuBarIcon.pdf"

echo "Done."
