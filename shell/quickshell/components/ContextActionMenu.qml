pragma ComponentBehavior: Bound
import QtQuick
import "interaction" as Interaction
import QtQuick.Controls
import "../config" as Config

// Context owns the contents. Qt Menu owns focus, keyboard navigation and dismissal.
Item {
    id: root
    property var actions: []
    property string accessibleLabel: "More actions"
    property string contextKey: ""
    property string status: ""
    property bool ownerActive: true
    property int contextRevision: 0
    property bool busy: false
    readonly property var visibleActions: actions.filter(action => action.visible !== false)
    readonly property bool opened: menu.opened
    signal actionRequested(string action)
    width: Config.DirectoryStyle.touchMode ? 48 : 38
    height: visible ? width : 0
    visible: visibleActions.length > 0
    onVisibleChanged: if (!visible) menu.close()
    onContextKeyChanged: { ++contextRevision; menu.close(); status = ""; }
    onOwnerActiveChanged: { ++contextRevision; if (!ownerActive) { menu.close(); status = ""; } }
    function open() { if (visible && ownerActive) menu.open(); }
    function showStatus(message) { if (visible && ownerActive) { status = message; menu.open(); } }
    function invoke(id) {
        const action = visibleActions.find(entry => entry.id === id);
        if (!ownerActive || busy || !action || action.enabled === false) return false;
        menu.close(); status = "";
        actionRequested(id);
        return true;
    }
    function reposition() { if (menu.opened) menu.anchorPoint = trigger.mapToItem(menu.parent, 0, trigger.height); }
    Connections {
        target: menu.parent
        function onWidthChanged() { Qt.callLater(root.reposition); }
        function onHeightChanged() { Qt.callLater(root.reposition); }
    }
    ToolButton {
        id: trigger
        objectName: "context-menu-trigger"
        anchors.fill: parent
        text: "⋯"
        hoverEnabled: true
        Accessible.name: root.accessibleLabel
        Accessible.description: root.status
        onClicked: root.open()
        Keys.onDownPressed: root.open()
        Keys.onReturnPressed: root.open()
        Keys.onEnterPressed: root.open()
        contentItem: Text {
            text: trigger.text; color: Config.DirectoryStyle.muted
            font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 26
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: "transparent"
            border.width: 0; border.color: Config.DirectoryStyle.ink; radius: 2
        }
        ButtonHoverFrame { focused: trigger.visualFocus; anchors.fill: parent; engaged: trigger.enabled && trigger.hovered }
        ToolTip.visible: hovered; ToolTip.text: root.accessibleLabel
    }
    TextMetrics { id: measure; font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: Config.DirectoryStyle.bodySize; text: root.visibleActions.map(a => a.label).sort((a,b) => b.length-a.length)[0] || "" }
    Menu {
        enter: Interaction.MenuMotion {}
        exit: Interaction.MenuMotion { opening: false }
        id: menu
        objectName: "context-action-popup"
        parent: Overlay.overlay
        property point anchorPoint: Qt.point(0, 0)
        onAboutToShow: anchorPoint = trigger.mapToItem(parent, 0, trigger.height)
        onOpened: {
            if(currentIndex<0)for (let i=0;i<count;++i) if(itemAt(i) && itemAt(i).enabled){currentIndex=i;break;}
        }
        width: Math.max(1, Math.min(Math.max(180, measure.width + 36), parent ? parent.width - 16 : 280))
        height: Math.min(implicitHeight, parent ? Math.max(1, parent.height - 16) : implicitHeight)
        x: Math.max(8, Math.min(anchorPoint.x + trigger.width - width, parent ? parent.width - width - 8 : 0))
        y: Math.max(8, Math.min(anchorPoint.y + height <= (parent ? parent.height - 8 : height) ? anchorPoint.y : anchorPoint.y - trigger.height - height, parent ? parent.height - height - 8 : 0))
        padding: 6; margins: 8; focus: true; modal: true; dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: Config.DirectoryStyle.glass; border.width: 1; border.color: Config.DirectoryStyle.rule; radius: 3 }
        Repeater {
            model: root.visibleActions
            delegate: MenuItem {
                id: entry
                required property var modelData
                objectName: "context-action-" + modelData.id
                text: modelData.label
                enabled: !root.busy && modelData.enabled !== false
                leftPadding:Config.DirectoryStyle.controlInset;rightPadding:Config.DirectoryStyle.controlInset
                topPadding:Config.DirectoryStyle.controlVerticalInset;bottomPadding:Config.DirectoryStyle.controlVerticalInset
                height: Math.max(Config.DirectoryStyle.controlTarget, labels.implicitHeight + topPadding + bottomPadding)
                Accessible.name: text
                Accessible.description: modelData.reason || ""
                ButtonHoverFrame { focused: entry.visualFocus; anchors.fill: parent; selected: entry.highlighted && !entry.hovered; engaged: entry.enabled && entry.hovered }
                onTriggered: root.invoke(modelData.id)
                contentItem: Column {
                    id: labels; spacing: 4
                    Text { width: parent.width; text: entry.text; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: Config.DirectoryStyle.ink; opacity: entry.enabled ? 1 : 0.5; font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: Config.DirectoryStyle.bodySize }
                    Text { width: parent.width; visible: !!text; text: !entry.enabled ? entry.modelData.reason || (root.busy ? "Action in progress" : "Unavailable") : ""; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: Config.DirectoryStyle.muted; font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: Config.DirectoryStyle.detailSize }
                }
                background: Rectangle { color: "transparent"; border.width: 0; border.color: Config.DirectoryStyle.ink }
            }
        }
        MenuItem {
            visible: root.status.length > 0
            height: visible ? feedback.implicitHeight + 16 : 0
            enabled: false
            contentItem: Text { id: feedback; text: root.status; textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: Config.DirectoryStyle.ink; font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: Config.DirectoryStyle.detailSize }
        }
        onClosed: if (trigger.visible) trigger.forceActiveFocus(Qt.PopupFocusReason)
    }
}
