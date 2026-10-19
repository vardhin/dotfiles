import QtQuick
import qs

// A line to type in, on the glass (in dots): `hint` while empty, Enter
// runs `action` with {value} filled in, Escape folds the panel. A click
// asks the desktop layer for the keyboard (DeskPanel: "panel keys").
//   Field { width: 80; hint: "SEARCH"; action: "find {value}"; color: Ink.pink }
Item {
    id: field

    property string hint: ""
    property string action: ""
    property color color: Ink.pink
    property color hintColor: Ink.violet
    readonly property alias text: input.text
    signal typed(string text)

    implicitHeight: Tokens.lineDots

    // The face this sits in (Face.qml).
    readonly property Item face: {
        for (let p = parent; p; p = p.parent)
            if (p.tokyoFace === true)
                return p;
        return null;
    }

    DotInput {
        id: input
        anchors.fill: parent
        onTextChanged: field.typed(text)
        onAccepted: {
            const v = text.trim();
            if (v !== "" && field.action)
                field.face?.run(field.action.replace("{value}", v));
            text = "";
        }
        Keys.onEscapePressed: {
            input.text = "";
            field.face?.run("panel fold");
        }
    }
    MatrixText {
        visible: input.text === "" && !input.activeFocus
        y: Math.round((parent.height - 5) / 2)
        width: parent.width
        height: 5
        font: "3x5"
        text: field.hint
        color: field.hintColor
        opacity: 0.7
    }
    MouseArea {
        anchors.fill: parent
        visible: !input.activeFocus
        cursorShape: Qt.IBeamCursor
        onClicked: {
            field.face?.run("panel keys");
            input.forceActiveFocus();
        }
    }
}
