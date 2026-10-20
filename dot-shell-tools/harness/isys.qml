import QtQuick
import QtQuick.Window
import "nineties" as V
Window { id: win; width: 1000; height: 420; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ cpu: 0.38, mem: 0.6, memGb: 11.2, temp: 61, tempF: 0.44, hasTemp: true,
    cpuHist: [0.2,0.3,0.5,0.4,0.2,0.1,0.3,0.6,0.5,0.3,0.4,0.7,0.6,0.38,0.2,0.3,0.5,0.4,0.2,0.1,0.3,0.6,0.5,0.3,0.4,0.7,0.6,0.38],
    memHist: [0.5,0.55,0.56,0.58,0.6,0.6,0.61,0.6,0.59,0.6], tempHist: [0.4,0.42,0.44,0.45,0.44],
    top: [{name:"firefox",cpu:"14.2",mem:"6",rss:2200000,pid:"3121"},{name:"code",cpu:"8.1",mem:"4",rss:1400000,pid:"2204"},{name:"mpv",cpu:"4.0",mem:"1",rss:310000,pid:"4471"},{name:"quickshell",cpu:"2.3",mem:"1",rss:280000,pid:"988"},{name:"dotd",cpu:"1.1",mem:"1",rss:190000,pid:"1017"},{name:"pipewire",cpu:"0.5",mem:"0",rss:40000,pid:"731"}] })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nineties"; Tokens.slot0 = "#ff2e97"; Tokens.slot1 = "#1fa8ff"; Tokens.slot2 = "#ffe600"; Tokens.unlit = "#22123a"; Tokens.glass = "#0a0514"; Tokens.current = ({ slots: ["#ff2e97", "#1fa8ff", "#ffe600"], unlit: "#22123a", glass: "#0a0514", ramp: ["#3b0d5c", "#a3157f", "#ff2e97", "#ffe600"], glow: 0.9, shape: "round" }); Tokens.previous = Tokens.current }
    V.System { x: 20; y: 20; width: 360; height: 132; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.System { x: 20; y: 170; width: 400; height: 150; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.System { x: 440; y: 20; width: 504; height: 360; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
