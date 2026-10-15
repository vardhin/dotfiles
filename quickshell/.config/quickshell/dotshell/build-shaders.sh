#!/usr/bin/env bash
# Compile shaders/*.frag|*.vert to .qsb (Qt 6 shader bundles).
# The compiled .qsb files are committed, so this is only needed after editing a shader.
# Needs qsb from qt6-shadertools (/usr/lib/qt6/bin/qsb).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/shaders"

QSB=${QSB:-$(command -v qsb || echo /usr/lib/qt6/bin/qsb)}
[[ -x $QSB ]] || { echo "qsb not found; install qt6-shadertools" >&2; exit 1; }

shopt -s nullglob
for s in *.frag *.vert; do
  "$QSB" --qt6 -o "$s.qsb" "$s"
  echo "built shaders/$s.qsb"
done
