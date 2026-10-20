import QtQuick
import QtQuick.Window
import "nineties" as V
Window { id: win; width: 940; height: 400; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property real t: Date.now()
  property var items: [{app:"Firefox",summary:"Download finished · thesis-v4.pdf",ts:t},{app:"Firefox",summary:"Download finished · screenshot_0012.png",ts:t-60000},{app:"Telegram",summary:"2 new messages",ts:t-300000},{app:"pacman",summary:"14 updates waiting",ts:t-900000},{app:"Battery",summary:"Charged to 80%",ts:t-2000000}]
  property var ctx: ({ dnd: false, live: 3, items: items })
  property var ctx2: ({ dnd: true, live: 0, items: items })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nineties"; Tokens.slot0 = "#ff2e97"; Tokens.slot1 = "#1fa8ff"; Tokens.slot2 = "#ffe600"; Tokens.unlit = "#22123a"; Tokens.glass = "#0a0514"; Tokens.current = ({ slots: ["#ff2e97", "#1fa8ff", "#ffe600"], unlit: "#22123a", glass: "#0a0514", ramp: ["#3b0d5c", "#a3157f", "#ff2e97", "#ffe600"], glow: 0.9, shape: "round" }); Tokens.previous = Tokens.current }
    V.Messages { x: 20; y: 20; width: 360; height: 168; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Messages { x: 20; y: 210; width: 360; height: 168; ctx: win.ctx2; sink: sink; panel: ({}); words: ({}) }
    V.Messages { x: 400; y: 20; width: 528; height: 360; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 2000; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
