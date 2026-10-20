import QtQuick

// Leans a whole compact gadget 10° like the signs (the pager's LCD, the
// camcorder's viewfinder, inside a Plate), so every compact panel on the
// desk leans the same way: its children are laid out upright in `body`
// (narrower by the lean) and the lot is sheared about its centre, top edge
// right, in a multisampled layer so the slanted edges come out smooth.
//   Leaning { anchors.fill: parent; Pager { anchors.fill: parent } }
Item {
    id: lean

    readonly property real by: Math.round(height * 0.1763)
    default property alias content: body.data

    layer.enabled: true
    layer.samples: 4
    layer.smooth: true

    Item {
        id: body
        x: lean.by / 2
        width: lean.width - lean.by
        height: lean.height
        transform: Lean {
            item: body
        }
    }
}
