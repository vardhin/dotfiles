import QtQuick
import QtQuick.Window
import "nightvision" as V
Window { id: win; width: 940; height: 380; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ list: [{id:9,home:true,windows:0},{id:1,windows:2},{id:2,windows:3,focused:true},{id:3,windows:1},{id:4,windows:0}] })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nightvision"; Tokens.slot0 = "#7dff6a"; Tokens.slot1 = "#d6ffc9"; Tokens.slot2 = "#2fae2a"; Tokens.unlit = "#0d260b"; Tokens.glass = "#040a03"; Tokens.current = ({ slots: ["#7dff6a", "#d6ffc9", "#2fae2a"], unlit: "#0d260b", glass: "#040a03", ramp: ["#0f3a0c", "#2b8a22", "#62e04f", "#c9ffb8"], glow: 0.6, shape: "round" }); Tokens.previous = Tokens.current }
    V.Workspaces { x: 20; y: 20; width: 360; height: 96; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Workspaces { x: 20; y: 140; width: 420; height: 160; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Workspaces { x: 450; y: 20; width: 480; height: 312; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 2000; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
