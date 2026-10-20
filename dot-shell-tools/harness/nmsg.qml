import QtQuick
import QtQuick.Window
import "nixie" as V
Window { id: win; width: 940; height: 400; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property real t: Date.now()
  property var items: [{app:"Firefox",summary:"Download finished · thesis-v4.pdf",ts:t},{app:"Firefox",summary:"Download finished · screenshot_0012.png",ts:t-60000},{app:"Telegram",summary:"2 new messages",ts:t-300000},{app:"pacman",summary:"14 updates waiting",ts:t-900000},{app:"Battery",summary:"Charged to 80%",ts:t-2000000}]
  property var ctx: ({ dnd: false, live: 3, items: items })
  property var ctx2: ({ dnd: true, live: 0, items: items })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nixie"; Tokens.slot0 = "#ff7a1a"; Tokens.slot1 = "#ffb366"; Tokens.slot2 = "#c2410c"; Tokens.unlit = "#2b130a"; Tokens.glass = "#0a0503"; Tokens.current = ({ slots: ["#ff7a1a", "#ffb366", "#c2410c"], unlit: "#2b130a", glass: "#0a0503", ramp: ["#3a1606", "#8a3510", "#ff7a1a", "#ffc285"], glow: 0.85, shape: "round" }); Tokens.previous = Tokens.current }
    V.Messages { x: 20; y: 20; width: 360; height: 168; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Messages { x: 20; y: 210; width: 360; height: 168; ctx: win.ctx2; sink: sink; panel: ({}); words: ({}) }
    V.Messages { x: 400; y: 20; width: 528; height: 360; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 2000; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
