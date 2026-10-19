#!/bin/sh
# mk.sh <aero page> : blueprint copy b<name>.qml, rendered to the scratchpad
n=$(basename $1 .qml | sed 's/^a//')
sed -e 's#import "aero" as V#import "blueprint" as V#' -e 's#Rectangle { id: root; anchors.fill: parent; color: "\#101014"#Rectangle { id: root; anchors.fill: parent; color: "\#101014"; Component.onCompleted: { Tokens.era = "blueprint"; Tokens.slot0 = "\#e8f1ff"; Tokens.slot1 = "\#a9cdfa"; Tokens.slot2 = "\#ffffff" }#' $1 > b$n.qml
./run.sh b$n.qml /tmp/claude-1000/-home-vardhin-dotfiles/19689b17-9894-4c1e-b08c-b020a60e1ccd/scratchpad/b$n.png
