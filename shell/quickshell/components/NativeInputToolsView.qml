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
            ? root.settings.oskCapabilities.manualCandidate === true ? "MANUAL CONTROLS / UNVERIFIED"
              : root.settings.oskCapabilities.protocolState === "incompatible" ? "PROTOCOLS INCOMPATIBLE" : "COMPATIBILITY UNKNOWN"
            : "PROVIDER UNAVAILABLE"
        detail: root.settings && root.settings.oskCapabilities
            ? root.settings.oskCapabilities.message + " Manual controls require an installed provider and advertised protocols. Application text-entry acceptance remains open."
            : "OSK capabilities have not been checked. Integration remains open."
    }
    OskControls { width: parent.width; controller: root.settings && root.settings.oskController ? root.settings.oskController : null }
}
