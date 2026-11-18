import QtQuick
import "calendar" as CalendarUi
import "../config" as Config
Column {
    id: root
    property alias text: field.text
    property string label: ""
    property int maximum: 59
    signal edited()
    spacing: 2
    function focusInput(){field.forceActiveFocus();}
    function increment(step){field.text=String(Math.max(0,Math.min(maximum,Number(field.text||0)+step))).padStart(2,"0");edited();}
    CalendarUi.CalendarTextField {
        id: field; objectName:root.objectName+"-input"; width: parent.width; text: "00"; maximumLength: root.maximum>99?3:2
        implicitHeight:Math.max(Config.DirectoryStyle.controlTarget,contentHeight+2*Config.DirectoryStyle.controlVerticalInset)
        topPadding:Config.DirectoryStyle.controlVerticalInset;bottomPadding:Config.DirectoryStyle.controlVerticalInset
        verticalAlignment:TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        validator: IntValidator {bottom:0;top:root.maximum}
        inputMethodHints: Qt.ImhDigitsOnly
        Accessible.name: "Countdown " + root.label
        font.family: Config.QuickPanelStyle.dataFont; font.pixelSize: Math.round(24*Config.DirectoryStyle.textScale)
        onTextEdited: root.edited()
        Keys.onUpPressed: root.increment(1)
        Keys.onDownPressed: root.increment(-1)
    }
    Text {width:parent.width;text:root.label;horizontalAlignment:Text.AlignHCenter;font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.QuickPanelStyle.secondary}
    Row {
        width: parent.width
        visible:width>=2*Config.DirectoryStyle.controlTarget
        QuietButton {width:parent.width/2;height:Config.QuickPanelStyle.target;text:"−";accessibleLabel:"Decrease countdown "+root.label;onClicked:root.increment(-1)}
        QuietButton {width:parent.width/2;height:Config.QuickPanelStyle.target;text:"+";accessibleLabel:"Increase countdown "+root.label;onClicked:root.increment(1)}
    }
}
