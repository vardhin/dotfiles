pragma Singleton

import QtQuick
import Quickshell
import qs

// Where a dragged panel would dock (DeskPanel.qml, the strip and the rail
// all ask here), from the slots the strip and the rail publish in
// Panels.slots: { id: { place, zone, order, x, y, w, h } } in screen px.
//   stripAim(x, screenW) -> { zone, order }   rail: railAim(y) -> order
// The strip's zones by x, from where TopStrip says they meet (_zones):
// left (l), center (c), right (r) up to the middle of the settings words,
// end (e) after it.
Singleton {
    id: root

    function items(place: string, skip: string): var {
        const out = [];
        for (const id in Panels.slots) {
            const s = Panels.slots[id];
            if (s.place === place && id !== skip && id[0] !== "_")
                out.push(Object.assign({ id: id }, s));
        }
        return out;
    }

    function stripAim(x: real, screenW: real): var {
        const skip = Panels.drag?.id ?? "";
        const z = Panels.slots["_zones"];
        let zone;
        if (z)
            zone = x < z.lc ? "l" : x < z.cr ? "c" : x < z.re ? "r" : "e";
        else
            zone = x < screenW * 0.35 ? "l" : x < screenW * 0.6 ? "c" : "r";
        const order = items("strip", skip).filter(s => s.zone === zone && s.x + s.w / 2 < x).length;
        return { zone: zone, order: order };
    }

    function railAim(y: real): int {
        const skip = Panels.drag?.id ?? "";
        return items("rail", skip).filter(s => s.y + s.h / 2 < y).length;
    }
}
