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
    property bool requestedOpen: false
    readonly property bool compactNativeVisible: !!contentItem.Window.window && contentItem.Window.window.visible
        && (typeof root.backingWindowVisible === "undefined" || root.backingWindowVisible)
    property string title: "SENOMYOS"
    property string eyebrow: "SYSTEM SURFACE"
    property var sections: []
    property var navigationNodes: []
    property string searchQuery:""
    property string activeNode: "overview"
    signal nodeRequested(var node)
    property string activeSection: ""
    property int preferredWidth: 960
    property int preferredHeight: 720
    property string motif: "identity"
    property string frameKey: "insights"
    property real anchorCenterX: targetScreen ? targetScreen.width / 2 : preferredWidth / 2
    readonly property int sidebarWidth: Math.round(260 * Config.DirectoryStyle.textScale)
    readonly property bool reducedMotion: ((Config.Skin.registry.persona || {}).reducedMotion === true)
    property bool fullSettings: false
    signal modeRequested(bool full)
    readonly property bool narrowLayout: (fullSettings ? settingsNative.width : width) < 850 * Config.DirectoryStyle.textScale
    property alias nativeSettingsWindow: settingsNative
    property bool settingsGeometryInitialized: false
    property int settingsPreferredWidth:1200
    property int settingsPreferredHeight:860
    property int settingsRestoredWidth:0
    property int settingsRestoredHeight:0
    function rememberSettingsGeometry() {
        if(settingsGeometryInitialized && settingsGeometryReady && !settingsMaximized && settingsNative.width>0 && settingsNative.height>0) {
            settingsRestoredWidth=settingsNative.width;settingsRestoredHeight=settingsNative.height;
        }
    }
    // Qt can retain an obsolete maximised flag after a compositor rule changes
    // the first configure. Read the owned native toplevel on Hyprland instead.
    readonly property bool hasHyprland: Boolean(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
    property var settingsToplevel: null
    function refreshSettingsToplevel() {
        settingsToplevel=Hyprland.toplevels.values.find(t =>
            t.title === "SenomyOS Settings" && Number(t.lastIpcObject.pid) === Quickshell.processId) || null;
    }
    readonly property bool settingsMaximized: settingsToplevel
        ? (Number(settingsToplevel.lastIpcObject.fullscreen) & 1) !== 0
        : (!hasHyprland && settingsNative.maximized)
    onSettingsToplevelChanged: if(settingsNative.visible)prepareSettingsGeometry()
    function setSettingsMaximized(value) {
        if(!hasHyprland) { settingsNative.maximized=Boolean(value);return true; }
        refreshSettingsToplevel();
        if(!settingsToplevel || !Hyprland.usingLua)return false;
        const address=String(settingsToplevel.lastIpcObject.address || "");
        if(!/^0x[0-9a-f]+$/i.test(address))return false;
        if(settingsMaximized === Boolean(value))return true;
        if(value)rememberSettingsGeometry();
        const state=value ? 1 : 0;
        Hyprland.dispatch('hl.dsp.window.fullscreen_state({window="address:'+address+'",internal='+state+',client='+state+',action="set"})');
        settingsStateRefresh.restart();return true;
    }
    function requestSettingsReadback() {
        // Native open/fullscreen events omit PID and complete window state.
        if(hasHyprland)Hyprland.refreshToplevels();
        settingsStateRefresh.restart();
    }
    Timer { id:settingsStateRefresh;interval:150;onTriggered:root.refreshSettingsToplevel() }
    Connections {
        target:Hyprland
        function onRawEvent(event) {
            if(root.fullSettings && /^(openwindow|closewindow|windowtitle|fullscreen)/.test(event.name))
                root.requestSettingsReadback();
        }
    }
    property bool settingsPrepared:false
    property bool settingsGeometryReady:false
    property size settingsOpeningSize:Qt.size(1280,860)
    function prepareSettingsOpen() {
        if(!fullSettings || !requestedOpen)return;
        if(!settingsNative.visible){
            settingsGeometryReady=false;
            settingsGeometryInitialized=false;
            settingsOpeningSize=Qt.size(Math.round(Math.min(settingsRestoredWidth || settingsPreferredWidth,workWidth)),Math.round(Math.min(settingsRestoredHeight || settingsPreferredHeight,workHeight)));
            settingsNative.implicitWidth=settingsOpeningSize.width;
            settingsNative.implicitHeight=settingsOpeningSize.height;
        }
        settingsPrepared=true;
    }
    onFullSettingsChanged: {
        if(fullSettings)prepareSettingsOpen();
        else {rememberSettingsGeometry();settingsPrepared=false;}
    }
    onWorkWidthChanged: if(settingsNative.visible)prepareSettingsGeometry()
    onWorkHeightChanged: if(settingsNative.visible)prepareSettingsGeometry()
    function prepareSettingsGeometry() {
        const window=settingsNative.contentItem.Window.window;
        if(!window || !settingsGeometryReady || settingsMaximized || (hasHyprland && !settingsToplevel))return;
        const width=Math.round(Math.min(window.width,workWidth));
        const height=Math.round(Math.min(window.height,workHeight));
        if(width===window.width && height===window.height)return;
        // Only an observed work-area shrink may resize an already mapped window.
        if(hasHyprland){
            const address=String(settingsToplevel.lastIpcObject.address || "");
            if(Hyprland.usingLua && /^0x[0-9a-f]+$/i.test(address))
                Hyprland.dispatch('hl.dsp.window.resize({window="address:'+address+'",x='+width+',y='+height+',relative=false})');
        }else{window.width=width;window.height=height;}
    }

    function ownsEscape() {
        const content = fullSettings ? settingsNative.contentItem : root.contentItem;
        return requestedOpen && content.Window.window && content.Window.window.active;
    }
    function focusWorkspace() {
        if(fullSettings) activateSettings();
        else surface.forceActiveFocus(Qt.OtherFocusReason);
    }
    function activateSettings() {
        prepareSettingsOpen();
        if (fullSettings && requestedOpen && !settingsNative.visible) {
            settingsNative.visible = false;
            settingsNative.visible = Qt.binding(() => root.fullSettings && !presentation.suppressed && root.settingsPrepared && (root.requestedOpen || presentation.retained));
        }
        if(settingsNative.minimized)settingsNative.minimized=false;
        const window=settingsNative.contentItem.Window.window;
        if(window)window.requestActivate();
    }
    function restoreSettingsVisibility() {
        prepareSettingsOpen();
        // 0.3.2 FloatingWindow can retain wantsVisible=true after its backing
        // QWindow closes. Reassigning true alone cannot change that target.
        // Reset only the already-hidden native intent before restoring binding.
        if (!settingsNative.visible) settingsNative.visible = false;
        settingsNative.visible = Qt.binding(() => root.fullSettings && !presentation.suppressed && root.settingsPrepared && (root.requestedOpen || presentation.retained));
        if (fullSettings && requestedOpen) activateSettings();
    }
    function repairPresentation() {
        Children.dismiss(surface);
        if (!compactNativeVisible) root.visible = false;
        root.visible = Qt.binding(() => !root.fullSettings && !presentation.suppressed && (root.requestedOpen || presentation.retained));
        restoreSettingsVisibility();
        if (requestedOpen) focusWorkspace();
    }
    Connections {
        target: root.interactionCoordinator
        ignoreUnknownSignals: true
        function onRecoveryRequested() { Qt.callLater(root.repairPresentation); }
    }
    FloatingWindow {
        id: settingsNative
        visible: root.fullSettings && !presentation.suppressed && root.settingsPrepared && (root.requestedOpen || presentation.retained)
        onVisibleChanged: {
            if(visible) {
                root.requestSettingsReadback();
            } else root.rememberSettingsGeometry();
        }
        title: "SenomyOS Settings"
        screen: root.targetScreen
        color: "transparent"
        implicitWidth: Math.min(root.settingsRestoredWidth || root.preferredWidth, root.workWidth)
        implicitHeight: Math.min(root.settingsRestoredHeight || root.preferredHeight, root.workHeight)
        // Advertise the intended size before the compositor's initial configure.
        // Release these initial constraints on the first queued frame, then keep
        // ordinary user resize constraints. No late resize/center operation.
        minimumSize: !root.settingsGeometryReady ? root.settingsOpeningSize : Qt.size(Math.min(360,Math.max(240,root.workWidth)),Math.min(360,Math.max(240,root.workHeight)))
        maximumSize: !root.settingsGeometryReady ? root.settingsOpeningSize : Qt.size(0,0)
        Item {
            anchors.fill: parent
            z: 20
            Repeater {
                model: [Qt.LeftEdge,Qt.RightEdge,Qt.TopEdge,Qt.BottomEdge,Qt.TopEdge|Qt.LeftEdge,Qt.TopEdge|Qt.RightEdge,Qt.BottomEdge|Qt.LeftEdge,Qt.BottomEdge|Qt.RightEdge]
                MouseArea {
                    required property int modelData
                    readonly property bool horizontal: Boolean(modelData & (Qt.LeftEdge|Qt.RightEdge))
                    readonly property bool vertical: Boolean(modelData & (Qt.TopEdge|Qt.BottomEdge))
                    width: horizontal ? 8 : parent.width-16
                    height: vertical ? 8 : parent.height-16
                    x: modelData & Qt.RightEdge ? parent.width-width : horizontal ? 0 : 8
                    y: modelData & Qt.BottomEdge ? parent.height-height : vertical ? 0 : 8
                    enabled: root.fullSettings && !root.settingsMaximized
                    cursorShape: horizontal && vertical ? (Boolean(modelData & Qt.LeftEdge) === Boolean(modelData & Qt.TopEdge) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor) : horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor
                    onPressed: settingsNative.startSystemResize(modelData)
                }
            }
        }
        onClosed: {
            Children.dismiss(surface);
            root.closeRequested();
            // A dirty draft can refuse close. Restore the binding after the
            // compositor's close request so its review remains reachable.
            Qt.callLater(root.restoreSettingsVisibility);
        }
    }
    Connections {
        target:settingsNative.contentItem.Window.window
        function onFrameSwapped(){
            if(!root.fullSettings || !root.requestedOpen || !settingsNative.visible || root.settingsGeometryReady)return;
            if((settingsNative.width===root.settingsOpeningSize.width && settingsNative.height===root.settingsOpeningSize.height) || root.settingsMaximized){
                root.settingsGeometryReady=true;root.settingsGeometryInitialized=true;
            }
        }
    }
    property bool navigationOpen: false
    readonly property var navigation: narrowLayout ? drawerNav : nav
    property alias contentArea: body
    onActiveNodeChanged: if (narrowLayout)
        navigationOpen = false
    onActiveSectionChanged: if (narrowLayout)
        navigationOpen = false
    readonly property bool surfaceShown: presentation.shown
    readonly property real presentationProgress: presentation.progress
    readonly property string lifecycle: presentation.phase
    Interaction.NativePresentation {
        id: presentation
        targetItem: surface
        contentReady:!root.fullSettings || root.settingsGeometryReady
        focusOnReady:!root.interactionCoordinator || !root.interactionCoordinator.modalActive
        requested: root.requestedOpen
        onClosed: if(!root.requestedOpen){root.rememberSettingsGeometry();root.settingsPrepared=false;}
        suppressed: root.replacementOpening || !!(root.interactionCoordinator && root.interactionCoordinator.capturePaused)
    }
    Interaction.ContentMotion {id:routeMotion;targetItem:body;context:typeof root.activeNode==="string"?root.activeNode:root.activeSection;active:root.requestedOpen}
    function revealContent(){routeMotion.pulse();}
    property bool replacementOpening: false
    property alias captureItem: surface
    default property alias bodyData: body.data
    signal closeRequested
    signal sectionRequested(string section)

    screen: targetScreen
    visible: !fullSettings && !presentation.suppressed && (requestedOpen || presentation.retained)
    readonly property var nativeMonitor: targetScreen ? Hyprland.monitorFor(targetScreen) : null
    readonly property var reservations: nativeMonitor ? nativeMonitor.lastIpcObject.reserved : null
    readonly property real reservedLeft: reservations && reservations.length === 4 ? Number(reservations[0]) : 0
    readonly property real reservedTop: reservations && reservations.length === 4 ? Number(reservations[1]) : 0
    readonly property real reservedRight: reservations && reservations.length === 4 ? Number(reservations[2]) : 0
    readonly property real reservedBottom: reservations && reservations.length === 4 ? Number(reservations[3]) : Config.Theme.railHeight
    readonly property real workWidth: Math.max(1, (targetScreen ? targetScreen.width : preferredWidth) - reservedLeft - reservedRight - 40)
    readonly property real workHeight: Math.max(1, (targetScreen ? targetScreen.height : preferredHeight) - reservedTop - reservedBottom - 34)
    readonly property var fitted: Config.OskGeometry.place(targetScreen, {
        x: reservedLeft + 20,
        y: reservedTop + 17,
        width: workWidth,
        height: workHeight
    }, preferredWidth, preferredHeight, anchorCenterX)
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
        bottom: Math.max(0, (root.targetScreen ? root.targetScreen.height : root.preferredHeight) - root.reservedBottom - root.fitted.y - root.fitted.height)
    }

    WlrLayershell.namespace: "senomy-v2-primary"
    WlrLayershell.layer: Config.OskGeometry.floatingOn(targetScreen) ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.requestedOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: DirectoryFrameMask {frameItem:surface;rectangles:!root.requestedOpen?[]:FrameGeometry.regions([FrameGeometry.chamfer(frame.perimeterInset,frame.perimeterInset,root.width-2*frame.perimeterInset,root.height-2*frame.perimeterInset,frame.perimeterCorner/2)],root.width,root.height)}

    onRequestedOpenChanged: {
        if(requestedOpen && fullSettings)prepareSettingsOpen();
        if(!requestedOpen){
        Children.dismiss(surface);
        navigationOpen=false;
        }
    }

    // Control Centre persists until explicit close; quick popovers own their
    // own outside-click region and must not dismiss this workspace.
    FocusScope {
        id: surface
        FrameObserver { targetItem:surface; key:root.frameKey; contentKey:root.activeNode; requested:root.requestedOpen }
        parent: root.fullSettings ? settingsNative.contentItem : root.contentItem
        enabled: root.requestedOpen
        anchors.fill: parent
        focus: root.surfaceShown
        opacity:root.presentationProgress
        scale: 1
        transform: Translate {
            y:root.fullSettings?0:(1-root.presentationProgress)*Config.Motion.travel

        }


        Keys.onEscapePressed: {
            if(root.interactionCoordinator && (root.interactionCoordinator.activePopup || root.interactionCoordinator.modalActive)){root.interactionCoordinator.escapeOverlay();return;}
            if(root.navigation.query.length)root.navigation.query="";
            else if(root.navigationOpen){root.navigationOpen=false;menuButton.forceActiveFocus(Qt.TabFocusReason);}
            else root.closeRequested();
        }
        Keys.onPressed:event=>{if(event.modifiers & Qt.ControlModifier && event.key===Qt.Key_F){if(root.narrowLayout)root.navigationOpen=true;Qt.callLater(()=>root.navigation.focusSearch());event.accepted=true;}}

        IslandPopupFrame {
            id:frame;anchors.fill:parent;frameKey:root.frameKey;animate:false;active:true
            contentInset:Config.QuickPanelStyle.inset;perimeterCorner:Config.QuickPanelStyle.corner
            Item {
                id:persistentHeader;width:parent.width;height:Config.DirectoryStyle.controlTarget
                QuietButton {id:menuButton;objectName:"control-navigation-toggle";visible:root.narrowLayout;width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:"\uf0c9";accessibleLabel:root.navigationOpen?"Close settings navigation":"Open settings navigation";active:root.navigationOpen;onClicked:{root.navigationOpen=!root.navigationOpen;if(root.navigationOpen)drawerNav.focusSection();else menuButton.forceActiveFocus(Qt.TabFocusReason);}}
                Text {id:titleColumn;x:root.narrowLayout?menuButton.width+12:0;width:Math.max(1,windowControls.x-x-12);height:parent.height;verticalAlignment:Text.AlignVCenter;text:root.fullSettings?"// Settings":"// Control Centre";font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Config.QuickPanelStyle.titleSize;color:Config.DirectoryStyle.ink;elide:Text.ElideRight
                    MouseArea {anchors.fill:parent;enabled:root.fullSettings;onPressed:root.nativeSettingsWindow.startSystemMove();onDoubleClicked:root.setSettingsMaximized(!root.settingsMaximized)}
                }
                Row {id:windowControls;anchors.right:parent.right;spacing:8
                    QuietButton {id:modeButton;objectName:"control-mode-switch";glyph:root.fullSettings?"\uf1de":"\uf013";iconOnly:root.narrowLayout;text:root.narrowLayout?"":root.fullSettings?"Controls":"Settings";accessibleLabel:root.fullSettings?"Open compact Control Centre":"Open full Settings";width:root.narrowLayout?Config.DirectoryStyle.controlTarget:Math.max(120,implicitWidth);onClicked:root.modeRequested(!root.fullSettings)}
                    QuietButton {id:maximizeButton;objectName:"control-maximise";visible:root.fullSettings && !root.narrowLayout;width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:root.settingsMaximized?"\uf2d2":"\uf2d0";accessibleLabel:root.settingsMaximized?"Restore Settings window":"Maximise Settings window";onClicked:root.setSettingsMaximized(!root.settingsMaximized)}
                    QuietButton {id:closeButton;objectName:"control-close";width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:"\uf00d";accessibleLabel:root.fullSettings?"Close Settings":"Close Control Centre";onClicked:root.closeRequested()}
                }
            }
            IslandRule {y:persistentHeader.height+12;width:parent.width;leadingPoint:false}
            Item {
                id: routeArea
                y:persistentHeader.height+28
                width: parent.width
                height: Math.max(0, parent.height - y)
                Rectangle {
                    visible: !root.narrowLayout
                    x: root.sidebarWidth + 16
                    width: 1
                    height: parent.height
                    color: Config.DirectoryStyle.rule
                }
                ControlNavigation {
                    id: nav
                    visible: !root.narrowLayout
                    width: root.sidebarWidth
                    height: parent.height
                    hierarchical: true
                    nodes: root.navigationNodes
                    sharedQuery:root.searchQuery
                    onQueryChanged:if(root.searchQuery!==query)root.searchQuery=query
                    activeNode: root.activeNode
                    restoreFocus: root.surfaceShown && !root.narrowLayout
                    onActivated: node => root.nodeRequested(node)
                }
                Flickable {
                    id: contentViewport
                    x: root.narrowLayout ? 0 : root.sidebarWidth + 33
                    width: Math.max(1, parent.width - x)
                    height: parent.height
                    contentWidth: width
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    Item {
                        id: body
                        width: contentViewport.width
                        height: contentViewport.height
                    }
                    Connections {
                        target: contentViewport.Window.window
                        function onActiveFocusItemChanged() {
                            const item = contentViewport.Window.window.activeFocusItem;
                            if (!item)
                                return;
                            let ancestor = item;
                            while (ancestor && ancestor !== body)
                                ancestor = ancestor.parent;
                            if (ancestor !== body)
                                return;
                            if(root.narrowLayout && root.navigationOpen)root.navigationOpen=false;
                            const pos = item.mapToItem(body, 0, 0);
                            if (pos.x < contentViewport.contentX)
                                contentViewport.contentX = Math.max(0, pos.x - 8);
                            else if (pos.x + item.width > contentViewport.contentX + contentViewport.width)
                                contentViewport.contentX = Math.min(contentViewport.contentWidth - contentViewport.width, pos.x + item.width - contentViewport.width + 8);
                        }
                    }
                }
                // Route controls remain independent of any content scrolling.
                Rectangle {
                    visible: root.narrowLayout && root.navigationOpen
                    width: Math.min(300*Config.DirectoryStyle.textScale, parent.width)
                    height: parent.height
                    z: 10
                    color: Config.QuickPanelStyle.surface
                    ControlNavigation {
                        id: drawerNav
                        anchors.fill: parent
                        anchors.margins: 8
                        hierarchical: true
                    nodes: root.navigationNodes
                    sharedQuery:root.searchQuery
                    onQueryChanged:if(root.searchQuery!==query)root.searchQuery=query
                        activeNode: root.activeNode
                        restoreFocus: root.surfaceShown && root.navigationOpen
                        onActivated: node => {
                            root.navigationOpen = false;
                            root.nodeRequested(node);
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: Config.DirectoryStyle.rule
                    }
                }
            }
        }
    }
}
