import QtQuick

// A glossy marble (the design's app dots and lamps): `hue` 0 orange,
// 1 sky blue, 2 grass green, 3 red; light at the top, a shine on it.
//   Orb { width: 18; height: 18; hue: 1 }
Item {
    id: orb

    property int hue: 1
    readonly property var tones: [["#ffd29a", "#ff8a2a"], ["#bfe6fb", "#1f7fd1"], ["#b9f0a8", "#23963c"], ["#ffb3b3", "#c8323c"]]
    readonly property var tone: tones[Math.max(0, hue) % tones.length]

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: orb.tone[0]
            }
            GradientStop {
                position: 0.75
                color: orb.tone[1]
            }
        }
    }
    Rectangle {
        x: parent.width * 0.2
        y: parent.height * 0.06
        width: parent.width * 0.6
        height: parent.height * 0.42
        radius: height / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, 0.75)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(1, 1, 1, 0)
            }
        }
    }
}
