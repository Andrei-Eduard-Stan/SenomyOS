pragma ComponentBehavior: Bound
import QtQuick
import "../../config" as Config
Item {
    id:root
    property string label:""
    property string value:"Not reported"
    readonly property bool stacked:width<310
    implicitHeight:stacked?labelText.implicitHeight+valueText.implicitHeight+17:Math.max(labelText.implicitHeight,valueText.implicitHeight)+17
    Text {id:labelText;width:root.stacked?root.width:root.width*0.40;text:root.label;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
    TextEdit {
        id:valueText;x:root.stacked?0:Math.round(root.width*0.43);y:root.stacked?labelText.implicitHeight+4:0
        width:root.stacked?root.width:root.width-x;readOnly:true;selectByMouse:true;activeFocusOnTab:false
        text:root.value;textFormat:TextEdit.PlainText;wrapMode:TextEdit.WrapAnywhere;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12
        selectionColor:Config.DirectoryStyle.selection;selectedTextColor:Config.DirectoryStyle.ink
        Accessible.name:root.label+": "+root.value
    }
    Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:1;color:Config.DirectoryStyle.rule;opacity:0.5}
}
