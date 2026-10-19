import QtQuick

// A neon folder: a tab and a body, outlined (the design's file icons).
//   Folder { width: 48; height: 36; tint: Ink.cyan }
Item {
    id: folder

    property color tint: Ink.cyan
    readonly property real line: Math.max(1.5, Math.round(height * 0.06))

    Tube {
        width: folder.width * 0.42
        height: folder.height * 0.4
        radius: Math.round(folder.height * 0.1)
        line: folder.line
        tint: folder.tint
        glow: 0.5
    }
    Tube {
        y: folder.height * 0.18
        width: folder.width
        height: folder.height * 0.82
        radius: Math.round(folder.height * 0.12)
        line: folder.line
        tint: folder.tint
        fill: Ink.glass
        glow: 0.7
    }
}
