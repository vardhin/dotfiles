#!/bin/sh
# mkf.sh <aero page> [pitch] : split-flap copy f<name>.qml, rendered to the scratchpad
n=$(basename $1 .qml | sed 's/^a//')
p=${2:-3}
sed -e 's#import "aero" as V#import "flap" as V#' -e 's#Rectangle { id: root; anchors.fill: parent; color: "\#101014"#Rectangle { id: root; anchors.fill: parent; color: "\#101014"; Component.onCompleted: { Tokens.pitch = '"$p"'; Tokens.era = "flap"; Tokens.slot0 = "\#f2f2e6"; Tokens.slot1 = "\#ffd400"; Tokens.slot2 = "\#ff8c00"; Tokens.unlit = "\#1e1e1e"; Tokens.glass = "\#0b0b0b"; Tokens.current = ({ slots: ["\#f2f2e6", "\#ffd400", "\#ff8c00"], unlit: "\#1e1e1e", glass: "\#0b0b0b", ramp: ["\#262626", "\#6e6e64", "\#bdbdb0", "\#f2f2e6"], glow: 0.1, shape: "square" }); Tokens.previous = Tokens.current }#' $1 > f$n.qml
./run.sh f$n.qml /tmp/claude-1000/-home-vardhin-dotfiles/c3755760-1765-4281-bb81-6164bb1c8623/scratchpad/f$n-p$p.png
