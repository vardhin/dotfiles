#!/usr/bin/env bash
# Compile shaders/*.frag|*.vert to .qsb (Qt 6 shader bundles).
# The compiled .qsb files are committed, so this is only needed after editing a shader.
# Needs qsb from qt6-shadertools (/usr/lib/qt6/bin/qsb).
#
# Each build records the sources it compiled in shaders/SOURCES.sha256, so a
# clone can tell whether the committed .qsb still match their sources.
#
#   ./build-shaders.sh          compile every shader, rewrite SOURCES.sha256
#   ./build-shaders.sh --check  no qsb needed; exit 1 if a .qsb is missing,
#                               orphaned, or its source changed since the build
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/shaders"
shopt -s nullglob

MANIFEST=SOURCES.sha256

check() {
  local bad=0 s q
  for s in *.frag *.vert; do
    [[ -f $s.qsb ]] || { echo "shaders/$s has no .qsb" >&2; bad=1; }
  done
  for q in *.qsb; do
    [[ -f ${q%.qsb} ]] || { echo "shaders/$q has no source (orphaned)" >&2; bad=1; }
  done
  if [[ ! -f $MANIFEST ]]; then
    echo "shaders/$MANIFEST missing: run build-shaders.sh once to record the sources" >&2
    bad=1
  else
    local listed have
    listed=$(awk '{print $2}' "$MANIFEST" | sort)
    have=$(printf '%s\n' *.frag *.vert | sort)
    [[ $listed == "$have" ]] || { echo "shaders/$MANIFEST lists other shaders than shaders/ holds" >&2; bad=1; }
    sha256sum --quiet -c "$MANIFEST" >&2 || { echo "a shader changed since its .qsb was built: run build-shaders.sh" >&2; bad=1; }
  fi
  return $bad
}

if [[ ${1:-} == --check ]]; then
  check && echo "shaders: .qsb up to date"
  exit
fi

QSB=${QSB:-$(command -v qsb || echo /usr/lib/qt6/bin/qsb)}
[[ -x $QSB ]] || { echo "qsb not found; install qt6-shadertools" >&2; exit 1; }

for s in *.frag *.vert; do
  "$QSB" --qt6 -o "$s.qsb" "$s"
  echo "built shaders/$s.qsb"
done
sha256sum *.frag *.vert > "$MANIFEST"
echo "wrote shaders/$MANIFEST"
