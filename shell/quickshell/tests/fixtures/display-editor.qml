//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import Quickshell
import "../../components"
import "../../services"
import "../../config" as Config

ShellRoot {
    id:host
    DisplayDraft {id:editorDraft;displays:fake.displays;observedDigest:"fixture"}
    DisplayActions {id:actions;provider:fake;context:"fixture"}
    QtObject {
        id:fake
        property var recoveryHealth:({enabled:false,needed:false,state:"disabled",message:"Automatic display recovery is off."})
        property string recoveryMessage:""
        property bool displayBusy:false
        property var commands:[]
        property var lastPlan:null
        property var draft:editorDraft
        property var displayActions:actions
        property bool loading:false
        property int selectedWorkspace:0
        property bool identifying:false
        property string error:""
        property var policy:({workspaceMode:"global",workspaces:{},primary:"",rail:{}})
        property var profiles:[{id:"desk",name:"Desk setup",displayCount:3}]
        property var displays:[
            {name:"A",key:"A",number:1,friendlyName:"External display",width:1920,height:1080,refreshRate:60,scale:1,transform:0,x:0,y:0,disabled:false,dpmsStatus:true,availableModes:["1920x1080@60.00Hz","1280x720@60.00Hz"],activeWorkspace:{id:1}},
            {name:"B",key:"B",number:2,friendlyName:"External display",width:1920,height:1080,refreshRate:60,scale:1,transform:0,x:1920,y:0,disabled:false,dpmsStatus:true,availableModes:["1920x1080@60.00Hz"],activeWorkspace:{id:2}},
            {name:"eDP-QA",key:"C",number:3,friendlyName:"Internal display",width:1920,height:1080,refreshRate:60,scale:1,transform:0,x:960,y:1080,disabled:false,dpmsStatus:true,availableModes:["1920x1080@60.00Hz"],activeWorkspace:{id:3}}
        ]
        property var workspaces:[{id:1,name:"1",monitor:"A",windows:1},{id:2,name:"2",monitor:"B",windows:1},{id:3,name:"3",monitor:"eDP-QA",windows:0}]
        property var windows:[{address:"0xa",pid:1,class:"Terminal",workspace:{id:1}},{address:"0xb",pid:2,class:"Browser",workspace:{id:2}}]
        function planProjection(mode,source,externals){lastPlan={mode:mode,source:source,externals:externals};return true;}
        function workspaceLabel(id){return String(id);}
        function workspaceOrder(id){return id;}
        function railVisible(name){return true;}
        function runDisplayOperation(op,arg){let value=arg;try{value=JSON.parse(arg);}catch(e){}commands=commands.concat([{operation:op,argument:value}]);return true;}
        function refresh(force){}
        function identify(){identifying=true;}
        function dismissIdentify(){identifying=false;}
        function requestWorkspace(arg,text){return actions.requestOperation("workspace",arg,text);}
    }
    Window {
        id:testWindow
        width:1000;height:500;visible:true;color:"#0a0c10"
        Item {anchors.fill:parent
            Rectangle {anchors.fill:parent;color:Config.DirectoryStyle.glass}
            IslandPopupFrame {anchors.fill:parent;frameKey:"control";active:true;animate:false;contentInset:Config.QuickPanelStyle.inset
                Text {id:displayHeading;width:parent.width;height:44;text:"Display layout";font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:20;color:Config.DirectoryStyle.ink;verticalAlignment:Text.AlignVCenter}
                IslandRule {y:52;width:parent.width;leadingPoint:false}
                Flickable {id:viewport;y:76;width:parent.width;height:Math.max(1,parent.height-y);contentHeight:editor.height;clip:true
                    DisplaySettings {id:editor;view:"arrangement";width:parent.width-12;inventory:fake}
                }
            }
        }
    }
    property var checkReview:null
    Timer {id:reviewCheck;interval:80;onTriggered:host.checkReview()}
    property bool reviewChecked:false
    property int captureIndex:0
    readonly property var cases:{let result=[];for(const w of [1000,640,380])for(const v of ["projection","arrangement","settings","workspaces","profiles","diagnostics"])result.push({view:v,width:w});return result;}

    Timer {id:next;interval:200;running:true;onTriggered:{
        if(!editor.selectedDisplay){console.error("FAIL editor selection");Qt.exit(1);return;}
        if(!host.reviewChecked){
            editorDraft.selectName("eDP-QA");editorDraft.centreGroup(true);
            function find(item,name){if(item.objectName===name)return item;for(const c of item.children){const hit=find(c,name);if(hit)return hit;}return null;}
            const duplicate=find(editor,"projection-mode-duplicate");
            if(!duplicate){console.error("FAIL projection control missing");Qt.exit(1);return;}
            duplicate.clicked();
            if(!fake.lastPlan||fake.lastPlan.mode!=="duplicate"||fake.lastPlan.externals.length!==2){console.error("FAIL projection control backend wiring");Qt.exit(1);return;}
            // Actual review buttons: conflict and overlap must not hide Review.
            editorDraft.patch("A",{mode:"3840x2160@60.00Hz"});editorDraft.observedDigest="new-baseline";
            viewport.contentY=Math.max(0,viewport.contentHeight-viewport.height);
            const review=find(editor,"displayReviewBottom"),confirm=find(editor,"displayConfirm");
            if(!review.enabled)throw new Error("Review disabled on blocked draft");
            review.clicked();
            if(actions.actionState!=="pending"||confirm.enabled||editor.draftProblems.length<2)throw new Error("Blocked review/confirmation mismatch");
            if(editor.confirmReview()||fake.commands.length)throw new Error("Blocked review invoked backend");
            find(editor,"displayUpdateBaseline").clicked();
            if(editorDraft.conflict||confirm.enabled||editorDraft.selectedOutput.mode!=="1920x1080@60.00Hz")throw new Error("Baseline repair lost selection or bypassed overlap");
            if(editorDraft.outputs.find(o=>o.key==="A").mode!=="3840x2160@60.00Hz")throw new Error("Baseline repair discarded edited mode");
            find(editor,"displayResolveOverlap").clicked();
            if(editorDraft.validationError||!confirm.enabled)throw new Error("Explicit spacing did not unblock confirmation");
            host.checkReview=function(){
                const panel=find(editor,"displayReviewPanel"),point=panel.mapToItem(viewport,0,0);
                const buttonPoint=confirm.mapToItem(viewport,0,0);
                if(panel.height<100||actions.actionState!=="pending"||point.y< -1||buttonPoint.y+confirm.height>viewport.height+1)throw new Error("Review controls remained outside scrolled viewport");
                console.log("PASS display review conflict, overlap and scroll handling");
                testWindow.contentItem.grabToImage(function(image){
                image.saveToFile((Quickshell.env("SENOMY_DISPLAY_QA_DIR")||"/tmp")+"/display-review-ready.png");
                confirm.clicked();
                if(fake.commands.length!==1||fake.commands[0].operation!=="apply-topology"||fake.commands[0].argument.baseDigest!=="new-baseline")throw new Error("Confirm did not use repaired current proposal");
                actions.applied("fixture-preview",Date.now()+15000);
                actions.observe({state:"recovery-failed",token:"fixture-preview",message:"Inert recovery failure"});
                if(editor.canReview||editor.editable||editor.reviewDraft())throw new Error("Recovery token allowed another edit/apply review");
                if(!actions.revert()||fake.commands[1].operation!=="revert")throw new Error("Recovery retry inaccessible");
                actions.reset();editorDraft.discard();
                editorDraft.selectName("eDP-QA");editorDraft.centreGroup(true);
                testWindow.height=820;host.reviewChecked=true;next.restart();
                });
            };
            reviewCheck.restart();
            return;
        }
        const scene=host.cases[host.captureIndex];testWindow.width=scene.width;editor.width=Math.max(1,viewport.width-12);viewport.contentY=0;editor.view=scene.view;
        capture.restart();
    }}
    Timer {id:capture;interval:100;onTriggered:{
        const scene=host.cases[host.captureIndex];
        testWindow.contentItem.grabToImage(function(image){
            image.saveToFile((Quickshell.env("SENOMY_DISPLAY_QA_DIR")||"/tmp")+"/display-"+scene.view+"-"+scene.width+".png");
            host.captureIndex++;
            if(host.captureIndex<host.cases.length)next.restart();else{console.log("PASS display editor all views at 1000 and 640 logical pixels");Qt.quit();}
        });
    }}
}
