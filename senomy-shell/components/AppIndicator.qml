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
    readonly property string iconName: {
        const aliases = {
            "code": "visual-studio-code",
            "code-url-handler": "visual-studio-code",
            "google-chrome": "google-chrome",
            "org.mozilla.firefox": "firefox",
            "org.gnome.nautilus": "system-file-manager",
            "thunar": "system-file-manager"
        };
        return aliases[appClass] || appClass;
    }
    readonly property string iconSource: iconName.length > 0 ? Quickshell.iconPath(iconName, true) : ""

    width: 12
    height: 12

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.emphasized ? Config.Theme.accent : Config.Theme.surfaceRaised
        border.width: 1
        border.color: root.emphasized ? Config.Theme.accent : Config.Theme.dim
    }

    Image {
        visible: root.iconSource.length > 0
        anchors.fill: parent
        anchors.margins: 1
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        mipmap: true
    }

    Rectangle {
        visible: root.iconSource.length === 0
        anchors.centerIn: parent
        width: 4
        height: 4
        radius: 2
        color: root.emphasized ? Config.Theme.background : Config.Theme.muted
    }
}
