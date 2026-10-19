import QtQuick
import qs

// What every Tokyo Night face is: a desktop panel drawn as the design
// canvas's neon sign (dot-shell-panels.html) instead of the generic board.
// DeskPanel.qml loads one per template, compact or `big` (expanded), and
// hands it the panel's feed (ctx), its action sink and the era's words.
Item {
    id: face

    required property var ctx
    required property var sink
    required property var panel
    required property var words
    // Expanded on home.
    property bool big: false

    readonly property bool tokyoFace: true
    readonly property int pitch: Tokens.pitch

    // px -> whole dots, for laying out the glass from crisp measurements.
    function d(px: real): int {
        return Math.round(px / pitch);
    }

    function run(a: string): void {
        sink.run(a);
    }

    // Press, move, release from a Hit: a hold or a drag lifts the panel.
    function grip(kind: string, area: Item, mouse: var): bool {
        const p = area.mapToItem(null, mouse?.x ?? 0, mouse?.y ?? 0);
        return sink.grip(kind, p.x, p.y);
    }
}
