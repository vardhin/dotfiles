import QtQuick
import QtQuick.Window
import "nightvision" as V
Window { id: win; width: 800; height: 440; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var hist: { let h=[]; for (let i=0;i<288;i++) h.push(i<120?0.9-i/300:i<160?0.5+(i-120)/60:0.98-(i-160)/600); return h }
  property var ctx: ({ fraction: 0.72, pct: 72, charging: false, level: "ok", stateWord: "ON BATTERY", time: "3:41", watts: 7.4, health: "91%", hist: hist })
  property var ctx2: ({ fraction: 0.08, pct: 8, charging: false, level: "bad", stateWord: "ON BATTERY", time: "0:22" })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nightvision"; Tokens.slot0 = "#7dff6a"; Tokens.slot1 = "#d6ffc9"; Tokens.slot2 = "#2fae2a"; Tokens.unlit = "#0d260b"; Tokens.glass = "#040a03"; Tokens.current = ({ slots: ["#7dff6a", "#d6ffc9", "#2fae2a"], unlit: "#0d260b", glass: "#040a03", ramp: ["#0f3a0c", "#2b8a22", "#62e04f", "#c9ffb8"], glow: 0.6, shape: "round" }); Tokens.previous = Tokens.current }
    V.Battery { x: 20; y: 20; width: 288; height: 120; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Battery { x: 20; y: 170; width: 288; height: 120; ctx: win.ctx2; sink: sink; panel: ({}); words: ({}) }
    V.Battery { x: 340; y: 20; width: 432; height: 264; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
