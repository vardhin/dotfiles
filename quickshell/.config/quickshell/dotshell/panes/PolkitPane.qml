import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs

// Polkit agent: the "an app wants admin rights" prompt, as an LED pane.
// Enter submits, Escape cancels the request.
Pane {
    id: pane

    name: "polkit"
    managed: false
    shown: agent.isActive && agent.flow !== null
    grab: false
    keyboard: WlrKeyboardFocus.Exclusive
    screen: Ui.focusedScreen()

    readonly property var flow: agent.flow
    readonly property int inner: 44 * Tokens.charDots
    cols: inner + 8
    rows: col.implicitHeight + 8

    PolkitAgent {
        id: agent
    }

    onOpened: pass.forceActiveFocus()

    Connections {
        target: pane.flow
        function onIsResponseRequiredChanged() {
            if (pane.flow.isResponseRequired)
                pass.forceActiveFocus();
        }
    }

    Column {
        id: col
        x: 4
        y: 4
        width: pane.inner
        spacing: 3

        DotText {
            height: Tokens.lineDots
            text: "AUTHENTICATE"
            color: Tokens.slot2
        }
        Rule {}
        DotLabel {
            width: parent.width
            text: pane.flow?.message ?? ""
            wrapMode: Text.Wrap
            maximumLineCount: 4
        }
        DotText {
            height: Tokens.lineDots
            width: parent.width
            text: (pane.flow?.actionId ?? "").toUpperCase()
            color: Tokens.slot1
            opacity: 0.5
            elide: Text.ElideMiddle
        }

        Item {
            width: 1
            height: 2
        }

        Item {
            width: parent.width
            height: Tokens.lineDots

            DotText {
                id: label
                text: ((pane.flow?.inputPrompt || "PASSWORD").replace(/:\s*$/, "")).toUpperCase()
                color: Tokens.slot1
            }
            DotInput {
                id: pass
                x: label.width + Tokens.charDots
                width: parent.width - x
                mask: !(pane.flow?.responseVisible ?? false)
                enabled: pane.flow?.isResponseRequired ?? false
                onAccepted: {
                    pane.flow.submit(text);
                    text = "";
                }
                Keys.onEscapePressed: event => {
                    pane.flow.cancelAuthenticationRequest();
                    text = "";
                    event.accepted = true;
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 1
            color: Tokens.slot1
            opacity: 0.5
        }

        DotText {
            height: Tokens.lineDots
            width: parent.width
            visible: text !== ""
            text: (pane.flow?.supplementaryMessage ?? "") !== "" ? pane.flow.supplementaryMessage.toUpperCase() : pane.flow?.failed ? "WRONG, TRY AGAIN" : ""
            color: pane.flow?.supplementaryIsError || pane.flow?.failed ? Tokens.slot2 : Tokens.slot1
            elide: Text.ElideRight
        }

        Row {
            spacing: 3
            DotButton {
                text: "OK"
                enabled: pane.flow?.isResponseRequired ?? false
                onClicked: pass.accepted()
            }
            DotButton {
                text: "CANCEL"
                color: Tokens.slot1
                onClicked: pane.flow.cancelAuthenticationRequest()
            }
        }
    }
}
