import QtQuick
import QtQuick.Window
import "flap" as V
Window { id: win; width: 760; height: 300; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ on: true, left: "42:10", holders: [{who: "dotshell", why: "caffeine"}, {who: "mpv", why: "playing video"}] })
  property var ctx2: ({ on: false, left: "", holders: [] })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "flap"; Tokens.slot0 = "#f2f2e6"; Tokens.slot1 = "#ffd400"; Tokens.slot2 = "#ff8c00"; Tokens.unlit = "#1e1e1e"; Tokens.glass = "#0b0b0b"; Tokens.current = ({ slots: ["#f2f2e6", "#ffd400", "#ff8c00"], unlit: "#1e1e1e", glass: "#0b0b0b", ramp: ["#262626", "#6e6e64", "#bdbdb0", "#f2f2e6"], glow: 0.1, shape: "square" }); Tokens.previous = Tokens.current }
    V.Caffeine { x: 20; y: 20; width: 264; height: 108; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Caffeine { x: 20; y: 160; width: 264; height: 108; ctx: win.ctx2; sink: sink; panel: ({}); words: ({}) }
    V.Caffeine { x: 340; y: 20; width: 384; height: 240; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
