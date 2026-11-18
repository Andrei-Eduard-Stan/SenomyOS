import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../config" as Config
import "interaction" as Interaction
import "interaction/InteractionChildren.js" as Children

PanelWindow {
    id: root

    required property var targetScreen
    property var interactionCoordinator:null
    property bool requestedOpen: false
    property string title: "SENOMYOS"
    property string eyebrow: "SYSTEM SURFACE"
    property var sections: []
    property string activeSection: ""
    property int preferredWidth: 960
    property int preferredHeight: 720
    property string motif: "identity"
    property string frameKey: "insights"
    property real anchorCenterX: targetScreen ? targetScreen.width / 2 : preferredWidth / 2
    readonly property int sidebarWidth: implicitWidth < 650 ? 120 : 190
    readonly property bool surfaceShown:presentation.shown
    readonly property real presentationProgress:presentation.progress
    readonly property string lifecycle:presentation.phase
    Interaction.NativePresentation {
        id:presentation;targetItem:surface;requested:root.requestedOpen
        focusOnReady:!root.interactionCoordinator || !root.interactionCoordinator.modalActive
        suppressed:root.replacementOpening || !!(root.interactionCoordinator && root.interactionCoordinator.capturePaused)
    }
    Interaction.ContentMotion {id:routeMotion;targetItem:body;context:typeof root.activeNode==="string"?root.activeNode:root.activeSection;active:root.requestedOpen}
    function revealContent(){routeMotion.pulse();}
    property bool replacementOpening: false
    default property alias bodyData: body.data
    property alias navigation: routeNavigation
    property alias contentArea: body
    signal closeRequested()
    signal sectionRequested(string section)

    screen: targetScreen
    visible: !presentation.suppressed && (requestedOpen || presentation.retained)
    readonly property var nativeMonitor: targetScreen ? Hyprland.monitorFor(targetScreen) : null
    readonly property var reservations: nativeMonitor ? nativeMonitor.lastIpcObject.reserved : null
    readonly property real reservedLeft: reservations && reservations.length===4 ? Number(reservations[0]) : 0
    readonly property real reservedTop: reservations && reservations.length===4 ? Number(reservations[1]) : 0
    readonly property real reservedRight: reservations && reservations.length===4 ? Number(reservations[2]) : 0
    readonly property real reservedBottom: reservations && reservations.length===4 ? Number(reservations[3]) : Config.Theme.railHeight
    readonly property real workWidth: Math.max(1,(targetScreen ? targetScreen.width : preferredWidth)-reservedLeft-reservedRight-40)
    readonly property real workHeight: Math.max(1,(targetScreen ? targetScreen.height : preferredHeight)-reservedTop-reservedBottom-34)
    readonly property var fitted: Config.OskGeometry.place(targetScreen, {
        x:reservedLeft+20,y:reservedTop+17,width:workWidth,height:workHeight}, preferredWidth,preferredHeight,anchorCenterX)
    readonly property real surfaceLeft: fitted.x
    implicitWidth: fitted.width
    implicitHeight: fitted.height
    color: "transparent"
    exclusiveZone: 0
    focusable: true

    anchors {
        left: true
        bottom: true
    }
    margins {
        left: root.surfaceLeft
        // The Rail's exclusive zone already removes its height from the
        // layershell work area. Zero keeps this frame visually docked above it.
        bottom: Math.max(0,(root.targetScreen ? root.targetScreen.height : root.preferredHeight)-root.reservedBottom-root.fitted.y-root.fitted.height)
    }

    WlrLayershell.namespace: "senomy-v2-primary"
    WlrLayershell.layer: Config.OskGeometry.floatingOn(targetScreen) ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.requestedOpen?WlrKeyboardFocus.OnDemand:WlrKeyboardFocus.None

    mask: Region {
        Region { item: root.requestedOpen?frame:null; radius: 5 }
    }

    onRequestedOpenChanged: if(!requestedOpen) Children.dismiss(surface)

    HyprlandFocusGrab {
        windows: [root]
        active: root.surfaceShown
        onCleared: if (root.requestedOpen) root.closeRequested()
    }

    FocusScope {
        id: surface
        enabled:root.requestedOpen
        anchors.fill: parent
        focus: root.surfaceShown
        opacity:root.presentationProgress
        scale:1
        transform: Translate {
            y:(1-root.presentationProgress)*Config.Motion.travel

        }


        Keys.onEscapePressed: root.closeRequested()

        ShellSurfaceFrame {
            id: frame
            frameKey: root.frameKey
            anchors.fill: parent
            tier: "large"
            motif: root.motif
            motifCenterX: root.anchorCenterX - root.surfaceLeft
            active: true

            Row {
                anchors.fill: parent
                spacing: 16

                Column {
                    width: root.sidebarWidth
                    height: parent.height
                    spacing: 12

                    Row {
                        width: parent.width
                        spacing: 8
                        Column {
                            width: parent.width - 46
                            spacing: 4
                            Text {
                                width: parent.width
                                text: root.eyebrow
                                color: Config.Theme.accent
                                font.family: Config.Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: root.title
                                color: Config.Theme.foreground
                                font.family: Config.Theme.fontFamily
                                font.pixelSize: 19
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                            }
                        }
                        SurfaceButton {
                            anchors.verticalCenter: parent.verticalCenter
                            headerControl: true
                            width: 44
                            height: 44
                            text: "×"
                            onClicked: root.closeRequested()
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Config.Theme.surfaceHover
                    }

                    DashboardNavigation {
                        id: routeNavigation
                        width: parent.width
                        height: Math.max(0,parent.height - 112)
                        spacing: 6
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        sections: root.sections
                        activeSection: root.activeSection
                        restoreFocus: root.requestedOpen && root.surfaceShown
                        onSectionRequested: section => root.sectionRequested(section)
                        delegate: SurfaceButton {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            enabled: modelData.enabled !== false
                            onActiveFocusChanged: if (activeFocus) {
                                routeNavigation.currentIndex = index;
                                routeNavigation.positionViewAtIndex(index,ListView.Contain);
                            }
                            text: modelData.label
                            detail: modelData.detail || ""
                            active: root.activeSection === modelData.id
                            onClicked: root.sectionRequested(modelData.id)
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: parent.height
                    color: Config.Theme.surfaceHover
                }

                Item {
                    id: body
                    width: Math.max(1,parent.width - root.sidebarWidth - 17)
                    height: parent.height
                }
            }
        }
    }
}
