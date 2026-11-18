import QtQuick
import QtQuick.Controls
import "../config" as Config
MenuItem {
    id: root
    hoverEnabled: true
    leftPadding:Config.DirectoryStyle.controlInset
    rightPadding:Config.DirectoryStyle.controlInset
    topPadding:Config.DirectoryStyle.controlVerticalInset
    bottomPadding:Config.DirectoryStyle.controlVerticalInset
    Binding {target:root.indicator;property:"x";value:root.mirrored?root.width-root.rightPadding-(root.indicator?root.indicator.width:0):root.leftPadding}
    contentItem:Text {leftPadding:root.checkable&&!root.mirrored?root.indicator.width+Config.DirectoryStyle.controlGap:0;rightPadding:root.checkable&&root.mirrored?root.indicator.width+Config.DirectoryStyle.controlGap:0;text:root.text;textFormat:Text.PlainText;font:root.font;color:root.enabled?Config.DirectoryStyle.ink:Config.DirectoryStyle.dim;wrapMode:Text.WordWrap;verticalAlignment:Text.AlignVCenter}

    implicitHeight: Math.max(Config.DirectoryStyle.controlTarget, contentItem.implicitHeight + topPadding + bottomPadding)
    font.family: Config.DirectoryStyle.bodyFont
    font.pixelSize: Config.DirectoryStyle.bodySize
    palette.text: Config.DirectoryStyle.ink
    palette.highlightedText: Config.DirectoryStyle.ink
    ButtonHoverFrame { focused: root.visualFocus; selected: root.checked || (root.highlighted && !root.hovered); anchors.fill: parent; engaged: root.enabled && root.hovered }
    background: Rectangle {
        color: "transparent"
        border.width: 0
        border.color: Config.DirectoryStyle.ink
    }
}
