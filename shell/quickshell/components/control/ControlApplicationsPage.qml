import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower
import ".."
import "../../config" as Config
import "../../services" as Services

FocusScrollArea {
    id: root
    property var desktopSettings: null
    Services.ApplicationLaunch {id:lensLaunch}
    property string part: "overview"
    property string deviceKey:""
    signal destinationRequested(string id)

    ScrollBar.vertical: ShellScrollBar {}
    contentHeight: appsColumn.implicitHeight
    Column {
        id: appsColumn
        width: parent.width
        spacing: 12
        Loader {
            width: parent.width
            active: root.desktopSettings !== null && (root.part === "defaults" || root.part === "autostart")
            sourceComponent: DesktopPreferencesView {
                settings: root.desktopSettings
                part: root.part
                        selectedKey:root.deviceKey
            }
        }
        Column {
            width: parent.width
            spacing: 12
            visible: root.part === "launcher"
            DashboardCard {
                width: parent.width
                title: "COMMAND LENS"
                value: "APPLICATION LAUNCHER"
                detail: "Open applications, files, windows and curated actions in Command Lens."
            }
            Flow {
                width: parent.width
                spacing: 8
                ControlWorkspaceButton {
                    width: 170
                    text: "APPLICATIONS"
                    onClicked: lensLaunch.request("tool","lens",["apps"])
                }
                ControlWorkspaceButton {
                    width: 170
                    text: "FILES"
                    onClicked: lensLaunch.request("tool","lens",["files"])
                }
                ControlWorkspaceButton {
                    width: 170
                    text: "WINDOWS"
                    onClicked: lensLaunch.request("tool","lens",["windows"])
                }
                ControlWorkspaceButton {
                    width: 170
                    text: "ACTIONS"
                    onClicked: lensLaunch.request("tool","lens",["actions"])
                }
            }
            Text {
                width: parent.width
                text: "Command Lens opens as a separate launcher. These buttons choose its starting mode."
                color: Config.Theme.muted
                font.family: Config.Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }
        Text {width:parent.width;visible:lensLaunch.state==="failed" || lensLaunch.state==="unverified";text:lensLaunch.message;wrapMode:Text.WordWrap;color:Config.Theme.warning}
        ControlRouteTiles {
            width: parent.width
            visible: root.part === "overview"
            entries: [
                {
                    id: "apps/defaults",
                    label: "DEFAULT APPLICATIONS",
                    detail: "Choose application handlers"
                },
                {
                    id: "apps/autostart",
                    label: "STARTUP APPLICATIONS",
                    detail: "Review future login entries"
                },
                {
                    id: "apps/launcher",
                    label: "COMMAND LENS",
                    detail: "Applications, files and windows"
                }
            ]
            onActivated: id => root.destinationRequested(id)
        }
    }
}
