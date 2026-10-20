#!/bin/sh
# mki.sh <nixie page> [pitch] : 90s Nights copy i<name>.qml, rendered to the scratchpad
n=$(basename $1 .qml | sed 's/^n//')
p=${2:-3}
sed -e 's#import "nixie" as V#import "nineties" as V#' -e 's#Tokens.era = "nixie"; .*Tokens.previous = Tokens.current }#Tokens.era = "nineties"; Tokens.slot0 = "\#ff2e97"; Tokens.slot1 = "\#1fa8ff"; Tokens.slot2 = "\#ffe600"; Tokens.unlit = "\#22123a"; Tokens.glass = "\#0a0514"; Tokens.current = ({ slots: ["\#ff2e97", "\#1fa8ff", "\#ffe600"], unlit: "\#22123a", glass: "\#0a0514", ramp: ["\#3b0d5c", "\#a3157f", "\#ff2e97", "\#ffe600"], glow: 0.9, shape: "round" }); Tokens.previous = Tokens.current }#' $1 > i$n.qml
./run.sh i$n.qml /tmp/claude-1000/-home-vardhin-dotfiles/1760663c-7770-497e-b6b7-0c6febcb7425/scratchpad/i$n-p$p.png
