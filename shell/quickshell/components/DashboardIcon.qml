import QtQuick
Text {
    property string kind: ""
    readonly property string key: kind.toLowerCase()
    text: key === "audio" ? "\uf028"
        : key === "input" ? "\uf11c"
        : key === "calendar" ? "\uf073"
        : key.indexOf("device") >= 0 ? "\uf108"
        : key === "appearance" ? "\uf53f"
        : key === "settings" ? "\uf013"
        : key.indexOf("cpu") >= 0 || key === "model" || key === "topology" ? "\uf2db"
        : key.indexOf("mem") >= 0 ? "\uf538"
        : key.indexOf("storage") >= 0 || key === "filesystem" ? "\uf0a0"
        : key.indexOf("network") >= 0 || key === "connection" ? "\uf0ac"
        : key === "power" ? "\uf0e7"
        : key === "processes" ? "\uf03a"
        : key === "benchmarks" ? "\uf080"
        : key === "host" ? "\uf233"
        : key === "system" || key === "services" ? "\uf1b2" : "\uf00a"
    font.family: "Font Awesome 7 Free Solid"
    font.weight: Font.Black
    font.pixelSize: 16
    color: "#c9c3d6"
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
