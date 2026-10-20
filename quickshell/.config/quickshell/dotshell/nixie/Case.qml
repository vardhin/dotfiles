import QtQuick
import qs

// An expanded panel: the walnut case holding one dark dot screen ruled in
// brass, 12 px in (the NIXIE expanded boards). Contents go on `screen`
// (in dots) or over it in px; `sx`/`sy`/`sw`/`sh` are the screen's rect.
//   Case { anchors.fill: parent; Glass children… }
Item {
    id: box

    property real pad: 12
    readonly property real sx: pad
    readonly property real sy: pad
    readonly property real sw: width - pad * 2
    readonly property real sh: height - pad * 2
    readonly property alias screen: glass
    default property alias content: glass.content

    Wood {
        anchors.fill: parent
    }
    Glass {
        id: glass
        x: box.sx
        y: box.sy
        width: box.sw
        height: box.sh
    }
}
