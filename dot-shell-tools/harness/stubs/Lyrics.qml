pragma Singleton
import QtQuick
QtObject { property bool has: true; property bool synced: true; property int index: 1; property var lines: [{text:"line before"},{text:"line playing now"}]; property string status: "found" }
