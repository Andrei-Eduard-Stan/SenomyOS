import QtQuick
import QtQuick.Controls
import ".."
import "CalendarFormat.js" as Format
import "../../config" as Config
import "../../services/calendar" as CalendarState

Item {
    id:root
    // Public text is canonical ISO; invalid edits remain in the draft verbatim.
    property string text: ""
    property string dateFormat: CalendarState.Navigation.dateFormat
    property bool syncing: false
    readonly property bool valid: !!Format.iso(text,"iso")
    function syncDisplay() { if(!syncing)entry.text=Format.display(text,dateFormat); }
    function focusInput() { entry.forceActiveFocus(); }
    onTextChanged: syncDisplay()
    onDateFormatChanged: syncDisplay()
    Component.onCompleted: syncDisplay()
    property string validationMessage:""
    property string fieldObjectName:""
    property string accessibleName:"Date"
    implicitHeight:Math.max(44,Config.Theme.touchTarget)
    function parsedDate() {
        const parts=/^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
        return parts?CalendarState.Navigation.dateAt(Number(parts[1]),Number(parts[2])-1,Number(parts[3])):CalendarState.Navigation.today;
    }
    CalendarTextField {id:entry;validationMessage:root.validationMessage;objectName:root.fieldObjectName;width:Math.max(1,parent.width-50);height:parent.height;maximumLength:10;placeholderText:Format.hint(root.dateFormat);Accessible.name:root.accessibleName+", "+Format.hint(root.dateFormat);onTextEdited:{root.syncing=true;root.text=Format.iso(text,root.dateFormat)||text;root.syncing=false;}}
    DashboardButton {id:trigger;objectName:root.fieldObjectName+"-picker";anchors.right:parent.right;width:44;height:parent.height;text:"▦";accessibleLabel:"Choose "+root.accessibleName.toLowerCase()+" from calendar";onClicked:picker.show()}
    Popup {
        id:picker;objectName:root.fieldObjectName+"-picker-popup";parent:Overlay.overlay;padding:12;focus:true
        width:Math.max(1,Math.min(380,parent?parent.width-24:380));height:Math.min(pickerBody.implicitHeight+24,parent?Math.max(1,parent.height-24):500)
        closePolicy:Popup.CloseOnEscape|Popup.CloseOnPressOutside
        property date anchorDate:CalendarState.Navigation.today
        readonly property bool compact:width<(Config.DirectoryStyle.touchMode?416:356)
        readonly property int target:Config.DirectoryStyle.touchMode?56:44
        readonly property var dates: {
            const first=CalendarState.Navigation.dateAt(anchorDate.getFullYear(),anchorDate.getMonth(),compact?anchorDate.getDate():1);
            const offset=(first.getDay()-CalendarState.Navigation.weekStart+7)%7;
            return Array.from({length:compact?7:42},(_,i)=>CalendarState.Navigation.dateAt(first.getFullYear(),first.getMonth(),first.getDate()-offset+i));
        }
        function show() {
            anchorDate=root.parsedDate();const point=root.mapToItem(parent,0,0);
            x=Math.max(12,Math.min(point.x,parent.width-width-12));
            y=Math.max(12,point.y+root.height+6+height<parent.height-12?point.y+root.height+6:Math.min(point.y-height-6,parent.height-height-12));
            open();Qt.callLater(()=>previous.forceActiveFocus());
        }
        function move(amount) {const date=CalendarState.Navigation.dateAt(anchorDate.getFullYear(),anchorDate.getMonth()+(compact?0:amount),compact?anchorDate.getDate()+7*amount:1);if(CalendarState.Navigation.supported(date))anchorDate=date;}
        onClosed:trigger.forceActiveFocus()
        background:ShellSurfaceFrame {contentInset:0;perimeterCorner:16;backdropColor:Config.Theme.surfaceRaised;stateColor:"transparent";animate:picker.visible&&!((Config.Skin.registry.persona||{}).reducedMotion)}
        contentItem:FocusScrollArea {
            contentHeight:pickerBody.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
            Column {
                id:pickerBody;width:Math.max(1,parent.width-8);spacing:8
                Row {
                    width:parent.width;spacing:4
                    DashboardButton {id:previous;width:44;text:"‹";accessibleLabel:picker.compact?"Previous week":"Previous month";onClicked:picker.move(-1)}
                    Text {width:parent.width-96;height:44;text:Qt.formatDate(picker.anchorDate,picker.compact?"d MMM yyyy":"MMMM yyyy");textFormat:Text.PlainText;wrapMode:Text.WordWrap;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignHCenter;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.ink}
                    DashboardButton {width:44;text:"›";accessibleLabel:picker.compact?"Next week":"Next month";onClicked:picker.move(1)}
                }
                Row {
                    visible:!picker.compact;width:parent.width;spacing:2
                    Repeater {model:CalendarState.Navigation.weekdayNames;delegate:Text {required property string modelData;width:(pickerBody.width-12)/7;text:modelData;horizontalAlignment:Text.AlignHCenter;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:10;color:Config.DirectoryStyle.muted}}
                }
                Grid {
                    width:parent.width;columns:picker.compact?1:7;spacing:2
                    Repeater {
                        model:picker.dates
                        delegate:DashboardButton {
                            required property var modelData
                            width:picker.compact?pickerBody.width:(pickerBody.width-12)/7;height:picker.target
                            text:Qt.formatDate(modelData,picker.compact?"ddd d MMM":"d")
                            active:CalendarState.Navigation.key(modelData)===root.text
                            enabled:CalendarState.Navigation.supported(modelData)
                            accessibleLabel:Qt.formatDate(modelData,"dddd d MMMM yyyy")
                            onClicked:{root.text=CalendarState.Navigation.key(modelData);picker.close();}
                        }
                    }
                }
                DashboardButton {width:parent.width;text:"TODAY";onClicked:{root.text=CalendarState.Navigation.todayKey;picker.close();}}
            }
        }
    }
}
