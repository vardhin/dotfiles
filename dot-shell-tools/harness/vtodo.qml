import QtQuick
import QtQuick.Window
import "vapor" as V
Window { id: win; width: 940; height: 420; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var today: [{n:1,text:"Lock the now playing panel design",done:true,due:"today"},{n:2,text:"Phase 10 · data-driven panel schema",done:false,due:"today",next:true,prio:"!"},{n:3,text:"Wire LRCLIB synced lyrics",done:false,due:"tue"},{n:4,text:"Match local mp3s to their videos",done:false,due:"fri",lists:["dotfiles"]},{n:5,text:"Clock and workspace panels",done:true,due:"sat"}]
  property var ctx: ({ today: today, items: today, left: 3, lists: [{name:"dotfiles",count:5},{name:"research",count:2},{name:"later",count:7}] })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.era = "vapor"; Tokens.slot0 = "#ff71ce"; Tokens.slot1 = "#01cdfe"; Tokens.slot2 = "#b967ff"; Tokens.unlit = "#2d1b4e"; Tokens.glass = "#130a24"; Tokens.current = ({ slots: ["#ff71ce", "#01cdfe", "#b967ff"], unlit: "#2d1b4e", glass: "#130a24", ramp: ["#3d1d63", "#b967ff", "#ff71ce", "#fffb96"], glow: 0.7, shape: "round" }); Tokens.previous = Tokens.current }
    V.Todo { x: 20; y: 20; width: 360; height: 192; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Todo { x: 400; y: 20; width: 528; height: 384; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 2000; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
