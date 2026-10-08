import QtQuick
import "../config" as Config

Column {
    id: root
    property var settings: null
    spacing: 12
    DashboardCard {
        width: parent.width
        title: "INPUT METHODS"
        value: root.settings && root.settings.editorAvailable === true ? "FCITX5 SETTINGS AVAILABLE" : "SETTINGS TOOL UNAVAILABLE"
        detail: root.settings && root.settings.engineInstalled === true
            ? "Fcitx5 is installed. Application text entry and session integration remain unverified."
            : "Fcitx5 engine is not detected. Input methods require an installed, configured provider."
    }
    DashboardButton {
        objectName: "openInputMethodSettings"
        width: parent.width
        text: root.settings && root.settings.nativeToolsBusy === true ? "STARTING SETTINGS…" : "OPEN INPUT-METHOD SETTINGS"
        enabled: root.settings && root.settings.editorAvailable === true && root.settings.nativeToolsBusy !== true
        onClicked: root.settings.openInputMethodSettings()
    }
    Text {
        width: parent.width
        visible: root.settings && !!root.settings.nativeToolsMessage
        text: root.settings ? root.settings.nativeToolsMessage || "" : ""
        color: Config.Theme.muted; font.family: Config.Theme.fontFamily; font.pixelSize: 10; wrapMode: Text.WordWrap
    }
    DashboardCard {
        width: parent.width
        title: "ON-SCREEN KEYBOARD"
        value: "NOT INTEGRATED"
        detail: "A compatible provider, explicit show/hide controls and application text-entry testing are still required."
    }
}
