pragma Singleton

import QtQuick

QtObject {
    readonly property color background: "#08090b"
    readonly property color surface: "#0a0c0f"
    readonly property color surfaceRaised: "#0f1115"
    readonly property color surfaceHover: "#161922"
    readonly property color foreground: "#f1f1f4"
    readonly property color muted: "#92959f"
    readonly property color dim: "#666a74"
    readonly property color accent: "#9892e8"
    readonly property color cyan: "#7ec8e3"
    readonly property color amber: "#e6b86a"
    readonly property color danger: "#e47d87"
    readonly property color success: "#83c99a"

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int railHeight: 64
    readonly property int islandHeight: 56
    readonly property int screenInset: 20
    readonly property int islandGap: 22
    readonly property int compactCorner: 16
    readonly property int touchTarget: 48
}
