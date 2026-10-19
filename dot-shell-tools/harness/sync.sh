#!/bin/sh
# Mirror the shell (root and the era dirs) into w/ with stubs for services.
H=$(dirname "$(realpath "$0")")
D=/home/vardhin/dotfiles/quickshell/.config/quickshell/dotshell
W=$H/w
rm -rf $W; mkdir -p $W/tokyo $W/vfd $W/aero $W/blueprint $W/vapor $W/flap
cp -r $D/shaders $D/fonts $W/
cp $D/*.js $W/
fix() { sed -e 's/^import qs$/import ".."/' -e '/^import qs\.services/d' -e '/^import Quickshell/d' \
  -e 's#^import qs\.\([a-z]*\) as \(.*\)#import "../\1" as \2#' -e 's/QsWindow.window?.devicePixelRatio ?? 1/1/' -e 's/^Singleton {/Item {/' "$1"; }
for f in DotSurface DotText MatrixText DotInput MediaArt BarChrome; do fix $D/$f.qml | sed -e "s/^import \"\.\.\"$//" -e "s#\"\.\./#\"#" > $W/$f.qml; done
cp $H/stubs/*.qml $W/
for d in tokyo vfd aero blueprint vapor flap; do
  [ -d $D/$d ] || continue
  for f in $D/$d/*.qml; do fix $f > $W/$d/$(basename $f); done
  for f in $W/$d/*.qml; do n=$(basename $f .qml); if grep -q "pragma Singleton" $f; then echo "singleton $n 1.0 $n.qml"; else echo "$n 1.0 $n.qml"; fi; done > $W/$d/qmldir
done
for f in $W/*.qml; do n=$(basename $f .qml); if grep -q "pragma Singleton" $f; then echo "singleton $n 1.0 $n.qml"; else echo "$n 1.0 $n.qml"; fi; done > $W/qmldir
