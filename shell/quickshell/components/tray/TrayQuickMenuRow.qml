import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import "../../config" as Config
import ".." as UI

UI.QuietButton {
    id: root
    required property var entry
    property bool current: false
    property string label: ""
    readonly property bool checkEntry: !!entry && entry.buttonType === QsMenuButtonType.CheckBox
    readonly property bool radioEntry: !!entry && entry.buttonType === QsMenuButtonType.RadioButton
    implicitHeight:Math.max(Config.DirectoryStyle.controlTarget,labelItem.implicitHeight+2*Config.DirectoryStyle.controlVerticalInset)
    leftPadding:Config.DirectoryStyle.controlInset;rightPadding:Config.DirectoryStyle.controlInset
    topPadding:Config.DirectoryStyle.controlVerticalInset;bottomPadding:Config.DirectoryStyle.controlVerticalInset; hoverEnabled: true; focusPolicy: Qt.StrongFocus
    enabled: !!entry && !!entry.enabled && !entry.isSeparator
    opacity: enabled ? 1 : 0.4
    Accessible.role: checkEntry ? Accessible.CheckBox : radioEntry ? Accessible.RadioButton : Accessible.MenuItem
    Accessible.name: label + (entry && entry.hasChildren ? ". Submenu" : "")
    Accessible.checkable: checkEntry || radioEntry
    Accessible.checked: !!entry && entry.checkState === Qt.Checked
    Accessible.onPressAction: if (enabled) clicked()
    active: current || ((checkEntry || radioEntry) && entry.checkState === Qt.Checked)
    contentItem: Item {
        Text {
            width: 20; anchors.left: parent.left; anchors.leftMargin: 0; anchors.verticalCenter: parent.verticalCenter
            visible: root.checkEntry || root.radioEntry
            text: !root.entry ? "" : root.radioEntry ? (root.entry.checkState === Qt.Checked ? "●" : "○") : root.entry.checkState === Qt.Checked ? "☑" : root.entry.checkState === Qt.PartiallyChecked ? "▣" : "☐"
            textFormat: Text.PlainText; horizontalAlignment: Text.AlignHCenter
            color: Config.DirectoryStyle.ink; font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 17
        }
        IconImage {
            x: 0; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20
            visible: !root.checkEntry && !root.radioEntry && !!root.entry && !!root.entry.icon
            source: root.entry ? root.entry.icon || "" : ""
        }
        Text {
            id:labelItem
            x:(root.checkEntry || root.radioEntry || !!(root.entry && root.entry.icon))?20+Config.DirectoryStyle.controlGap:0; width: Math.max(1, parent.width - x - (root.entry && root.entry.hasChildren ? 16+Config.DirectoryStyle.controlGap : 0)); anchors.verticalCenter: parent.verticalCenter
            text: root.label; font.weight: root.current ? Font.DemiBold : Font.Normal; textFormat: Text.PlainText; wrapMode:Text.WordWrap
            color: Config.DirectoryStyle.ink; font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: Config.DirectoryStyle.bodySize
        }
        Text {
            visible: !!root.entry && !!root.entry.hasChildren
            anchors.right: parent.right; anchors.rightMargin: 0; anchors.verticalCenter: parent.verticalCenter
            text: "›"; color: Config.DirectoryStyle.muted; font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: 22
        }
    }
}
