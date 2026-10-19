import QtQuick

// A clickable part of a face. A click runs `action` (Actions.qml, or the
// panel's own verbs) and fires tap(); a hold or a drag from here still
// lifts the whole panel, like anywhere else on it (DeskPanel.sink.grip).
//   Hit { anchors.fill: parent; action: "capture shot area" }
MouseArea {
    id: hit

    property string action: ""
    signal tap
    property bool dragged: false

    // The face this sits in (Face.qml), wherever in it.
    readonly property Item face: {
        for (let p = parent; p; p = p.parent)
            if (p.tokyoFace === true)
                return p;
        return null;
    }

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: mouse => {
        dragged = false;
        face?.grip("press", hit, mouse);
    }
    onPositionChanged: mouse => {
        if (pressed)
            face?.grip("move", hit, mouse);
    }
    onReleased: mouse => dragged = face ? face.grip("release", hit, mouse) : false
    onCanceled: face?.grip("cancel", hit, null)
    onClicked: {
        if (dragged)
            return;
        if (action)
            face?.run(action);
        tap();
    }
}
