import QtQuick
import QtQuick.Controls
import "../config" as Config

CheckBox {
    id: root
    implicitHeight: Math.max(44, Config.Theme.touchTarget, contentItem.implicitHeight + topPadding + bottomPadding)
    hoverEnabled: true
    ButtonHoverFrame { focused: root.visualFocus; anchors.fill: parent; engaged: root.enabled && root.hovered }
    spacing: 12
    leftPadding: Config.DirectoryStyle.controlInset
    rightPadding: Config.DirectoryStyle.controlInset
    topPadding: 8
    bottomPadding: 8
    opacity: enabled ? 1 : 0.46
    indicator: Rectangle {
        x: root.mirrored ? root.width - root.rightPadding - width : root.leftPadding
        y: (parent.height - height) / 2
        width: 20
        height: 20
        color: "transparent"
        border.width: 1
        border.color: Config.DirectoryStyle.dim
        Text {
            anchors.centerIn: parent
            visible: root.checked
            text: "✓"
            color: Config.DirectoryStyle.ink
            font.family: Config.DirectoryStyle.bodyFont
            font.pixelSize: 16
        }
    }
    contentItem: Text {
        text: root.text
        leftPadding: root.mirrored ? 0 : root.indicator.width + root.spacing
        rightPadding: root.mirrored ? root.indicator.width + root.spacing : 0
        textFormat: Text.PlainText
        color: Config.DirectoryStyle.ink
        font.family: Config.DirectoryStyle.bodyFont
        font.pixelSize: Config.DirectoryStyle.bodySize
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
    }
    background: Rectangle {
        color: "transparent"
    }
}
