import QtQuick
import Quickshell
import "." as UI
import "../config" as Config

// The fill and authored outline share one fixed chamfer. Canvas clipping works
// in software and GPU renderers; no rectangular image or shader-mask fallback.
UI.CathedralPopupFrame {
    id:root
    frameKey:"control";active:true;animate:false
    backdropColor:"transparent";stateColor:"transparent"
    backgroundItem.visible:false
    readonly property var backgroundSpec:Config.Skin.registry.backgrounds && Config.Skin.registry.backgrounds["senomy-expanded"] || ({})
    readonly property string imageUrl:String(Config.Skin.resolve(backgroundSpec.source || ""))
    onImageUrlChanged:fill.syncImage()
    onBackgroundSpecChanged:fill.requestPaint()
    Canvas {
        id:fill;parent:root;anchors.fill:parent;z:-1;antialiasing:true
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        Component.onCompleted:syncImage()
        function syncImage(){if(root.imageUrl)loadImage(root.imageUrl);requestPaint();}
        onImageLoaded:requestPaint()
        Connections {target:Config.DirectoryStyle;function onHighContrastChanged(){fill.requestPaint();}}
        onPaint:{
            const c=getContext("2d");c.reset();
            const inset=root.perimeterInset,cut=Math.max(0,Math.min(root.perimeterCorner/2,(width-2*inset)/2,(height-2*inset)/2));
            const l=inset,t=inset,r=width-inset,b=height-inset;
            c.beginPath();c.moveTo(l+cut,t);c.lineTo(r-cut,t);c.lineTo(r,t+cut);c.lineTo(r,b-cut);c.lineTo(r-cut,b);c.lineTo(l+cut,b);c.lineTo(l,b-cut);c.lineTo(l,t+cut);c.closePath();c.clip();
            if(Config.DirectoryStyle.highContrast){c.fillStyle=Config.QuickPanelStyle.surface;c.fillRect(l,t,r-l,b-t);return;}
            if(root.imageUrl && isImageLoaded(root.imageUrl)) {
                // Native QML Image supplies bounded dimensions for aspect geometry.
                const iw=probe.implicitWidth || 850,ih=probe.implicitHeight || 350;
                const scale=root.backgroundSpec.scaling==="fit"?Math.min((r-l)/iw,(b-t)/ih):Math.max((r-l)/iw,(b-t)/ih);
                c.globalAlpha=root.backgroundSpec.imageOpacity===undefined?1:root.backgroundSpec.imageOpacity;
                c.drawImage(root.imageUrl,l+((r-l)-iw*scale)/2,t+((b-t)-ih*scale)/2,iw*scale,ih*scale);
                c.globalAlpha=root.backgroundSpec.scrimOpacity || 0;c.fillStyle=Qt.rgba(Config.DirectoryStyle.glass.r,Config.DirectoryStyle.glass.g,Config.DirectoryStyle.glass.b,1);c.fillRect(l,t,r-l,b-t);
            }else{c.globalAlpha=0.65;c.fillStyle=Qt.rgba(Config.DirectoryStyle.glass.r,Config.DirectoryStyle.glass.g,Config.DirectoryStyle.glass.b,1);c.fillRect(l,t,r-l,b-t);}
        }
    }
    Image {id:probe;parent:root;visible:false;source:root.imageUrl;sourceSize:Qt.size(850,350);onStatusChanged:fill.requestPaint()}
}
