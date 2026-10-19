#!/bin/sh
# mkv.sh <aero page> : vaporwave copy v<name>.qml, rendered to the scratchpad
n=$(basename $1 .qml | sed 's/^a//')
sed -e 's#import "aero" as V#import "vapor" as V#' -e 's#Rectangle { id: root; anchors.fill: parent; color: "\#101014"#Rectangle { id: root; anchors.fill: parent; color: "\#101014"; Component.onCompleted: { Tokens.era = "vapor"; Tokens.slot0 = "\#ff71ce"; Tokens.slot1 = "\#01cdfe"; Tokens.slot2 = "\#b967ff"; Tokens.unlit = "\#2d1b4e"; Tokens.glass = "\#130a24"; Tokens.current = ({ slots: ["\#ff71ce", "\#01cdfe", "\#b967ff"], unlit: "\#2d1b4e", glass: "\#130a24", ramp: ["\#3d1d63", "\#b967ff", "\#ff71ce", "\#fffb96"], glow: 0.7, shape: "round" }); Tokens.previous = Tokens.current }#' $1 > v$n.qml
./run.sh v$n.qml /tmp/claude-1000/-home-vardhin-dotfiles/469e412a-2968-402b-9cb9-c7a3db7309c1/scratchpad/v$n.png
