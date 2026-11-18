import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import ".."
import "../../config" as Config

Column {
    id:root
    required property var service
    property string fileError:""
    property bool showGuide:false
    property bool showExport:false
    signal reviewRequested(string operation,var args)
    spacing:10
    function chosenFile(url) {
        const value=String(url);
        if(!value.startsWith("file:///")){fileError="Choose a file on this device.";return;}
        importPath.text=decodeURIComponent(value.slice(7));fileError="";
    }
    FileDialog {id:filePicker;title:"Import a calendar or schedule";nameFilters:["Calendar and schedule files (*.ics *.csv *.tsv)"];fileMode:FileDialog.OpenFile;onAccepted:root.chosenFile(selectedFile)}
    FileDialog {id:exportPicker;title:"Export a calendar";nameFilters:["Calendar files (*.ics)"];fileMode:FileDialog.SaveFile;defaultSuffix:"ics";onAccepted:exportPath.text=decodeURIComponent(String(selectedFile).slice(7))}
    Text {width:parent.width;text:"Bring in a calendar file, or paste rows copied from a spreadsheet. Preview first; nothing is saved until you confirm.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.muted}
    Text {text:"ADD TO";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
    ShellComboBox {id:sourceChoice;width:parent.width;model:root.service.sources;textRole:"name";Accessible.name:"Calendar to import into"}
    Text {text:"IMPORT A FILE";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:14;color:Config.DirectoryStyle.ink}
    DashboardButton {objectName:"calendar-choose-file";width:parent.width;text:"CHOOSE ICS, CSV OR TSV FILE";onClicked:filePicker.open()}
    ShellTextField {id:importPath;objectName:"calendar-transfer-path";width:parent.width;placeholderTextColor:Config.DirectoryStyle.muted;placeholderText:"Or enter a file path…";Accessible.name:"Calendar or schedule file path"}
    Text {visible:root.fileError.length>0;width:parent.width;text:root.fileError;wrapMode:Text.WordWrap;color:Config.Theme.warning;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
    DashboardButton {objectName:"calendar-import-preview";width:parent.width;text:"PREVIEW FILE IMPORT";enabled:root.service.available&&!root.service.busy&&sourceChoice.currentIndex>=0&&importPath.text.trim().length>0;onClicked:root.reviewRequested("importPreview",{source:sourceChoice.model[sourceChoice.currentIndex].id,path:importPath.text})}
    Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
    Text {text:"PASTE A LIST";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:14;color:Config.DirectoryStyle.ink}
    Text {width:parent.width;text:"Copy a header and rows from a spreadsheet, or paste CSV. Required columns: date, title. Dates use YYYY-MM-DD; optional times use HH:MM.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.muted}
    TextArea {
        id:batch;objectName:"calendar-batch-text";width:parent.width;height:160
        placeholderTextColor:Config.DirectoryStyle.muted;placeholderText:"date,title,start,end,notes,link\nPaste your schedule here…"
        textFormat:TextEdit.PlainText;wrapMode:TextEdit.Wrap;selectByMouse:true;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;Accessible.name:"Bulk schedule: CSV or spreadsheet rows"
        background:Rectangle {color:Config.Theme.glassRaised;border.width:batch.activeFocus?1:0;border.color:Config.DirectoryStyle.ink}
    }
    Row {
        width:parent.width;spacing:6
        DashboardButton {objectName:"calendar-batch-preview";width:(parent.width-6)/2;text:"PREVIEW LIST";enabled:root.service.available&&!root.service.busy&&sourceChoice.currentIndex>=0&&batch.text.trim().length>0;onClicked:root.reviewRequested("batchPreview",{source:sourceChoice.model[sourceChoice.currentIndex].id,data:batch.text})}
        DashboardButton {width:(parent.width-6)/2;text:"CLEAR LIST";enabled:!root.service.busy&&batch.text.length>0;onClicked:batch.clear()}
    }
    DashboardButton {width:parent.width;text:root.showGuide?"HIDE FORMAT GUIDE":"FORMAT GUIDE & AUTOMATION";onClicked:root.showGuide=!root.showGuide}
    Column {
        visible:root.showGuide;width:parent.width;spacing:8
        Text {width:parent.width;text:"Up to 200 rows / 24 KiB per list. Start/end blank means all day. Use kind=note for a dated note (notes required, no times). Optional columns: notes, link, location, reminder, repeat, count, interval, end_date. Set reminder=none to turn it off; otherwise the new-event default is used. Repeat accepts DAILY, WEEKLY, MONTHLY or YEARLY. Identical rows are skipped when imported again.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.muted}
        TextArea {width:parent.width;height:110;readOnly:true;selectByMouse:true;text:"Example format (replace with your own dates and details):\ndate,title,start,end,notes,link\n2026-10-20,Planning,09:00,10:00,Discuss next steps,https://example.org\n\nAutomation: senomy-calendar-batch < schedule.csv\nTo save: senomy-calendar-batch --confirm < schedule.csv";textFormat:TextEdit.PlainText;wrapMode:TextEdit.Wrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;background:Rectangle {color:Config.Theme.glassRaised}}
    }
    DashboardButton {width:parent.width;text:root.showExport?"HIDE EXPORT":"EXPORT A CALENDAR";onClicked:root.showExport=!root.showExport}
    Column {
        visible:root.showExport;width:parent.width;spacing:8
        Text {width:parent.width;text:"Export all event and note contents in the selected calendar as an ICS file. Existing files require an overwrite review.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.muted}
        DashboardButton {width:parent.width;text:"CHOOSE EXPORT LOCATION";onClicked:exportPicker.open()}
        ShellTextField {id:exportPath;objectName:"calendar-export-path";width:parent.width;placeholderTextColor:Config.DirectoryStyle.muted;placeholderText:"calendar.ics";Accessible.name:"ICS export destination"}
        DashboardButton {objectName:"calendar-export-review";width:parent.width;text:"REVIEW EXPORT";enabled:root.service.available&&!root.service.busy&&sourceChoice.currentIndex>=0&&exportPath.text.trim().length>0;onClicked:root.reviewRequested("exportPreview",{source:sourceChoice.model[sourceChoice.currentIndex].id,path:exportPath.text})}
    }
}
