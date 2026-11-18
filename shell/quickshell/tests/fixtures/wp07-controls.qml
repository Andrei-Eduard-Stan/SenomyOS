import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtTest
import Quickshell
import "../../components" as Components
import "../../config" as Config

Window {
    id:fixture
    visible:true;width:440;height:640
    property int clicks:0
    property int failures:0
    TestCase {id:input;when:false}
    Column {
        anchors.fill:parent;spacing:12
        Components.ShellButton {id:button;text:"Open settings";width:200;onClicked:fixture.clicks++}
        Components.ShellCheckBox {id:check;width:180;text:"Keep this longer accessibility preference readable when text is enlarged and the available Settings column is narrow."}
        Components.ShellSpinBox {id:spin;width:200;from:0;to:100;value:20;Accessible.name:"Fixture amount"}
        Components.ShellComboBox {id:combo;width:200;model:["One","Two","Three"];Accessible.name:"Fixture choice"}
        Components.FocusScrollArea {
            id:scroll;width:300;height:100;contentHeight:400
            Components.ShellTextField {id:lastField;y:300;width:240;Accessible.name:"Last field"}
        }
    }
    function checkResult(ok,message){if(!ok){failures++;console.error("FAIL: "+message);}else console.log("PASS: "+message);}
    Timer {
        interval:300;running:true
        onTriggered:{
            button.forceActiveFocus();input.keyClick(Qt.Key_Enter);input.wait(20);
            fixture.checkResult(fixture.clicks===1,"keypad Enter activates shared button once");
            fixture.clicks=0;input.keyClick(Qt.Key_Return);input.keyClick(Qt.Key_Space);
            fixture.checkResult(fixture.clicks===2 && button.activeFocus && button.border.width>0,"Return/Space and visible focus remain functional");
            button.enabled=false;input.keyClick(Qt.Key_Enter);fixture.checkResult(fixture.clicks===2,"disabled button cannot activate");button.enabled=true;
            Config.DirectoryStyle.touchMode=true;
            Config.Skin.registry=Object.assign({},Config.Skin.registry,{persona:{uiTextScale:1.5,reducedMotion:true,highContrast:true}});
            input.wait(60);
            fixture.checkResult(check.height>=check.contentItem.implicitHeight+check.topPadding+check.bottomPadding,"wrapped large-text checkbox reserves its full label height");
            fixture.checkResult(spin.up.indicator.width>=Config.Theme.touchTarget && spin.down.indicator.width>=Config.Theme.touchTarget,"both spinbox step targets meet the shared target size");
            fixture.checkResult(Config.Motion.duration(250)===0 && Config.DirectoryStyle.textScale===1.5 && Config.DirectoryStyle.highContrast,"reduced motion and readability policy are applied in memory only");
            combo.forceActiveFocus();input.keyClick(Qt.Key_Space);input.wait(40);
            fixture.checkResult(combo.popup.visible,"combo opens with keyboard");
            input.keyClick(Qt.Key_Down);input.keyClick(Qt.Key_Return);input.wait(40);
            fixture.checkResult(!combo.popup.visible && combo.currentIndex===1 && combo.activeFocus,"combo keyboard selection closes deepest popup and returns focus");
            combo.forceActiveFocus();input.keyClick(Qt.Key_Space);input.wait(20);input.keyClick(Qt.Key_Escape);input.wait(40);
            fixture.checkResult(!combo.popup.visible && combo.activeFocus,"nested Escape preserves combo focus");
            lastField.forceActiveFocus();input.wait(40);
            fixture.checkResult(scroll.contentY>200 && lastField.activeFocus,"keyboard-focused field is revealed by shared scroller");
            console.log("RESULT: shared controls "+fixture.failures+" failures; private in-memory preferences only");
            Qt.exit(fixture.failures?1:0);
        }
    }
}
