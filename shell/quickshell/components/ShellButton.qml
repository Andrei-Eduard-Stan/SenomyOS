import QtQuick
import QtQuick.Controls
import "../config" as Config

Rectangle {
    id: root
    property string frameKey: "button"
    property string iconName: ""
    property string text: ""
    property string detail: ""
    property bool enabled: true
    property bool iconOnly: !detail && (!text || ["×","☰","−","+","–","-","‹","›","⌃","⌄","□","❐","⋯","…","↻","←","→"].includes(text))
    readonly property real contentInset: iconOnly ? Math.min(8, width / 4) : Config.DirectoryStyle.contentInsetFor(width, height)
    readonly property real minimumContentWidth: Math.ceil(labelMetrics.advanceWidth) + Config.DirectoryStyle.controlGap + 2 * (iconOnly ? 8 : Config.DirectoryStyle.controlInset) + (iconName ? 18 + Config.DirectoryStyle.controlGap : 0)
    property bool wrapLabel: !headerControl
    property bool wrapDetail: true
    property bool active: false
    // Pointer hover uses the centre-out border and label emphasis; resting buttons remain unframed.
    readonly property bool pointerHovered: enabled && area.containsMouse
    property bool headerControl: false
    property int labelSize: Config.DirectoryStyle.bodySize
    readonly property real touchMargin: Config.DirectoryStyle.touchMode ? Math.max(0, (48 - Math.min(width, height)) / 2) : 0
    property bool artBackground: false
    property bool centered: !iconName && !detail
    property string accessibleLabel: text === "×" ? "Close" : text + (detail ? ". " + detail : "")
    property color accentColor: Config.DirectoryStyle.ink
    readonly property var skinSpec: Config.Skin.frame(frameKey)
    // Compatibility metadata; panel buttons no longer render art/backdrop chrome.
    readonly property bool legacyArt: false
    signal clicked
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: accessibleLabel
    Accessible.onPressAction: if(enabled)clicked()
    Keys.onReturnPressed: if (enabled)
        clicked()
    Keys.onEnterPressed: if (enabled)
        clicked()
    Keys.onSpacePressed: if (enabled)
        clicked()
    TextMetrics { id: labelMetrics; text: root.text; font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: root.labelSize }
    implicitWidth: iconOnly ? Config.DirectoryStyle.controlTarget : Math.max(148, minimumContentWidth)
    implicitHeight: Math.max(Config.DirectoryStyle.controlTarget, labelColumn.implicitHeight + 2 * Config.DirectoryStyle.controlVerticalInset)
    radius: 0
    color: "transparent"
    border.width: 0
    border.color: Config.DirectoryStyle.ink
    opacity: enabled ? 1 : 0.46
    Behavior on color {
        ColorAnimation {
            duration: Config.Motion.duration(100)
        }
    }
    ButtonHoverFrame { focusTarget: root; pointerTarget: area; selected: root.active;anchors.fill:parent;engaged:root.pointerHovered}
    DashboardIcon {
        x: root.contentInset
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        kind: root.text
        visible: !!root.iconName
    }
    Column {
        id:labelColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.contentInset + (root.iconName ? 18 + Config.DirectoryStyle.controlGap : 0)
        anchors.rightMargin: root.contentInset
        spacing: Config.DirectoryStyle.controlGap / 2
        Text {
            width: parent.width
            text: root.text
            textFormat: Text.PlainText
            color: root.accentColor
            opacity: Config.DirectoryStyle.highContrast || !Qt.colorEqual(root.accentColor,Config.DirectoryStyle.ink) || root.pointerHovered || root.activeFocus || root.active ? 1 : 0.86
            Behavior on opacity { NumberAnimation { duration: Config.Motion.duration(80) } }
            font.family: root.text === "×" ? Config.DirectoryStyle.dataFont : Config.DirectoryStyle.bodyFont
            font.weight: root.active ? Font.DemiBold : Font.Normal
            font.pixelSize: root.text === "×" ? 22 : root.labelSize
            horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
            wrapMode: root.wrapLabel ? Text.WordWrap : Text.NoWrap
            elide: root.wrapLabel ? Text.ElideNone : Text.ElideRight
        }
        Text {
            visible: root.detail.length > 0
            width: parent.width
            text: root.detail
            textFormat: Text.PlainText
            color: Config.DirectoryStyle.muted
            font.family: Config.DirectoryStyle.bodyFont
            font.pixelSize: Config.DirectoryStyle.detailSize
            wrapMode: root.wrapDetail ? Text.WordWrap : Text.NoWrap
            elide: root.wrapDetail ? Text.ElideNone : Text.ElideRight
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -root.touchMargin
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) {
            root.forceActiveFocus();
            root.clicked();
        }
    }
}
