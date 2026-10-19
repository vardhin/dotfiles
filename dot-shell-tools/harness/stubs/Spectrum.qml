import QtQuick
Row { property int bars: 24; spacing: 1; Repeater { model: bars; Rectangle { width: 2; anchors.bottom: parent.bottom; height: Math.max(1, Math.round(parent.height * Math.abs(Math.sin(index * 0.7)))); color: Tokens.slot0 } } }
