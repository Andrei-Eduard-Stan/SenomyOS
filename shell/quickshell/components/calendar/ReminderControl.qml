import QtQuick
import QtQuick.Controls
import ".."
import "../../config" as Config
import "CalendarFormat.js" as Format
Column {
    id: root
    property string text: ""
    property string fieldObjectName: "reminder"
    property bool custom: false
    property bool syncing: false
    readonly property var presets: ["", "0", "5", "10", "15", "30", "60", "1440", "10080"]
    readonly property var factors: [1,60,1440,10080]
    readonly property bool valid: text==="" || (/^\d+$/.test(text) && Number(text)<=10080)
    spacing: 6
    function load() {
        if(syncing)return;
        const value=Format.reminder(text);if(value!==text){text=value;return;}
        custom=!presets.includes(text);
        syncing=true;
        let unit=0;
        if(/^\d+$/.test(text)&&Number(text)>0)for(let i=3;i>0;i--)if(Number(text)%factors[i]===0){unit=i;break;}
        units.currentIndex=unit;amount.text=/^\d+$/.test(text)?String(Number(text)/factors[unit]):text;
        syncing=false;
    }
    function updateValue(){if(syncing)return;syncing=true;text=/^\d+$/.test(amount.text)?String(Number(amount.text)*factors[units.currentIndex]):amount.text||"invalid";syncing=false;}
    function focusInput(){if(custom)amount.forceActiveFocus();else preset.forceActiveFocus();}
    onTextChanged:load()
    Component.onCompleted:load()
    ShellComboBox {
        id:preset;objectName:root.fieldObjectName+"-preset";width:parent.width
        model:["No reminder","At the start","5 minutes before","10 minutes before","15 minutes before","30 minutes before","1 hour before","1 day before","1 week before","Custom amount…"]
        currentIndex:root.custom?9:Math.max(0,root.presets.indexOf(root.text))
        Accessible.name:"Remind me before"
        onActivated:{if(currentIndex<9){root.custom=false;root.text=root.presets[currentIndex];}else{root.custom=true;if(!amount.text||!/^\d+$/.test(amount.text))amount.text="20";root.updateValue();Qt.callLater(()=>amount.forceActiveFocus());}}
    }
    Flow {
        visible:root.custom;width:parent.width;spacing:6
        ShellTextField {id:amount;objectName:root.fieldObjectName+"-amount";width:parent.width<280?parent.width:Math.max(80,(parent.width-6)*0.4);placeholderText:"Amount";inputMethodHints:Qt.ImhDigitsOnly;maximumLength:6;Accessible.name:"Reminder amount";onTextEdited:root.updateValue()}
        ShellComboBox {id:units;objectName:root.fieldObjectName+"-unit";width:parent.width<280?parent.width:(parent.width-6)*0.6;model:["Minutes before","Hours before","Days before","Weeks before"];Accessible.name:"Reminder unit";onActivated:root.updateValue()}
    }
    Text {visible:root.custom;width:parent.width;text:"Choose a whole amount up to 1 week before the start.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
}
