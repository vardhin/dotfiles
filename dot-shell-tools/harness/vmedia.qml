import QtQuick
import QtQuick.Window
import "vapor" as V
Window { id: win; width: 940; height: 230; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ active: true, playing: true, progress: 0.42, title: "Oole Oolele 4K", artist: "90SHD", album: "Singles", pos: 98, len: 234, art: "" })
  property var ctx2: ({ active: false, count: 120 })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.era = "vapor"; Tokens.slot0 = "#ff71ce"; Tokens.slot1 = "#01cdfe"; Tokens.slot2 = "#b967ff"; Tokens.unlit = "#2d1b4e"; Tokens.glass = "#130a24"; Tokens.current = ({ slots: ["#ff71ce", "#01cdfe", "#b967ff"], unlit: "#2d1b4e", glass: "#130a24", ramp: ["#3d1d63", "#b967ff", "#ff71ce", "#fffb96"], glow: 0.7, shape: "round" }); Tokens.previous = Tokens.current }
    V.Media { x: 20; y: 20; width: 432; height: 168; ctx: win.ctx; sink: sink; panel: ({}); words: ({ idle: "Nothing playing" }) }
    V.Media { x: 480; y: 20; width: 432; height: 168; ctx: win.ctx2; sink: sink; panel: ({}); words: ({ idle: "Nothing playing" }) }
  }
  Timer { interval: 2000; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
