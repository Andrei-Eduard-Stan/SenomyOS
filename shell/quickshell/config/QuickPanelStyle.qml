pragma Singleton
import QtQuick

// Functional-panel roles recovered from the Rail and System Overview.
// Theme remains generated from appearance/tokens.json; these compose its roles.
QtObject {
    readonly property color surface: Theme.surface
    readonly property color ink: DirectoryStyle.ink
    readonly property color secondary: DirectoryStyle.muted
    readonly property color rule: DirectoryStyle.rule
    readonly property string headingFont: DirectoryStyle.headingFont
    readonly property string bodyFont: DirectoryStyle.bodyFont
    readonly property string dataFont: DirectoryStyle.dataFont
    readonly property string valueFont: DirectoryStyle.valueFont
    readonly property int metadataSize: Math.round(11 * DirectoryStyle.textScale)
    readonly property int bodySize: DirectoryStyle.bodySize
    readonly property int deviceSize: Math.round(15 * DirectoryStyle.textScale)
    readonly property int titleSize: Math.round(18 * DirectoryStyle.textScale)
    readonly property int valueSize: Math.round(30 * DirectoryStyle.textScale)
    readonly property int unit: 4
    readonly property int inset: 24
    readonly property int gap: 12
    readonly property int sectionGap: 20
    readonly property int target: DirectoryStyle.touchMode ? 48 : 44
    readonly property int preferredWidth: DirectoryStyle.touchMode ? 456 : 432
    readonly property int corner: 24
    readonly property int openMs: Motion.compactMs
}
