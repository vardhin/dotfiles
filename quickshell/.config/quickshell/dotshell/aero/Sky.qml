import QtQuick
import QtQuick.Effects

// The sky glass every Aero panel is: a white plate with a sky-blue horizon
// across its middle, a white rim, a soft navy shadow under it, the sky
// welling up from its bottom edge, and the gloss over its top half (the
// design's plate and its `pointer-events: none` shine).
//   Sky { anchors.fill: parent; radius: 28 }
Item {
    id: sky

    property real radius: 28
    // Where the horizon is, 0 .. 1 down the plate.
    property real horizon: 0.5
    property bool gloss: true
    // Room the gloss keeps from the sides, in px.
    property real glossInset: 22
    property real glossHeight: height * 0.44

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: sky.radius
        border.width: 1
        border.color: Ink.c("white", Qt.rgba(1, 1, 1, 0.16))
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.plate0
            }
            GradientStop {
                position: sky.horizon - 0.02
                color: Ink.plate1
            }
            GradientStop {
                position: sky.horizon + 0.02
                color: Ink.plate2
            }
            GradientStop {
                position: 1
                color: Ink.plate3
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Ink.shadow
            shadowBlur: 0.6
            blurMax: 20
            shadowVerticalOffset: 5
            shadowHorizontalOffset: 0
        }
    }

    // The sky welling up from the bottom edge.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: sky.radius - 1
        gradient: Gradient {
            GradientStop {
                position: 0.7
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Ink.c(Qt.rgba(98 / 255, 195 / 255, 238 / 255, 0.4), Qt.rgba(60 / 255, 140 / 255, 210 / 255, 0.35))
            }
        }
    }

    // The shine.
    Rectangle {
        visible: sky.gloss
        x: sky.glossInset
        y: 4
        width: parent.width - sky.glossInset * 2
        height: sky.glossHeight
        topLeftRadius: Math.max(0, sky.radius - 4)
        topRightRadius: Math.max(0, sky.radius - 4)
        bottomLeftRadius: Math.min(height, 60)
        bottomRightRadius: Math.min(height, 60)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ink.gloss(0.8)
            }
            GradientStop {
                position: 1
                color: Ink.gloss(0)
            }
        }
    }
}
