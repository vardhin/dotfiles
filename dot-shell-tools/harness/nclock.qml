import QtQuick
import QtQuick.Window
import "nixie" as V
Window { id: win; width: 760; height: 420; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ time: "21:47", utc: "16:17", dd: "19", year: "2026" })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nixie"; Tokens.slot0 = "#ff7a1a"; Tokens.slot1 = "#ffb366"; Tokens.slot2 = "#c2410c"; Tokens.unlit = "#2b130a"; Tokens.glass = "#0a0503"; Tokens.current = ({ slots: ["#ff7a1a", "#ffb366", "#c2410c"], unlit: "#2b130a", glass: "#0a0503", ramp: ["#3a1606", "#8a3510", "#ff7a1a", "#ffc285"], glow: 0.85, shape: "round" }); Tokens.previous = Tokens.current }
    V.Clock { x: 20; y: 20; width: 288; height: 144; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Clock { x: 20; y: 190; width: 360; height: 160; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Clock { x: 340; y: 20; width: 408; height: 360; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
