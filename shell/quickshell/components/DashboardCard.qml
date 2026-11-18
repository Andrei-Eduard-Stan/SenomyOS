import QtQuick
import "../config" as Config
Rectangle {
    id: root
    property string frameKey: "card"
    property string title: ""
    property string value: ""
    property string detail: ""
    property bool wrapDetail: true
    property color valueColor: Config.DirectoryStyle.ink
    property var cardPadding: ({left:20,right:20,top:12,bottom:12})
    readonly property bool numericValue: /^[-+]?\d/.test(value) && value.length < 20
    implicitWidth: 210
    implicitHeight: Math.max(84, summary.implicitHeight + cardPadding.top + cardPadding.bottom)
    color: "transparent"
    Column {
        id: summary
        x: root.cardPadding.left; y: root.cardPadding.top
        width: Math.max(1, root.width-root.cardPadding.left-root.cardPadding.right)
        spacing: 5
        Text { width:parent.width;text:root.title;textFormat:Text.PlainText;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;elide:Text.ElideRight }
        Text { width:parent.width;text:root.value;textFormat:Text.PlainText;color:root.valueColor;font.family:root.numericValue?Config.DirectoryStyle.valueFont:Config.DirectoryStyle.bodyFont;font.pixelSize:root.numericValue?Math.round(23*Config.DirectoryStyle.textScale):Config.DirectoryStyle.bodySize+2;font.weight:Font.DemiBold;wrapMode:Text.WordWrap }
        Text { width:parent.width;visible:!!text;text:root.detail;textFormat:Text.PlainText;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:root.wrapDetail?Text.WordWrap:Text.NoWrap;elide:root.wrapDetail?Text.ElideNone:Text.ElideRight }
    }
}
