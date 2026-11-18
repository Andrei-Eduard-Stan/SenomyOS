import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../config" as Config
import "interaction" as Interaction
import "interaction/InteractionChildren.js" as Children
import "DirectoryFrameGeometry.js" as FrameGeometry

PanelWindow {
    id: root

    required property var targetScreen
    property var interactionCoordinator: null
    function ownsEscape() {return requestedOpen && contentItem.Window.window && contentItem.Window.window.active;}
    property bool requestedOpen: false
    property string title: "SENOMYOS"
    property string eyebrow: "SYSTEM SURFACE"
    property var sections: []
    property string activeSection: ""
    property int preferredWidth: 1320
    property int preferredHeight: 780
    property string motif: "identity"
    property string frameKey: "insights"
    property real anchorCenterX: targetScreen ? targetScreen.width / 2 : preferredWidth / 2
    readonly property bool narrowLayout: width < 900 * Config.DirectoryStyle.textScale
    property bool directoryOpen: false
    property var backHandler:null
    readonly property int sidebarWidth: Math.round(184 * Config.DirectoryStyle.textScale)
    onActiveNodeChanged: if(narrowLayout) directoryOpen=false
    property var directoryNodes: []
    property string activeNode: activeSection
    property var navigationTelemetry: ({})
    property bool touchMode: Config.DirectoryStyle.touchMode
    property string breadcrumb: "SENOMY_systems / " + frameKey + ".dashboard / " + activeSection
    property string statusLine: ""
    readonly property var navigation: narrowLayout ? drawerNavigation : directoryNavigation
    property alias contentArea: body
    signal nodeRequested(var node)
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
    property alias captureItem: surface
    default property alias bodyData: body.data
    signal closeRequested()
    signal surfaceRequested(string kind)
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

    mask: DirectoryFrameMask { frameItem: surface; rectangles: !root.requestedOpen?[]:FrameGeometry.regions([FrameGeometry.chamfer(frame.perimeterInset,frame.perimeterInset,root.width-2*frame.perimeterInset,root.height-2*frame.perimeterInset,frame.perimeterCorner/2)],root.width,root.height) }

    onRequestedOpenChanged: if(!requestedOpen) Children.dismiss(surface)

    FocusScope {
        id: surface
        FrameObserver {targetItem:surface;key:root.frameKey;contentKey:root.activeNode;requested:root.requestedOpen}
        Connections {
            target:surface.Window.window
            function onActiveFocusItemChanged(){
                if(!root.narrowLayout || !root.directoryOpen || !surface.Window.window)return;
                let item=surface.Window.window.activeFocusItem;
                while(item && item!==body)item=item.parent;
                if(item===body)root.directoryOpen=false;
            }
        }
        enabled:root.requestedOpen
        anchors.fill:parent;focus:root.surfaceShown;opacity:root.presentationProgress
        transform:Translate {y:(1-root.presentationProgress)*Config.Motion.travel;}

        Keys.onEscapePressed:{
            if(root.interactionCoordinator && (root.interactionCoordinator.activePopup || root.interactionCoordinator.modalActive)){root.interactionCoordinator.escapeOverlay();return;}
            if(root.directoryOpen){root.directoryOpen=false;directoryToggle.forceActiveFocus();}
            else if(root.backHandler && root.backHandler())return;
            else root.closeRequested();
        }
        IslandPopupFrame {
            id:frame;objectName:"insights-island-frame";anchors.fill:parent;frameKey:"insights";animate:false;active:true
            contentInset:Config.QuickPanelStyle.inset;perimeterCorner:Config.QuickPanelStyle.corner
            Item {
                id:toolbar;width:parent.width;height:Config.QuickPanelStyle.target
                QuietButton {id:directoryToggle;objectName:"insights-directory-toggle";visible:root.narrowLayout;width:Config.QuickPanelStyle.target;height:width;glyph:"\uf0c9";iconOnly:true;active:root.directoryOpen;accessibleLabel:root.directoryOpen?"Close Insights navigation":"Open Insights navigation";onClicked:{root.directoryOpen=!root.directoryOpen;if(root.directoryOpen)drawerNavigation.focusSection();}}
                Text {x:root.narrowLayout?directoryToggle.width+12:0;width:Math.max(1,surfaceControls.x-x-16);anchors.verticalCenter:parent.verticalCenter;text:"// Insights";elide:Text.ElideRight;font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Config.QuickPanelStyle.titleSize;color:Config.DirectoryStyle.ink}
                Row {id:surfaceControls;anchors.right:parent.right;spacing:8
                    QuietButton {objectName:"switch-performance";width:root.width<620?Config.QuickPanelStyle.target:Math.max(140,implicitWidth);glyph:"\uf201";iconOnly:root.width<620;text:root.width<620?"":"Performance";accessibleLabel:"Open Performance";onClicked:root.surfaceRequested("performance")}
                    QuietButton {objectName:"insights-close";width:Config.QuickPanelStyle.target;height:width;glyph:"\uf00d";iconOnly:true;accessibleLabel:"Close Insights";onClicked:root.closeRequested()}
                }
            }
            IslandRule {y:toolbar.height+12;width:parent.width;leadingPoint:false}
            Item {id:workspace;y:toolbar.height+32;width:parent.width;height:Math.max(1,parent.height-y)
                InsightsWorkspaceNavigation {id:directoryNavigation;visible:!root.narrowLayout;width:root.sidebarWidth;height:parent.height;nodes:root.directoryNodes.length?root.directoryNodes:root.sections;activeNode:root.activeNode;onActivated:node=>root.sectionRequested(node.route || node.id)}
                Rectangle {visible:!root.narrowLayout;x:root.sidebarWidth+16;width:1;height:parent.height;color:Config.DirectoryStyle.rule}
                Item {id:body;x:root.narrowLayout?0:root.sidebarWidth+40;width:Math.max(1,parent.width-x);height:parent.height}
                Rectangle {id:drawer;visible:root.narrowLayout && root.directoryOpen;z:10;width:Math.min(280*Config.DirectoryStyle.textScale,parent.width);height:parent.height;color:Config.QuickPanelStyle.surface;border.width:1;border.color:Config.DirectoryStyle.rule
                    InsightsWorkspaceNavigation {id:drawerNavigation;anchors.fill:parent;anchors.margins:12;nodes:root.directoryNodes.length?root.directoryNodes:root.sections;activeNode:root.activeNode;onActivated:node=>{root.sectionRequested(node.route || node.id);root.directoryOpen=false;directoryToggle.forceActiveFocus();}}
                }
            }
        }
    }
}
