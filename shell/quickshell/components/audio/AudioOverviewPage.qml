import QtQuick
import QtQuick.Controls
import ".."
import "../../config" as Config
FocusScrollArea {
    id:root
    required property var audio
    property bool meterRequested:false
    readonly property var observedInput:audio.source || null
    onObservedInputChanged:meterRequested=false
    onVisibleChanged:if(!visible)meterRequested=false
    width:parent.width;height:parent.height;contentHeight:body.implicitHeight
    ScrollBar.vertical:ShellScrollBar {}
    Column {
        id:body;width:parent.width;spacing:Config.DirectoryStyle.sectionGap
        Column {width:parent.width;spacing:Config.DirectoryStyle.controlGap
        AudioLabel {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:"Output";font.pixelSize:Config.DirectoryStyle.bodySize+2;font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
        AudioLabel {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:root.audio.outputName}
        AudioVolumeControl {objectName:"control-output-volume";width:parent.width;audio:root.audio;showNumeric:true}
        }
        Column {width:parent.width;spacing:Config.DirectoryStyle.controlGap
        AudioLabel {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:"Microphone";font.pixelSize:Config.DirectoryStyle.bodySize+2;font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
        AudioLabel {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:root.audio.inputName}
        AudioVolumeControl {objectName:"control-microphone-volume";width:parent.width;audio:root.audio;input:true;showNumeric:true}
        AudioLabel {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:"Default microphone mute affects this endpoint only. Other physical or virtual sources may still record."}
        AudioLabel {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:typeof root.audio.recordingCount==="number"?root.audio.recordingCount+" actively linked recording stream(s) · inspect Recording in Mixer":"Recording activity unavailable"}
        DashboardButton {width:Math.min(parent.width,Math.ceil(minimumContentWidth));centered:false;text:root.meterRequested?"Stop microphone test":"Test microphone level";enabled:root.audio.inputAvailable && root.audio.nativeMetering===true;onClicked:root.meterRequested=!root.meterRequested}
        Loader {width:parent.width;active:root.meterRequested && root.visible && root.audio.inputAvailable && root.audio.nativeMetering===true;sourceComponent:AudioInputMeter {width:parent.width;node:root.audio.source}}
        }
        Rectangle {width:parent.width;height:1;color:"#28ffffff"}
        Column {
            width:parent.width;spacing:Config.DirectoryStyle.controlGap
        ShellCheckBox {width:parent.width;visible:root.audio.preferences!==undefined;text:"Allow amplification up to 150%";checked:root.audio.amplification===true;enabled:root.audio.preferenceBusy!==true;onToggled:root.audio.setPreference("amplification",checked)}
        AudioLabel {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;visible:root.audio.amplification===true;text:"Amplification can clip and distort. Disabling it limits future changes to 100%; an existing external level is not silently changed."}
        AudioLabel {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;visible:root.audio.preferenceMessage!==undefined && root.audio.preferenceMessage.length>0;text:root.audio.preferenceMessage || ""}
        }
        AudioLabel {width:parent.width;visible:root.audio.preferences!==undefined && (root.audio.preferences.routes || []).length>0;text:"REMEMBERED APP ROUTES · apply from Mixer";color:"#ffffff"}
        Repeater {
            model:root.audio.preferences?(root.audio.preferences.routes || []):[]
            delegate:Column {
                required property var modelData;width:body.width;spacing:4
                AudioLabel {width:parent.width;text:modelData.appKey+" · "+modelData.direction+" → "+modelData.endpointName}
                DashboardButton {width:parent.width;text:"FORGET THIS ROUTE";enabled:root.audio.preferenceBusy!==true;onClicked:root.audio.forgetRule(modelData)}
            }
        }
    }
}
