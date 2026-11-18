import QtQuick
import QtQuick.Controls
import ".."
import "../../config" as Config
Column {
    id:root
    required property var audio
    required property var media
    property string route:"overview"
    property bool directoryNavigation:false
    property bool recordingMode:false
    signal directionRequested(bool recording)
    readonly property bool compactNavigation:height<480
    readonly property bool reviewing:audio.selectionActions.actionState==="pending" || !!(audio.graphActions && audio.graphActions.actionState==="pending")
    onRouteChanged:{if(audio.selectionActions.actionState==="pending")audio.selectionActions.cancel();if(audio.graphActions && audio.graphActions.actionState==="pending")audio.graphActions.cancel();}
    signal deviceManagementRequested()
    width:parent.width;height:parent.height;spacing:10
    Flow {
        visible:!root.directoryNavigation && !root.compactNavigation
        width:parent.width;spacing:4
        Repeater {model:["overview","mixer","devices","media","diagnostics"];delegate:DashboardButton {required property string modelData;width:root.width<560?(root.width-8)/3:(root.width-16)/5;height:48;text:modelData.toUpperCase();active:root.route===modelData;onClicked:{if(root.audio.selectionActions.actionState==="pending")root.audio.selectionActions.cancel();if(root.audio.graphActions && root.audio.graphActions.actionState==="pending")root.audio.graphActions.cancel();root.route=modelData;}}}
    }
    ShellComboBox {visible:!root.directoryNavigation && root.compactNavigation;width:parent.width;model:["OVERVIEW","MIXER","DEVICES","MEDIA","DIAGNOSTICS"];currentIndex:["overview","mixer","devices","media","diagnostics"].indexOf(root.route);Accessible.name:"Audio section";onActivated:index=>root.route=["overview","mixer","devices","media","diagnostics"][index]}
    FocusScrollArea {
        width:parent.width;visible:root.audio.selectionActions.actionState!=="idle" || !!(root.audio.graphActions && root.audio.graphActions.actionState!=="idle");height:Math.min(review.implicitHeight,Math.max(0,root.height-(root.compactNavigation && root.reviewing?68:160)));contentHeight:review.implicitHeight
        ScrollBar.vertical:ShellScrollBar {}
        AudioActionReview {id:review;width:parent.width;audio:root.audio}
    }
    Loader {
        width:parent.width;visible:!(root.compactNavigation && root.reviewing);height:visible?Math.max(0,parent.height-y):0;sourceComponent:root.route==="mixer"?mixer:root.route==="devices"?devices:root.route==="media"?mediaView:root.route==="diagnostics"?diagnostics:overview
    }
    Component {id:overview;AudioOverviewPage {audio:root.audio}}
    Component {id:mixer;AudioMixerPage {audio:root.audio;property bool requestedRecording:root.recordingMode;onRequestedRecordingChanged:recording=requestedRecording;Component.onCompleted:recording=requestedRecording;onDirectionRequested:recording=>root.directionRequested(recording)}}
    Component {id:devices;AudioDevicesPage {audio:root.audio;onDeviceManagementRequested:root.deviceManagementRequested()}}
    Component {id:mediaView;FocusScrollArea {width:parent.width;height:parent.height;contentHeight:mediaBody.implicitHeight;ScrollBar.vertical:ShellScrollBar {}AudioMediaPage {id:mediaBody;media:root.media}}}
    Component {id:diagnostics;AudioDiagnosticsPage {audio:root.audio}}
}
