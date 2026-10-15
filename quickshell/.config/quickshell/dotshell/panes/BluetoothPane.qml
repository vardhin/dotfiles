import QtQuick
import Quickshell
import qs
import qs.services

// Bluetooth: power, scan, devices (click to connect, disconnect or pair).
Pane {
    id: pane

    name: "bluetooth"
    anchors {
        top: true
        right: true
    }

    readonly property int inner: 36 * Tokens.charDots
    cols: inner + 8
    rows: col.implicitHeight + 8

    Column {
        id: col
        x: 4
        y: 4
        width: pane.inner
        spacing: 3

        Line {
            label: "BLUETOOTH"
            labelColor: Tokens.slot2
            DotButton {
                text: Bt.scanning ? "SCANNING" : "SCAN"
                active: Bt.scanning
                enabled: Bt.powered
                onClicked: Bt.scan()
            }
            DotButton {
                text: Bt.powered ? "ON" : "OFF"
                active: Bt.powered
                enabled: Bt.present
                onClicked: Bt.setEnabled(!Bt.powered)
            }
        }

        Rule {}

        DotText {
            visible: !Bt.present || (Bt.powered && Bt.devices.length === 0)
            height: Tokens.lineDots
            text: Bt.present ? "NO DEVICES" : "NO ADAPTER"
            opacity: 0.5
        }

        Repeater {
            model: Bt.powered ? Bt.devices.slice(0, 12) : []

            Item {
                id: row
                required property var modelData
                width: pane.inner
                height: Tokens.lineDots

                Frame {
                    anchors.fill: parent
                    visible: row.modelData.connected
                }
                DotText {
                    x: 2
                    width: parent.width - x - tag.width - 4
                    text: (row.modelData.name || row.modelData.deviceName).toUpperCase()
                    color: Tokens.slot0
                    elide: Text.ElideRight
                }
                DotText {
                    id: tag
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    text: {
                        const d = row.modelData;
                        if (d.pairing)
                            return "PAIRING";
                        if (d.connected)
                            return d.batteryAvailable ? Math.round(d.battery * 100) + "%" : "ON";
                        return d.paired ? "PAIRED" : "NEW";
                    }
                    color: Tokens.slot1
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Bt.toggle(row.modelData)
                }
            }
        }

        Rule {}

        DotButton {
            text: "BLUETOOTHCTL"
            color: Tokens.slot1
            onClicked: {
                Ui.close();
                Quickshell.execDetached(["ghostty", "-e", "bluetoothctl"]);
            }
        }
    }
}
