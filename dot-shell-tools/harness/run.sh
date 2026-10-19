#!/bin/sh
# run.sh <page.qml> <out.png>
H=$(dirname "$(realpath "$0")")
$H/sync.sh
sed "s#OUT#$2#" "$1" > $H/w/main.qml
cd $H/w && QT_QUICK_BACKEND=rhi QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 30 qml6 main.qml 2>&1 | grep -v "^$" | head -30
