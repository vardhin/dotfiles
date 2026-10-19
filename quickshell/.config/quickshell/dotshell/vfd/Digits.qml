import QtQuick
import qs

// Big VFD numerals: the 5x7 cells drawn `size` dots a side, their dots
// spaced apart, with every segment that is off still faintly there behind
// (the design's dim 88:88 under the time). `cells` pads the ghost to that
// many characters, right-aligned, so 9:47 sits on 88:88.
//   Digits { text: "9:47"; cells: 5; size: 3 }
Item {
    id: digits

    property string text: ""
    property color color: Ink.cyan
    property int size: 2
    // The lit part of each cell: from size 3 on, one less spaces the dots.
    property int dot: size >= 3 ? size - 1 : size
    property bool ghosts: true
    property int cells: 0
    property string align: "left"
    // The unlit segments' own pattern ("8:88"), for when nothing is lit.
    property string mask: ""

    // Digits and blanks become 8s; points and colons stay as they are.
    readonly property string back: {
        if (mask)
            return mask;
        const t = String(text).replace(/[0-9A-Z ]/gi, "8");
        return "8".repeat(Math.max(0, cells - t.length)) + t;
    }
    readonly property string front: " ".repeat(Math.max(0, cells - String(text).length)) + text

    implicitWidth: ghost.implicitWidth
    implicitHeight: lit.implicitHeight

    MatrixText {
        id: ghost
        visible: digits.ghosts
        width: digits.width
        height: implicitHeight
        text: digits.back
        size: digits.size
        dot: digits.dot
        align: digits.align
        color: Ink.ghost
    }
    MatrixText {
        id: lit
        width: digits.width
        height: implicitHeight
        text: digits.ghosts ? digits.front : digits.text
        size: digits.size
        dot: digits.dot
        align: digits.align
        color: digits.color
    }
}
