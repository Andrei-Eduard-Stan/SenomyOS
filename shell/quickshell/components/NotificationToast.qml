import QtQuick
import QtQuick.Window
import "interaction" as Interaction
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../config" as Config
import "DirectoryFrameGeometry.js" as FrameGeometry

PanelWindow {
    id: root

    required property var targetScreen
    required property var notifications
    readonly property var sessionService: notifications.sessionService || null
    readonly property bool showCommitment: !!(sessionService && sessionService.schedule.state === "scheduled" && sessionService.remainingSeconds <= 60 && (!notifications.dnd || sessionService.remainingSeconds <= 10))
    property bool placementEnabled: false
    // Only admitted generations may replace the presented record. DND still
    // updates history/latest, without changing an already visible toast.
    property var presentedNotification:null
    property bool shown: false
    readonly property bool toastShown: presentation.shown
    readonly property bool requestedPresentation:placementEnabled && (showCommitment || (notifications.serverEnabled && presentedNotification!==null && shown))
    Interaction.NativePresentation {id:presentation;targetItem:frame;requested:root.requestedPresentation;suppressed:!root.placementEnabled;focusOnReady:false}
    Interaction.ContentMotion {targetItem:toastContent;context:String(root.presentedNotification?root.presentedNotification.id:"")+":"+String(root.presentedNotification?root.presentedNotification.receivedAt:"");active:root.shown}

    screen: targetScreen
    visible: requestedPresentation || presentation.retained
    implicitWidth: Math.max(1, Math.min(430, (targetScreen ? targetScreen.width : 430) - 2 * Config.Theme.screenInset))
    readonly property real workHeight: Math.max(1, (targetScreen ? targetScreen.height : 600) - Config.Theme.railHeight - 2 * Config.Theme.screenInset)
    implicitHeight: Math.min(workHeight,showCommitment?Math.max(220,commitmentContent.implicitHeight+2*frame.contentInset+64):Math.min(500,Math.max(190,toastContent.implicitHeight+actionFooter.implicitHeight+2*frame.contentInset+72)))
    color: "transparent"
    exclusiveZone: 0
    aboveWindows: true

    anchors {
        right: true
        top: true
    }
    margins {
        right: Config.Theme.screenInset
        top: Config.Theme.screenInset
    }

    WlrLayershell.namespace: "senomy-v2-notification-toast"
    WlrLayershell.layer: Config.OskGeometry.floatingOn(targetScreen) ? WlrLayer.Top : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask:DirectoryFrameMask {frameItem:frame;rectangles:!root.requestedPresentation?[]:FrameGeometry.regions([FrameGeometry.chamfer(frame.perimeterInset,frame.perimeterInset,root.width-2*frame.perimeterInset,root.height-2*frame.perimeterInset,frame.perimeterCorner/2)],root.width,root.height)}

    Connections {
        target: root.notifications
        function onToastGenerationChanged() {
            if (root.notifications.latest && !root.notifications.dnd) {
                root.presentedNotification=root.notifications.latest;
                root.shown = true;
                hideTimer.restart();
            }
        }
    }

    Timer {
        id: hideTimer
        interval: root.presentedNotification && root.presentedNotification.urgency === "Critical" ? 12000 : 6000
        onTriggered: root.shown = false
    }

    IslandPopupFrame {
        id:frame;objectName:"toast-frame";anchors.fill:parent;frameKey:"notification-toast";active:true;animate:false
        contentInset:Config.QuickPanelStyle.inset;perimeterCorner:Config.QuickPanelStyle.corner
        backgroundItem.visible:!root.showCommitment
        backdropColor:root.showCommitment?Config.QuickPanelStyle.surface:Config.DirectoryStyle.glass
        Canvas {parent:frame;anchors.fill:parent;z:-0.5;visible:root.showCommitment;antialiasing:true
            property color ink:Config.QuickPanelStyle.surface
            onInkChanged:requestPaint();onWidthChanged:requestPaint();onHeightChanged:requestPaint();onVisibleChanged:if(visible)requestPaint()
            onPaint:{const c=getContext("2d");c.reset();const i=frame.perimeterInset,k=frame.perimeterCorner/2,r=width-i,b=height-i;c.beginPath();c.moveTo(i+k,i);c.lineTo(r-k,i);c.lineTo(r,i+k);c.lineTo(r,b-k);c.lineTo(r-k,b);c.lineTo(i+k,b);c.lineTo(i,b-k);c.lineTo(i,i+k);c.closePath();c.fillStyle=ink;c.fill();}
        }
        opacity:presentation.progress
        transform:Translate {x:(1-presentation.progress)*Config.Motion.travel}
        enabled:root.requestedPresentation
        FocusScrollArea {
            visible:root.showCommitment;width:parent.width;height:Math.max(0,parent.height-sessionFooter.height-12);contentHeight:commitmentContent.implicitHeight
            ScrollBar.vertical:ShellScrollBar {}
            ScheduleCommitment {id:commitmentContent;objectName:"final-session-warning";width:parent.width;service:root.sessionService;notification:true;managementVisible:false;finalWarning:root.sessionService && root.sessionService.remainingSeconds<=10}
        }
        Row {id:sessionFooter;visible:root.showCommitment;anchors.bottom:parent.bottom;width:parent.width;spacing:8;height:Config.DirectoryStyle.controlTarget
            QuietButton {objectName:"final-session-cancel";width:Math.floor((parent.width-8)/2);text:"Cancel";enabled:!!root.sessionService && !root.sessionService.busy;accessibleLabel:"Cancel the scheduled session action";onClicked:root.sessionService.cancelSchedule()}
            QuietButton {width:Math.floor((parent.width-8)/2);text:"Open session";onClicked:root.notifications.openSessionRequested()}
        }
        Item {id:toastHeader;visible:!root.showCommitment;width:parent.width;height:Config.DirectoryStyle.controlTarget
            Text {width:Math.max(1,parent.width-hide.width-12);anchors.verticalCenter:parent.verticalCenter;text:root.presentedNotification?root.presentedNotification.appName+(root.presentedNotification.urgency==="Critical"?" · Critical":""):"Notification";textFormat:Text.PlainText;color:root.presentedNotification&&root.presentedNotification.urgency==="Critical"?Config.Theme.danger:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;elide:Text.ElideRight}
            QuietButton {id:hide;objectName:"toast-hide";anchors.right:parent.right;width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:"\uf00d";accessibleLabel:"Hide notification";onClicked:root.shown=false}
        }
        IslandRule {visible:!root.showCommitment;y:toastHeader.height+8;width:parent.width;leadingPoint:false}
        FocusScrollArea {
            id:toastViewport;visible:!root.showCommitment;objectName:"toast-content";y:toastHeader.height+24;width:parent.width;height:Math.max(0,parent.height-y-(actionViewport.visible?actionViewport.height+16:0));contentHeight:toastContent.implicitHeight
            ScrollBar.vertical:ShellScrollBar {}
            Column {id:toastContent;width:parent.width-12;spacing:12
                Text {width:parent.width;text:root.presentedNotification?root.presentedNotification.summary:"";textFormat:Text.PlainText;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(18*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;wrapMode:Text.WordWrap}
                Text {width:parent.width;text:root.presentedNotification?root.presentedNotification.body:"";textFormat:Text.PlainText;visible:text.length>0;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;wrapMode:Text.WordWrap}
            }
        }
        FocusScrollArea {id:actionViewport;objectName:"toast-actions-viewport";visible:!root.showCommitment && toastActions.count>0;anchors.bottom:parent.bottom;width:parent.width;height:Math.min(actionFooter.implicitHeight,Math.max(Config.DirectoryStyle.controlTarget,parent.height*.52));contentHeight:actionFooter.implicitHeight
            ScrollBar.vertical:ShellScrollBar {}
        Flow {id:actionFooter;width:parent.width-12;spacing:8
            Repeater {id:toastActions;model:root.presentedNotification && (typeof root.notifications.isLive!=="function" || root.notifications.isLive(root.presentedNotification))?root.presentedNotification.actions || []:[]
                QuietButton {id:actionCommand;required property var modelData;objectName:"toast-action-"+(modelData.identifier || "action");width:Math.floor((parent.width-8)/2);height:Math.max(Config.DirectoryStyle.controlTarget,labelProbe.implicitHeight+20);Text {id:labelProbe;visible:false;width:Math.max(1,actionCommand.width-2*Config.DirectoryStyle.controlInset);text:actionCommand.text;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:Text.WordWrap}text:modelData.text || modelData.identifier || "Action";wrapLabel:true;onClicked:{if(typeof root.notifications.isLive==="function" && !root.notifications.isLive(root.presentedNotification))return;root.notifications.invoke(root.presentedNotification,modelData);root.shown=false;}}
            }
        }
        }
    }
}
