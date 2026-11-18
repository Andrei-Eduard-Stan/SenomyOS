import QtQuick
import QtTest
import Quickshell
import "../../services" as Services

Scope {
    id: test
    property bool operationBegan:false
    property bool staleAdopted:false
    TestCase {id:input;when:false}
    Services.DeviceInventory {
        id:inventory
        policyRestorePending:false
        actionContext:"inert-fixture"
        onSnapshotChanged:if(test.operationBegan && snapshot.displays && snapshot.displays.items[0].width===1920)test.staleAdopted=true
    }
    function check(value,message){if(!value){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
    Timer {
        interval:50;running:true
        onTriggered:{
            test.operationBegan=true;
            test.check(inventory.runDisplayOperation("workspace",'{"action":"accepted"}'),"start inert operation during old inventory");
            test.check(!inventory.runDisplayOperation("workspace",'{"action":"accepted"}'),"serialize pending operations");
            input.wait(850);
            test.check(!test.staleAdopted && inventory.displays[0].width===1280,"discard inventory begun before operation and reconcile fresh state");
            inventory.draft.patch("fixture",{x:50});
            const draft=JSON.stringify(inventory.draft.exported());
            inventory.displayActions.applied("fixture-token",Date.now()+15000);
            test.check(inventory.displayActions.keep(),"inert Keep submitted");input.wait(650);
            test.check(inventory.displayActions.actionState==="failed" && inventory.displayActions.token==="fixture-token","nonzero Keep cannot claim success or release recovery token");
            test.check(JSON.stringify(inventory.draft.exported())===draft,"nonzero Keep preserves exact draft");
            test.check(inventory.draftPersistenceError.length>0,"nonzero draft save cannot claim persistence");
            inventory.displayActions.reset();
            inventory.runDisplayOperation("workspace",'{"action":"reject"}');input.wait(300);
            test.check(inventory.displayActions.actionState==="failed" && inventory.displayActions.message.includes("rejected"),"backend rejection retained");
            inventory.runDisplayOperation("workspace",'{"action":"malformed"}');input.wait(300);
            test.check(inventory.displayActions.actionState==="failed","malformed operation cannot succeed");
            inventory.runDisplayOperation("workspace",'{"action":"inventory-fail"}');input.wait(350);
            test.check(inventory.displays[0].width===1280 && inventory.error.length>0,"nonzero inventory cannot replace valid observed geometry");
            inventory.runDisplayOperation("workspace",'{"action":"inventory-good"}');input.wait(350);
            test.check(inventory.error==="","manual operation reconciliation recovers inventory");
            inventory.policyRestorePending=true;inventory.refresh(true);input.wait(400);
            test.check(!inventory.policyRestorePending && inventory.error.includes("could not be restored"),"nonzero policy restore cannot claim success or spin");
            inventory.interpreter="/nonexistent/senomy-display-fixture";
            inventory.refresh(true);input.wait(350);
            test.check(!inventory.loading && !inventory.queryPending && inventory.error.includes("could not start"),"missing inventory interpreter releases loading");
            inventory.displayActions.requestOperation("workspace",{action:"accepted"},"Inert operation");inventory.displayActions.confirm();input.wait(350);
            test.check(!inventory.displayBusy && inventory.displayActions.actionState==="failed" && inventory.displayActions.message.includes("could not start"),"missing action interpreter releases pending state");
            inventory.draft.patch("fixture",{x:60});input.wait(700);
            test.check(!inventory.draftSavePending && inventory.draftPersistenceError.includes("could not start"),"missing draft helper reports persistence failure");
            inventory.interpreter="python3";inventory.refresh(true);input.wait(350);
            test.check(!inventory.loading && inventory.error==="" && inventory.draft.dirty,"explicit retry recovers without erasing draft");
            console.log("PASS: actual display transport rejects nonzero/malformed receipts, preserves drafts/tokens, ignores stale inventory, reports rejection and recovers missing workers; inert processes only");
            Qt.exit(0);
        }
    }
}
