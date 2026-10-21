import QtQuick
import QtQuick.Window
import "nineties" as V
Window { id: win; width: 940; height: 420; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var today: [{n:1,text:"Lock the now playing panel design",done:true,due:"today"},{n:2,text:"Phase 10 · data-driven panel schema",done:false,due:"today",next:true,prio:"!"},{n:3,text:"Wire LRCLIB synced lyrics",done:false,due:"tue"},{n:4,text:"Match local mp3s to their videos",done:false,due:"fri",lists:["dotfiles"]},{n:5,text:"Clock and workspace panels",done:true,due:"sat"}]
  property var ctx: ({ today: today, items: today, left: 3, lists: [{name:"dotfiles",count:5},{name:"research",count:2},{name:"later",count:7}] })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nineties"; Tokens.slot0 = "#c776c4"; Tokens.slot1 = "#e57ba9"; Tokens.slot2 = "#dff57e"; Tokens.unlit = "#2a1f30"; Tokens.glass = "#120d17"; Tokens.current = ({ slots: ["#c776c4", "#e57ba9", "#dff57e"], unlit: "#2a1f30", glass: "#120d17", ramp: ["#2a1f30", "#6a3f72", "#c776c4", "#dff57e"], glow: 0.35, shape: "round" }); Tokens.previous = Tokens.current }
    V.Todo { x: 20; y: 20; width: 360; height: 192; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Todo { x: 400; y: 20; width: 528; height: 384; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 2000; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
