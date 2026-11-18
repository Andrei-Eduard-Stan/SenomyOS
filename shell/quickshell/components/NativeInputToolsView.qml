import QtQuick
import "../config" as Config
Column {
 id:root
 property var settings:null
 spacing:24
 Column {width:parent.width;spacing:12
  Text {width:parent.width;text:"Input methods";font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Math.round(18*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.ink}
  Text {width:parent.width;text:root.settings && root.settings.engineInstalled?"Fcitx5 installed":"Input-method provider unavailable";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
  QuietButton {objectName:"openInputMethodSettings";text:root.settings && root.settings.nativeToolsBusy?"Opening…":"Input-method settings";glyph:"\uf11c";enabled:!!root.settings && root.settings.editorAvailable===true && root.settings.nativeToolsBusy!==true;onClicked:root.settings.openInputMethodSettings()}
  Text {width:parent.width;visible:!!root.settings && !!root.settings.nativeToolsMessage;text:root.settings?root.settings.nativeToolsMessage || "":"";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.Theme.warning;wrapMode:Text.WordWrap}
 }
 IslandRule {width:parent.width;leadingPoint:false}
 Column {width:parent.width;spacing:12
  Text {width:parent.width;text:"On-screen keyboard";font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Math.round(18*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.ink}
  Text {width:parent.width;text:root.settings && root.settings.oskCapabilities?root.settings.oskCapabilities.message:"Keyboard capabilities have not been checked.";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
  Flow {width:parent.width;spacing:8
   Repeater {model:[{id:"manual",label:"Manual"},{id:"auto",label:"Auto"}]
    QuietButton {required property var modelData;text:modelData.label;objectName:"osk-opening-"+modelData.id;active:!!root.settings && !!root.settings.oskAutomatic && root.settings.oskAutomatic.mode===modelData.id;Accessible.checkable:true;Accessible.checked:active;enabled:!!root.settings && !!root.settings.oskAutomatic && !root.settings.oskAutomatic.settingMode;onClicked:root.settings.oskAutomatic.setMode(modelData.id)}
   }
  }
  Text {width:parent.width;text:root.settings && root.settings.oskAutomatic?root.settings.oskAutomatic.status:"Automatic opening is unavailable.";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
  OskControls {width:parent.width;controller:root.settings && root.settings.oskController?root.settings.oskController:null}
 }
}
