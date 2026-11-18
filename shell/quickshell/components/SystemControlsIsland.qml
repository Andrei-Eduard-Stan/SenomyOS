import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import "../config" as Config

SenomyFrame {
    frameKey: ""
    fillKey: "control"
    borderType: "none"
    nativeFrameEnabled: false
    fullHeightFrame: true
    railBackground: true
    stateUnderlineEnabled: false
    id: root
    SilverIslandFrame {
        drawFill: false
        parent: root
        anchors.fill: parent
        z: -1
        active: false
        hovered: root.hovered
    }


    required property var audio
    required property var battery
    required property var network
    property bool trayOpen: false
    property bool networkOpen: false
    property bool batteryOpen: false
    property var controlAnchor: null
    property var networkAnchor: null
    property var batteryAnchor: null
    property bool volumeOpen: false
    property bool controlOpen: false
    property bool lensOpen: false
    property bool micro: false
    property alias trayAnchor: trayButton.anchorItem
    property var volumeAnchor: null
    property var lensAnchor: null
    signal toggleLens()
    signal toggleTray()
    signal toggleVolume()
    signal toggleNetwork()
    signal toggleBattery()
    signal openControl(string section)
    signal openSettings(string section)
    width: 338
    height: Config.Theme.islandHeight
    motif: "controls"
    active: trayOpen || volumeOpen || networkOpen || batteryOpen || controlOpen || lensOpen

    function batteryIcon() {
        if (!battery.available)
            return "battery.svg";
        if (battery.charging)
            return "battery-charging.svg";
        const percent = Math.round(battery.percentage * 100);
        if (percent >= 88)
            return "battery-100.svg";
        if (percent >= 63)
            return "battery-75.svg";
        if (percent >= 38)
            return "battery-50.svg";
        return "battery-25.svg";
    }

    function controlData(kind) {
        if(kind === "audio")return {id:kind,icon:audio.muted?"volume-muted.svg":"volume.svg",available:audio.available,tooltip:audio.available?"Open native audio controls":"PipeWire output unavailable"};
        if(kind === "network")return {id:kind,icon:"wifi.svg",available:network.available,tooltip:"Open network controls. "+network.detail};
        if(kind === "battery")return {id:kind,icon:batteryIcon(),available:battery.available,tooltip:"Open battery details. "+battery.detail};
        return {id:kind,icon:kind === "control"?"settings.svg":"applications.svg",available:true,tooltip:kind === "control"?"Open Control Centre. Right-click or press Menu for full Settings.":"Open SenomyOS Command Lens"};
    }

    Row {
        parent: root
        anchors.fill: parent
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        anchors.topMargin: 1
        anchors.bottomMargin: 1

        Repeater {
            id: controlRepeater
            // IDs are structural; live status updates must not recreate the
            // delegates that own popup anchors.
            model: root.micro ? ["control"] : root.width >= 300 ? ["control","applications","audio","network","battery"] : ["control","audio","network","battery"]

            delegate: Item {
                id: control
                required property string modelData
                readonly property var controlData: root.controlData(modelData)
                readonly property bool selected: (modelData === "control" && root.controlOpen)
                    || (modelData === "applications" && root.lensOpen)
                    || (modelData === "audio" && root.volumeOpen)
                    || (modelData === "network" && root.networkOpen)
                    || (modelData === "battery" && root.batteryOpen)
                objectName: "rail-control-"+modelData
                required property int index
                activeFocusOnTab: true
                Keys.onReturnPressed: controlArea.clicked(null)
                Keys.onSpacePressed: controlArea.clicked(null)
                Keys.onMenuPressed: if(control.modelData === "control") root.openSettings("")
                Accessible.role: Accessible.Button
                Accessible.name: controlData.tooltip
                width: parent.width / (root.micro ? 1 : controlRepeater.count+1)
                height: parent.height

                Component.onCompleted: {
                    if(controlData.id === "applications") root.lensAnchor=control;
                    if(controlData.id === "control") root.controlAnchor=control;
                    if(controlData.id === "audio") root.volumeAnchor=control;
                    if(controlData.id === "network") root.networkAnchor=control;
                    if(controlData.id === "battery") root.batteryAnchor=control;
                }
                Component.onDestruction: {
                    if(root.lensAnchor===control)root.lensAnchor=null;
                    if(root.controlAnchor===control)root.controlAnchor=null;
                    if(root.volumeAnchor===control)root.volumeAnchor=null;
                    if(root.networkAnchor===control)root.networkAnchor=null;
                    if(root.batteryAnchor===control)root.batteryAnchor=null;
                }

                ChamferHover {
                    anchors.fill: parent
                    leftCorner: control.index === 0
                    rightCorner: root.micro
                    highlighted: controlArea.containsMouse
                    selected: control.selected
                    focusTarget: control; pointerTarget: controlArea

                }
                Loader {
                    objectName:"rail-tooltip-"+control.modelData
                    source:"RailToolTip.qml"
                    onLoaded:{item.anchorItem=control;item.text=Qt.binding(()=>control.controlData.tooltip);item.hovered=Qt.binding(()=>controlArea.containsMouse);item.suppressed=Qt.binding(()=>root.active);}
                }
                Image {
                    anchors.centerIn: parent
                    width: 19
                    height: 19
                    source: "../assets/icons/" + controlData.icon
                    fillMode: Image.PreserveAspectFit
                    opacity: controlData.available ? 0.92 : 0.34
                }
                MouseArea {
                    id: controlArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: controlData.id === "control" ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
                    cursorShape: controlData.id === "audio" && !root.audio.available
                        ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (controlData.id === "control" && mouse && mouse.button === Qt.RightButton)
                            root.openSettings("");
                        else if (controlData.id === "control")
                            root.openControl("");
                        else if (controlData.id === "applications")
                            root.toggleLens();
                        else if (controlData.id === "audio")
                            root.toggleVolume();
                        else if (controlData.id === "network")
                            root.toggleNetwork();
                        else if (controlData.id === "battery")
                            root.toggleBattery();
                    }
                }
            }
        }

        Item {
            id: trayButton
            activeFocusOnTab: true
            Keys.onReturnPressed: root.toggleTray()
            Keys.onSpacePressed: root.toggleTray()
            Accessible.role: Accessible.Button
            Accessible.name: "Open system tray"
            Loader {
                objectName:"rail-tooltip-tray"
                source:"RailToolTip.qml"
                onLoaded:{item.anchorItem=trayButton;item.text="Open system tray";item.hovered=Qt.binding(()=>trayArea.containsMouse);item.suppressed=Qt.binding(()=>root.active);}
            }
            property alias anchorItem: trayArea
            visible: !root.micro
            width: visible ? parent.width / (controlRepeater.count+1) : 0
            height: parent.height

            ChamferHover {
                anchors.fill: parent
                rightCorner: true
                highlighted: trayArea.containsMouse
                selected: root.trayOpen
                focusTarget: trayButton; pointerTarget: trayArea
            }
            Image {
                anchors.centerIn: parent
                width: 19
                height: 19
                source: "../assets/icons/tray-up.svg"
                fillMode: Image.PreserveAspectFit
            }
            MouseArea {
                id: trayArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleTray()
            }
        }
    }
}
