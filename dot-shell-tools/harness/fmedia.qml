import QtQuick
import QtQuick.Window
import "flap" as V
Window { id: win; width: 940; height: 230; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ active: true, playing: true, progress: 0.42, title: "Oole Oolele 4K", artist: "90SHD", album: "Singles", pos: 98, len: 234, art: "" })
  property var ctx2: ({ active: false, count: 120 })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "flap"; Tokens.slot0 = "#f2f2e6"; Tokens.slot1 = "#ffd400"; Tokens.slot2 = "#ff8c00"; Tokens.unlit = "#1e1e1e"; Tokens.glass = "#0b0b0b"; Tokens.current = ({ slots: ["#f2f2e6", "#ffd400", "#ff8c00"], unlit: "#1e1e1e", glass: "#0b0b0b", ramp: ["#262626", "#6e6e64", "#bdbdb0", "#f2f2e6"], glow: 0.1, shape: "square" }); Tokens.previous = Tokens.current }
    V.Media { x: 20; y: 20; width: 432; height: 168; ctx: win.ctx; sink: sink; panel: ({}); words: ({ idle: "Nothing playing" }) }
    V.Media { x: 480; y: 20; width: 432; height: 168; ctx: win.ctx2; sink: sink; panel: ({}); words: ({ idle: "Nothing playing" }) }
  }
  Timer { interval: 2000; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
