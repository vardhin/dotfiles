import QtQuick

// A picture in era colors, dithered one texel per dot (shaders/art.frag).
// Use inside a DotSurface canvas, sized in dots:
//   DitherArt { width: 32; height: 32; source: Media.art }
// Shows nothing until the image loads, so the board's unlit dots stay.
Item {
    id: root

    property alias source: img.source
    readonly property bool ready: img.status === Image.Ready

    Image {
        id: img
        anchors.fill: parent
        sourceSize: Qt.size(root.width, root.height)
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.ready
        property variant source: img
        property size grid: Qt.size(root.width, root.height)
        property real depth: Tokens.depthBits
        property color ramp0: Tokens.current.ramp[0]
        property color ramp1: Tokens.current.ramp[1]
        property color ramp2: Tokens.current.ramp[2]
        property color ramp3: Tokens.current.ramp[3]
        fragmentShader: Qt.resolvedUrl("shaders/art.frag.qsb")
    }
}
