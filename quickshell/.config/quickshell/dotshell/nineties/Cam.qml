import QtQuick

// The camcorder, crisp (Capture): a dark graphite body, lit along its top
// edge, holding the viewfinder: deep violet fading to black, with faint
// scanlines. `head` px of the body above the screen (the expanded MENU
// bar). Contents go over it in px; `sx/sy/sw/sh` are the screen's rect.
//   Cam { anchors.fill: parent }
Item {
    id: cam

    property real pad: 8
    property real head: 0
    // Bare: only the viewfinder (it sits in a sign's glass instead of the body).
    property bool bare: false
    readonly property real sx: pad
    readonly property real sy: pad + head
    readonly property real sw: width - pad * 2
    readonly property real sh: height - pad * 2 - head

    Rectangle {
        visible: !cam.bare
        anchors.fill: parent
        radius: 10
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0
                color: Ink.camHi
            }
            GradientStop {
                position: 1
                color: Ink.camLo
            }
        }
        border.width: 1
        border.color: Qt.rgba(Ink.camRim.r, Ink.camRim.g, Ink.camRim.b, 0.5)
        // The light along the top edge.
        Rectangle {
            x: 8
            y: 1
            width: parent.width - 16
            height: 1
            color: Ink.camRim
        }
    }
    Item {
        x: cam.sx
        y: cam.sy
        width: cam.sw
        height: cam.sh
        clip: true
        Rectangle {
            anchors.fill: parent
            radius: 6
            color: Ink.night
        }
        // The violet glow, low in the middle.
        Rectangle {
            width: parent.width * 1.3
            height: parent.height * 1.6
            x: (parent.width - width) / 2
            y: parent.height * 0.6 - height / 2
            radius: width / 2
            opacity: 0.85
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: Ink.c("#3a2a42", "#3a2a42")
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
        // Scanlines.
        Repeater {
            model: Math.max(0, Math.ceil(parent.height / 3))
            Rectangle {
                required property int index
                y: index * 3
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }
    }
}
