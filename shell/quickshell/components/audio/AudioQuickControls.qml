import QtQuick
import "../interaction" as Interaction
import QtQuick.Controls
import ".."
import "../../config" as Config

Column {
    id: root
    Interaction.ContentMotion {targetItem:deviceChoices;context:String(root.chooserOpen);active:root.mediaActive}
    required property var audio
    property var media: null
    property bool mediaActive:visible
    property var viewport:null
    readonly property real muteWidth:Math.max(148,Math.ceil(muteMeasure.advanceWidth)+24+2*Config.DirectoryStyle.controlInset)
    TextMetrics {id:muteMeasure;text:"Unmute mic";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
    // Preserve direct choice when several endpoints exist.
    property bool chooserOpen: audio.outputNodes.length > 1 || audio.inputNodes.length > 1
    readonly property bool hasChoices: audio.outputNodes.length > 1 || audio.inputNodes.length > 1
    signal openAudioRequested()
    width: parent.width
    spacing: Config.QuickPanelStyle.sectionGap

    QuickAudioChannel { width: parent.width; audio: root.audio;muteWidth:root.muteWidth }
    Rectangle { width: parent.width; height: 1; color: Config.QuickPanelStyle.rule }
    QuickAudioChannel { width: parent.width; audio: root.audio; input: true;muteWidth:root.muteWidth }
    Rectangle {width:parent.width;height:1;color:Config.QuickPanelStyle.rule}
    AudioQuickMedia {width:parent.width;media:root.media;active:root.mediaActive;viewport:root.viewport}
    Flow {
        id:footer
        width: parent.width
        spacing: Config.QuickPanelStyle.gap
        readonly property bool stacked:root.hasChoices && width < devices.implicitWidth+settings.implicitWidth+spacing
        AudioButton {
            id:devices
            objectName: "quickAudioDevices"
            visible: root.hasChoices
            width:footer.stacked ? parent.width : (parent.width - parent.spacing) / 2
            height:Config.DirectoryStyle.controlTarget
            text: root.chooserOpen ? "Hide devices" : "Devices"
            glyph:"\uf390"
            accessibleLabel: root.chooserOpen ? "Hide audio devices" : "Show audio devices"
            active: false
            onClicked: root.chooserOpen = !root.chooserOpen
        }
        AudioButton {
            id:settings
            objectName: "quickAudioSettings"
            width: root.hasChoices && !footer.stacked ? (parent.width - parent.spacing) / 2 : parent.width
            height:Config.DirectoryStyle.controlTarget
            text: "Audio Settings"
            glyph:"\uf013"
            onClicked: root.openAudioRequested()
        }
    }
    AudioActionReview { width: parent.width; audio: root.audio; visible: height > 0 }
    Column {
        id:deviceChoices
        width: parent.width
        visible: root.chooserOpen && root.hasChoices
        spacing: 8
        Text {
            visible: root.audio.outputNodes.length > 1
            text: "OUTPUT DEVICES"
            color: Config.QuickPanelStyle.secondary
            font.family: Config.QuickPanelStyle.headingFont
            font.pixelSize: Math.max(12, Config.QuickPanelStyle.metadataSize)
        }
        Repeater {
            model: root.chooserOpen && root.audio.outputNodes.length > 1 ? root.audio.outputNodes : []
            delegate: QuickAudioDevice { required property var modelData; width: parent.width; audio: root.audio; node: modelData }
        }
        Text {
            visible: root.audio.inputNodes.length > 1
            text: "INPUT DEVICES"
            color: Config.QuickPanelStyle.secondary
            font.family: Config.QuickPanelStyle.headingFont
            font.pixelSize: Math.max(12, Config.QuickPanelStyle.metadataSize)
        }
        Repeater {
            model: root.chooserOpen && root.audio.inputNodes.length > 1 ? root.audio.inputNodes : []
            delegate: QuickAudioDevice { required property var modelData; width: parent.width; audio: root.audio; node: modelData; input: true }
        }
    }
}
