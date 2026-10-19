import QtQuick
import QtQuick.Window
import "vapor" as V
Window { id: win; width: 800; height: 340; visible: true
  QtObject { id: sink; function run(a) { console.log("run", a) } function grip(k, x, y) { return false } }
  property var ctx: ({ recording: false, audio: false, recent: [{name:"[35marea_2025-08-29_22-35-03.png[0m",path:"[36m/home/vardhin/Pictures/Screenshots/[35marea_2025-08-28_22-30-29.png[0m [36m/home/vardhin/Pictures/Screenshots/[35marea_2025-08-28_22-34-00.png[0m [36m/home/vardhin/Pictures/Screenshots/[35marea_2025-08-29_22-34-24.png[0m [36m/home/vardhin/Pictures/Screenshots/[35marea_2025-08-29_22-35-03.png[0m ",ts:1760890000000},] })
  property var ctx2: ({ recording: true, elapsed: "01:23", audio: true, recent: [] })
  Rectangle { id: root; anchors.fill: parent; color: "#101014"; Component.onCompleted: { Tokens.era = "vapor"; Tokens.slot0 = "#ff71ce"; Tokens.slot1 = "#01cdfe"; Tokens.slot2 = "#b967ff"; Tokens.unlit = "#2d1b4e"; Tokens.glass = "#130a24"; Tokens.current = ({ slots: ["#ff71ce", "#01cdfe", "#b967ff"], unlit: "#2d1b4e", glass: "#130a24", ramp: ["#3d1d63", "#b967ff", "#ff71ce", "#fffb96"], glow: 0.7, shape: "round" }); Tokens.previous = Tokens.current }
    V.Capture { x: 20; y: 20; width: 288; height: 120; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
    V.Capture { x: 20; y: 170; width: 288; height: 120; ctx: win.ctx2; sink: sink; panel: ({}); words: ({}) }
    V.Capture { x: 340; y: 20; width: 432; height: 288; big: true; ctx: win.ctx; sink: sink; panel: ({}); words: ({}) }
  }
  Timer { interval: 2000; running: true; onTriggered: root.grabToImage(function(r){ r.saveToFile("OUT"); Qt.quit() }) }
}
