import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../audio" as Audio
import "../../config" as Config
FocusScrollArea {
 id:root
 required property var state
 required property var metrics
 required property var network
 required property var audio
 required property var battery
 required property var bluetooth
 required property var notifications
 required property var senomy
 property var media:null
 property var pinnedEntries:[]
 readonly property bool stacked:width<700*Config.DirectoryStyle.textScale
 readonly property bool networkLocked:network.actions.locked || !!(network.profiles&&network.profiles.actions.locked) || !!(network.connectionAttempt&&network.connectionAttempt.busy)
 signal destinationRequested(string route)
 signal primaryRequested(string surface,string route)
 signal settingsRequested(string route)
 objectName:"control-overview";contentHeight:composition.implicitHeight;clip:true;boundsBehavior:Flickable.StopAtBounds
 ScrollBar.vertical:ShellScrollBar {}
 Column {id:composition;width:Math.max(1,root.width-12);spacing:20
  Text {objectName:"overview-assessment";width:parent.width;visible:root.senomy.state==="critical" || root.senomy.state==="warning";text:root.senomy.message || "Assessment unavailable";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:root.senomy.state==="critical"?Config.Theme.danger:Config.Theme.warning;wrapMode:Text.WordWrap}
  NetworkActionReview {width:parent.width;actions:root.network.actions}
  Audio.AudioActionReview {width:parent.width;audio:root.audio;visible:height>0}
  GridLayout {width:parent.width;columns:root.stacked?1:3;columnSpacing:24;rowSpacing:24
   Column {Layout.fillWidth:true;Layout.preferredWidth:5;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop;spacing:20;enabled:!root.state.modalActive
    Audio.QuickAudioChannel {width:parent.width;audio:root.audio;enabled:!root.audio.actionsLocked}
    Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule;}
    Audio.QuickAudioChannel {width:parent.width;audio:root.audio;input:true;enabled:!root.audio.actionsLocked}
    Audio.AudioQuickMedia {visible:!!root.media && root.media.available;width:parent.width;media:root.media;active:root.visible;viewport:root}
    QuietButton {objectName:"overview-audio";width:parent.width;glyph:"\uf1de";text:"Audio devices & mixer";onClicked:root.destinationRequested("audio/devices")}
   }
   Rectangle {visible:!root.stacked;Layout.preferredWidth:1;Layout.fillHeight:true;color:Config.DirectoryStyle.rule}
   Column {Layout.fillWidth:true;Layout.preferredWidth:4;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop;spacing:16
    Column {width:parent.width;spacing:8
     Text {width:parent.width;font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Math.round(13*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.muted;textFormat:Text.PlainText;wrapMode:Text.WordWrap;text:"Connection"}
     Text {width:parent.width;text:root.network.available?(root.network.activeConnection || "Not connected"):"Network unavailable";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(18*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink;textFormat:Text.PlainText;wrapMode:Text.WordWrap}
     Text {width:parent.width;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;textFormat:Text.PlainText;wrapMode:Text.WordWrap;text:root.network.available?root.network.connectivityName:(root.network.detail || "Provider unavailable")}
     Flow {width:parent.width;spacing:8
      QuietButton {objectName:"overview-network";text:"Networks";glyph:"\uf1eb";enabled:!root.state.modalActive;onClicked:root.destinationRequested("network/wifi")}
      QuietButton {objectName:"overview-wifi-toggle";text:root.network.wifiEnabled?"Wi-Fi on":"Wi-Fi off";active:root.network.wifiEnabled;enabled:!root.state.modalActive && root.network.available && root.network.wifiHardwareEnabled && !root.networkLocked;accessibleLabel:root.network.wifiEnabled?"Disable Wi-Fi":"Enable Wi-Fi";onClicked:root.network.toggleWifi()}
     }
    }
    Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule;}
    Column {width:parent.width;spacing:8
     Text {width:parent.width;font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Math.round(13*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.muted;textFormat:Text.PlainText;wrapMode:Text.WordWrap;text:"Power"}
     Text {width:parent.width;text:root.battery.available?root.battery.label:"Battery unavailable";font.family:Config.QuickPanelStyle.valueFont;font.pixelSize:Math.round(24*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.ink;wrapMode:Text.WordWrap}
     Text {width:parent.width;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;textFormat:Text.PlainText;wrapMode:Text.WordWrap;text:root.battery.detail || "No power observation"}
     QuietButton {objectName:"overview-power";text:root.battery.powerProfileAvailable?root.battery.powerProfileName+" · profiles":"Power & battery";glyph:"\uf0e7";width:Math.min(parent.width,implicitWidth);enabled:!root.state.modalActive;onClicked:root.destinationRequested("power/profiles")}
    }
    Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule;}
    Flow {width:parent.width;spacing:8
     QuietButton {objectName:"overview-bluetooth";glyph:"\uf2ce";text:!root.bluetooth.available?"Bluetooth unavailable":root.bluetooth.enabled?"Bluetooth":"Bluetooth off";width:Math.min(parent.width,implicitWidth);enabled:!root.state.modalActive;onClicked:root.destinationRequested("devices/bluetooth")}
     QuietButton {objectName:"overview-dnd";glyph:root.notifications.dnd?"\uf1f6":"\uf0f3";text:root.notifications.dnd?"Do not disturb · On":"Do not disturb · Off";active:root.notifications.dnd;enabled:!root.state.modalActive&&root.notifications.serverEnabled;accessibleLabel:root.notifications.dnd?"Turn off Do not disturb":"Turn on Do not disturb";onClicked:root.notifications.setDnd(!root.notifications.dnd)}
    }
   }
  }
  Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule;}
  Flow {width:parent.width;spacing:8;enabled:!root.state.modalActive
   Repeater {model:[{id:"devices/displays",label:"Displays",glyph:"\uf108"},{id:"input",label:"Input",glyph:"\uf11c"},{id:"appearance/backgrounds",label:"Wallpaper",glyph:"\uf03e"},{id:"apps",label:"Apps",glyph:"\uf009"},{id:"accounts",label:"Accounts",glyph:"\uf007"},{id:"settings/idle",label:"Idle & lock",glyph:"\uf023"}]
    QuietButton {required property var modelData;objectName:"overview-route-"+modelData.id;text:modelData.label;glyph:modelData.glyph;width:parent.width<380*Config.DirectoryStyle.textScale?Math.floor((parent.width-8)/2):Math.floor((parent.width-16)/3);onClicked:root.settingsRequested(modelData.id)}
   }
  }
  Column {visible:root.pinnedEntries.length>0;width:parent.width;spacing:8
   Text {width:parent.width;font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Math.round(13*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.muted;textFormat:Text.PlainText;wrapMode:Text.WordWrap;text:"Pinned · this session"}
   Flow {width:parent.width;spacing:8;Repeater {model:root.pinnedEntries;QuietButton {required property var modelData;objectName:"overview-pin-"+modelData.id;text:modelData.label;accessibleLabel:modelData.path || modelData.label;enabled:!root.state.modalActive;width:Math.min(parent.width,implicitWidth);onClicked:root.destinationRequested(modelData.id)}}}
  }
  Flow {width:parent.width;spacing:8
   QuietButton {objectName:"overview-performance";glyph:"\uf201";text:"Performance";enabled:!root.state.modalActive;onClicked:root.primaryRequested("performance","overview")}
   QuietButton {objectName:"overview-insights";glyph:"\uf0e7";text:"Insights";enabled:!root.state.modalActive;onClicked:root.primaryRequested("insights","briefing")}
   Text {width:parent.width;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;textFormat:Text.PlainText;wrapMode:Text.WordWrap;text:root.metrics.ready!==true?"Metrics awaiting a local sample":"CPU "+Math.round(root.metrics.cpuPercent)+"% · Memory "+(root.metrics.memoryTotalKib>0?Math.round(root.metrics.memoryPercent)+"%":"unavailable")+" · Up "+root.metrics.uptimeLabel}
  }
 }
}
