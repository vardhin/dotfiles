#!/bin/sh
# mkn.sh <aero page> [pitch] : nixie copy n<name>.qml, rendered to the scratchpad
n=$(basename $1 .qml | sed 's/^a//')
p=${2:-3}
sed -e 's#import "aero" as V#import "nixie" as V#' -e 's#Rectangle { id: root; anchors.fill: parent; color: "\#101014"#Rectangle { id: root; anchors.fill: parent; color: "\#101014"; Component.onCompleted: { Tokens.pitch = '"$p"'; Tokens.era = "nixie"; Tokens.slot0 = "\#ff7a1a"; Tokens.slot1 = "\#ffb366"; Tokens.slot2 = "\#c2410c"; Tokens.unlit = "\#2b130a"; Tokens.glass = "\#0a0503"; Tokens.current = ({ slots: ["\#ff7a1a", "\#ffb366", "\#c2410c"], unlit: "\#2b130a", glass: "\#0a0503", ramp: ["\#3a1606", "\#8a3510", "\#ff7a1a", "\#ffc285"], glow: 0.85, shape: "round" }); Tokens.previous = Tokens.current }#' $1 > n$n.qml
./run.sh n$n.qml /tmp/claude-1000/-home-vardhin-dotfiles/9d6af2c5-968f-414b-a79e-19e8103e1fef/scratchpad/n$n-p$p.png
