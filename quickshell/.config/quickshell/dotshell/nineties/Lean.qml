import QtQuick

// Leans an item 10° like the signs (CSS skewX(-10deg) about its centre):
// the top edge right, the bottom edge left. Put it in `transform`.
//   transform: Lean { item: key }
Matrix4x4 {
    property Item item
    property real deg: 10
    readonly property real t: Math.tan(deg * Math.PI / 180)
    matrix: Qt.matrix4x4(1, -t, 0, t * (item ? item.height : 0) / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
}
