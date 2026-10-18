import QtQuick
import qs.services

// A device's transport (Hardware.js `keys`), laid out in the box it is
// given: a row (stretched by weight, or packed at the start, centre or end),
// or each key at its own spot (`free`, a handheld's d-pad and buttons),
// centred in the box. The same keys on the mini panel and on the full
// device (Super M); `row` forces a plain row (the full device has its keys
// in a row under the window, whatever the panel does).
Item {
    id: root

    required property var hw
    property var grip: null
    property bool row: false

    readonly property var k: hw.keys
    readonly property bool free: k.free && !row
    readonly property var items: k.items

    // x of each key, and the widths, for a row.
    readonly property var widths: {
        const n = items.length, gaps = k.gap * Math.max(0, n - 1);
        if (k.align === "stretch") {
            const total = items.reduce((a, i) => a + (i.weight ?? 1), 0);
            return items.map(i => Math.floor((width - gaps) * (i.weight ?? 1) / total));
        }
        return items.map(i => i.w ?? k.h);
    }
    readonly property var xs: {
        const used = widths.reduce((a, w) => a + w, 0) + k.gap * Math.max(0, items.length - 1);
        let x = k.align === "end" ? width - used : k.align === "center" ? Math.floor((width - used) / 2) : 0;
        return widths.map(w => {
            const at = x;
            x += w + k.gap;
            return at;
        });
    }
    // A free block's own height (its keys and their captions).
    readonly property real blockH: free ? Math.max(...items.map(i => (i.y ?? 0) + (i.h ?? k.h))) : k.h
    readonly property real blockW: free ? Math.max(...items.map(i => (i.x ?? 0) + (i.w ?? k.h))) : width

    function run(what: string): void {
        if (what === "prev")
            Media.previous();
        else if (what === "next")
            Media.next();
        else if (what === "toggle")
            Media.toggle();
        else if (what === "pane")
            Ui.toggle("media", null);
    }

    Repeater {
        model: root.items

        DeviceKey {
            required property var modelData
            required property int index
            spec: modelData
            grip: root.grip
            width: root.free ? modelData.w ?? root.k.h : root.widths[index]
            height: root.free ? modelData.h ?? root.k.h : Math.min(root.height, modelData.h ?? root.k.h)
            x: root.free ? Math.floor((root.width - root.blockW) / 2) + (modelData.x ?? 0) : root.xs[index]
            y: root.free ? Math.floor((root.height - root.blockH) / 2) + (modelData.y ?? 0) : Math.floor((root.height - height) / 2)
            onAct: what => root.run(what)
        }
    }
}
