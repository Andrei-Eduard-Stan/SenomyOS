import QtQuick
import QtQuick.Window
import "../config" as Config

// Passive compact material inside SilverIslandFrame's existing contour.
// The source and transparency belong to the same skin role as the expanded Island.
Canvas {
    id: root
    property string fillKey: ""
    readonly property var localSpec: Config.Skin.registry.backgrounds && Config.Skin.registry.backgrounds[fillKey] || ({})
    readonly property var spec: localSpec.source ? localSpec
        : Config.Skin.registry.backgrounds && Config.Skin.registry.backgrounds["senomy-expanded"] || ({})
    readonly property string imageUrl: String(Config.Skin.resolve(spec.source || ""))
    property bool imageReady: false
    property string loadedUrl: ""
    antialiasing: true
    onImageUrlChanged: syncImage()
    onSpecChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onImageLoaded: { imageReady = imageUrl.length > 0 && isImageLoaded(imageUrl); requestPaint(); }
    Component.onCompleted: syncImage()
    function syncImage() {
        if (loadedUrl && loadedUrl !== imageUrl) unloadImage(loadedUrl);
        loadedUrl = imageUrl;
        imageReady = imageUrl.length > 0 && isImageLoaded(imageUrl);
        if (imageUrl && !imageReady) loadImage(imageUrl);
        requestPaint();
    }
    Connections {
        target: Config.DirectoryStyle
        function onHighContrastChanged() { root.requestPaint(); }
    }
    onPaint: {
        const c = getContext("2d"); c.reset();
        const left = 1, top = 1, right = width - 1, bottom = height - 1;
        const cut = Math.max(0, Math.min(7, (right-left)/2, (bottom-top)/2));
        c.beginPath(); c.moveTo(cut,top); c.lineTo(right-cut,top);
        c.lineTo(right,cut); c.lineTo(right,bottom-cut); c.lineTo(right-cut,bottom);
        c.lineTo(cut,bottom); c.lineTo(left,bottom-cut); c.lineTo(left,cut); c.closePath(); c.clip();
        if (Config.DirectoryStyle.highContrast) {
            c.fillStyle = Config.QuickPanelStyle.surface; c.fillRect(left,top,right-left,bottom-top); return;
        }
        if (imageReady) {
            const iw = probe.implicitWidth || 850, ih = probe.implicitHeight || 350;
            const scale = spec.scaling === "fit" ? Math.min((right-left)/iw,(bottom-top)/ih)
                : Math.max((right-left)/iw,(bottom-top)/ih);
            c.globalAlpha = spec.imageOpacity === undefined ? 1 : spec.imageOpacity;
            c.drawImage(imageUrl,left+((right-left)-iw*scale)/2,top+((bottom-top)-ih*scale)/2,iw*scale,ih*scale);
            c.globalAlpha = spec.scrimOpacity || 0;
            c.fillStyle = Qt.rgba(Config.DirectoryStyle.glass.r,Config.DirectoryStyle.glass.g,Config.DirectoryStyle.glass.b,1);
            c.fillRect(left,top,right-left,bottom-top);
        } else {
            c.globalAlpha = 0.65;
            c.fillStyle = Qt.rgba(Config.DirectoryStyle.glass.r,Config.DirectoryStyle.glass.g,Config.DirectoryStyle.glass.b,1);
            c.fillRect(left,top,right-left,bottom-top);
        }
    }
    Image {
        id: probe
        visible: false
        source: root.imageUrl
        sourceSize: Qt.size(Math.min(4096,Math.ceil(root.width*Math.max(1,Screen.devicePixelRatio))),
                           Math.min(4096,Math.ceil(root.height*Math.max(1,Screen.devicePixelRatio))))
        onStatusChanged: root.requestPaint()
    }
}
