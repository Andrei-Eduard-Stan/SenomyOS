import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "config" as Config
Window {
    id:fixture
    width:480;height:500;visible:true;color:"#08090b"
    property int selections:0
    property int numericEdits:0
    property int toggles:0
    property int trayActivations:0
    property int traySecondary:0
    TestCase {id:input;when:false}
    ShellSurfaceFrame {
        id:frame;anchors.fill:parent;frameKey:"notification-toast"
        Column {
            width:parent.width;spacing:14
            ShellComboBox {id:combo;width:parent.width;model:Array.from({length:40},(_,i)=>"Choice "+i);Accessible.name:"Fixture dropdown";onActivated:fixture.selections++}
            ShellSpinBox {id:number;width:parent.width;from:-50;to:100;value:25;editable:true;Accessible.name:"Fixture number";onValueModified:fixture.numericEdits++}
            ShellTextField {id:path;width:parent.width;placeholderText:"Fixture input";Accessible.name:"Fixture path"}
            ShellCheckBox {id:check;width:parent.width;text:"Readable checkbox label";onToggled:fixture.toggles++}
            TrayItemButton {id:tray;parentWindow:fixture;trayItem:({status:1,tooltipTitle:"Fixture tray",title:"Fixture",id:"fixture",icon:"",tooltipDescription:"",hasMenu:false,onlyMenu:false,activate:function(){fixture.trayActivations++;},secondaryActivate:function(){fixture.traySecondary++;},scroll:function(){}})}
            DashboardButton {id:disabled;width:parent.width;text:"DISABLED FIXTURE ACTION";enabled:false;onClicked:{throw new Error("Disabled action fired");}}
        }
    }
    function verify(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
    function capture(name){let done=false;fixture.contentItem.grabToImage(function(result){result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;});while(!done)input.wait(10);}
    Timer {running:true;interval:500;onTriggered:{
        fixture.capture("native-controls");
        combo.forceActiveFocus();input.keyClick(Qt.Key_Space);input.wait(60);fixture.verify(combo.popup.visible,"keyboard opens dropdown");fixture.capture("native-dropdown");
        input.keyClick(Qt.Key_End);input.keyClick(Qt.Key_Return);input.wait(60);fixture.verify(combo.currentIndex===39 && fixture.selections===1,"dropdown selects final offscreen choice exactly once");
        number.forceActiveFocus();input.keyClick(Qt.Key_Up);input.wait(30);fixture.verify(number.value===26 && fixture.numericEdits===1,"numeric keyboard increment emits modified once");
        number.contentItem.forceActiveFocus();number.contentItem.selectAll();input.keyClick("4");input.keyClick("2");input.keyClick(Qt.Key_Return);input.wait(60);fixture.verify(number.value===42 && fixture.numericEdits===2,"editable numeric value commits once");
        path.forceActiveFocus();for(const character of "fixture/path.png")input.keyClick(character);fixture.verify(path.text==="fixture/path.png","text input edits normally");
        check.forceActiveFocus();input.keyClick(Qt.Key_Space);fixture.verify(check.checked && fixture.toggles===1,"keyboard toggles checkbox once");
        input.mouseClick(check);fixture.verify(!check.checked && fixture.toggles===2,"pointer toggles checkbox once");
        tray.forceActiveFocus();input.keyClick(Qt.Key_Return);input.keyClick(Qt.Key_Space);fixture.verify(fixture.trayActivations===2,"tray keyboard activation path");
        input.mouseClick(tray,tray.width/2,tray.height/2,Qt.RightButton);fixture.verify(fixture.traySecondary===1,"tray secondary activation fallback");
        fixture.width=320;input.wait(80);fixture.capture("native-controls-narrow");
        Config.DirectoryStyle.touchMode=true;input.wait(80);fixture.capture("native-controls-touch");Config.DirectoryStyle.touchMode=false;
        console.log("PASS: styled dropdown, offscreen choice selection, numeric editing, text input, checkbox keyboard/pointer and disabled gates; fixture controls only");Qt.quit();
    }}
}
