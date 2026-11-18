import QtQuick
import QtQuick.Layouts
import "../config" as Config
import "ReportPreview.js" as Preview

Column {
    id:root
    property var lines:[]
    spacing:10
    Repeater {
        model:Preview.blocks(root.lines)
        delegate:Loader {
            id:block
            required property var modelData
            width:root.width
            sourceComponent:modelData.kind==="metadata"?metadata:paragraph
            Component {
                id:metadata
                Column {
                    width:block.width;spacing:6
                    Repeater {
                        model:block.modelData.fields
                        delegate:GridLayout {
                            required property var modelData
                            width:parent.width;columns:width<420*Config.DirectoryStyle.textScale?1:2
                            columnSpacing:16;rowSpacing:4
                            Text {Layout.preferredWidth:96;text:modelData.label;color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                            TextEdit {Layout.fillWidth:true;Layout.minimumWidth:0;text:modelData.text;textFormat:TextEdit.PlainText;readOnly:true;selectByMouse:true;wrapMode:TextEdit.Wrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;selectionColor:Config.DirectoryStyle.selection;selectedTextColor:Config.DirectoryStyle.ink}
                        }
                    }
                }
            }
            Component {
                id:paragraph
                Item {
                    readonly property bool heading:block.modelData.kind==="heading" || block.modelData.kind==="title"
                    implicitHeight:line.implicitHeight+(heading?16:0)
                    TextEdit {
                        id:line;y:parent.heading?16:0
                        width:Math.min(block.width,90*Config.DirectoryStyle.detailSize*.6)
                        text:block.modelData.text;textFormat:TextEdit.PlainText;readOnly:true;selectByMouse:true;wrapMode:TextEdit.Wrap
                        color:parent.heading?Config.DirectoryStyle.ink:Config.DirectoryStyle.muted
                        font.family:parent.heading?Config.DirectoryStyle.headingFont:Config.DirectoryStyle.dataFont
                        font.pixelSize:parent.heading?Math.round((block.modelData.kind==="title"?18:16)*Config.DirectoryStyle.textScale):Config.DirectoryStyle.detailSize
                        selectionColor:Config.DirectoryStyle.selection;selectedTextColor:Config.DirectoryStyle.ink
                    }
                }
            }
        }
    }
}
