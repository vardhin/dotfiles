import QtQuick
import qs.services

// A notes panel: desktop only, no frame, no glass, just the words on the
// wallpaper in the era's hues. The first line is the heading (slot1), the
// rest the body (slot0); slot2 for the grip and the caret. Saved to the
// panel's `text` as you type (Panels.set, half a second after the last key).
//   grip line      hold or drag to move it (DeskPanel's grab, under it)
//   click text     type; Escape or a click on the desktop lets go
Item {
    id: root

    required property var panel

    readonly property int gripH: 16

    // The grip: a short rule and the word, dim, so the panel can be moved
    // and found when it is empty. The grab area under it does the rest.
    Row {
        y: Math.round((root.gripH - height) / 2)
        spacing: 6
        opacity: edit.activeFocus || hover.hovered ? 0.7 : 0.35
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 2
            color: Tokens.slot2
        }
        Text {
            text: "notes"
            color: Tokens.slot2
            font.family: Tokens.font
            font.pixelSize: 11
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }
    HoverHandler {
        id: hover
    }

    Flickable {
        id: flick
        y: root.gripH + 2
        width: parent.width
        height: parent.height - y
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
