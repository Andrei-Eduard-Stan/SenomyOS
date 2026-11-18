import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
Window {
    id: test;visible:true;width:400;height:160;color:"black"
    TestCase {id:input;when:false}
    DirectoryMetric {id:metric;anchors.fill:parent;title:"CPU";value:"17%";detail:"Fixture / no system collectors"}
    property int phase:0
    property var menu:null
    Timer {
        interval:100;repeat:true;running:true
        onTriggered:{
            if(test.phase===0){
                test.phase=-1;const button=input.findChild(metric,"report-menu-cpu");test.menu=button.parent;
                input.mouseClick(button,16,16);input.wait(30);
                const popup=input.findChild(metric,"component-report-popup");
                if(popup)input.tryVerify(()=>popup.opened,1000);
                if(!popup || !popup.opened){console.error("FAIL: three-dot menu must open");Qt.exit(1);return;}
                popup.close();test.menu.run("text");test.phase=1;
            } else if(!test.menu.busy && test.phase===1){
                if(!test.menu.status.startsWith("Saved ")){console.error("FAIL: text export "+test.menu.status);Qt.exit(1);return;}
                test.menu.run("snapshot");test.phase=2;
            } else if(!test.menu.busy && test.phase===2){
                if(!test.menu.status.endsWith(".png")){console.error("FAIL: PNG export "+test.menu.status);Qt.exit(1);return;}
                test.menu.run("copy");test.phase=3;
            } else if(!test.menu.busy && test.phase===3){
                if(test.menu.status!=="Component report copied"){console.error("FAIL: clipboard "+test.menu.status);Qt.exit(1);return;}
                console.log("PASS: actual three-dot menu, text export, component PNG capture and mocked clipboard");Qt.quit();
            }
        }
    }
}
