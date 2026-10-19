pragma Singleton
import QtQuick
QtObject { property int profile: 1; property bool hasPerformance: true; function profileName(p) { return ["SAVER","BALANCED","PERFORMANCE"][p] } }
