import QtQuick

// Over a sunken VFD window: the shadow falling in from the top of the
// plate and the black lip round the glass (Unit.qml's, for a window
// placed by hand: the bars' Dash.qml). Fill it over the window's dots.
//   Smoke { x: surface.x; y: surface.y; width: surface.width; height: surface.height }
Item {
    id: smoke

    property real shade: 0.75

    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: 4
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(0, 0, 0, smoke.shade)
            }
            GradientStop {
                position: Math.min(0.5, 10 / Math.max(1, smoke.height))
                color: "transparent"
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: 4
        color: "transparent"
        border.width: 1
        border.color: "black"
    }
}
