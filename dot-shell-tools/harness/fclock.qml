import QtQuick
import QtQuick.Window
import "flap" as V
Window { id: win; width: 760; height: 420; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ time: "21:47", utc: "16:17", dd: "19", year: "2026" })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 5; Tokens.era = "flap"; Tokens.slot0 = "#f2f2e6"; Tokens.slot1 = "#ffd400"; Tokens.slot2 = "#ff8c00"; Tokens.unlit = "#1e1e1e"; Tokens.glass = "#0b0b0b"; Tokens.current = ({ slots: ["#f2f2e6", "#ffd400", "#ff8c00"], unlit: "#1e1e1e", glass: "#0b0b0b", ramp: ["#262626", "#6e6e64", "#bdbdb0", "#f2f2e6"], glow: 0.1, shape: "square" }); Tokens.previous = Tokens.current }
    V.Clock { x: 20; y: 20; width: 288; height: 144; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Clock { x: 20; y: 190; width: 360; height: 160; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Clock { x: 340; y: 20; width: 408; height: 360; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
