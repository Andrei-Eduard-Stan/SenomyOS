import QtQuick
import "../config" as Config

Rectangle {
    id: root
    property string frameKey: "card"

    property string title: ""
    property string value: ""
    property string detail: ""
    property color valueColor: Config.Theme.foreground

    implicitWidth: 210
    implicitHeight: 112
    radius: 0
    color: artBackground ? Qt.rgba(10/255,12/255,15/255,0.38*(legacySpec.opacity === undefined ? 1 : legacySpec.opacity)) : Config.Theme.glassRaised
    border.width: 0
    border.color: Qt.rgba(Config.Theme.muted.r, Config.Theme.muted.g, Config.Theme.muted.b, 0.24)

    readonly property var legacySpec: Config.Skin.frame(frameKey)
    readonly property bool artBackground: Config.Skin.mode(legacySpec) === "art" && legacyProbe.status === Image.Ready
    // Probe availability only; legacy decorative frames are never stacked.
    Image { id:legacyProbe; visible:false; source:Config.Skin.resolve(legacySpec.source || ""); sourceSize:Qt.size(4,4) }
    DashboardBorder { anchors.fill: parent }

    SurfaceBackground { anchors.fill: parent; anchors.margins: 5; fillKey: root.frameKey }

    Column {
        anchors.fill: parent
        anchors.leftMargin: (legacySpec.contentPadding || {}).left || (root.height < 90 ? 10 : 16)
        anchors.rightMargin: (legacySpec.contentPadding || {}).right || (root.height < 90 ? 10 : 16)
        anchors.topMargin: root.height < 90 ? 8 : ((legacySpec.contentPadding || {}).top || 16)
        anchors.bottomMargin: root.height < 90 ? 8 : ((legacySpec.contentPadding || {}).bottom || 16)
        spacing: root.height < 90 ? 3 : 7

        Text {
            width: parent.width
            text: root.title.toUpperCase()
            textFormat: Text.PlainText
            color: Config.Theme.dim
            font.family: Config.DirectoryStyle.headingFont
            font.pixelSize: 10
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.value
            textFormat: Text.PlainText
            color: root.valueColor
            font.family: Config.DirectoryStyle.valueFont
            font.pixelSize: 18
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.detail
            textFormat: Text.PlainText
            color: Config.Theme.muted
            font.family: Config.DirectoryStyle.dataFont
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
}
