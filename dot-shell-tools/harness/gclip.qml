import QtQuick
import QtQuick.Window
import "nightvision" as V
Window { id: win; width: 940; height: 380; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property real t: Date.now()
  property var items: [{text:"sudo pacman -Syu --needed",preview:"sudo pacman -Syu --needed",at:t},{text:"#ff3cac",preview:"#ff3cac",at:t-60000},{text:"https://lrclib.net/api/get?track_name=Oole",preview:"lrclib.net/api/get?track_name=Oole",at:t-400000},{text:"yay -S --needed matugen-bin",preview:"yay -S --needed matugen-bin",at:t-900000},{text:"pacman -Qdt",preview:"pacman -Qdt",at:t-90000000}]
  property var ctx: ({ items: items })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nightvision"; Tokens.slot0 = "#7dff6a"; Tokens.slot1 = "#d6ffc9"; Tokens.slot2 = "#2fae2a"; Tokens.unlit = "#0d260b"; Tokens.glass = "#040a03"; Tokens.current = ({ slots: ["#7dff6a", "#d6ffc9", "#2fae2a"], unlit: "#0d260b", glass: "#040a03", ramp: ["#0f3a0c", "#2b8a22", "#62e04f", "#c9ffb8"], glow: 0.6, shape: "round" }); Tokens.previous = Tokens.current }
    V.Clipboard { x: 20; y: 20; width: 360; height: 168; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Clipboard { x: 400; y: 20; width: 528; height: 336; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 2000; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
