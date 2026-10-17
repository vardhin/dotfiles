pragma Singleton

import QtQuick
import Quickshell
import qs

// Where a dragged panel would dock (DeskPanel.qml, the strip and the rail
// all ask here), from the slots the strip and the rail publish in
// Panels.slots: { id: { place, zone, order, x, y, w, h } } in screen px.
//   stripAim(x, screenW) -> { zone, order }   rail: railAim(y) -> order
// The strip's zones by x: left (l) up to 35% of the screen, center (c) to
// 60%, then right (r) up to the settings words and end (e) after them.
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
        const settings = Panels.slots["_settings"];
        let zone = x < screenW * 0.35 ? "l" : x < screenW * 0.6 ? "c" : "r";
        if (settings && x > settings.x + settings.w)
            zone = "e";
        const order = items("strip", skip).filter(s => s.zone === zone && s.x + s.w / 2 < x).length;
        return { zone: zone, order: order };
    }

    function railAim(y: real): int {
        const skip = Panels.drag?.id ?? "";
        return items("rail", skip).filter(s => s.y + s.h / 2 < y).length;
    }
}
