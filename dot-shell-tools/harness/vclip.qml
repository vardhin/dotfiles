import QtQuick
import QtQuick.Window
import "vapor" as V
Window { id: win; width: 940; height: 380; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property real t: Date.now()
  property var items: [{text:"sudo pacman -Syu --needed",preview:"sudo pacman -Syu --needed",at:t},{text:"#ff3cac",preview:"#ff3cac",at:t-60000},{text:"https://lrclib.net/api/get?track_name=Oole",preview:"lrclib.net/api/get?track_name=Oole",at:t-400000},{text:"yay -S --needed matugen-bin",preview:"yay -S --needed matugen-bin",at:t-900000},{text:"pacman -Qdt",preview:"pacman -Qdt",at:t-90000000}]
  property var ctx: ({ items: items })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.era = "vapor"; Tokens.slot0 = "#ff71ce"; Tokens.slot1 = "#01cdfe"; Tokens.slot2 = "#b967ff"; Tokens.unlit = "#2d1b4e"; Tokens.glass = "#130a24"; Tokens.current = ({ slots: ["#ff71ce", "#01cdfe", "#b967ff"], unlit: "#2d1b4e", glass: "#130a24", ramp: ["#3d1d63", "#b967ff", "#ff71ce", "#fffb96"], glow: 0.7, shape: "round" }); Tokens.previous = Tokens.current }
    V.Clipboard { x: 20; y: 20; width: 360; height: 168; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Clipboard { x: 400; y: 20; width: 528; height: 336; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 2000; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
