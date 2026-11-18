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
    property int preferredWidth: 1700
    property int preferredHeight: 900
    property string motif: "identity"
    property string frameKey: "insights"
    property real anchorCenterX: targetScreen ? targetScreen.width / 2 : preferredWidth / 2
    readonly property bool narrowLayout: width < 900 * Config.DirectoryStyle.textScale
    property bool directoryOpen: false
    readonly property int sidebarWidth: 238
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

    mask: DirectoryFrameMask { frameItem: frame; rectangles: root.requestedOpen?frame.inputRectangles:[] }

    onRequestedOpenChanged: if(!requestedOpen) Children.dismiss(surface)

    FocusScope {
        id: surface
        FrameObserver { targetItem:surface; key:root.frameKey; contentKey:root.activeNode; requested:root.requestedOpen }
        enabled:root.requestedOpen
        anchors.fill: parent
        focus: root.surfaceShown
        opacity:root.presentationProgress
        scale: 1
        transform: Translate {
            y:(1-root.presentationProgress)*Config.Motion.travel

        }


        Keys.onEscapePressed: {if(root.interactionCoordinator && (root.interactionCoordinator.activePopup || root.interactionCoordinator.modalActive)){root.interactionCoordinator.escapeOverlay();return;}if(root.directoryOpen){root.directoryOpen=false;directoryToggle.forceActiveFocus();}else root.closeRequested()}

        Item {
            id: frame
            objectName: "directory-art-frame"
            anchors.fill: parent
            // Back the actual authored lettering, cipher and corner silhouette.
            readonly property var silhouette: FrameGeometry.polygons(width,height,
                Qt.rect(authoredTop.x,authoredTop.y,authoredTop.labelWidth,26),
                Qt.rect(authoredTop.x+cipher.x,authoredTop.y+cipher.y,cipher.width,cipher.height))
            readonly property var inputRectangles: FrameGeometry.regions(silhouette,width,height)
            Canvas {
                id: frameBacking
                objectName: "directory-frame-backing"
                anchors.fill:parent
                readonly property color fillColor:Config.DirectoryStyle.glass
                onWidthChanged:requestPaint()
                onHeightChanged:requestPaint()
                onFillColorChanged:requestPaint()
                Connections {target:frame;function onSilhouetteChanged(){frameBacking.requestPaint();}}
                onPaint:{
                    const c=getContext("2d");c.reset();c.beginPath();
                    for(const polygon of frame.silhouette){
                        c.moveTo(polygon[0][0],polygon[0][1]);
                        for(let i=1;i<polygon.length;i++)c.lineTo(polygon[i][0],polygon[i][1]);
                        c.closePath();
                    }
                    c.fillStyle=fillColor;c.fill();
                }
            }
            MetalSheen { x:10;y:25;width:parent.width-20;height:parent.height-50;animate:root.requestedOpen && !(Config.Skin.registry.persona && Config.Skin.registry.persona.reducedMotion === true) }
            Rectangle { x:24;y:48;width:Math.max(0,parent.width-48);height:Math.max(0,parent.height-98);color:Config.DirectoryStyle.highContrast?"#080a0c":"#48080a0c" }
            // Authored Illustrator strips. Only the blank rule runs stretch;
            // title, cipher and corner artwork retain their aspect ratios.
            readonly property string artwork: "file://"+Quickshell.shellDir+"/../../assets/dashboads/1.5x/"
            Repeater {
                model:[{file:"Asset 71",right:false,bottom:false},{file:"Asset 72",right:true,bottom:false},{file:"Asset 69",right:false,bottom:true},{file:"Asset 70",right:true,bottom:true}]
                Image {
                    required property var modelData
                    width:46;height:46
                    x:modelData.right?frame.width-width:0;y:modelData.bottom?frame.height-height-25:25
                    source:frame.artwork+modelData.file+"@1.5x.png"
                    fillMode:Image.PreserveAspectFit
                }
            }
            Item {
                id:authoredTop;objectName:"authored-top-strip"
                x:48;y:14;width:parent.width-96;height:root.narrowLayout?56:26
                readonly property real artScale: Math.min(0.6, Math.max(0.28, (width-(root.narrowLayout?20:310))/866))
                readonly property real labelWidth: Math.min(280,width)
                Item {
                    objectName:"authored-title-plate"
                    x:0;y:0;width:authoredTop.labelWidth;height:26;clip:true
                    Text {
                        anchors.verticalCenter:parent.verticalCenter;width:parent.width
                        text:root.frameKey==="dashboard"?"SENOMY_systems / performance.dashboard":"SENOMY_systems / insights"
                        fontSizeMode:Text.HorizontalFit;minimumPixelSize:7;color:Config.DirectoryStyle.ink
                        font.family:Config.DirectoryStyle.headingFont;font.pixelSize:11
                    }
                }
                Image {x:authoredTop.labelWidth+10;y:13;width:Math.max(0,(root.narrowLayout?parent.width:cipher.x-10)-x);height:1;source:frame.artwork+"Asset 66@1.5x.png"}
                Item {
                    id:cipher;objectName:"authored-top-cipher"
                    width:866*authoredTop.artScale;height:39*authoredTop.artScale
                    x:root.narrowLayout?(parent.width-width)/2:Math.max(authoredTop.labelWidth+20,Math.min(authoredTop.width*1344/2655,authoredTop.width-width-20));y:root.narrowLayout?32:(parent.height-height)/2;clip:true
                    Text {
                        anchors.fill:parent;text:"///////////// + + + + + "+Array(31).fill("X").join(" ")
                        color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont
                        font.pixelSize:18*authoredTop.artScale;font.bold:true
                        horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
                        fontSizeMode:Text.HorizontalFit;minimumPixelSize:4
                    }
                }
                Image {visible:!root.narrowLayout;x:cipher.x+cipher.width+10;y:13;width:Math.max(0,parent.width-x);height:1;source:frame.artwork+"Asset 66@1.5x.png"}
            }
            Image {
                objectName:"authored-left-strip";x:0;y:84;width:10;height:Math.max(1,parent.height-168)
                source:frame.artwork+"Left Line@1.5x.png";fillMode:Image.PreserveAspectFit
            }
            Image {x:parent.width-1;y:84;width:1;height:Math.max(0,parent.height-168);source:frame.artwork+"Asset 65@1.5x.png"}
            Image {x:48;y:parent.height-27;width:Math.max(0,parent.width-96);height:1;source:frame.artwork+"Asset 66@1.5x.png"}
            Text {
                x:root.narrowLayout?28:root.sidebarWidth+74;y:root.narrowLayout?132:48;width:Math.max(0,parent.width-x-(root.narrowLayout?28:422))
                text:root.breadcrumb;elide:Text.ElideRight;color:Config.DirectoryStyle.dim
                font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11
            }
            Row {
                id:surfaceControls;objectName:"surface-controls"
                x:parent.width-width-28;y:root.narrowLayout?78:42;spacing:6
                DirectoryButton {
                    objectName:"switch-performance";visible:!root.narrowLayout || root.frameKey!=="dashboard";labelSize:Config.DirectoryStyle.detailSize;centered:true;width:root.narrowLayout?Math.max(90,minimumContentWidth):Math.max(148,minimumContentWidth);height:Config.DirectoryStyle.controlTarget
                    text:root.narrowLayout?"PERF":"PERFORMANCE";active:root.frameKey==="dashboard"
                    Accessible.name:"Open Performance Dashboard";onClicked:root.surfaceRequested("performance")

                }
                DirectoryButton {
                    objectName:"switch-insights";visible:!root.narrowLayout || root.frameKey!=="insights";labelSize:Config.DirectoryStyle.detailSize;centered:true;width:root.narrowLayout?Math.max(90,minimumContentWidth):Math.max(148,minimumContentWidth);height:Config.DirectoryStyle.controlTarget
                    text:"INSIGHTS";active:root.frameKey==="insights"
                    Accessible.name:"Open Senomy Insights";onClicked:root.surfaceRequested("insights")

                }
                DirectoryButton { iconOnly:true;width:root.touchMode?48:38;height:Config.DirectoryStyle.controlTarget;text:"×";Accessible.name:"Close "+root.title;onClicked:root.closeRequested() }
            }
            DirectoryButton {
                id:directoryToggle;objectName:"directory-toggle"
                x:28;y:78;width:Math.min(128,surfaceControls.x-36);height:48;visible:root.narrowLayout
                text:"MENU";active:root.directoryOpen
                Accessible.name:root.directoryOpen?"Close system directory":"Open system directory"
                onClicked:{root.directoryOpen=!root.directoryOpen;if(root.directoryOpen)drawerNavigation.focusSection();}
            }
            Row {
                x:28;y:root.narrowLayout?158:88;width:parent.width-56;height:parent.height-y-(root.narrowLayout?36:48);spacing:root.narrowLayout?0:22
                Column {
                    visible:!root.narrowLayout
                    width:root.sidebarWidth;height:parent.height;spacing:12
                    Text { text:root.title;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:13;color:Config.DirectoryStyle.ink }
                    DirectoryNavigation {
                        id:directoryNavigation
                        width:parent.width;height:Math.max(0,parent.height-76)
                        nodes:root.directoryNodes.length?root.directoryNodes:root.sections
                        activeNode:root.activeNode;telemetry:root.navigationTelemetry;touchMode:root.touchMode;restoreFocus:root.requestedOpen && root.surfaceShown && !root.narrowLayout
                        onActivated:node=>{root.nodeRequested(node);root.sectionRequested(node.route || node.id);}
                    }
                    Text { text:"S E N O M Y O S\n"+root.statusLine;color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:10;lineHeight:1.5 }
                }
                Image { visible:!root.narrowLayout;width:1;height:parent.height;source:"file://"+Quickshell.shellDir+"/../../assets/dashboads/1.5x/Asset 65@1.5x.png";opacity:0.22 }
                Item { id:body;width:Math.max(1,parent.width-(root.narrowLayout?0:root.sidebarWidth+45));height:parent.height }
            }
            Rectangle {
                id:drawer;visible:root.narrowLayout && root.directoryOpen;z:10
                x:28;y:158;width:Math.min(root.sidebarWidth+24,frame.width-56);height:frame.height-y-48
                color:"#080a0c";border.color:Config.DirectoryStyle.muted
                DirectoryNavigation {
                    id:drawerNavigation;anchors.fill:parent;anchors.margins:12
                    nodes:directoryNavigation.nodes;activeNode:root.activeNode
                    expanded:directoryNavigation.expanded;query:directoryNavigation.query
                    telemetry:root.navigationTelemetry;touchMode:root.touchMode;restoreFocus:drawer.visible
                    onActivated:node=>{root.nodeRequested(node);root.sectionRequested(node.route || node.id);root.directoryOpen=false;directoryToggle.forceActiveFocus();}
                }
            }
        }
    }
}
