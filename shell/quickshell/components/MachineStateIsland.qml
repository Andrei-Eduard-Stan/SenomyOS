import QtQuick
import QtQuick.Controls
import Quickshell
import "../config" as Config

SenomyFrame {
    id: root
    required property var senomy
    required property var metrics
    property bool performanceOpen: false
    property bool insightsOpen: false
    property bool expanded: false
    property bool compact: false
    property bool ultraCompact: false
    property bool microCompact: false
    property bool hoverExpansionEnabled: false
    readonly property bool pointerHovered: wholeHover.hovered
    readonly property bool hoverCharging: hoverExpansionEnabled && pointerHovered && !expanded
        && !(Config.Skin.registry.persona && Config.Skin.registry.persona.hoverExpansionEnabled === false)
    property real hoverProgress: 0
    signal hoverExpandRequested()
    onHoverChargingChanged: {
        hoverCharge.stop();
        hoverProgress = 0;
        if (hoverCharging) hoverCharge.start();
    }
    NumberAnimation {
        id: hoverCharge
        target: root; property: "hoverProgress"
        from: 0; to: 1; duration: 1000
        onFinished: if (root.hoverCharging) root.hoverExpandRequested()
    }
    signal togglePerformance()
    signal toggleInsights()
    signal toggleExpanded()
    width: microCompact ? 138 : ultraCompact ? 178 : compact ? 238 : 360
    height: Config.Theme.islandHeight
    frameKey: ""
    fillKey: "senomy-rail"
    railBackground: true
    borderType: "none"
    fullHeightFrame: true
    nativeFrameEnabled: false
    active: performanceOpen
    visualState: senomy.state === "critical" ? "critical" : senomy.attentionState === "warning" ? "warning" : active ? "active" : hovered ? "hover" : "normal"
    hovered: wholeHover.hovered || activeFocus
    HoverHandler { id: wholeHover; parent: root }
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Open System Dashboard. " + senomy.message
    Keys.onUpPressed: root.toggleExpanded()
    Keys.onEscapePressed: if (root.expanded) root.toggleExpanded()
    Keys.onSpacePressed: root.togglePerformance()
    Keys.onReturnPressed: root.togglePerformance()

    // Presentation mode is derived; never clears/replaces the health resolver.
    readonly property bool messagePreview: expanded
    readonly property bool smallLayout: width < 280
    readonly property int textSize: Math.max(10, Math.min(16, Config.Skin.registry.persona && Config.Skin.registry.persona.railTextPx || 12))
    readonly property real portraitSize: height - 10
    readonly property real portraitCenterX: portrait.x + portrait.width / 2
    readonly property real sideWidth: Math.max(0, (width - portraitSize) / 2 - 10)
    readonly property bool showSmallMetrics: width >= 170
    readonly property bool touchLayout: Config.DirectoryStyle.touchMode
    readonly property real arrowSlotWidth: touchLayout ? 48 : 24
    readonly property real arrowEdgeInset: touchLayout ? 8 : 14
    readonly property bool singleArrow: touchLayout && width < 260
    readonly property real messageLeftInset: arrowEdgeInset + (singleArrow ? 0 : arrowSlotWidth) + 8
    readonly property real messageRightInset: arrowEdgeInset + arrowSlotWidth + 8


    Canvas {
        parent: root
        anchors.fill: parent
        z: -1
        property bool messageMode: root.messagePreview
        onMessageModeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset();
            const w = width - 1, h = height - 1, cut = 7;
            c.beginPath(); c.moveTo(cut, 1); c.lineTo(w-cut, 1);
            c.lineTo(w, cut); c.lineTo(w, h-cut); c.lineTo(w-cut,h);
            c.lineTo(cut,h); c.lineTo(1,h-cut); c.lineTo(1,cut); c.closePath();
            const metal = c.createLinearGradient(0,0,w,h);
            metal.addColorStop(0,"#f4f1ff"); metal.addColorStop(.3,"#62616d");
            metal.addColorStop(.65,"#aaa6b6"); metal.addColorStop(1,"#f4f1ff");
            c.strokeStyle = metal; c.lineWidth = 1; c.stroke();
            c.strokeStyle = "#45444e";
            for (let side of (root.messagePreview ? [] : [0,1])) {
                const start = side === 0 ? 32 : w/2 + root.portraitSize/2 + 6;
                const end = side === 0 ? w/2 - root.portraitSize/2 - 6 : w-32;
                if (end > start) { c.beginPath(); c.moveTo(start,h/2); c.lineTo(end,h/2); c.stroke(); }
            }
        }
    }
    SilverIslandFrame {
        id: collapsedGlow
        objectName: "senomy-collapsed-reflective-frame"
        parent: root
        anchors.fill: parent
        z: -1
        glowOnly: true
        hoverGlow: true
        hovered: root.enabled && !root.messagePreview && root.hovered
    }
    Text {
        parent: root
        objectName: "senomy-message-preview"
        visible: root.messagePreview
        x: root.messageLeftInset; y: 8
        width: Math.max(0, parent.width - x - root.messageRightInset); height: parent.height - 16
        clip: true
        text: root.senomy.message
        color: root.senomy.state === "critical" ? Config.Theme.danger
            : root.senomy.attentionState === "warning" ? Config.Theme.warning : Config.Theme.foreground
        font.family: "Audiowide"
        font.pixelSize: root.textSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }
    // Full-allocation coordinates: the chevron must never shift the portrait.
    Item {
        parent: root
        anchors.fill: parent
        opacity: root.messagePreview ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Config.Motion.duration(160) } }
        Image {
            source: "file://" + Quickshell.shellDir + "/../../assets/senomy_island_expanded/lockinthosefirst/SVG/senomy avatar pfp.svg"
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(width * 2, height * 2)
            mipmap: true
            id: portrait
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: root.portraitSize; height: width
        }
        Column {
            x: 22; y: 0
            width: Math.max(0, root.sideWidth - 22)
            spacing: 0
            visible: !root.smallLayout || root.showSmallMetrics
            Repeater {
                model: root.smallLayout ? ["CPU"] : ["CPU", "RAM"]
                Text {
                    required property string modelData
                    width: parent.width
                    height: root.smallLayout ? root.height : root.height / 2
                    verticalAlignment: Text.AlignVCenter
                    text: modelData + " " + (modelData === "CPU"
                        ? (root.metrics.ready ? Math.round(root.metrics.cpuPercent) + "%" : "—")
                        : (root.metrics.memoryTotalKib > 0 ? Math.round(root.metrics.memoryPercent) + "%" : "—"))
                    color: Config.Theme.foreground
                    font.family: "Audiowide"
                    font.pixelSize: Math.min(root.textSize, 10)
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
            }
        }
        Column {
            x: (root.width + root.portraitSize) / 2 + 10; y: 0
            width: Math.max(0, root.sideWidth - 22)
            spacing: 0
            visible: !root.smallLayout || root.showSmallMetrics
            Repeater {
                model: root.smallLayout ? ["RAM"] : ["TEMP", "UP"]
                Text {
                    required property string modelData
                    width: parent.width
                    height: root.smallLayout ? root.height : root.height / 2
                    verticalAlignment: Text.AlignVCenter
                    text: modelData + " " + (modelData === "RAM"
                        ? (root.metrics.memoryTotalKib > 0 ? Math.round(root.metrics.memoryPercent) + "%" : "—")
                        : modelData === "TEMP" ? (root.metrics.temperatureAvailable ? Math.round(root.metrics.temperatureCelsius) + "°C" : "—")
                        : (root.metrics.uptimeDetailedLabel || root.metrics.uptimeLabel || "—"))
                    color: Config.Theme.foreground
                    font.family: "Audiowide"
                    font.pixelSize: Math.min(root.textSize, 10)
                    elide: Text.ElideRight
                }
            }
        }

    }
    MetalSheen { parent: root; anchors.fill: parent; anchors.margins: 1; idleMotion:false; engaged:false; strength:1+1.2*collapsedGlow.glow }
    MouseArea {
        id: pointer
        parent: root
        z: 1
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePerformance()
    }
    Repeater {
        model: root.singleArrow ? [true] : [false, true]
        delegate: Item {
            id: arrowSlot
            required property bool modelData
            parent: root
            z: 2
            objectName: modelData ? "senomy-expand-right" : "senomy-expand-left"
            x: modelData ? root.width - width - root.arrowEdgeInset : root.arrowEdgeInset
            width: root.arrowSlotWidth; height: root.height
            activeFocusOnTab: true
            Keys.onReturnPressed: root.toggleExpanded()
            Keys.onSpacePressed: root.toggleExpanded()
            ExpansionChevrons {
                anchors.fill: parent
                revealed: root.pointerHovered || root.expanded || root.activeFocus || arrowSlot.activeFocus
                reducedMotion: !!Config.Skin.registry.persona && Config.Skin.registry.persona.reducedMotion === true
            }
            // Arrow regions keep touch and pointer activation without a label.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleExpanded()
            }
            Accessible.role: Accessible.Button
            Accessible.name: root.expanded ? "Collapse Senomy context" : "Expand Senomy context"
            Accessible.onPressAction: root.toggleExpanded()
        }
    }
}
