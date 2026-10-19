import QtQuick
import qs
import "../Hardware.js" as Hardware

// The sign's glass: the panel as LED dots, cut to the sign's rounded
// outline (the design's `.pn`). Children are authored in dots, as on any
// DotSurface. Centred in its parent, as many whole dots as fit.
//   Glass { radius: 26; Neon { text: "21:47" } }
DotSurface {
    id: glass

    // Corner radius in px, like the tubes round it.
    property real radius: 26

    anchors.centerIn: parent
    cols: Math.max(1, Math.floor(parent.width / Tokens.pitch))
    rows: Math.max(1, Math.floor(parent.height / Tokens.pitch))
    shape: Hardware.rounded(0, 0, cols, rows, radius / Tokens.pitch)
}
