import QtQuick
import Quickshell
import "../config" as Config

Item {
    id: root

    required property var toplevel
    property bool emphasized: false

    readonly property string appClass: {
        if (!toplevel)
            return "";
        const ipc = toplevel.lastIpcObject || {};
        return String(ipc.class || ipc.initialClass || "").toLowerCase();
    }
    readonly property string initialClass: {
        if (!toplevel)
            return "";
        const ipc = toplevel.lastIpcObject || {};
        return String(ipc.initialClass || ipc.class || "").toLowerCase();
    }
    readonly property var desktopEntry: DesktopEntries.heuristicLookup(appClass)
        || DesktopEntries.heuristicLookup(initialClass)
    readonly property string iconName: {
        const aliases = {
            "chatgpt": "chatgpt",
            "code": "vscode",
            "code-url-handler": "vscode",
            "google-chrome": "google-chrome",
            "org.mozilla.firefox": "firefox",
            "org.gnome.nautilus": "org.gnome.Nautilus",
            "thunar": "thunar"
        };
        const aliased = aliases[appClass] || aliases[initialClass] || "";
        if (aliased.length > 0)
            return aliased;
        if (desktopEntry && desktopEntry.icon)
            return desktopEntry.icon;
        return appClass || initialClass;
    }
    readonly property string iconSource: iconName.length > 0 ? Quickshell.iconPath(iconName, true) : ""

    width: 18
    height: 18

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.iconSource.length > 0 ? "transparent"
            : root.emphasized ? Config.Theme.glassFocus : Config.Theme.glassRaised
        border.width: root.iconSource.length > 0 ? 0 : 1
        border.color: root.emphasized ? Config.Theme.accent : Config.Theme.dim
    }

    Image {
        visible: root.iconSource.length > 0
        anchors.fill: parent
        anchors.margins: 0
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        mipmap: true
    }

    Rectangle {
        visible: root.iconSource.length === 0
        anchors.centerIn: parent
        width: 5
        height: 5
        radius: 2
        color: root.emphasized ? Config.Theme.background : Config.Theme.muted
    }
}
