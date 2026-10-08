import QtQuick
import QtQuick.Window

// Preserve the existing layout while keeping keyboard-focused content visible.
Flickable {
    id: root
    property real focusMargin: 8
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function revealFocus() {
        if (!visible || !Window.window || height <= 0)
            return;
        const item = Window.window.activeFocusItem;
        if (!item || !item.visible)
            return;
        let ancestor = item;
        while (ancestor && ancestor !== contentItem)
            ancestor = ancestor.parent;
        if (ancestor !== contentItem)
            return;
        const position = item.mapToItem(contentItem, 0, 0);
        let next = contentY;
        if (position.y < contentY + focusMargin)
            next = position.y - focusMargin;
        else if (position.y + item.height > contentY + height - focusMargin)
            next = position.y + item.height - height + focusMargin;
        contentY = Math.max(0, Math.min(Math.max(0, contentHeight - height), next));
    }

    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { Qt.callLater(root.revealFocus); }
    }
    onHeightChanged: Qt.callLater(revealFocus)
    onContentHeightChanged: Qt.callLater(revealFocus)
}
