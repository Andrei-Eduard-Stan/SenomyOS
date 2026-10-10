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
        value: root.settings && root.settings.oskCapabilities && root.settings.oskCapabilities.providerInstalled === true
            ? root.settings.oskCapabilities.manualCandidate === true ? root.settings.oskAutomatic && root.settings.oskAutomatic.available ? "AUTO / MANUAL CONTROLS" : "MANUAL CONTROLS"
              : root.settings.oskCapabilities.protocolState === "incompatible" ? "PROTOCOLS INCOMPATIBLE" : "COMPATIBILITY UNKNOWN"
            : "PROVIDER UNAVAILABLE"
        detail: root.settings && root.settings.oskCapabilities
            ? root.settings.oskCapabilities.message + " Auto opens in supported text fields when no usable physical keyboard is detected. Super+Ctrl+K still opens or hides it manually."
            : "OSK capabilities have not been checked. Integration remains open."
    }
    DashboardButton {
        width: parent.width
        text: root.settings && root.settings.oskAutomatic && root.settings.oskAutomatic.mode === "auto" ? "AUTO OPEN · SWITCH TO MANUAL" : "MANUAL · ENABLE AUTO OPEN"
        enabled: root.settings && root.settings.oskAutomatic && !root.settings.oskAutomatic.settingMode
        onClicked: root.settings.oskAutomatic.setMode(root.settings.oskAutomatic.mode === "auto" ? "manual" : "auto")
    }
    Text {
        width: parent.width; wrapMode: Text.WordWrap
        text: root.settings && root.settings.oskAutomatic ? root.settings.oskAutomatic.status : "Automatic opening is unavailable."
        color: Config.Theme.muted; font.family: Config.Theme.fontFamily; font.pixelSize: 10
    }
    OskControls { width: parent.width; controller: root.settings && root.settings.oskController ? root.settings.oskController : null }
}
