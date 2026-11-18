import QtQuick
import QtQuick.Window
import "../config" as Config

// A single source texture is shared by clipped cells. Unlike BorderImage's
// read-only sourceSize, Image lets SVG rasterization follow display density.
// Fixed centre bands protect crests WITHOUT requiring additional art files.
Item {
    id: root
    property var spec: ({})
    property string visualState: "normal"
    property url sourceOverride: ""
    property bool requested: true
    readonly property string normalSource: String(sourceOverride).length > 0 ? String(sourceOverride) : Config.Skin.resolve(spec.source || "")
    readonly property string stateSource: spec.variants && spec.variants[visualState]
        ? Config.Skin.resolve(spec.variants[visualState]) : normalSource
    readonly property bool variantFailed: stateProbe.status === Image.Error
    readonly property string selectedSource: variantFailed ? normalSource : stateSource
    readonly property real logicalWidth: (spec.logicalSize || [width, height])[0]
    readonly property real logicalHeight: (spec.logicalSize || [width, height])[1]
    readonly property bool fit: spec.scaling === "fit"
    readonly property var xs: bands(logicalWidth, width, spec.insets && spec.insets.left || 0,
        spec.insets && spec.insets.right || 0, spec.fixedCenterWidth || 0)
    readonly property var ys: bands(logicalHeight, height, spec.insets && spec.insets.top || 0,
        spec.insets && spec.insets.bottom || 0, spec.fixedCenterHeight || 0)
    readonly property bool valid: logicalWidth > 0 && logicalHeight > 0 && (fit || (xs.length > 0 && ys.length > 0))
    readonly property bool ready: requested && valid && probe.status === Image.Ready
    readonly property real density: Math.max(1, Screen.devicePixelRatio)
    // Bound memory while avoiding rerasterization during width animations.
    readonly property real rasterScale: Math.min(density, 4096 / Math.max(logicalWidth, logicalHeight))
    readonly property var cells: {
        const result = [];
        if (!fit) for (const y of ys) for (const x of xs) result.push({x:x, y:y});
        return result;
    }
    opacity: spec.opacity === undefined ? 1 : spec.opacity
    visible: ready
    function bands(sourceLength, targetLength, first, last, center) {
        const middle = sourceLength - first - last;
        if (middle <= center || targetLength < first + last + center || first < 0 || last < 0 || center < 0) return [];
        const source = center > 0 ? [first, (middle-center)/2, center, (middle-center)/2, last] : [first, middle, last];
        const targetMiddle = targetLength-first-last;
        const target = center > 0 ? [first,(targetMiddle-center)/2,center,(targetMiddle-center)/2,last] : [first,targetMiddle,last];
        let s=0, d=0; const result=[];
        for(let i=0;i<source.length;i++) {
            if(source[i]>0 && target[i]>0) result.push({source:s, size:source[i], dest:d, length:target[i]});
            s+=source[i];d+=target[i];
        }
        return result;
    }
    Image {
        id: stateProbe
        visible: false
        source: root.requested ? root.stateSource : ""
        sourceSize: Qt.size(Math.ceil(root.logicalWidth*root.rasterScale), Math.ceil(root.logicalHeight*root.rasterScale))
        asynchronous: true
    }
    Image {
        id: probe
        anchors.fill: parent
        visible: root.fit
        source: root.requested ? root.selectedSource : ""
        sourceSize: stateProbe.sourceSize
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        onStatusChanged: if (status === Image.Error) console.warn("Frame unavailable; native fallback: " + source)
    }
    Repeater {
        model: root.ready && !root.fit ? root.cells : []
        delegate: Item {
            required property var modelData
            x: modelData.x.dest; y: modelData.y.dest
            width: modelData.x.length; height: modelData.y.length
            clip: true
            Image {
                source: probe.source
                sourceSize: probe.sourceSize
                x: -modelData.x.source * modelData.x.length / modelData.x.size
                y: -modelData.y.source * modelData.y.length / modelData.y.size
                width: root.logicalWidth * modelData.x.length / modelData.x.size
                height: root.logicalHeight * modelData.y.length / modelData.y.size
                fillMode: Image.Stretch
            }
        }
    }
}
