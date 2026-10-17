import QtQuick
import qs

// A switch on the ANIME page: its name, then every choice; the framed one is
// how it is now.
//   AnimeSwitch { label: "AUDIO"; choices: [["sub", "SUB"], ["dub", "DUB"]]; value: Anime.mode }
Row {
    id: sw

    property string label
    property var choices: []
    property var value
    signal picked(var v)

    spacing: 2

    DotText {
        visible: sw.label !== ""
        text: sw.label
        color: Tokens.slot1
    }
    Repeater {
        model: sw.choices

        DotButton {
            required property var modelData
            text: modelData[1]
            active: sw.value === modelData[0]
            color: active ? Tokens.slot0 : Tokens.slot1
            onClicked: sw.picked(modelData[0])
        }
    }
}
