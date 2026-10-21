import QtQuick
import QtQuick.Window
import "nineties" as V
Window { id: win; width: 760; height: 300; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ on: true, left: "42:10", holders: [{who: "dotshell", why: "caffeine"}, {who: "mpv", why: "playing video"}] })
  property var ctx2: ({ on: false, left: "", holders: [] })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nineties"; Tokens.slot0 = "#5fb8ac"; Tokens.slot1 = "#a77ba6"; Tokens.slot2 = "#d6e6a4"; Tokens.unlit = "#2e2434"; Tokens.glass = "#1a1420"; Tokens.current = ({ slots: ["#5fb8ac", "#a77ba6", "#d6e6a4"], unlit: "#2e2434", glass: "#1a1420", ramp: ["#2e2434", "#5e4463", "#5fb8ac", "#d6e6a4"], glow: 0.25, shape: "round" }); Tokens.previous = Tokens.current }
    V.Caffeine { x: 20; y: 20; width: 264; height: 108; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Caffeine { x: 20; y: 160; width: 264; height: 108; ctx: win.ctx2; sink: sink; panel: ({}); words: ({}) }
    V.Caffeine { x: 340; y: 20; width: 384; height: 240; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
