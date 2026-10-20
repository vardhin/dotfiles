import QtQuick
import QtQuick.Window
import "nixie" as V
Window { id: win; width: 760; height: 300; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ on: true, left: "42:10", holders: [{who: "dotshell", why: "caffeine"}, {who: "mpv", why: "playing video"}] })
  property var ctx2: ({ on: false, left: "", holders: [] })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nixie"; Tokens.slot0 = "#ff7a1a"; Tokens.slot1 = "#ffb366"; Tokens.slot2 = "#c2410c"; Tokens.unlit = "#2b130a"; Tokens.glass = "#0a0503"; Tokens.current = ({ slots: ["#ff7a1a", "#ffb366", "#c2410c"], unlit: "#2b130a", glass: "#0a0503", ramp: ["#3a1606", "#8a3510", "#ff7a1a", "#ffc285"], glow: 0.85, shape: "round" }); Tokens.previous = Tokens.current }
    V.Caffeine { x: 20; y: 20; width: 264; height: 108; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Caffeine { x: 20; y: 160; width: 264; height: 108; ctx: win.ctx2; sink: sink; panel: ({}); words: ({}) }
    V.Caffeine { x: 340; y: 20; width: 384; height: 240; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
