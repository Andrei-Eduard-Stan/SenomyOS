import QtQuick
import "../config" as Config

// One integrated selector; each segment retains a full keyboard/touch target.
Item {
    id: root
    property var choices: []
    property string value: ""
    signal chosen(string value)
    implicitHeight: Math.max(Config.QuickPanelStyle.target, measure.implicitHeight + 2*Config.DirectoryStyle.controlVerticalInset)
    FontMetrics {id:metrics;font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Config.QuickPanelStyle.metadataSize}
    Text {id:measure;visible:false;width:Math.max(1,root.width/Math.max(1,root.choices.length)-2*Config.DirectoryStyle.controlInset);text:root.choices.reduce((a,b)=>metrics.advanceWidth(a)>metrics.advanceWidth(b.label)?a:b.label,"");font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Config.QuickPanelStyle.metadataSize;font.weight:Font.DemiBold;wrapMode:Text.WordWrap}
    function focusFirst(){if(segments.count)segments.itemAt(0).forceActiveFocus();}
    Repeater {
        id: segments
        model: root.choices
        Item {
            id: segment
            required property var modelData
            required property int index
            objectName: "session-mode-"+modelData.id
            x: index*width; width:root.width/root.choices.length; height:root.height
            enabled: root.enabled && modelData.enabled !== false
            readonly property bool selected: root.value===modelData.id
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Button
            Accessible.name: modelData.label+(selected?", selected":"")
            Accessible.onPressAction: if(enabled)root.chosen(modelData.id)
            Keys.onReturnPressed: if(enabled)root.chosen(modelData.id)
            Keys.onSpacePressed: if(enabled)root.chosen(modelData.id)
            Keys.onRightPressed: if(index+1<segments.count)segments.itemAt(index+1).forceActiveFocus()
            Keys.onLeftPressed: if(index>0)segments.itemAt(index-1).forceActiveFocus()
            Rectangle {
                anchors.fill:parent
                color:"transparent"
                border.width:0;border.color:Config.QuickPanelStyle.ink
                Behavior on color {ColorAnimation {duration:Config.Motion.duration(80)}}
            }
            Text {anchors.centerIn:parent;width:Math.max(0,parent.width-2*Config.DirectoryStyle.controlInset);horizontalAlignment:Text.AlignHCenter;wrapMode:Text.WordWrap;text:segment.modelData.label;font.weight:segment.selected?Font.DemiBold:Font.Normal;color:Config.QuickPanelStyle.ink;opacity:segment.enabled?1:0.4;font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Config.QuickPanelStyle.metadataSize}
            ButtonHoverFrame { focusTarget: segment; pointerTarget: hover; selected: segment.selected; anchors.fill: parent; engaged: segment.enabled && hover.containsMouse }
            MouseArea {id:hover;anchors.fill:parent;hoverEnabled:true;cursorShape:segment.enabled?Qt.PointingHandCursor:Qt.ArrowCursor;onClicked:if(segment.enabled){segment.forceActiveFocus();root.chosen(segment.modelData.id);}}
        }
    }
}
