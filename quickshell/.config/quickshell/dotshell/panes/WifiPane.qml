import QtQuick
import Quickshell
import qs
import qs.services

// Wi-Fi: radio on/off, networks (click to join or leave), password prompt.
// The scanner runs only while the pane is open.
Pane {
    id: pane

    name: "wifi"
    anchors {
        top: true
        right: true
    }

    readonly property int inner: 36 * Tokens.charDots
    cols: inner + 8
    rows: col.implicitHeight + 8

    onShownChanged: Net.scan(shown)
    onOpened: {
        if (Net.needsPassword)
            psk.forceActiveFocus();
    }

    Column {
        id: col
        x: 4
        y: 4
        width: pane.inner
        spacing: 3

        Line {
            label: "WIFI"
            labelColor: Tokens.slot2
            DotButton {
                text: Net.wifiOn ? "ON" : "OFF"
                active: Net.wifiOn
                enabled: Net.hardwareEnabled
                onClicked: Net.setEnabled(!Net.wifiOn)
            }
        }

        DotText {
            visible: Net.wiredUp
            height: Tokens.lineDots
            text: "WIRED CONNECTED"
            color: Tokens.slot1
        }

        Rule {}

        DotText {
            visible: Net.wifiOn && Net.networks.length === 0
            height: Tokens.lineDots
            text: "SCANNING"
            opacity: 0.5
        }

        Repeater {
            model: Net.wifiOn ? Net.networks.slice(0, 12) : []

            Item {
                id: row
                required property var modelData
                width: pane.inner
                height: Tokens.lineDots

                Frame {
                    anchors.fill: parent
                    visible: row.modelData.connected
                }

                // Signal: four rising segments.
                Row {
                    id: bars
                    x: 2
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    spacing: 1
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            width: 1
                            height: 2 + index * 2
                            anchors.bottom: parent.bottom
                            color: Tokens.slot1
                            opacity: row.modelData.signalStrength > index * 0.25 ? 1 : 0.5
                        }
                    }
                }

                DotText {
                    x: bars.width + 6
                    width: parent.width - x - tag.width - 4
                    text: row.modelData.name.toUpperCase()
                    color: Tokens.slot0
                    elide: Text.ElideRight
                }
                DotText {
                    id: tag
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    text: row.modelData.stateChanging ? "..." : row.modelData.known ? "SAVED" : Net.securityName(row.modelData)
                    color: Tokens.slot1
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Net.connect(row.modelData)
                }
            }
        }

        // ── Password prompt ─────────────────────────────────────────
        Column {
            visible: Net.needsPassword !== null
            width: pane.inner
            spacing: 2

            Rule {}
            DotText {
                width: parent.width
                height: Tokens.lineDots
                text: "PASSWORD FOR " + (Net.needsPassword?.name ?? "").toUpperCase()
                color: Tokens.slot2
                elide: Text.ElideRight
            }
            DotInput {
                id: psk
                width: parent.width
                mask: true
                onAccepted: {
                    Net.connectWithPassword(Net.needsPassword, text);
                    text = "";
                }
                Keys.onEscapePressed: event => {
                    Net.needsPassword = null;
                    text = "";
                    event.accepted = true;
                }
            }
        }

        Connections {
            target: Net
            function onNeedsPasswordChanged() {
                if (Net.needsPassword && pane.shown)
                    psk.forceActiveFocus();
            }
        }

        DotText {
            visible: Net.lastError !== ""
            height: Tokens.lineDots
            text: Net.lastError
            color: Tokens.slot2
        }

        Rule {}

        Row {
            spacing: 3
            DotButton {
                text: "FORGET"
                visible: Net.active !== null && Net.active.known
                color: Tokens.slot1
                onClicked: Net.active.forget()
            }
            DotButton {
                text: "NMTUI"
                color: Tokens.slot1
                onClicked: {
                    Ui.close();
                    Quickshell.execDetached(["ghostty", "-e", "nmtui"]);
                }
            }
        }
    }
}
