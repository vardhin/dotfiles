#!/bin/sh
# render.sh <dir>: zoom 2x and screenshot every <dir>/*.html to <dir>/png/*.png (headless Firefox), trimmed.
D=$1; P=$(mktemp -d); mkdir -p "$D/png"
for f in "$D"/*.html; do
  grep -q 'zoom:2' "$f" || sed -i 's/<body>/<body style="zoom:2">/' "$f"
  n=$(basename "$f" .html)
  timeout 40 firefox --headless --profile "$P" --no-remote --window-size 1600,1600 --screenshot "$D/png/$n.png" "file://$(realpath "$f")" >/dev/null 2>&1
  magick "$D/png/$n.png" -fuzz 3% -trim +repage "$D/png/$n.png"
done
