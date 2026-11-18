import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "components" as UI
import "services" as Services
import "config" as Config

ShellRoot {
    id:test
    property var screen:Quickshell.screens[Number(Quickshell.env("SENOMY_QA_SCREEN") || 0)]
    property string outputName:screen.name
    property bool baseline:Quickshell.env("SENOMY_MOTION_BASELINE")==="1"
    property int step:0
    property int checks:0
    property int unexpectedActions:0
    property string phase:"settle"
    property var frames:[]
    property var events:[]
    property var firstSettingsGeometry:null
    property int settingsCorrections:0
    property var openingGeometry:({})
    property int primaryCorrections:0
    property int tailStep:0
    property var captured:({})
    TestCase {id:input;when:false}
    Services.ShellState {id:state;availableScreens:[test.outputName];railWindows:[rail]}
    PanelWindow {
        id:backdrop;screen:test.screen;anchors {top:true;bottom:true;left:true;right:true}
        exclusiveZone:0;color:"#101218";visible:!control.fullSettings || !control.requestedOpen
        WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"senomy-motion-test-backdrop"
        Text {x:24;y:24;text:"SENOMYOS · INERT MOTION REVIEW · "+test.phase;color:"#f1f1f4";font.pixelSize:18}
    }
    PanelWindow {
        id:rail;screen:test.screen;anchors {bottom:true;left:true;right:true}
        implicitHeight:72;exclusiveZone:0;color:"#202329"
        WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"senomy-motion-test-rail"
        Item {id:trigger;x:(rail.width-360)/2;y:4;width:360;height:64
            Rectangle {anchors.fill:parent;color:"#30343c";border.color:"#b9bdc8"}
            Text {anchors.centerIn:parent;text:"Motion fixture anchor";color:"white"}
        }
    }
    UI.DashboardWindow {
        id:control;targetScreen:test.screen;interactionCoordinator:state
        requestedOpen:state.activePrimary==="control";fullSettings:state.controlMode==="full"
        settingsPreferredWidth:1280;settingsPreferredHeight:860;preferredWidth:fullSettings?1280:1120;preferredHeight:fullSettings?860:800
        activeNode:state.controlPath || state.controlSection;activeSection:state.controlSection
        navigationNodes:[{id:"overview",label:"OVERVIEW",route:"overview",children:[]},{id:"network",label:"NETWORK",route:"network",children:[{id:"network/wifi",label:"WI-FI",route:"network/wifi",children:[]}]}]
        replacementOpening:!!state.activePrimary && state.activePrimary!=="control"
        onCloseRequested:state.closePrimary()
        onModeRequested:full=>state.showPrimary("control",test.outputName,"overview",full?"full":"compact")
        Text {text:"Control workspace · "+control.activeNode;color:Config.DirectoryStyle.ink;font.pixelSize:24}
    }
    UI.PerformanceWorkspaceWindow {
        id:performance;targetScreen:test.screen;interactionCoordinator:state
        requestedOpen:state.activePrimary==="performance";activeSection:state.performanceSection
        activeNode:activeSection;sections:[{id:"overview",label:"OVERVIEW",route:"overview"},{id:"cpu",label:"CPU",route:"cpu"}]
        replacementOpening:!!state.activePrimary && state.activePrimary!=="performance"
        onCloseRequested:state.closePrimary()
        Text {text:"Performance · "+performance.activeSection;color:Config.DirectoryStyle.ink;font.pixelSize:24}
    }
    UI.InsightsWorkspaceWindow {
        id:insights;targetScreen:test.screen;interactionCoordinator:state
        requestedOpen:state.activePrimary==="insights";activeSection:state.insightsSection
        activeNode:activeSection;sections:[{id:"briefing",label:"BRIEFING",route:"briefing"},{id:"reports",label:"REPORTS",route:"reports"}]
        replacementOpening:!!state.activePrimary && state.activePrimary!=="insights"
        onCloseRequested:state.closePrimary()
        Text {text:"Insights · "+insights.activeSection;color:Config.DirectoryStyle.ink;font.pixelSize:24}
    }
    QtObject {id:gain;property real volume:0.5;property bool muted:false;property var channels:[PwAudioChannel.FrontLeft,PwAudioChannel.FrontRight];property var volumes:[0.5,0.5]}
    QtObject {id:output;property int id:400;property string description:"Inert output";property string nickname:"Fixture";property string name:"fixture-output";property bool ready:true;property bool isSink:true;property bool isStream:false;property int type:PwNodeType.AudioSink;property var properties:({"object.serial":400});property var audio:gain}
    QtObject {id:microphone;property int id:401;property string description:"Inert microphone";property string nickname:"Fixture mic";property string name:"fixture-input";property bool ready:true;property bool isSink:false;property bool isStream:false;property int type:PwNodeType.AudioSource;property var properties:({"object.serial":401});property var audio:gain}
    QtObject {id:audioBackend;property bool ready:true;property var defaultAudioSink:output;property var defaultAudioSource:microphone;property var preferredDefaultAudioSink:output;property var preferredDefaultAudioSource:microphone;property var nodes:({values:[output,microphone]});property var linkGroups:({values:[]})}
    Services.AudioService {id:audio;pipewire:audioBackend;nativeProvider:false;adapterEnabled:false;persistenceEnabled:false;active:volume.requestedOpen;actionContext:"audio:fixture"}
    UI.VolumePopup {id:volume;anchorItem:trigger;targetScreen:test.screen;coordinator:state;popupToken:"volume:"+test.outputName;requestedOpen:state.activePopup===popupToken;audio:audio;media:null}
    QtObject {id:networkActions;property bool locked:false;property string actionState:"idle";property string action:"";property string targetName:"";property string impact:"";property string message:"";function cancel(){return false;}function confirm(){test.unexpectedActions++;}}
    QtObject {id:network;property var actions:networkActions;property var profiles:null;property var connectionAttempt:null;property bool available:false;property bool wifiEnabled:false;property bool wifiHardwareEnabled:false;property bool scanning:false;property string detail:"Inert unavailable network provider";property var sortedWifiNetworks:[];property var connectedWifi:null;property string activeConnection:"";property int connectivity:0;property string primaryDevice:"";property string handoffMessage:"";property bool authenticationAvailable:false;function toggleWifi(){test.unexpectedActions++;}function refreshNetworks(){test.unexpectedActions++;}function activate(){test.unexpectedActions++;}}
    UI.NetworkPopup {id:networkPopup;anchorItem:trigger;targetScreen:test.screen;coordinator:state;popupToken:"network:"+test.outputName;requestedOpen:state.activePopup===popupToken;network:network}
    UI.CalendarPopup {id:calendar;anchorItem:trigger;targetScreen:test.screen;coordinator:state;popupToken:"calendar:"+test.outputName;requestedOpen:state.activePopup===popupToken;calendarService:null}
    QtObject {
        id:session;property bool available:true;property bool schedulingAvailable:true;property string unavailableReason:"";property string state:"idle";property bool busy:false;property string error:"";property string message:"";property var fieldErrors:({});property var schedule:({});property var review:null;property string pendingKind:"";property string pendingAction:"";property real remainingSeconds:30
        property string remainingText:"30 seconds";property real progress:0.5;signal prepared()
        function supported(action){return true;}
        function clearFeedback(){}function refresh(){}function cancel(){session.review=null;session.state="idle";}function request(action){session.pendingAction=action;session.pendingKind="now";session.review={action:action,mode:"now",label:action,title:"Inert review",dueLabel:"Now · inert fixture",impact:"Inert review only"};session.state="pending";}function confirm(){test.unexpectedActions++;}
    }
    UI.PowerPopup {id:power;anchorItem:trigger;targetScreen:test.screen;coordinator:state;popupToken:"power:"+test.outputName;requestedOpen:state.activePopup===popupToken;powerService:session}
    QtObject {
        id:notifications;property var sessionService:session;property bool dnd:false;property bool serverEnabled:true;property int toastGeneration:0;property var latest:null
        function isLive(record){return true;}function invoke(){test.unexpectedActions++;}signal openSessionRequested()
    }
    UI.NotificationToast {id:toast;targetScreen:test.screen;notifications:notifications;placementEnabled:true}
    Connections {target:control.captureItem.Window.window;function onFrameSwapped(){test.frame(control,"control");}}
    Connections {target:performance.captureItem.Window.window;function onFrameSwapped(){test.frame(performance,"performance");}}
    Connections {target:insights.captureItem.Window.window;function onFrameSwapped(){test.frame(insights,"insights");}}
    Connections {target:volume.contentItem.Window.window;function onFrameSwapped(){test.frame(volume,"audio");}}
    Connections {target:networkPopup.contentItem.Window.window;function onFrameSwapped(){test.frame(networkPopup,"network");}}
    Connections {target:power.contentItem.Window.window;function onFrameSwapped(){test.frame(power,"session");}}
    Connections {target:calendar.contentItem.Window.window;function onFrameSwapped(){test.frame(calendar,"calendar");}}
    function check(ok,why){checks++;if(!ok)throw Error(why);}
    function progress(p){return typeof p.presentationProgress==="number"?p.presentationProgress:(p.surfaceShown || p.cardShown?1:0);}
    function frame(p,name){
        const window=(p.captureItem || p.contentItem).Window.window;
        const floating=p===control && control.fullSettings;
        const width=floating?control.nativeSettingsWindow.width:p.width,height=floating?control.nativeSettingsWindow.height:p.height;
        const row={at:Date.now(),phase:phase,surface:floating?"settings":name,requested:p.requestedOpen,width:width,height:height,progress:progress(p),implicitWidth:floating?control.nativeSettingsWindow.implicitWidth:p.implicitWidth,implicitHeight:floating?control.nativeSettingsWindow.implicitHeight:p.implicitHeight,active:window?window.active:false};frames.push(row);
        if(Quickshell.env("SENOMY_QA_CAPTURES")==="1" && row.progress>0 && p.requestedOpen){
            const bin=row.progress<0.3?"early":row.progress<0.8?"middle":"rest",key=phase+"-"+row.surface+"-"+bin;
            if(!captured[key]){captured[key]=true;const item=p.focusTarget || p.captureItem || p.contentItem;Qt.callLater(()=>item.grabToImage(result=>result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/scene-"+key+".png")));}
        }
        if(floating && p.requestedOpen && progress(p)>0){const geometry=[width,height];if(firstSettingsGeometry && firstSettingsGeometry.phase===phase && phase!=="settings-resize" && JSON.stringify(firstSettingsGeometry.geometry)!==JSON.stringify(geometry))settingsCorrections++;firstSettingsGeometry={phase:phase,geometry:geometry};}
        if(!floating && p.requestedOpen && progress(p)>0 && !["session-select","session-schedule","session-review","session-reverse"].includes(phase)){const old=openingGeometry[name];if(old && old.phase===phase && JSON.stringify(old.geometry)!==JSON.stringify([width,height]))primaryCorrections++;openingGeometry[name]={phase:phase,geometry:[width,height]};}
    }
    function go(name,action){phase=name;events.push({at:Date.now(),phase:name});console.log("SCREEN_PHASE "+JSON.stringify({phase:name,at:Date.now(),output:outputName,pid:Quickshell.processId}));action();}
    function popup(kind){state.togglePopup(kind,outputName);}
    function setReduced(value){Config.Skin.registry=Object.assign({},Config.Skin.registry,{persona:Object.assign({},Config.Skin.registry.persona || {},{reducedMotion:value})});}
    function saveTrace(){console.log("MOTION_TRACE "+JSON.stringify({checks:checks,settingsCorrections:settingsCorrections,primaryCorrections:primaryCorrections,unexpectedActions:unexpectedActions,events:events,frames:frames}));}
    Timer {interval:600;repeat:true;running:true;onTriggered:{try{
        switch(test.step){
        case 0:test.setReduced(false);test.go("control-open",()=>state.showPrimary("control",test.outputName,"overview","compact"));break;
        case 1:test.check(control.visible && control.surfaceShown,"compact primary opens");test.go("control-route",()=>state.showPrimary("control",test.outputName,"network/wifi","compact"));break;
        case 2:test.go("settings-open",()=>state.showSettings(test.outputName,"network/wifi"));break;
        case 3:test.check(control.nativeSettingsWindow.visible && control.surfaceShown,"native Settings visible");if(!test.baseline)test.check(control.nativeSettingsWindow.width===1280 && control.nativeSettingsWindow.height===860,"native Settings correct final dimensions: "+control.nativeSettingsWindow.width+"x"+control.nativeSettingsWindow.height);if(!test.baseline)test.check(test.settingsCorrections===0,"native Settings has no first-map size correction");test.go("settings-resize",()=>{const window=control.captureItem.Window.window;window.width=1000;window.height=720;});break;
        case 4:test.check(control.nativeSettingsWindow.width===1000,"owned user resize observed");test.go("settings-to-compact",()=>state.showPrimary("control",test.outputName,"overview","compact"));break;
        case 5:test.go("settings-reopen",()=>state.showSettings(test.outputName,"network/wifi"));break;
        case 6:test.check(control.nativeSettingsWindow.width===1000 && control.nativeSettingsWindow.height===720,"Settings restores user size");test.go("performance-open",()=>state.showPrimary("performance",test.outputName,"overview"));break;
        case 7:test.check(performance.visible && performance.surfaceShown && !control.nativeSettingsWindow.visible,"exclusive major replacement");test.go("performance-route",()=>state.showPrimary("performance",test.outputName,"cpu"));break;
        case 8:test.go("insights-open",()=>state.showPrimary("insights",test.outputName,"briefing"));break;
        case 9:test.check(insights.visible && insights.surfaceShown && !performance.visible,"Insights replaces Performance");test.go("insights-reports",()=>state.showPrimary("insights",test.outputName,"reports"));break;
        case 10:test.go("calendar-open",()=>test.popup("calendar"));break;
        case 11:test.check(calendar.visible && calendar.cardShown,"actual Calendar native opening");test.go("audio-open",()=>test.popup("volume"));break;
        case 12:test.check(volume.visible && volume.cardShown && volume.contentItem.Window.window.active && !calendar.visible,"actual Audio replaces Calendar");test.go("network-open",()=>test.popup("network"));break;
        case 13:test.check(networkPopup.visible && networkPopup.cardShown && networkPopup.contentItem.Window.window.active && !volume.visible,"actual Network replaces Audio");test.go("alternate",()=>{for(let i=0;i<12;i++){test.popup("volume");test.popup("network");}test.popup("volume");});break;
        case 14:test.check(volume.visible && volume.cardShown && !networkPopup.visible,"rapid actual Network/Audio ends with one surface");test.go("primary-dismisses-popup",()=>state.showPrimary("performance",test.outputName,"overview"));break;
        case 15:test.check(!state.activePopup && !volume.visible && performance.visible,"opening primary dismisses transient");test.go("session-open",()=>test.popup("power"));break;
        case 16:test.check(power.visible && power.cardShown,"actual Session native opening");test.go("session-select",()=>{const button=input.findChild(power.contentItem,"session-action-lock");test.check(!!button,"Session action exists");button.clicked();});break;
        case 17:test.go("session-schedule",()=>{const contents=input.findChild(power.contentItem,"power-contents");contents.setMode("schedule");});break;
        case 18:test.go("session-review",()=>{session.request("lock");state.externalModalActive=true;});break;
        case 19:test.check(!state.togglePopup("network",test.outputName) && power.visible,"protected review blocks replacement");test.go("session-cancel",()=>{session.cancel();state.externalModalActive=false;state.closePopups();state.closePrimary();});break;
        case 20:test.go("toast-open",()=>{notifications.latest={id:1,receivedAt:1,appName:"Motion QA",summary:"Inert notification",body:"This is a synthetic test record.",urgency:"Normal",actions:[]};notifications.toastGeneration++;});break;
        case 21:test.check(toast.visible && toast.toastShown,"actual notification presentation opens");test.go("toast-replace",()=>{notifications.latest={id:2,receivedAt:2,appName:"Motion QA",summary:"New inert record",body:"The existing native host retains its position.",urgency:"Critical",actions:[]};notifications.toastGeneration++;});break;
        case 22:test.go("toast-close",()=>toast.shown=false);break;
        case 23:test.check(!toast.visible,"toast closes at completion");test.go("reduced-primary",()=>{test.setReduced(true);state.showSettings(test.outputName,"overview");});break;
        case 24:test.check(control.surfaceShown && test.progress(control)===1,"reduced native primary");test.go("reduced-close",()=>state.closePrimary());break;
        case 25:
            if(test.tailStep===0)test.check(!control.nativeSettingsWindow.visible,"reduced close ends immediately");
            if(test.tailStep<10){
                switch(test.tailStep){
                case 0:test.setReduced(false);test.go("session-reopen",()=>test.popup("power"));break;
                case 1:{const body=input.findChild(power.contentItem,"power-contents");test.check(!body.selectedAction && body.mode==="now","fresh Session prepares initial state before mapping");test.go("session-reverse",()=>{body.selectAction("lock");body.setMode("schedule");state.closePopups();test.popup("power");});break;}
                case 2:{const body=input.findChild(power.contentItem,"power-contents");if(!test.baseline)test.check(body.selectedAction==="lock" && body.mode==="schedule","in-flight Session reopen retains editor and size");test.go("session-finish-close",()=>state.closePopups());break;}
                case 3:test.check(!power.visible,"Session retraction completes");test.go("session-fresh-again",()=>test.popup("power"));break;
                case 4:{const body=input.findChild(power.contentItem,"power-contents");test.check(!body.selectedAction && body.mode==="now","new mapping resets Session before presentation");test.go("session-final-close",()=>state.closePopups());break;}
                case 5:test.check(!power.visible,"final Session is hidden");test.go("settings-max-prepare",()=>state.showSettings(test.outputName,"overview"));break;
                case 6:test.go("settings-maximize",()=>test.check(control.setSettingsMaximized(true),"owned Settings maximize request"));break;
                case 7:test.check(control.settingsMaximized,"owned Settings maximize observed");test.go("settings-restore",()=>test.check(control.setSettingsMaximized(false),"owned Settings restore request"));break;
                case 8:test.check(!control.settingsMaximized && control.nativeSettingsWindow.width===1000 && control.nativeSettingsWindow.height===720,"owned Settings restored dimensions");test.go("settings-final-close",()=>state.closePrimary());break;
                case 9:test.check(!control.nativeSettingsWindow.visible,"Settings close completes");test.go("finish",()=>{});break;
                }
                test.tailStep++;test.step--;break;
            }
            test.check(test.unexpectedActions===0,"no real or fixture action dispatch");test.saveTrace();console.log("PASS: native primaries/Settings first-map and remembered geometry, actual quick replacements, protected Session, Calendar, notifications and reduced motion; inert providers only");Qt.quit();return;
        }
        test.step++;
    }catch(e){test.saveTrace();console.error("FAIL:",e);Qt.exit(1);}}}
}
