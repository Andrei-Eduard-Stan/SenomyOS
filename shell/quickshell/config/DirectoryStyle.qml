pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id:root
    // Shared operational row anatomy; artwork caps remain owned by Skin.
    // Feedback geometry and its content safe zone share the same measurements.
    readonly property real controlFrameInset: 6
    readonly property real controlFrameCorner: 5
    readonly property int controlInset: Math.ceil((controlFrameInset + controlFrameCorner + controlGap) / 4) * 4
    readonly property real controlVerticalInset: controlFrameInset + controlGap / 2
    function frameInsetFor(width, height) {
        return Math.min(controlFrameInset, Math.max(0.5, Math.min(width, height) / 6));
    }
    function frameCornerFor(width, height) {
        const inset = frameInsetFor(width, height);
        return Math.min(controlFrameCorner, Math.max(0, width / 2 - inset), Math.max(0, height / 2 - inset));
    }
    function contentInsetFor(width, height) {
        return Math.ceil((frameInsetFor(width, height) + frameCornerFor(width, height) + controlGap) / 4) * 4;
    }
    readonly property int controlGap: 8
    readonly property int sectionGap: 20
    readonly property int controlTarget: touchMode ? 48 : 44
    property bool touchMode:false
    readonly property string headingFont: "Bruno Ace SC"
    readonly property string bodyFont: "sans-serif"
    readonly property real textScale: (Skin.registry.persona || {}).uiTextScale || 1
    readonly property bool highContrast: (Skin.registry.persona || {}).highContrast === true
    readonly property int bodySize: Math.round((touchMode ? 16 : 14)*textScale)
    readonly property int detailSize: Math.round((touchMode ? 14 : 13)*textScale)
    readonly property string dataFont: Theme.fontFamily
    readonly property string valueFont: "Audiowide"
    readonly property color ink: highContrast ? "#ffffff" : Theme.foreground
    readonly property color muted: highContrast ? "#d6d9e0" : "#b7bac3"
    readonly property color dim: highContrast ? "#b7bcc7" : "#9298a4"
    readonly property color rule: Qt.rgba(ink.r, ink.g, ink.b, highContrast ? 0.4 : 0.13)
    readonly property color selection: Qt.rgba(ink.r, ink.g, ink.b, 0.09)
    readonly property color glass: highContrast ? "#080a0c" : "#fc080a0c"
    FileView {
        path:Quickshell.env("SENOMY_PROFILE") || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME")+"/.config")+"/senomyos/profile.json"
        watchChanges:true
        printErrors:false
        onFileChanged:reload()
        onLoaded:{try{const profile=JSON.parse(text());root.touchMode=profile.schema_version===1 && (Boolean((profile.capabilities || {}).touch_preferred) || (profile.appearance || {}).font_scale==="touch");}catch(error){root.touchMode=false;}}
        onLoadFailed:root.touchMode=false
    }
}
