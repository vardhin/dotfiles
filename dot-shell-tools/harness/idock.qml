import QtQuick
import QtQuick.Window
import "nineties" as V
Window { id: win; width: 2900; height: 1250; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctxs: ({
    media: { active: true, playing: true, title: "Track Title Long Name", progress: 0.4, pos: 98, len: 240 },
    clock: { time: "21:47", hh: "21", mm: "47", dateShort: "Sun 19", date: "Sun 19 Oct", dd: "19" },
    workspaces: { list: [{id:9,home:true,windows:0,focused:false},{id:1,windows:2,focused:false},{id:2,windows:3,focused:true},{id:3,windows:1},{id:4,windows:0}] },
    system: { cpu: 0.38, mem: 0.45, memGb: 11.2, temp: 61, tempF: 0.61, hasTemp: true },
    battery: { present: true, pct: 72, fraction: 0.72, level: "ok", charging: false },
    messages: { live: 3, dnd: false, items: [{app:"firefox", summary:"Download finished"}] },
    capture: { recording: false, elapsed: "01:23", blink: 1 },
    caffeine: { on: true, left: "4:12" },
    clipboard: { count: 4, lastPreview: "sudo pacman -Syu --needed" },
    todo: { left: 3, next: "Phase 10 data-driven panel schema", today: [{done:true},{done:false,next:true},{done:false},{done:true}] }
  })
  property var words: ({ messages: {icon:"MSG"}, caffeine: {icon:"WARM"}, clipboard: {icon:"M1"} })
  property var names: ["media","clock","workspaces","system","battery","messages","capture","caffeine","clipboard","todo"]
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.era = "nineties"; Tokens.pitch = 5; Tokens.current = { slots: ["#ff2e97", "#1fa8ff", "#ffe600"], unlit: "#22123a", glass: "#0a0514", ramp: ["#3b0d5c", "#a3157f", "#ff2e97", "#ffe600"], glow: 0.9, shape: "round" }; Tokens.previous = Tokens.current; Tokens.slot0 = "#ff2e97"; Tokens.slot1 = "#1fa8ff"; Tokens.slot2 = "#ffe600"; Tokens.unlit = "#22123a"; Tokens.glass = "#0a0514" }
    V.Edge { x: 6; y: 6; width: 560*5; height: 11*5; place: "strip" }
    DotSurface { bare: false; x: 6; y: 6; cols: 560; rows: 11
      Row { x: 2; spacing: 6
        Repeater { model: win.names.slice(0,5)
          V.Docked { required property string modelData; template: modelData; ctx: win.ctxs[modelData]; sink: sink; panel: ({}); words: win.words[modelData] ?? ({}) } } } }
    V.Edge { x: 6; y: 80; width: 560*5; height: 11*5; place: "strip" }
    DotSurface { bare: false; x: 6; y: 80; cols: 560; rows: 11
      Row { x: 2; spacing: 6
        Repeater { model: win.names.slice(5)
          V.Docked { required property string modelData; template: modelData; ctx: win.ctxs[modelData]; sink: sink; panel: ({}); words: win.words[modelData] ?? ({}) } } } }
    V.Edge { x: 6; y: 160; width: 16*5; height: 220*5; place: "rail" }
    DotSurface { bare: false; x: 6; y: 160; cols: 16; rows: 220
      Column { y: 2; spacing: 4
        Repeater { model: win.names.slice(0,4)
          V.Docked { required property string modelData; rail: true; template: modelData; ctx: win.ctxs[modelData]; sink: sink; panel: ({}); words: win.words[modelData] ?? ({}) } } } }
    V.Edge { x: 110; y: 160; width: 16*5; height: 220*5; place: "rail" }
    DotSurface { bare: false; x: 110; y: 160; cols: 16; rows: 220
      Column { y: 2; spacing: 4
        Repeater { model: win.names.slice(4)
          V.Docked { required property string modelData; rail: true; template: modelData; ctx: win.ctxs[modelData]; sink: sink; panel: ({}); words: win.words[modelData] ?? ({}) } } } }
    Item { x: 300; y: 300; width: 1500; height: 60
      Rectangle { anchors.fill: parent; color: "#08071a" }
      V.Edge { x: 0; y: 0; width: 300*5; height: 11*5; place: "strip" }
    DotSurface { bare: false; x: 0; y: 0; cols: 300; rows: 11 }
       }
  }
  Timer { interval: 1500; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
