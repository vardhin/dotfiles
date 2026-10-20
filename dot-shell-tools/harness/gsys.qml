import QtQuick
import QtQuick.Window
import "nightvision" as V
Window { id: win; width: 1000; height: 420; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ cpu: 0.38, mem: 0.6, memGb: 11.2, temp: 61, tempF: 0.44, hasTemp: true,
    cpuHist: [0.2,0.3,0.5,0.4,0.2,0.1,0.3,0.6,0.5,0.3,0.4,0.7,0.6,0.38,0.2,0.3,0.5,0.4,0.2,0.1,0.3,0.6,0.5,0.3,0.4,0.7,0.6,0.38],
    memHist: [0.5,0.55,0.56,0.58,0.6,0.6,0.61,0.6,0.59,0.6], tempHist: [0.4,0.42,0.44,0.45,0.44],
    top: [{name:"firefox",cpu:"14.2",mem:"6",rss:2200000,pid:"3121"},{name:"code",cpu:"8.1",mem:"4",rss:1400000,pid:"2204"},{name:"mpv",cpu:"4.0",mem:"1",rss:310000,pid:"4471"},{name:"quickshell",cpu:"2.3",mem:"1",rss:280000,pid:"988"},{name:"dotd",cpu:"1.1",mem:"1",rss:190000,pid:"1017"},{name:"pipewire",cpu:"0.5",mem:"0",rss:40000,pid:"731"}] })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nightvision"; Tokens.slot0 = "#7dff6a"; Tokens.slot1 = "#d6ffc9"; Tokens.slot2 = "#2fae2a"; Tokens.unlit = "#0d260b"; Tokens.glass = "#040a03"; Tokens.current = ({ slots: ["#7dff6a", "#d6ffc9", "#2fae2a"], unlit: "#0d260b", glass: "#040a03", ramp: ["#0f3a0c", "#2b8a22", "#62e04f", "#c9ffb8"], glow: 0.6, shape: "round" }); Tokens.previous = Tokens.current }
    V.System { x: 20; y: 20; width: 360; height: 132; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.System { x: 20; y: 170; width: 400; height: 150; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.System { x: 440; y: 20; width: 504; height: 360; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
