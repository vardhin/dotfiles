pragma Singleton
import QtQuick
QtObject { property bool isPlaying: true; function clock(s) { s = Math.round(s||0); return Math.floor(s/60) + ":" + String(s%60).padStart(2,"0") } function seekTo(f) {} function toggle() {} function next() {} function previous() {} }
