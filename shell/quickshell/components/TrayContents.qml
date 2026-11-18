import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import "tray" as TrayUi
import "../config" as Config

FocusScope {
    id: root
    objectName: "tray-contents"
    property bool surfaceOpen: true
    property var parentWindow: null
    property var items: SystemTray.items.values
    property alias menuProvider: controller.provider
    readonly property var selectedItem: controller.selectedItem
    readonly property var menuStack: controller.stack
    readonly property var menuEntries: controller.entries
    readonly property bool menuOpen: controller.opened
    readonly property int rowHeight: Math.max(96,Math.ceil(32*Config.DirectoryStyle.textScale)+2*Math.ceil(Config.DirectoryStyle.bodySize*1.25)+24)
    readonly property int commandHeight: Math.max(Config.QuickPanelStyle.target, 32 * Config.DirectoryStyle.textScale)
    readonly property int maxBodyHeight: 7 * commandHeight
    property real menuReserve: 0
    readonly property real entriesHeight: menuList.contentHeight
    readonly property real preferredBodyHeight: menuOpen ? Math.min(maxBodyHeight, Math.max(menuReserve, entriesHeight, menuEntries.length ? 0 : emptyBody.implicitHeight)) : items.length ? Math.min(Math.max(1,Math.floor(maxBodyHeight/rowHeight)),Math.ceil(items.length/trayList.columns))*rowHeight : emptyBody.implicitHeight
    readonly property real preferredHeight: header.height + (menuOpen?26:12) + preferredBodyHeight
    signal dismissRequested()
    function label(item) { return String(item ? item.tooltipTitle || item.title || item.id || "Application" : "Application"); }
    function openMenu(item) { return controller.open(item); }
    function resetMenu() { controller.reset(); }
    function back() { return controller.back(); }
    function invoke(entry) { controller.invoke(entry); }
    function focusInitial() { if (menuOpen) menuList.forceActiveFocus(); else focusItem(Math.max(0, trayList.currentIndex), Qt.PopupFocusReason); }
    function focusItem(index, reason = Qt.TabFocusReason) {
        if (!surfaceOpen || menuOpen) return;
        if (!items.length) { if (reason === Qt.PopupFocusReason) root.forceActiveFocus(reason); else close.forceActiveFocus(reason); return; }
        const next = Math.max(0, Math.min(items.length - 1, index));
        trayList.currentIndex = next;
        trayList.positionViewAtIndex(next, GridView.Contain);
        trayList.forceLayout();
        const row = trayList.itemAtIndex(next);
        if (row) row.primaryControl.focusForReason(reason);
        else trayList.forceActiveFocus(reason);
    }
    function moveCommand(direction) {
        const count = menuEntries.length;
        if (!count) return;
        let index = menuList.currentIndex;
        for (let step = 0; step < count; step++) {
            index = (index + direction + count) % count;
            if (menuEntries[index].enabled && !menuEntries[index].isSeparator) {
                menuList.currentIndex = index;
                menuList.positionViewAtIndex(index, ListView.Contain);
                return;
            }
        }
        menuList.currentIndex = -1;
    }
    function reserveMenu() { if (menuOpen) menuReserve = Math.min(maxBodyHeight, Math.max(menuReserve, entriesHeight)); }
    onMenuOpenChanged: { menuReserve = menuOpen ? 2 * commandHeight : 0; reserveMenu(); }
    onEntriesHeightChanged: reserveMenu()
    onMenuEntriesChanged: {
        const generation = controller.generation;
        Qt.callLater(function() {
            if (!root.surfaceOpen || !root.menuOpen || controller.generation !== generation) return;
            menuList.currentIndex = -1; root.moveCommand(1);
        });
    }
    Keys.onEscapePressed: event => { if (!back()) event.accepted = false; }
    TrayUi.TrayMenuController {
        id: controller; items: root.items; active: root.surfaceOpen
        onFocusMenuRequested: {
            const opening = generation;
            Qt.callLater(function() {
                if (root.surfaceOpen && controller.opened && controller.generation === opening) {
                    menuList.currentIndex = -1; root.moveCommand(1); menuList.forceActiveFocus();
                }
            });
        }
        onFocusAppRequested: item => {
            const opening = controller.generation;
            Qt.callLater(function() {
                if (root.surfaceOpen && !root.menuOpen && controller.generation === opening) root.focusItem(Math.max(0, root.items.indexOf(item)), Qt.PopupFocusReason);
            });
        }
    }
    Row {
        id: header; objectName:"tray-header"; width: parent.width; height: Math.max(Config.QuickPanelStyle.target, identity.implicitHeight); spacing: 8
        QuietButton {
            visible: root.menuOpen; width: Config.QuickPanelStyle.target; height: width
            objectName: "tray-menu-back"; glyph: "\uf104"; iconOnly: true
            accessibleLabel: root.menuStack.length > 1 ? "Back to parent menu" : "Back to applications"
            onClicked: root.back()
        }
        Column {
            id: identity; objectName:"tray-identity"
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - close.width - 8 - (root.menuOpen ? Config.QuickPanelStyle.target + 8 : 0)
            spacing: 4
            Text {
                width: parent.width
                objectName:"tray-menu-title"
                text: root.menuOpen ? "// " + root.label(root.selectedItem) : "// Tray"
                textFormat: Text.PlainText; maximumLineCount: 1; elide: Text.ElideRight
                font.family: Config.QuickPanelStyle.headingFont
                font.pixelSize: Config.QuickPanelStyle.titleSize
                color: Config.DirectoryStyle.ink
            }
            Text {
                width: parent.width
                visible:root.menuOpen && root.menuStack.length>1
                text: root.menuOpen ? (root.menuStack.length > 1 ? controller.cleanLabel(root.menuStack[root.menuStack.length - 1].text) : "Application menu") : root.items.length + (root.items.length === 1 ? " tray app" : " tray apps")
                textFormat: Text.PlainText; maximumLineCount: 1; elide: Text.ElideRight
                font.family: Config.DirectoryStyle.dataFont; font.pixelSize: Config.DirectoryStyle.detailSize
                color: Config.DirectoryStyle.muted
            }
        }
        QuietButton {
            id: close; objectName: "tray-close"
            width: Config.QuickPanelStyle.target; height: width
            glyph: "\uf00d"; iconOnly: true; accessibleLabel: "Close application tray"
            onClicked: root.dismissRequested()
        }
    }
    IslandRule {visible:root.menuOpen;y:header.height+12;width:parent.width;leadingPoint:false}
    GridView {
        id: trayList; objectName: "tray-item-list"
        visible: !root.menuOpen && root.items.length > 0
        y: header.height + 12; width: parent.width; height: Math.max(1, root.height - y)
        readonly property real usableWidth:Math.max(1,width-(Config.DirectoryStyle.touchMode?24:10))
        readonly property int columns:Math.max(1,Math.min(4,Math.floor(usableWidth/Math.max(96,86*Config.DirectoryStyle.textScale))))
        cellWidth:usableWidth/columns;cellHeight:root.rowHeight
        function keepFocusVisible() {
            if (!root.surfaceOpen || root.menuOpen || !root.activeFocus) return;
            Qt.callLater(function() {
                if (root.surfaceOpen && !root.menuOpen && root.activeFocus && trayList.currentIndex >= 0)
                    trayList.positionViewAtIndex(trayList.currentIndex, GridView.Contain);
            });
        }
        onWidthChanged: keepFocusVisible()
        onHeightChanged: keepFocusVisible()
        clip: true; boundsBehavior: Flickable.StopAtBounds
        activeFocusOnTab: false; keyNavigationEnabled: false
        model: ScriptModel { values: root.items; comparisonMode: ObjectComparison.Identity }
        ScrollBar.vertical: ShellScrollBar { policy: ScrollBar.AsNeeded }
        Keys.onDownPressed: root.focusItem(currentIndex + columns)
        Keys.onUpPressed: root.focusItem(currentIndex - columns)
        Keys.onRightPressed:root.focusItem(currentIndex+1)
        Keys.onLeftPressed:root.focusItem(currentIndex-1)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Home) { root.focusItem(0); event.accepted = true; }
            else if (event.key === Qt.Key_End) { root.focusItem(root.items.length - 1); event.accepted = true; }
        }
        delegate: Item {
            id: appRow
            required property var modelData
            required property int index
            readonly property alias primaryControl: app
            width: trayList.cellWidth
            height: root.rowHeight
            TrayQuickItemButton {
                id: app; objectName: "tray-app-" + appRow.index
                anchors.fill: parent
                trayItem: appRow.modelData; parentWindow: root.parentWindow
                onMenuRequested: root.openMenu(appRow.modelData)
                onActiveFocusChanged: if (activeFocus) { trayList.currentIndex = appRow.index; trayList.positionViewAtIndex(appRow.index, GridView.Contain); }
            }
        }
    }
    ListView {
        id: menuList; objectName: "tray-menu-list"
        visible: root.menuOpen && root.menuEntries.length > 0
        y: header.height + 26; width: parent.width; height: Math.max(1, root.height - y)
        clip: true; spacing: 2; boundsBehavior: Flickable.StopAtBounds
        activeFocusOnTab: false; keyNavigationEnabled: false
        model: ScriptModel { values: root.menuEntries; comparisonMode: ObjectComparison.Identity }
        Keys.onDownPressed: root.moveCommand(1)
        Keys.onUpPressed: root.moveCommand(-1)
        Keys.onReturnPressed: if (currentItem) root.invoke(currentItem.modelData)
        Keys.onSpacePressed: if (currentItem) root.invoke(currentItem.modelData)
        Keys.onRightPressed: if (currentItem && currentItem.modelData.hasChildren) root.invoke(currentItem.modelData)
        Keys.onLeftPressed: root.back()
        ScrollBar.vertical: ShellScrollBar { policy: ScrollBar.AsNeeded }
        delegate: Item {
            id: menuRow
            required property var modelData
            required property int index
            width: menuList.width - (Config.DirectoryStyle.touchMode ? 24 : 10)
            height: modelData.isSeparator ? 10 : Math.max(root.commandHeight,command.implicitHeight)
            Rectangle { visible: menuRow.modelData.isSeparator; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Config.DirectoryStyle.rule }
            TrayUi.TrayQuickMenuRow {
                id:command
                objectName: "tray-menu-command-" + menuRow.index
                visible: !menuRow.modelData.isSeparator
                width: parent.width; height: parent.height
                entry: menuRow.modelData; label: controller.cleanLabel(menuRow.modelData.text)
                current: menuRow.ListView.isCurrentItem && menuList.activeFocus
                onClicked: { menuList.currentIndex = menuRow.index; root.invoke(menuRow.modelData); }
                onActiveFocusChanged: if (activeFocus) { menuList.currentIndex = menuRow.index; menuList.positionViewAtIndex(menuRow.index, ListView.Contain); }
                Keys.onRightPressed: if (menuRow.modelData.hasChildren) root.invoke(menuRow.modelData)
                Keys.onLeftPressed: root.back()
            }
        }
    }
    Column {
        id: emptyBody
        visible: root.menuOpen ? !root.menuEntries.length : !root.items.length
        y: header.height + 26; width: parent.width; spacing: 8
        Text {
            width: parent.width
            text: !root.menuOpen ? "No tray items" : controller.loading ? "Loading application menu…" : "No menu commands available."
            textFormat: Text.PlainText; wrapMode: Text.WordWrap
            font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: Config.DirectoryStyle.bodySize
            color: Config.DirectoryStyle.ink
        }
        QuietButton {
            objectName: "tray-menu-retry"
            visible: root.menuOpen && !controller.loading
            width: Math.min(parent.width, 140); height: Config.QuickPanelStyle.target
            text: "Retry menu"; labelSize: Config.DirectoryStyle.detailSize
            onClicked: root.openMenu(root.selectedItem)
        }
    }
}
