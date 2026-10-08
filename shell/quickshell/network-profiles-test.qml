import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services"
Window {
    id:test;visible:true;width:600;height:500
    property int calls:0
    property string edited:""
    TestCase {id:input;when:false}
    QtObject {id:runner;property bool running:false;function exec(args){test.calls++;}}
    ProfileActions {id:actions;runner:runner;helper:"fixture.py";active:true;context:"network:fixture";items:profiles.items}
    QtObject {
        id:profiles
        property bool available:true
        property bool editorAvailable:true
        property bool loading:false
        property bool busy:actions.locked
        property string error:""
        property string message:"Fixture profiles only"
        property var actions:actions
        property var items:Array.from({length:24},(_,i)=>({uuid:"12345678-1234-1234-1234-"+String(i).padStart(12,"0"),name:"Profile "+i,type:i===0?"vpn":"wifi",active:false,autoconnect:true,mutable:true,token:"a".repeat(64)}))
        function refresh(){test.calls++;}
        function openEditor(mode,uuid){test.edited=mode+":"+uuid;}
    }
    FocusScrollArea {
        id:scroll;anchors.fill:parent;contentHeight:view.implicitHeight
        NetworkProfilesView {id:view;width:parent.width;profiles:profiles}
    }
    function check(ok,msg){if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw new Error(msg);}}
    Timer {
        interval:300;running:true
        onTriggered:{
            for(const width of [600,340]){
                test.width=width;input.wait(30);const seen=new Set();
                for(let step=0;step<100;step++){
                    input.keyClick(Qt.Key_Tab);input.wait(2);const item=test.activeFocusItem;
                    if(item && item.parent){let row=item;while(row && row!==scroll){if(row.modelData && row.modelData.uuid)seen.add(row.modelData.uuid);row=row.parent;}
                        const pos=item.mapToItem(scroll,0,0);test.check(pos.y>=-1&&pos.y+item.height<=scroll.height+1,"profile keyboard focus clipped");}
                }
                test.check(seen.size===24,"all 24 profile controls reached");test.check(test.calls===0 && test.edited==="","Tab must not act");
            }
            actions.request("forget",profiles.items[23]);input.wait(30);
            test.check(test.activeFocusItem.objectName==="selectionCancel","profile review safe Cancel focus");input.keyClick(Qt.Key_Return);test.check(actions.actionState==="idle"&&test.calls===0,"cancel does not apply");
            test.check(profiles.items[0].type==="vpn","VPN inventory represented");
            console.log("PASS: 24 saved profiles, constrained keyboard reachability and safe review cancellation; fake profiles only");Qt.quit();
        }
    }
}
