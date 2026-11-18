import QtQuick
import Quickshell
import "../config" as Config

Item {
    id: root

    required property var toplevel
    property bool emphasized: false

    readonly property string appClass: {
        if (!toplevel) return "";
        const ipc = toplevel.lastIpcObject || {};
        return String((toplevel.wayland && toplevel.wayland.appId) || ipc.class || ipc.initialClass || "");
    }
    readonly property string initialClass: {
        const ipc = toplevel ? toplevel.lastIpcObject || {} : {};
        return String(ipc.initialClass || appClass);
    }
    // Track discovery completion as well as the window app ID.
    readonly property var applications: DesktopEntries.applications.values
    readonly property var desktopEntry: {
        const count = applications.length;
        if (!appClass && !initialClass) return null;
        return (appClass ? DesktopEntries.byId(appClass) : null)
            || (initialClass ? DesktopEntries.byId(initialClass) : null)
            || (appClass ? DesktopEntries.heuristicLookup(appClass) : null)
            || (initialClass ? DesktopEntries.heuristicLookup(initialClass) : null);
    }
    readonly property string iconSource: {
        const aliases = {"code": "vscode", "code-url-handler": "vscode",
            "org.mozilla.firefox": "firefox", "org.gnome.nautilus": "org.gnome.Nautilus"};
        const candidates = [desktopEntry ? desktopEntry.icon : "", appClass, initialClass,
            aliases[appClass.toLowerCase()] || "", aliases[initialClass.toLowerCase()] || ""];
        for (const name of candidates) {
            if (!name) continue;
            if (name.startsWith("/")) return "file://" + name;
            if (name.startsWith("file://")) return name;
            const resolved = Quickshell.iconPath(name, true);
            if (resolved) return resolved;
        }
        return "";
    }
    readonly property bool iconReady: icon.status === Image.Ready
    Accessible.name: desktopEntry ? desktopEntry.name : appClass || "Unknown application"

    width: 18
    height: 18

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.iconReady ? "transparent"
            : root.emphasized ? Config.Theme.glassFocus : Config.Theme.glassRaised
        border.width: root.iconReady ? 0 : 1
        border.color: root.emphasized ? Config.Theme.accent : Config.Theme.dim
    }

    Image {
        id: icon
        visible: root.iconReady
        anchors.fill: parent
        anchors.margins: 0
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        mipmap: true
    }

    Text {
        visible: !root.iconReady
        anchors.centerIn: parent
        text: root.appClass ? root.appClass.charAt(0).toUpperCase() : "?"
        font.pixelSize: 10
        color: Config.Theme.foreground
    }
}
