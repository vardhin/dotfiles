import QtQuick
QtObject { property var menu; property var children: ({ values: [{text:"Show Telegram",enabled:true},{text:"Mute for 1 hour",enabled:true},{isSeparator:true},{text:"Unread: 2 chats",enabled:false},{text:"Settings",enabled:true,hasChildren:true},{isSeparator:true},{text:"Quit",enabled:true}] }) }
