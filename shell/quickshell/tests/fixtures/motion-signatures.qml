import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Wayland
import "components" as UI
import "components/lens" as Lens
import "components/interaction" as Interaction
import "services" as Services
import "config" as Config

PanelWindow {
    id: test
    // This is an inert review host, never the production shell or notification owner.
    property var reviewScreen: Quickshell.screens[Number(Quickshell.env("SENOMY_QA_SCREEN") || 0)]
    property string outputName:reviewScreen.name || "fixture"
    screen: reviewScreen
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 72
    exclusiveZone: 0
    WlrLayershell.namespace: "senomy-motion-review"
    color: "#111218"
    property string output: Quickshell.env("SENOMY_QA_OUT")
    property string tracePhase: "idle"
    property bool baseline: Quickshell.env("SENOMY_MOTION_BASELINE") === "1"
    property bool profile:Quickshell.env("SENOMY_MOTION_PROFILE")==="1"
    property bool captures: Quickshell.env("SENOMY_MOTION_CAPTURES") === "1"
    property int captureIndex: 0
    property bool capturePending: false
    property int captureGeneration:0
    property var rows: []
    property var events: []
    property int checks: 0
    property int mappings: 0
    property int corrections: 0
    property var firstGeometry: null
    property int actions: 0
    property var metrics: ({ready:true,cpuPercent:23,memoryPercent:41,memoryTotalKib:16000000,memoryUsedKib:6560000,
        temperatureAvailable:true,temperatureCelsius:44,uptimeDetailedLabel:"01:42:06",kernelRelease:"Fixture",hostName:"Review host",hostModel:"Synthetic telemetry",cpuModel:"Fixture CPU"})
    TestCase { id: input; when: false }
    Services.ShellState { id: state; availableScreens:[test.outputName];railWindows:[test] }
    QtObject { id: fakeLaunch; property bool busy:false; property int heldSession:-1;property int heldRevision:-1;property int heldGeneration:-1;function request(){test.actions++;return false;} }
    Item { id: trigger; x:(test.width-width)/2;y:4;width:360;height:64
        UI.MachineStateIsland {anchors.fill:parent;metrics:test.metrics;senomy:({state:"normal",attentionState:"",message:"Review fixture"});hoverExpansionEnabled:false;expanded:false;onToggleExpanded:expanded.requestedOpen=!expanded.requestedOpen}
    }
    Lens.CommandLensPopup {
        id:lens;anchorItem:trigger;targetScreen:test.reviewScreen;coordinator:state;popupToken:"lens:"+test.outputName
        requestedOpen:state.activePopup===popupToken
        applicationLauncher:fakeLaunch
        applicationRows:[{kind:"apps",id:"apps:editor",label:"Editor",detail:"Review application",icon:"",object:{}},{kind:"apps",id:"apps:files",label:"Files",detail:"Review application",icon:"",object:{}}]
        windowRows:[]
        onVisibleChanged: if(visible){test.mappings++;test.firstGeometry=null;}
    }
    Interaction.QuickPopoverWindow {
        id:other;anchorItem:trigger;targetScreen:test.reviewScreen;coordinator:state;popupToken:"volume:"+test.outputName
        requestedOpen:state.activePopup===popupToken;implicitWidth:432;implicitHeight:280;color:"transparent"
        anchor.item:trigger;anchor.edges:Edges.Top;anchor.gravity:Edges.Top;anchor.rect.x:trigger.width/2;anchor.rect.y:-12
        UI.IslandPopupFrame {anchors.fill:parent;animate:false;opacity:other.cardShown?1:0}
    }
    UI.MachineStateOverlay {id:expanded;targetScreen:test.reviewScreen;senomy:({});metrics:test.metrics;anchorCenterX:trigger.x+trigger.width/2;keyboardRequested:true;onCloseRequested:requestedOpen=false}
    Connections {target:lens;function onRequestedOpenChanged(){test.events.push({at:Date.now(),surface:"lens",phase:test.tracePhase,requested:lens.requestedOpen});}}
    Connections {target:expanded;function onRequestedOpenChanged(){test.events.push({at:Date.now(),surface:"island",phase:test.tracePhase,requested:expanded.requestedOpen});}}
    Connections {
        target:lens.contentItem.Window.window
        function onFrameSwapped(){test.record(lens,"lens");}
    }
    Connections {
        target:expanded.contentItem.Window.window
        function onFrameSwapped(){test.record(expanded,"island");}
    }
    // QsWindow's C++ contentItem has no QML engine for grabToImage. These
    // fixture-only parents capture the child opacity/translation at native size.
    Item {id:lensScene;parent:lens.contentItem;anchors.fill:parent;Component.onCompleted:lens.content.parent=lensScene}
    Item {id:islandScene;parent:expanded.contentItem;anchors.fill:parent;Component.onCompleted:{const stage=input.findChild(expanded.contentItem,"machineStage");if(stage)stage.parent=islandScene;}}
    function progress(p){return p===expanded?p.reveal:typeof p.presentationProgress==="number"?p.presentationProgress:(p.content?p.content.opacity:(p.cardShown?1:0));}
    function record(p,kind){
        const origin=p.contentItem.mapToGlobal(0,0),geo=[p.width,p.height,origin.x,origin.y];
        if(p===lens && p.requestedOpen){if(!firstGeometry)firstGeometry=geo;else if(JSON.stringify(geo)!==JSON.stringify(firstGeometry)){corrections++;firstGeometry=geo;}}
        rows.push({at:Date.now(),phase:tracePhase,surface:kind,visible:p.visible,requested:p.requestedOpen,progress:progress(p),width:p.width,height:p.height,x:origin.x,y:origin.y,active:!!p.contentItem.Window.window.active,focused:p===lens?lens.content.searchInput.activeFocus:false});
    }
    function check(ok,message){checks++;if(!ok)throw Error(message);}
    function capture(){
        if(!captures || capturePending || tracePhase==="idle" || captureIndex>=8)return;
        const p=tracePhase.indexOf("lens")===0?lens:expanded;
        if(!p.visible)return;
        capturePending=true;
        const generation=captureGeneration;
        const name=output+"/"+tracePhase+"-"+String(captureIndex++).padStart(3,"0")+".png";
        const item=p===lens?lensScene:islandScene;
        if(!item || !item.visible || !item.grabToImage(result=>{result.saveToFile(name);if(generation===captureGeneration)capturePending=false;}))capturePending=false;
    }
    function phase(name){tracePhase=name;captureIndex=0;captureGeneration++;capturePending=false;}
    function until(predicate){for(let i=0;i<150 && !predicate();i++)input.wait(10);test.check(predicate(),"bounded transition completion");}
    function open(){state.togglePopup("lens",test.outputName);}
    function setReduced(value){Config.Skin.registry=Object.assign({},Config.Skin.registry,{persona:Object.assign({},Config.Skin.registry.persona||{},{reducedMotion:value})});}
    Timer {interval:40;repeat:true;running:test.captures;onTriggered:test.capture()}
    property int profileStep:0
    Timer {interval:500;repeat:true;running:test.profile;onTriggered:{
        try {
            if(test.profileStep===0)test.setReduced(false);
            const step=test.profileStep%4;
            if(test.profileStep===80){
                console.log("MOTION_TRACE "+JSON.stringify({checks:test.checks,mappings:test.mappings,qtGeometryCorrections:test.corrections,events:test.events,cycles:20,frames:test.rows,profile:true}));
                console.log("PASS: 20 asynchronous native Lens/island profile cycles; no QtTest waits or image readbacks");Qt.quit();return;
            }
            if(step===0){test.phase("lens-open");test.open();}
            else if(step===1){test.check(lens.visible && lens.cardShown && test.progress(lens)===1 && lens.ownsEscape,"profile Lens ready");test.phase("lens-close");state.closePopups();}
            else if(step===2){test.check(!lens.visible,"profile Lens closes");test.phase("island-open");expanded.requestedOpen=true;}
            else {test.check(expanded.visible && expanded.reveal===1,"profile island ready");test.phase("island-close");expanded.requestedOpen=false;}
            test.profileStep++;
        }catch(e){console.error("FAIL:",e);Qt.exit(1);}
    }}
    Timer {interval:450;running:!test.profile;onTriggered:{try {
        test.setReduced(false);
        test.phase("lens-open");test.open();test.until(()=>lens.visible && lens.cardShown && test.progress(lens)===1);input.wait(80);
        test.check(lens.visible && lens.cardShown,"Lens appears: "+JSON.stringify({requested:lens.requestedOpen,shown:lens.cardShown,prepared:lens.anchorPrepared,visible:lens.visible,state:state.activePopup,phase:lens.lifecycle}));
        test.until(()=>lens.ownsEscape && lens.content.searchInput.activeFocus);test.check(lens.content.searchInput.activeFocus,"search focus");
        test.check(lens.width===640 && lens.height===560,"first geometry uses final bounds");
        lens.content.searchInput.forceActiveFocus();input.keyClick(Qt.Key_E);test.check(lens.content.searchText==="e","typing during session");
        test.phase("lens-close");lens.handleEscape();
        if(!test.baseline)test.check(lens.visible && !lens.requestedOpen && !lens.focusGrabActive,"closing retains pixels and releases grab");
        test.until(()=>!lens.visible);test.check(!lens.visible,"close finishes: "+JSON.stringify({visible:lens.visible,requested:lens.requestedOpen,shown:lens.cardShown,progress:test.progress(lens),phase:lens.lifecycle}));
        test.phase("lens-reversal");test.open();
        for(let i=0;i<40 && test.progress(lens)<0.6;i++)input.wait(10);
        const mapped=test.mappings;
        state.closePopups();input.wait(16);
        if(!test.baseline)test.check(lens.visible && test.progress(lens)>0,"reopen interrupts an actual exit");
        test.open();test.until(()=>lens.visible && lens.cardShown && test.progress(lens)===1);
        if(!test.baseline)test.check(test.mappings===mapped,"exit reversal does not remap");
        test.check(lens.visible && lens.cardShown,"reversal opens latest request");
        test.phase("idle");
        for(let i=0;i<(test.captures?2:20);i++){
            state.closePopups();input.wait(190);test.open();input.wait(240);
            test.check(lens.visible && lens.content.searchInput.activeFocus,"repeat focus "+i);
            state.togglePopup("volume",test.outputName);input.wait(25);
            test.check(!lens.visible && other.visible,"replacement has one native owner "+i);
            state.closePopups();input.wait(180);
        }
        test.open();input.wait(100);state.externalModalActive=true;
        test.check(!state.togglePopup("volume",test.outputName) && lens.visible,"protected review blocks switching");
        state.externalModalActive=false;state.closePopups();input.wait(200);
        test.phase("island-open");expanded.requestedOpen=true;test.until(()=>expanded.reveal===1);input.wait(80);
        test.check(expanded.visible && expanded.reveal===1,"expanded island opens");
        const stage=input.findChild(expanded.contentItem,"machineStage");
        if(!test.baseline)test.check(stage.scale===1,"authored geometry stays unscaled");
        test.phase("island-close");expanded.requestedOpen=false;test.until(()=>!expanded.visible);test.check(!expanded.visible,"island close finishes");
        test.phase("island-reversal");expanded.requestedOpen=true;test.until(()=>expanded.reveal>=0.6);expanded.requestedOpen=false;input.wait(16);expanded.requestedOpen=true;test.until(()=>expanded.reveal===1);
        test.check(expanded.visible && expanded.reveal===1,"island reverses");expanded.requestedOpen=false;input.wait(200);
        test.phase("idle");test.setReduced(true);test.open();test.until(()=>test.progress(lens)===1 && lens.content.searchInput.activeFocus && lens.ownsEscape);
        test.check(test.progress(lens)===1 && lens.content.searchInput.activeFocus,"reduced Lens focus and progress");
        state.closePopups();input.wait(20);test.check(!lens.visible,"reduced close immediate");
        expanded.requestedOpen=true;test.until(()=>expanded.reveal===1);test.check(expanded.reveal===1,"reduced island opens");expanded.requestedOpen=false;input.wait(20);test.check(!expanded.visible,"reduced island closes");
        test.check(test.actions===0,"no activation or device actions");
        console.log("MOTION_TRACE "+JSON.stringify({checks:test.checks,mappings:test.mappings,qtGeometryCorrections:test.corrections,events:test.events,cycles:test.captures?2:20,frames:test.rows}));
        console.log("PASS: inert signature motion, "+(test.captures?2:20)+" replacement/reopen cycles, focus, interruption, guards and reduced motion");Qt.quit();
    }catch(e){console.log("MOTION_TRACE "+JSON.stringify({checks:test.checks,mappings:test.mappings,qtGeometryCorrections:test.corrections,events:test.events,cycles:test.captures?2:20,frames:test.rows}));console.error("FAIL:",e);Qt.exit(1);}}}
}
