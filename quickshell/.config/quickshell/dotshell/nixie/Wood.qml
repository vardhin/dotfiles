import QtQuick

// The walnut case, crisp: grain bands across it, a brass rule just inside
// its edge and a dark one inside that (`rule` px each; the strip and rail
// take one brass px). Contents sit `inset` in.
//   Wood { anchors.fill: parent }
Rectangle {
    id: wood

    property int rule: 2
    property bool vertical: false
    // An arched top (the workspaces dial): the top corners' radius.
    property real dome: 0
    readonly property int inset: rule * 2 + 8

    radius: 6
    topLeftRadius: dome > 0 ? dome : radius
    topRightRadius: dome > 0 ? dome : radius
    gradient: Gradient {
        orientation: wood.vertical ? Gradient.Vertical : Gradient.Horizontal
        GradientStop {
            position: 0
            color: Ink.woodA
        }
        GradientStop {
            position: 0.3
            color: Ink.woodB
        }
        GradientStop {
            position: 0.6
            color: Ink.woodC
        }
        GradientStop {
            position: 1
            color: Ink.woodB
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: wood.radius
        topLeftRadius: wood.topLeftRadius
        topRightRadius: wood.topRightRadius
        color: "transparent"
        border.width: wood.rule
        border.color: Ink.brass
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: wood.rule
        radius: Math.max(0, wood.radius - wood.rule)
        topLeftRadius: Math.max(0, wood.topLeftRadius - wood.rule)
        topRightRadius: Math.max(0, wood.topRightRadius - wood.rule)
        color: "transparent"
        border.width: wood.rule
        border.color: Ink.edge
        visible: wood.rule > 1
    }
}
