import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "config" as Config
Window {
    id: test; visible: true; width: 390; height: 640; color: "#080a0c"
    property var invoked: []
    TestCase { id: input; when: false }
    ContextActionMenu {
        id: menu; x:8; y:580; contextKey:"first"; accessibleLabel:"Fixture actions"
        actions:[{id:"copy",label:"Copy display configuration"},{id:"unavailable",label:"Restore saved arrangement",enabled:false,reason:"No saved profile"},{id:"pin",label:"Pin destination (session)"}]
        onActionRequested:action=>test.invoked.push(action)
    }
    ContextEvidenceMenu {
        id:evidence; x:test.width-48; y:8; contextKey:"diagnostics";componentKey:"fixture-diagnostics"
        report:({output:["Sanitized fixture"],available:true})
        extraActions:[{id:"refresh",label:"Refresh task catalog"}]
        onExtraActionRequested:action=>test.invoked.push(action)
    }
    function check(ok,msg) { if(!ok) { console.error("FAIL: "+msg); Qt.exit(1); throw Error(msg); } }
    function until(predicate,reason){for(let i=0;i<100 && !predicate();i++)input.wait(10);test.check(predicate(),reason);}
    function capture(name) { let done=false;test.contentItem.grabToImage(result=>{check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture");done=true;});while(!done)input.wait(10); }
    Timer {interval:250;running:true;onTriggered:{
        const trigger=input.findChild(menu,"context-menu-trigger");
        trigger.forceActiveFocus();input.keyClick(Qt.Key_Return);input.wait(60);
        const popup=input.findChild(menu,"context-action-popup");test.until(()=>menu.opened,"menu completes opening: visible="+popup.visible+" opacity="+popup.opacity);test.check(menu.opened,"keyboard opens menu");
        let point=popup.contentItem.mapToItem(test.contentItem,0,0);
        test.check(popup.anchorPoint.y>500 && point.y>350,"bottom menu stays beside its trigger");
        test.check(point.x>=0 && point.y>=0 && point.x+popup.contentItem.width<=test.width && point.y+popup.contentItem.height<=test.height,"bottom/left bounds");
        test.capture("01-menu-portrait-bottom");
        test.check(!menu.invoke("unavailable") && !menu.invoke("snapshot") && test.invoked.length===0,"disabled and unknown actions cannot dispatch");input.keyClick(Qt.Key_Down);input.wait(20);input.keyClick(Qt.Key_Return);input.wait(30);
        test.check(test.invoked.join()==="pin","Down skips disabled entry; Enter invokes pin");menu.open();test.until(()=>menu.opened,"menu completes opening: visible="+popup.visible+" opacity="+popup.opacity);input.keyClick(Qt.Key_Escape);test.until(()=>!popup.visible,"menu completes close");
        test.until(()=>trigger.activeFocus,"trigger focus restored");test.check(!menu.opened && trigger.activeFocus,"Escape returns focus");
        menu.open();test.until(()=>menu.opened,"menu completes opening: visible="+popup.visible+" opacity="+popup.opacity);input.mouseClick(test.contentItem,350,330);input.wait(30);test.check(!menu.opened,"outside press dismisses");
        menu.open();test.until(()=>menu.opened,"menu completes opening: visible="+popup.visible+" opacity="+popup.opacity);menu.contextKey="second";input.wait(20);test.check(!menu.opened,"route change closes menu");
        menu.open();test.until(()=>menu.opened,"menu completes opening: visible="+popup.visible+" opacity="+popup.opacity);menu.ownerActive=false;input.wait(20);test.check(!menu.opened && !menu.invoke("copy"),"owner deactivation closes and blocks dispatch");menu.ownerActive=true;for(const touch of [false,true]){
            Config.DirectoryStyle.touchMode=touch;menu.x=test.width-menu.width-4;menu.y=4;menu.open();input.wait(40);
            const row=popup.itemAt(0);test.check(!touch || row.height>=48,"touch target");
            point=popup.contentItem.mapToItem(test.contentItem,0,0);test.check(point.x>=0 && point.x+popup.contentItem.width<=test.width,"right bounds");
            test.capture(touch?"03-menu-touch":"02-menu-portrait-top");popup.close();
        }
        menu.actions=[];input.wait(20);test.check(!menu.visible && menu.height===0,"empty menu has no allocation");evidence.open();input.wait(30);test.check(evidence.invoke("refresh") && test.invoked.includes("refresh"),"custom action delivered");
        test.check(evidence.invoke("text"),"text action delivered");let count=0;while(evidence.busy && count++<100)input.wait(20);
        test.check(!evidence.busy && evidence.status.startsWith("Saved "),"actual text helper result");
        input.keyClick(Qt.Key_Escape);input.wait(20);
        if(evidence.clipboardAvailable){test.check(evidence.invoke("copy"),"copy delivered");count=0;while(evidence.busy && count++<100)input.wait(20);test.check(Quickshell.env("SENOMY_COPY_FAILURE")==="1" ? evidence.status!=="Component report copied" && evidence.status.length>0 : evidence.status==="Component report copied","truthful clipboard helper result");}
        else test.check(!evidence.invoke("copy"),"missing clipboard capability disabled");
        evidence.evidenceAvailable=false;test.check(!evidence.invoke("copy")&&!evidence.invoke("text"),"unavailable evidence blocked");
        evidence.evidenceAvailable=true;evidence.invoke("text");evidence.contextKey="different";count=0;while(evidence.busy && count++<100)input.wait(20);test.check(evidence.status==="" && !evidence.opened,"late feedback cannot reopen another route");
        console.log("PASS: contextual action routing, keyboard, focus, outside dismissal, edge geometry, touch, empty/disabled states, capability gate, real text/clipboard helper, stale completion");Qt.quit();
    }}
}
