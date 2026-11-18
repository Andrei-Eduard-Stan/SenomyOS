import QtQuick
import QtQuick.Window
import QtTest
import "components/lens" as Lens
Window {
    id:test;visible:true;width:500;height:300
    property int chosen:0
    TestCase {id:input;when:false}
    Lens.LensResult {id:row;width:parent.width;row:({kind:"apps",id:"app:fixture",label:"Fixture application",detail:"Fixture",icon:""});onChosen:reveal=>test.chosen+=reveal?10:1}
    function check(ok,msg){if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw Error(msg);}}
    Timer {interval:250;running:true;onTriggered:{
        const menu=input.findChild(row,"lensContextMenu");
        for(const kind of ["apps","windows","actions"]){row.row={kind:kind,label:"Fixture",detail:"Info",icon:""};input.wait(20);input.mouseClick(row,16,16,Qt.RightButton);input.wait(30);test.check(!menu.opened,"no inert metadata-only menu for "+kind);}
        row.row={kind:"files",id:"file:fixture",label:"Fixture file",info:"/tmp/fixture.txt",icon:""};input.wait(20);input.mouseClick(row,16,16,Qt.RightButton);input.wait(30);input.tryVerify(()=>menu.opened,1000);test.check(menu.opened,"file context menu retained");input.mouseClick(menu.itemAt(0),20,15);input.wait(20);test.check(test.chosen===10,"reveal invokes original chosen handler");menu.close();input.tryVerify(()=>!menu.visible,1000);
        input.mouseClick(row,16,16);test.check(test.chosen===11,"primary selection retained");
        row.row={kind:"files",label:"Refresh index",info:"__senomy_refresh__",icon:""};input.wait(20);input.mouseClick(row,16,16,Qt.RightButton);input.wait(20);test.check(!menu.opened,"index sentinel has no inert menu");
        console.log("PASS: file reveal context dispatch and primary activation retained; inert app/window/action/index menus suppressed");Qt.quit();
    }}
}
