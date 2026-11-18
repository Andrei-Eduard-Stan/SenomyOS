import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Services.Pipewire
import "components"
import "components/audio"
import "services"

Window {
    id:test;visible:true;width:1000;height:800
    property int caseIndex:0
    property var cases:["overview","mixer","devices","media","diagnostics"]
    property int phase:0
    property int writes:0
    TestCase {id:keys;when:false}
    QtObject {id:a1;property real volume:0.51;property bool muted:false;property var channels:[PwAudioChannel.FrontLeft,PwAudioChannel.FrontRight];property var volumes:[0.51,0.51]}
    QtObject {id:a2;property real volume:0.62;property bool muted:false;property var channels:[PwAudioChannel.Mono];property var volumes:[0.62]}
    QtObject {id:output;property int id:4;property string description:"Very long USB / Bluetooth output name · wide and narrow device labels must remain readable";property string nickname:"Output";property string name:"fixture-output";property bool ready:true;property bool isSink:true;property bool isStream:false;property int type:PwNodeType.AudioSink;property var properties:({"object.serial":4});property var audio:a1}
    QtObject {id:input;property int id:5;property string description:"Built-in microphone";property string nickname:"Input";property string name:"fixture-input";property bool ready:true;property bool isSink:false;property bool isStream:false;property int type:PwNodeType.AudioSource;property var properties:({"object.serial":5});property var audio:a2}
    QtObject {id:streamAudio;property real volume:0.42;property bool muted:false;property var channels:[PwAudioChannel.Mono];property var volumes:[0.42]}
    QtObject {id:stream;property int id:6;property string description:"Browser · music playback";property string nickname:"Browser";property string name:"fixture-stream";property bool ready:true;property bool isSink:false;property bool isStream:true;property int type:PwNodeType.AudioOutStream;property var properties:({"application.name":"Browser","object.serial":6,"application.id":"fixture.browser"});property var audio:streamAudio}
    QtObject {id:recordAudio;property real volume:0.75;property bool muted:false;property var channels:[PwAudioChannel.Mono];property var volumes:[0.75]}
    QtObject {id:record;property int id:7;property string description:"Call app · microphone capture";property string nickname:"Call";property string name:"fixture-record";property bool ready:true;property bool isSink:true;property bool isStream:true;property int type:PwNodeType.AudioInStream;property var properties:({"application.name":"Call app","object.serial":7,"application.id":"fixture.call"});property var audio:recordAudio}
    QtObject {id:output2;property int id:8;property string description:"USB headphones";property string nickname:"USB";property string name:"fixture-usb";property bool ready:true;property bool isSink:true;property bool isStream:false;property int type:PwNodeType.AudioSink;property var properties:({"object.serial":8});property var audio:a1}
    QtObject {id:backend;property bool ready:true;property var defaultAudioSink:output;property var defaultAudioSource:input;property var preferredDefaultAudioSink:output;property var preferredDefaultAudioSource:input;property var nodes:({values:[output,input,stream,record,output2]});property var linkGroups:({values:[{source:stream,target:output,state:PwLinkState.Active},{source:input,target:record,state:PwLinkState.Active}]})}
    AudioService {
        id:audio;pipewire:backend;nativeProvider:false;adapterEnabled:false;persistenceEnabled:false;active:true;actionContext:"audio:fixture"
        graphSnapshot:({available:true,generation:"fixture",canMove:true,error:"",nodes:[{id:4,token:"f:4",revision:"o",serial:"4",name:"Output",class:"Audio/Sink",movable:true},{id:5,token:"f:5",revision:"i",serial:"5",name:"Input",class:"Audio/Source",movable:true},{id:6,token:"f:6",revision:"s",serial:"6",name:"Stream",class:"Stream/Output/Audio",movable:true,routes:[4]},{id:7,token:"f:7",revision:"r",serial:"7",name:"Recorder",class:"Stream/Input/Audio",movable:true,routes:[5]},{id:8,token:"f:8",revision:"e2",serial:"8",name:"USB headphones",class:"Audio/Sink",movable:true}],cards:[{id:2,token:"f:2",revision:"c",name:"Fixture sound card",canProfile:true,canPort:true,profile:0,profiles:[{index:0,name:"Analog stereo",available:"yes"},{index:1,name:"Duplex",available:"yes"}],ports:[{index:0,name:"Speakers",available:"yes",direction:"Output",profiles:[0]},{index:1,name:"Headphones",available:"unknown",direction:"Output",profiles:[0]}],activePorts:[{index:0,device:0,direction:"Output"}]}]})
    }
    QtObject {
        id:player;property string identity:"Fixture player";property string uniqueId:"fixture";property bool isPlaying:true;property bool canGoPrevious:true;property bool canGoNext:true;property bool canTogglePlaying:true;property bool canSeek:true;property bool canControl:true;property bool positionSupported:true;property bool lengthSupported:true;property bool loopSupported:true;property bool shuffleSupported:true;property bool shuffle:false;property int loopState:0
    }
    QtObject {
        id:media;property bool available:true;property bool playing:true;property var selectedPlayer:player;property var players:[player];property string identity:"Fixture player";property string title:"A long track title that wraps instead of overlapping neighboring controls";property string artist:"Local artist";property string artwork:"";property real duration:240;property real position:42
        function select(p) {test.writes++;}function previous(){test.writes++;}function next(){test.writes++;}function toggle(){test.writes++;}function seek(n){position=n;test.writes++;}function shuffle(){player.shuffle=!player.shuffle;test.writes++;}function repeat(){test.writes++;}
    }
    ShellSurfaceFrame {
        anchors.fill:parent
        AudioPanel {id:panel;anchors.fill:parent;audio:audio;media:media;visible:test.phase!==2}
        FocusScrollArea {id:quickScroll;anchors.fill:parent;visible:test.phase===2;contentHeight:quick.implicitHeight;AudioQuickControls {id:quick;width:parent.width;audio:audio;media:media}}
    }
    function check(condition,message) {if(!condition){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
    function walk(item) {if(item.visible && item.activeFocusOnTab && item.width>0){check(Number.isFinite(item.width) && item.width>=0,"negative control size");}for(const child of item.children || [])walk(child);}
    function runBehavior() {
        check(audio.playbackStreams.length===1 && audio.recordingStreams.length===1,"stream directions");check(audio.recordingCount===1,"recording link evidence");
        check(audio.setNodeVolume(stream,2) && streamAudio.volume===1,"standard cap");audio.amplification=true;audio.setNodeVolume(stream,2);check(streamAudio.volume===1.5,"amplification cap");audio.amplification=false;
        audio.toggleNodeMuted(stream);check(streamAudio.muted,"stream mute");audio.setBalance(output,1);check(a1.volumes[0]===0 && a1.volumes[1]===0.51,"channel balance");audio.setBalance(output,0);
        check(!audio.setNodeVolume({ready:true,audio:a1},0.4),"stale node gate");check(!audio.setNodeVolume(output,NaN),"finite volume gate");
        const card=audio.graphSnapshot.cards[0];check(audio.graphActions.request("profile",card,1,"Duplex"),"profile review");check(audio.graphActions.actionState==="pending","confirmation required");audio.graphActions.cancel();check(audio.graphActions.actionState==="idle","cancel");
        audio.graphActions.request("profile",card,1,"Duplex");audio.actionContext="";check(audio.graphActions.actionState==="idle","context cancellation");audio.actionContext="audio:fixture";
        audio.graphActions.request("profile",card,1,"Duplex");const snap=JSON.parse(JSON.stringify(audio.graphSnapshot));snap.cards[0].revision="changed";audio.graphSnapshot=snap;check(audio.graphActions.actionState==="failed","stale inventory gate");audio.graphActions.actionState="idle";
        check(test.writes===0,"no real/provider actions invoked in screenshot tests");
    }
    function findVisible(item,name) {
        if(item.visible && item.objectName===name)return item;
        for(const child of item.children || []){const found=findVisible(child,name);if(found)return found;}
        return null;
    }
    function uiBehavior() {
        const chooser=findVisible(panel,"audioStreamRoute");check(chooser!==null,"stream route chooser exists");chooser.forceActiveFocus();keys.keyClick(Qt.Key_Space);keys.wait(40);keys.keyClick(Qt.Key_End);keys.keyClick(Qt.Key_Return);keys.wait(40);
        check(audio.graphActions.actionState==="pending","keyboard route selection stages review");
        const cancel=findVisible(panel,"selectionCancel");check(cancel!==null,"cancel control visible");cancel.forceActiveFocus();keys.keyClick(Qt.Key_Return);keys.wait(40);check(audio.graphActions.actionState==="idle","keyboard cancels route without mutation");
        const search=findVisible(panel,"audioStreamSearch");search.forceActiveFocus();for(const character of "missing")keys.keyClick(character);keys.wait(40);check(findVisible(panel,"audioStreamRoute")===null,"search removes nonmatching streams");search.clear();keys.wait(40);
        check(audio.rememberedRoute(stream)===null,"no default remembered rules");audio.preferences=({schemaVersion:1,amplification:false,routes:[{direction:"playback",appKey:"id:fixture.browser",endpointName:"fixture-usb"}]});check(audio.rememberedEndpoint(stream)===output2,"saved stable endpoint resolution");
        check(audio.requestMove(stream,audio.rememberedEndpoint(stream)),"saved route uses same guard");check(audio.graphActions.actionState==="pending","saved route requires confirmation");audio.graphActions.cancel();
        check(test.writes===0,"UI review/search tests do not invoke device actions");
    }
    function capture() {
        if(test.phase===0 && panel.route==="mixer")uiBehavior();
        walk(panel);const label=test.phase===2?"quick":test.phase===4?"review":panel.route;
        test.contentItem.grabToImage(result=>{check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/audio-"+label+"-"+test.width+(test.phase>=3?"-"+test.height:"")+".png"),"capture");advance();});
    }
    function advance() {
        if(phase===2){phase=3;width=390;height=320;panel.route="overview";waiter.restart();return;}
        if(phase===3){phase=4;audio.graphActions.request("profile",audio.graphSnapshot.cards[0],1,"Duplex");waiter.restart();return;}
        if(phase===4){const cancel=findVisible(panel,"selectionCancel");check(cancel!==null,"constrained confirmation accessible");cancel.forceActiveFocus();keys.wait(40);const p=cancel.mapToItem(test.contentItem,0,0);check(p.y>=0 && p.y+cancel.height<=test.height,"review cancel inside constrained viewport");audio.graphActions.cancel();console.log("PASS: modular Audio routes, narrow popup, native facade stream/mute/balance/caps and guarded stale/context cancellation; fake providers only");Qt.quit();return;}
        caseIndex++;
        if(caseIndex>=cases.length){caseIndex=0;phase++;if(phase===1)width=390;if(phase===2){width=480;height=700;quick.chooserOpen=true;}}
        panel.route=cases[caseIndex];waiter.restart();
    }
    Timer {id:waiter;interval:180;onTriggered:test.capture()}
    Component.onCompleted:{runBehavior();waiter.restart();}
}
