#!/bin/sh
# mkg.sh <90s page i<name>.qml> [out dir] : Night Vision copy g<name>.qml, rendered to out dir
n=$(basename $1 .qml | sed 's/^i//')
o=${2:-/tmp/claude-1000/-home-vardhin-dotfiles/4cfe4217-8380-4b6e-8f3e-f83465d75b7c/scratchpad/g}
mkdir -p $o
sed -e 's#import "nineties" as V#import "nightvision" as V#' -e 's#Tokens.era = "nineties"; .*Tokens.previous = Tokens.current }#Tokens.era = "nightvision"; Tokens.slot0 = "\#7dff6a"; Tokens.slot1 = "\#d6ffc9"; Tokens.slot2 = "\#2fae2a"; Tokens.unlit = "\#0d260b"; Tokens.glass = "\#040a03"; Tokens.current = ({ slots: ["\#7dff6a", "\#d6ffc9", "\#2fae2a"], unlit: "\#0d260b", glass: "\#040a03", ramp: ["\#0f3a0c", "\#2b8a22", "\#62e04f", "\#c9ffb8"], glow: 0.6, shape: "round" }); Tokens.previous = Tokens.current }#' $1 > g$n.qml
./run.sh g$n.qml $o/g$n.png
