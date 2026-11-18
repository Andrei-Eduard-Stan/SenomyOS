import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services"
Window {
    id:test;visible:true;width:600;height:700
    property int mutations:0
    TestCase{id:input;when:false}
    QtObject{id:runner;property bool running:false;function exec(args){test.mutations++;}}
    DesktopPreferenceActions{id:reviews;runner:runner;helper:"fixture.py";active:true;context:"apps:fixture";defaults:settings.defaults;autostart:settings.autostart;apps:settings.apps;deployment:settings.deployment}
    QtObject {
        id:settings;property bool available:true;property bool loading:false;property string error:"";property string capabilityError:"";property string message:"Fixture desktop registry"
        property var actions:reviews
        property var defaults:Array.from({length:6},(_,i)=>({mime:i===0?"text/plain":"type/"+i,label:"Role "+i,current:"one.desktop",currentName:"Fixture One",options:[{id:"one.desktop",name:"Fixture One"},{id:"two.desktop",name:"Fixture Two"}],token:"role-token"}))
        property var apps:[{id:"two.desktop",name:"Fixture Two",token:"app-token",autostartAllowed:true}]
        property var autostart:Array.from({length:24},(_,i)=>({id:"entry-"+i+".desktop",name:"Autostart "+i,enabled:true,eligible:true,protected:i===0,source:"user",token:"entry-token"}))
        property var deployment:({supported:true,enabled:false,token:"deployment-token",message:"Future login required"})
        property var capabilities:({services:[{unit:"fixture-portal.service",available:true,state:"active"}],portal:{state:"advertised",message:"Not physical acceptance",features:[{name:"ScreenCast",advertised:true}]},flatpakAvailable:false,permissionPolicy:"Fixture native permission dialogs",journeys:"Fixture journeys"})
        function refresh(){test.mutations++;}
    }
    FocusScrollArea {id:scroll;anchors.fill:parent;contentHeight:body.implicitHeight;Column{id:body;width:parent.width;DesktopPreferencesView{id:view;width:parent.width;settings:settings}DesktopCapabilitiesView{width:parent.width;settings:settings}}}
    function check(ok,msg){if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw new Error(msg);}}
    Timer {
        interval:400;running:true
        onTriggered:{
            test.check(view.part==="defaults","default associations are the initial route");
            const defaultsSeen=new Set();
            for(let step=0;step<35;step++){input.keyClick(Qt.Key_Tab);input.wait(2);const item=test.activeFocusItem;if(item && String(item.Accessible.name).indexOf("Choose default for Role ")===0)defaultsSeen.add(String(item.Accessible.name));}
            test.check(defaultsSeen.size===6,"each default application chooser is keyboard reachable");
            view.part="autostart";input.wait(30);
            for(const width of [600,340]){
                test.width=width;input.wait(30);const seen=new Set();
                for(let step=0;step<90;step++){
                    input.keyClick(Qt.Key_Tab);input.wait(2);const item=test.activeFocusItem;
                    if(item){let row=item;while(row&&row!==scroll){if(row.modelData&&row.modelData.id&&row.modelData.id.indexOf("entry-")===0)seen.add(row.modelData.id);row=row.parent;}
                        const pos=item.mapToItem(scroll,0,0);test.check(pos.y>=-1&&pos.y+item.height<=scroll.height+1,"desktop focused control clipped");}
                }
                test.check(seen.size===23,"all unprotected autostart controls reached");test.check(test.mutations===0,"Tab must not save or launch");
            }
            reviews.request("autostart","entry-23.desktop","no");input.wait(30);test.check(test.activeFocusItem.objectName==="selectionCancel","desktop review defaults to Cancel");input.keyClick(Qt.Key_Return);test.check(reviews.actionState==="idle"&&test.mutations===0,"Cancel has no mutation");
            console.log("PASS: default/autostart/portal views, populated narrow keyboard reachability and safe cancellation; fake desktop providers only");Qt.quit();
        }
    }
}
