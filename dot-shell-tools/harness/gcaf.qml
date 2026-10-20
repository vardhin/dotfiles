import QtQuick
import QtQuick.Window
import "nightvision" as V
Window { id: win; width: 760; height: 300; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ on: true, left: "42:10", holders: [{who: "dotshell", why: "caffeine"}, {who: "mpv", why: "playing video"}] })
  property var ctx2: ({ on: false, left: "", holders: [] })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nightvision"; Tokens.slot0 = "#7dff6a"; Tokens.slot1 = "#d6ffc9"; Tokens.slot2 = "#2fae2a"; Tokens.unlit = "#0d260b"; Tokens.glass = "#040a03"; Tokens.current = ({ slots: ["#7dff6a", "#d6ffc9", "#2fae2a"], unlit: "#0d260b", glass: "#040a03", ramp: ["#0f3a0c", "#2b8a22", "#62e04f", "#c9ffb8"], glow: 0.6, shape: "round" }); Tokens.previous = Tokens.current }
    V.Caffeine { x: 20; y: 20; width: 264; height: 108; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Caffeine { x: 20; y: 160; width: 264; height: 108; ctx: win.ctx2; sink: sink; panel: ({}); words: ({}) }
    V.Caffeine { x: 340; y: 20; width: 384; height: 240; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
