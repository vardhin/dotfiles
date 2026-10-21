import QtQuick
import qs.services
import qs.tokyo as Tokyo
import qs.vfd as Vfd
import qs.aero as Aero
import qs.blueprint as Bp
import qs.vapor as Vw
import qs.flap as Fl
import qs.nixie as Nx
import qs.nineties as Ni
import qs.nightvision as Nv

// A notes panel. Empty, it sits in the era's casing like any other panel
// so it can be found; with words in it, it is just the words on the
// wallpaper in the era's hues, no casing, no label. The first line is the
// heading (slot1), the rest the body (slot0); slot2 for the caret. Saved
// to the panel's `text` as you type (Panels.set, half a second after the
// last key).
//   margins        hold or drag to move it (DeskPanel's grab, under it)
//   click text     type; Escape or a click on the desktop lets go
Item {
    id: root

    required property var panel

    readonly property bool empty: edit.text === ""
    // The words keep one place, cased or bare: inside the casing's body,
    // with room round them for the grab.
    readonly property int padX: Tokens.era === "nineties" ? 26 : 16
    readonly property int padTop: Tokens.era === "vapor" ? 34 : 14

    // The era's casing, only while empty.
    Loader {
        anchors.fill: parent
        active: root.empty
        sourceComponent: casings[Tokens.era] ?? plain
    }
    readonly property var casings: ({
            tokyo: tkCase,
            vfd: vfdCase,
            aero: aeroCase,
            blueprint: bpCase,
            vapor: vwCase,
            flap: flCase,
            nixie: nxCase,
            nineties: niCase,
            nightvision: nvCase
        })
    Component {
        id: tkCase
        Item {
            Tokyo.Glass {
                radius: 24
            }
            Tokyo.Sign {
                radius: 24
                tone: "dim"
            }
        }
    }
    Component {
        id: vfdCase
        Vfd.Unit {}
    }
    Component {
        id: aeroCase
        Aero.Sky {
            radius: Math.min(26, height * 0.22)
            gloss: false
        }
    }
    Component {
        id: bpCase
        Bp.Paper {}
    }
    Component {
        id: vwCase
        Vw.Win {
            icon: "📝"
            title: "Notepad"
            controls: "max"
        }
    }
    Component {
        id: flCase
        Fl.Housing {}
    }
    Component {
        id: nxCase
        Nx.Wood {}
    }
    Component {
        id: niCase
        Ni.Plate {}
    }
    Component {
        id: nvCase
        Nv.Scope {}
    }
    Component {
        id: plain
        Rectangle {
            radius: Tokens.pitch * 2
            color: Tokens.glass
            border.width: 1
            border.color: Qt.alpha(Tokens.slot2, 0.5)
        }
    }

    Flickable {
        id: flick
        x: root.padX
        y: root.padTop
        width: parent.width - root.padX * 2
        height: parent.height - y - 14
        clip: true
        contentWidth: width
        contentHeight: edit.contentHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        function follow(r: rect): void {
            if (r.y < contentY)
                contentY = r.y;
            else if (r.y + r.height > contentY + height)
                contentY = r.y + r.height - height;
        }

        TextEdit {
            id: edit
            width: flick.width
            height: Math.max(flick.height, contentHeight)
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            selectByMouse: true
            persistentSelection: false
            font.family: Tokens.font
            font.pixelSize: 22
            color: Tokens.slot0
            selectionColor: Qt.alpha(Tokens.slot1, 0.4)
            selectedTextColor: Tokens.slot0
            onCursorRectangleChanged: flick.follow(cursorRectangle)

            // The first line is the heading.
            onTextChanged: {
                tint();
                if (activeFocus)
                    save.restart();
            }
            Component.onCompleted: {
                text = root.panel.text ?? "";
                tint();
            }
            function tint(): void {
                const nl = text.indexOf("\n");
                heading.text = nl < 0 ? text : text.slice(0, nl);
            }

            onActiveFocusChanged: {
                if (activeFocus)
                    Panels.typing = true;
                else if (save.running) {
                    save.stop();
                    root.store();
                }
            }
            Keys.onEscapePressed: {
                focus = false;
                Panels.typing = false;
            }

            cursorDelegate: Rectangle {
                width: 2
                color: Tokens.slot2
                visible: edit.activeFocus
                SequentialAnimation on opacity {
                    running: edit.activeFocus
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0
                        duration: 0
                    }
                    PauseAnimation {
                        duration: 530
                    }
                    NumberAnimation {
                        to: 1
                        duration: 0
                    }
                    PauseAnimation {
                        duration: 530
                    }
                }
            }

            // The heading, over the first line in slot1 (same font, same
            // wrap, so it lies exactly on it).
            Text {
                id: heading
                width: edit.width
                wrapMode: Text.Wrap
                font: edit.font
                color: Tokens.slot1
                textFormat: Text.PlainText
            }

            // Empty: a hint in the body's place.
            Text {
                visible: edit.text === "" && !edit.activeFocus
                text: "click to write"
                font: edit.font
                color: Tokens.slot0
                opacity: 0.35
            }
        }
    }

    // Typing loses the wallpaper's keyboard when Panels.typing drops (a
    // click on the desktop, Escape); let go of the caret with it.
    Connections {
        target: Panels
        function onTypingChanged(): void {
            if (!Panels.typing && edit.activeFocus)
                edit.focus = false;
        }
    }

    // Written from elsewhere (dot set <id> --text ...): take it unless
    // the caret is in it.
    onPanelChanged: {
        if (!edit.activeFocus && edit.text !== (panel.text ?? ""))
            edit.text = panel.text ?? "";
    }

    Timer {
        id: save
        interval: 500
        onTriggered: root.store()
    }
    function store(): void {
        if (edit.text !== (root.panel.text ?? ""))
            Panels.set(root.panel.id, { text: edit.text });
    }
}
