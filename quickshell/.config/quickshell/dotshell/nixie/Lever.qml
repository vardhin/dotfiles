import QtQuick
import qs.tokyo as T

// A toggle switch on a steel plate, crisp: the plate shaded round its
// centre, ringed in brass, the brass-ringed boss in the middle and the
// chrome bat up (`on`) or down. A click flips it (runs `action`).
//   Lever { width: 56; height: 90; on: true; action: "caffeine toggle" }
Item {
    id: lever

    property bool on: false
    property string action: ""

    Rectangle {
        anchors.fill: parent
        radius: 8
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.c("#4a4a4a", "#b8b2a6")
            }
            GradientStop {
                position: 0.5
                color: Ink.c("#8a8a8a", "#e6e1d6")
            }
            GradientStop {
                position: 1
                color: Ink.c("#3a3a3a", "#a8a296")
            }
        }
        border.width: 2
        border.color: Ink.brass
    }
    // The bat, its shadow under it.
    Rectangle {
        id: bat
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(6, lever.width * 0.18)
        height: lever.height * 0.4
        y: lever.on ? lever.height * 0.07 : lever.height * 0.53
        radius: width / 2
        Behavior on y {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Ink.c("#f0f0f0", "#ffffff")
            }
            GradientStop {
                position: 1
                color: Ink.c("#9a9a9a", "#a8a8a8")
            }
        }
        Rectangle {
            z: -1
            y: 2
            width: parent.width
            height: parent.height
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.35)
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: Math.max(10, lever.width * 0.32)
        height: width
        radius: width / 2
        color: Ink.c("#2a2a2a", "#5a5650")
        border.width: 2
        border.color: Ink.brass
    }
    T.Hit {
        anchors.fill: parent
        action: lever.action
    }
}
