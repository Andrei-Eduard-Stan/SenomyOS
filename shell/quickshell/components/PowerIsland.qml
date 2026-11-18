import QtQuick
import QtQuick.Controls
import Quickshell
import "../config" as Config

Item {
    id: root

    property var powerService
    property bool panelOpen: false
    property alias panelAnchor: powerArea
    signal togglePower()
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Open session actions" + (powerService && powerService.hasSchedule ? ". "+powerService.schedule.label+" scheduled in "+powerService.remainingText : "")
    Keys.onReturnPressed: if(powerService)togglePower()
    Keys.onSpacePressed: if(powerService)togglePower()

    width: 64
    height: Config.Theme.islandHeight

    RailIslandBackground {
        anchors.fill: parent
        z: -1
        fillKey: "power-island"
    }
    SilverIslandFrame {
        drawFill: false
        objectName: "power-reflective-frame"
        hoverGlow: true
        anchors.fill: parent
        active: false
        hovered: !!root.powerService && (powerArea.containsMouse || root.activeFocus)
    }


    Image {
        visible: !(root.powerService && root.powerService.hasSchedule)
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) - 18
        height: width
        source: "file://" + Quickshell.shellDir + "/../../assets/senomy_island_expanded/lockinthosefirst/SVG/sos logo.svg"
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        mipmap: true
        opacity: powerService ? 0.86 : 0.32

        scale: 1
        Behavior on scale { NumberAnimation { duration: Config.Motion.duration(120); easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Config.Motion.duration(120) } }
    }

    Column {
        visible: !!(root.powerService && root.powerService.hasSchedule)
        anchors.centerIn: parent
        width: parent.width-8; spacing: 2
        Text {width:parent.width;text:root.powerService?String(root.powerService.schedule.label||"SESSION").toUpperCase():"";font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:8;color:Config.QuickPanelStyle.secondary;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight}
        Text {objectName:"rail-session-countdown";width:parent.width;text:root.powerService?root.powerService.remainingText:"";font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:10;color:Config.QuickPanelStyle.ink;horizontalAlignment:Text.AlignHCenter;fontSizeMode:Text.HorizontalFit;minimumPixelSize:8}
        ScheduleRail {width:parent.width;height:10;progress:root.powerService?root.powerService.progress:0;critical:root.powerService&&root.powerService.remainingSeconds<=60}
    }
    MouseArea {
        id: powerArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: powerService ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (powerService) root.togglePower()
    }
}
