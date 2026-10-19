pragma Singleton
import QtQuick
QtObject {
  property string home: "/home/v"
  property var windows: [{ ws: 2, cls: "code" }, { ws: 2, cls: "kitty" }, { ws: 3, cls: "firefox" }, { ws: 4, cls: "mpv" }]
}
