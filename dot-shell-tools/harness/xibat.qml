import QtQuick
import QtQuick.Window
import "nineties" as V
Window { id: win; width: 800; height: 440; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var hist: { let h=[]; for (let i=0;i<288;i++) h.push(i<120?0.9-i/300:i<160?0.5+(i-120)/60:0.98-(i-160)/600); return h }
  property var ctx: ({ fraction: 0.72, pct: 72, charging: false, level: "ok", stateWord: "ON BATTERY", time: "3:41", watts: 7.4, health: "91%", hist: hist })
  property var ctx2: ({ fraction: 0.08, pct: 8, charging: false, level: "bad", stateWord: "ON BATTERY", time: "0:22" })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.pitch = 3; Tokens.era = "nineties"; Tokens.slot0 = "#5fb8ac"; Tokens.slot1 = "#a77ba6"; Tokens.slot2 = "#d6e6a4"; Tokens.unlit = "#2e2434"; Tokens.glass = "#1a1420"; Tokens.current = ({ slots: ["#5fb8ac", "#a77ba6", "#d6e6a4"], unlit: "#2e2434", glass: "#1a1420", ramp: ["#2e2434", "#5e4463", "#5fb8ac", "#d6e6a4"], glow: 0.25, shape: "round" }); Tokens.previous = Tokens.current }
    V.Battery { x: 20; y: 20; width: 288; height: 120; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Battery { x: 20; y: 170; width: 288; height: 120; ctx: win.ctx2; sink: sink; panel: ({}); words: ({}) }
    V.Battery { x: 340; y: 20; width: 432; height: 264; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
