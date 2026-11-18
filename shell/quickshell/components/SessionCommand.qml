import QtQuick
import QtQuick.Controls
import "../config" as Config
Control {
    id: root
    property string text: ""
    property string icon: ""
    property bool selected: false
    signal clicked()
    implicitHeight: Math.max(Config.QuickPanelStyle.target, label.implicitHeight + 2 * Config.DirectoryStyle.controlVerticalInset)
    focusPolicy: enabled ? Qt.TabFocus : Qt.NoFocus
    padding: 0
    // Qt keeps focusReason when forceActiveFocus targets an already focused item.
    function focusForReason(reason) { focusReason = reason; forceActiveFocus(reason); }
    activeFocusOnTab: enabled
    opacity: enabled ? 1 : 0.4
    Accessible.role: Accessible.Button
    Accessible.name: text + (selected ? ", selected" : "")
    Accessible.onPressAction: if(enabled)clicked()
    Keys.onReturnPressed: if(enabled){root.focusForReason(Qt.TabFocusReason);clicked();}
    Keys.onSpacePressed: if(enabled){root.focusForReason(Qt.TabFocusReason);clicked();}
    Rectangle {anchors.fill:parent;color:"transparent";border.width:0;border.color:Config.QuickPanelStyle.ink;Behavior on color {ColorAnimation {duration:Config.Motion.duration(80)}}}
    Text {x:Config.DirectoryStyle.controlInset;width:16;horizontalAlignment:Text.AlignHCenter;anchors.verticalCenter:parent.verticalCenter;text:root.icon;font.family:"Font Awesome 7 Free Solid";font.weight:Font.Black;font.pixelSize:11;color:Config.QuickPanelStyle.secondary}
    Text {id:label;x:Config.DirectoryStyle.controlInset+16+Config.DirectoryStyle.controlGap;anchors.verticalCenter:parent.verticalCenter;width:Math.max(0,parent.width-x-Config.DirectoryStyle.controlInset);text:root.text;font.weight:root.selected?Font.DemiBold:Font.Normal;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize;color:Config.QuickPanelStyle.ink;wrapMode:Text.WordWrap}
    ButtonHoverFrame { focused: root.visualFocus; pointerTarget: area; selected: root.selected; anchors.fill: parent; engaged: root.enabled && area.containsMouse }
    MouseArea {id:area;anchors.fill:parent;hoverEnabled:true;cursorShape:root.enabled?Qt.PointingHandCursor:Qt.ArrowCursor;onClicked:if(root.enabled){root.focusForReason(Qt.MouseFocusReason);root.clicked();}}
}
