import QtQuick
import QtQuick.Window
import "nineties" as V
Window { id: win; width: 760; height: 420; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ time: "21:47", utc: "16:17", dd: "19", year: "2026" })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nineties"; Tokens.slot0 = "#ff2e97"; Tokens.slot1 = "#1fa8ff"; Tokens.slot2 = "#ffe600"; Tokens.unlit = "#22123a"; Tokens.glass = "#0a0514"; Tokens.current = ({ slots: ["#ff2e97", "#1fa8ff", "#ffe600"], unlit: "#22123a", glass: "#0a0514", ramp: ["#3b0d5c", "#a3157f", "#ff2e97", "#ffe600"], glow: 0.9, shape: "round" }); Tokens.previous = Tokens.current }
    V.Clock { x: 20; y: 20; width: 288; height: 144; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Clock { x: 20; y: 190; width: 360; height: 160; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Clock { x: 340; y: 20; width: 408; height: 360; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
