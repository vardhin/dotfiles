import QtQuick
import QtQuick.Window
import "vapor" as V
Window { id: win; width: 760; height: 300; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ on: true, left: "42:10", holders: [{who: "dotshell", why: "caffeine"}, {who: "mpv", why: "playing video"}] })
  property var ctx2: ({ on: false, left: "", holders: [] })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.era = "vapor"; Tokens.slot0 = "#ff71ce"; Tokens.slot1 = "#01cdfe"; Tokens.slot2 = "#b967ff"; Tokens.unlit = "#2d1b4e"; Tokens.glass = "#130a24"; Tokens.current = ({ slots: ["#ff71ce", "#01cdfe", "#b967ff"], unlit: "#2d1b4e", glass: "#130a24", ramp: ["#3d1d63", "#b967ff", "#ff71ce", "#fffb96"], glow: 0.7, shape: "round" }); Tokens.previous = Tokens.current }
    V.Caffeine { x: 20; y: 20; width: 264; height: 108; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Caffeine { x: 20; y: 160; width: 264; height: 108; ctx: win.ctx2; sink: sink; panel: ({}); words: ({}) }
    V.Caffeine { x: 340; y: 20; width: 384; height: 240; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
