import QtQuick
import QtQml.Models
import Quickshell

// Application-owned menus stay inside one popup. Each ancestor retains its
// opener until Back/reset, so loading a deeper submenu cannot unload its parent.
QtObject {
    id: root
    property var items: []
    property var provider: null
    property bool active: true
    property var selectedItem: null
    property var stack: []
    property int generation: 0
    property int openerRevision: 0
    readonly property bool opened: selectedItem !== null
    readonly property bool loading: emptyTimer.running && entries.length === 0
    readonly property var currentOpener: {
        const revision = openerRevision;
        return openers.objectAt(stack.length - 1);
    }
    readonly property var entries: !opened ? [] : provider ? provider.entries : currentOpener ? currentOpener.children.values : []
    signal focusAppRequested(var item)
    signal focusMenuRequested()
    function cleanLabel(text) { return String(text || "Unnamed command").replace(/&&|&/g, part => part === "&&" ? "&" : ""); }
    function open(item) {
        if (!active || !item || !item.hasMenu || !items.includes(item)) return false;
        ++generation;
        stack = [];
        selectedItem = item;
        stack = [item.menu];
        emptyTimer.restart();
        focusMenuRequested();
        return true;
    }
    function reset() {
        const item = selectedItem;
        ++generation;
        selectedItem = null;
        stack = [];
        emptyTimer.stop();
        focusAppRequested(item);
    }
    function back() {
        if (!opened) return false;
        if (stack.length > 1) {
            ++generation;
            stack = stack.slice(0, -1);
            emptyTimer.restart();
            focusMenuRequested();
        } else reset();
        return true;
    }
    function invoke(entry) {
        if (!active || !opened || !entry || !entries.includes(entry) || !entry.enabled || entry.isSeparator) return false;
        if (entry.hasChildren) {
            ++generation;
            stack = stack.concat([entry]);
            emptyTimer.restart();
            focusMenuRequested();
        } else {
            entry.triggered();
            reset();
        }
        return true;
    }
    onActiveChanged: if (!active) reset()
    onItemsChanged: if (selectedItem && !items.includes(selectedItem)) reset()
    onOpenedChanged: if (!opened) { stack = []; emptyTimer.stop(); }
    onEntriesChanged: if (entries.length) emptyTimer.stop()
    property Timer emptyTimer: Timer { interval: 1500 }
    property Instantiator openers: Instantiator {
        model: ScriptModel { values: root.provider ? [] : root.stack; comparisonMode: ObjectComparison.Identity }
        delegate: QsMenuOpener {
            required property var modelData
            menu: modelData
        }
        onObjectAdded: root.openerRevision++
        onObjectRemoved: root.openerRevision++
    }
}
