import QtQuick
import qs.aero as Aero

// The top strip's or side rail's sky glass in Frutiger Aero, under its
// lit-only dots (DotSurface.bare): white going sky blue across a horizon,
// with a white edge where it meets the desktop (the strip's bottom, the
// rail's left).
//   BarChrome { anchors.fill: parent; place: "strip" }
Item {
    id: chrome

    property string place: "strip"
    readonly property bool vertical: place === "rail"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: chrome.vertical ? Gradient.Horizontal : Gradient.Vertical
            GradientStop {
                position: 0
                color: Aero.Ink.plate0
            }
            GradientStop {
                position: 0.48
                color: Aero.Ink.plate1
            }
            GradientStop {
                position: 0.52
                color: Aero.Ink.plate2
            }
            GradientStop {
                position: 1
                color: Aero.Ink.plate3
            }
        }
    }
    Rectangle {
        y: chrome.vertical ? 0 : parent.height - 1
        width: chrome.vertical ? 1 : parent.width
        height: chrome.vertical ? parent.height : 1
        color: "white"
    }
}
