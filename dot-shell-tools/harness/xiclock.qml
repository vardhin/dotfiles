import QtQuick
import QtQuick.Window
import "nineties" as V
Window { id: win; width: 760; height: 420; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ time: "21:47", utc: "16:17", dd: "19", year: "2026" })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nineties"; Tokens.slot0 = "#c776c4"; Tokens.slot1 = "#e57ba9"; Tokens.slot2 = "#dff57e"; Tokens.unlit = "#2a1f30"; Tokens.glass = "#120d17"; Tokens.current = ({ slots: ["#c776c4", "#e57ba9", "#dff57e"], unlit: "#2a1f30", glass: "#120d17", ramp: ["#2a1f30", "#6a3f72", "#c776c4", "#dff57e"], glow: 0.35, shape: "round" }); Tokens.previous = Tokens.current }
    V.Clock { x: 20; y: 20; width: 288; height: 144; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Clock { x: 20; y: 190; width: 360; height: 160; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Clock { x: 340; y: 20; width: 408; height: 360; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
