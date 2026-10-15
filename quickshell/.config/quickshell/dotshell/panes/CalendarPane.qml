import QtQuick
import qs

// Month grid under the clock. Wheel or < > to change month; today is lit.
Pane {
    id: pane

    name: "calendar"
    anchors.top: true

    readonly property int cell: 3 * Tokens.charDots
    readonly property int inner: 7 * cell
    cols: inner + 8
    rows: col.implicitHeight + 8

    property date today: new Date()
    property int offset: 0
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    // Monday first.
    readonly property int lead: (month.getDay() + 6) % 7
    readonly property int days: new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()

    onOpened: {
        today = new Date();
        offset = 0;
    }
    onKeyPressed: event => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H)
            offset -= 1;
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_L)
            offset += 1;
    }

    Column {
        id: col
        x: 4
        y: 4
        width: pane.inner
        spacing: 3

        Item {
            width: parent.width
            height: Tokens.lineDots

            DotButton {
                text: "<"
                onClicked: pane.offset -= 1
            }
            DotText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(pane.month, "MMMM yyyy").toUpperCase()
                color: Tokens.slot2
            }
            DotButton {
                anchors.right: parent.right
                text: ">"
                onClicked: pane.offset += 1
            }
        }

        Rule {}

        Grid {
            columns: 7

            Repeater {
                model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                DotText {
                    required property string modelData
                    required property int index
                    width: pane.cell
                    height: Tokens.lineDots
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index >= 5 ? Tokens.slot2 : Tokens.slot1
                }
            }

            Repeater {
                model: 42

                Item {
                    id: day
                    required property int index
                    readonly property int n: index - pane.lead + 1
                    readonly property bool real: n >= 1 && n <= pane.days
                    readonly property bool isToday: real && pane.offset === 0 && n === pane.today.getDate()
                    width: pane.cell
                    height: Tokens.lineDots
                    visible: index < 35 || pane.lead + pane.days > 35

                    Frame {
                        anchors.fill: parent
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        visible: day.isToday
                    }
                    DotText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: day.real ? day.n : ""
                        color: Tokens.slot0
                    }
                }
            }
        }
    }

    MouseArea {
        width: pane.cols
        height: pane.rows
        acceptedButtons: Qt.NoButton
        onWheel: wheel => pane.offset += wheel.angleDelta.y > 0 ? -1 : 1
    }
}
