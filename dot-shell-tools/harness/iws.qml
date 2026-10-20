import QtQuick
import QtQuick.Window
import "nineties" as V
Window { id: win; width: 940; height: 380; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ list: [{id:9,home:true,windows:0},{id:1,windows:2},{id:2,windows:3,focused:true},{id:3,windows:1},{id:4,windows:0}] })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nineties"; Tokens.slot0 = "#ff2e97"; Tokens.slot1 = "#1fa8ff"; Tokens.slot2 = "#ffe600"; Tokens.unlit = "#22123a"; Tokens.glass = "#0a0514"; Tokens.current = ({ slots: ["#ff2e97", "#1fa8ff", "#ffe600"], unlit: "#22123a", glass: "#0a0514", ramp: ["#3b0d5c", "#a3157f", "#ff2e97", "#ffe600"], glow: 0.9, shape: "round" }); Tokens.previous = Tokens.current }
    V.Workspaces { x: 20; y: 20; width: 360; height: 96; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Workspaces { x: 20; y: 140; width: 420; height: 160; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Workspaces { x: 450; y: 20; width: 480; height: 312; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 2000; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
