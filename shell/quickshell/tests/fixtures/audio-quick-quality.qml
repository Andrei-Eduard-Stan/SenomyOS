import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Services.Pipewire
import "components"
import "components/audio"
import "services"
import "config" as Config

Window {
    id:test;visible:true;width:900;height:800
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
    QtObject {id:input2;property int id:9;property string description:"USB microphone";property string nickname:"USB mic";property string name:"fixture-usb-mic";property bool ready:true;property bool isSink:false;property bool isStream:false;property int type:PwNodeType.AudioSource;property var properties:({"object.serial":9});property var audio:a2}
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
        function select(p) {test.writes++;}function previous(){test.writes++;}function next(){test.writes++;}function toggle(){playing=!playing;player.isPlaying=playing;test.writes++;}function seek(n){position=n;test.writes++;}function shuffle(){player.shuffle=!player.shuffle;test.writes++;}function repeat(){test.writes++;}
    }

    property int settingsRequests: 0
    property int closes: 0
    property real workWidth: 1920
    property real workHeight: 1080
    Repeater {
        model: 36
        Text { required property int index; y: index*22; text: "BACKGROUND APPLICATION / READABLE TEXT MUST NOT BLEED THROUGH // 0123456789"; color: "white"; font.pixelSize: 18 }
    }
    VolumePopup {
        id: popup
        width: implicitWidth
        height: implicitHeight
        x: 20; y: 20
        availableWidth: test.workWidth - 40
        availableHeight: test.workHeight - Config.Theme.railHeight - 40
        audio: audio
        media: media
        onOpenAudioRequested: test.settingsRequests++
        onDismissRequested: test.closes++
    }
    function check(ok, message) { if (!ok) { console.error("FAIL: "+message); Qt.exit(1); throw new Error(message); } }
    function named(name) { const item=keys.findChild(popup,name); check(item!==null,name+" exists"); return item; }
    function capture(name) {
        let done=false;
        popup.grabToImage(result=>{check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture");done=true;});
        while(!done)keys.wait(20);
    }
    function press(name) { const item=named(name); item.forceActiveFocus(); keys.keyClick(Qt.Key_Return); keys.wait(60); }
    function inView(item) { const p=item.mapToItem(popup,0,0);return p.y>=0 && p.y+item.height<=popup.height; }
    Timer {
        interval: 250; running: true
        onTriggered: {
            backend.nodes=({values:[output,input]});
            output.description="Built-in Audio Analog Stereo";
            keys.wait(100);
            test.check(popup.width===432 && popup.height<560,"content-sized standard panel");
            test.capture("01-standard");
            const outputMute=test.named("quickOutputMute"),inputMute=test.named("quickInputMute");
            test.check(outputMute.width===inputMute.width && outputMute.height===inputMute.height,"mute controls match geometry");
            const mediaView=test.named("quickAudioMedia"),toggle=test.named("quickMediaToggle");
            test.press("quickMediaToggle");test.check(mediaView.expanded,"media strip expands inside Audio");
            test.capture("10-media-expanded");
            const beforeMedia=test.writes;test.press("quickMediaPrevious");test.press("quickMediaPlay");test.press("quickMediaNext");
            test.check(test.writes===beforeMedia+3 && !media.playing,"media controls reach existing facade once each");
            test.check(test.named("quickMediaPrevious").width===test.named("quickMediaPlay").width && test.named("quickMediaPlay").width===test.named("quickMediaNext").width,"media buttons match geometry");
            const seek=test.named("quickMediaSeek");seek.forceActiveFocus();keys.keyClick(Qt.Key_Right);keys.wait(30);test.check(test.writes===beforeMedia+4,"keyboard seeking uses facade");
            player.canSeek=false;keys.wait(20);test.check(!seek.enabled,"unsupported seeking disabled");player.canSeek=true;
            const heldPosition=media.position;keys.mousePress(seek,seek.width*.3,seek.height/2);media.title="Replacement track";keys.mouseRelease(seek,seek.width*.6,seek.height/2);keys.wait(30);test.check(media.position===heldPosition,"track change cancels stale drag");
            media.available=false;keys.wait(20);test.check(!test.named("quickMediaPlay").enabled,"lost player disables transport");test.capture("11-media-empty");media.available=true;
            test.press("quickMediaToggle");test.check(!mediaView.expanded,"media collapses");
            media.playing=true;player.isPlaying=true;media.artist="";media.title="01234567890123456789012345678901234567890123456789";
            // Choose a modest overflow so an actual out-and-back cycle is bounded.
            while(mediaView.overflow>45 && media.title.length>2){media.title=media.title.slice(0,-1);keys.wait(5);}
            popup.forceActiveFocus();keys.mouseMove(test,880,780);keys.wait(100);test.check(mediaView.marqueeRunning && mediaView.overflow>0,"overflowing playing title scrolls");test.capture("12-marquee-start");
            const run=Math.max(700,Math.min(16000,mediaView.overflow/24*1000));keys.wait(1000+run/2);test.check(mediaView.marqueeOffset<0,"marquee travels left");test.capture("13-marquee-left");
            keys.wait(run/2+1000);test.capture("14-marquee-end");keys.wait(run/2);test.capture("15-marquee-return");test.check(mediaView.marqueeOffset>-mediaView.overflow,"marquee returns right");
            media.playing=false;keys.wait(30);test.check(!mediaView.marqueeRunning && mediaView.marqueeOffset===0,"paused text rests at start");
            media.playing=true;const originalRegistry=Config.Skin.registry;Config.Skin.registry=Object.assign({},originalRegistry,{persona:Object.assign({},originalRegistry.persona || {},{reducedMotion:true})});keys.wait(30);test.check(!mediaView.marqueeRunning,"reduced motion stops scrolling");Config.Skin.registry=originalRegistry;
            test.workHeight=400;test.named("quickAudioClose").forceActiveFocus();keys.wait(50);mediaView.viewport.contentY=0;keys.wait(30);test.check(!mediaView.marqueeRunning,"clipped-off strip stops scrolling");test.workHeight=1080;keys.wait(50);mediaView.viewport.contentY=0;
            mediaView.active=false;keys.wait(20);test.check(!mediaView.marqueeRunning,"hidden/inactive panel stops scrolling");mediaView.active=true;
            // Reset the fixture before exercising the unchanged audio contracts.
            media.title="A long track title that wraps instead of overlapping neighboring controls";media.artist="Local artist";test.writes=0;popup.forceActiveFocus();keys.wait(30);
            const singleHeight=popup.height;test.check(!test.named("quickAudioDevices").visible,"single endpoints need no duplicate chooser");
            popup.forceActiveFocus();keys.mouseMove(test,880,780);keys.wait(30);test.capture("16-pointer-rest");
            keys.mouseMove(test.named("quickOutputSlider"),50,20);keys.wait(220);test.capture("17-pointer-slider");
            keys.mouseMove(test.named("quickOutputMute"),40,20);keys.wait(220);test.capture("18-pointer-mute");
            popup.forceActiveFocus();
            const visited=[];
            for(let i=0;i<12;i++){keys.keyClick(Qt.Key_Tab);keys.wait(10);visited.push(test.activeFocusItem ? test.activeFocusItem.objectName : "");}
            for(const name of ["quickAudioClose","quickOutputSlider","quickOutputMute","quickInputSlider","quickInputMute","quickAudioSettings"])test.check(visited.indexOf(name)>=0,"Tab reaches "+name);

            const slider=test.named("quickOutputSlider");
            slider.forceActiveFocus();keys.keyClick(Qt.Key_Left);keys.wait(80);
            test.check(Math.abs(audio.volume-0.5)<0.001,"output keyboard volume reaches native facade");
            test.press("quickOutputMute");test.check(audio.muted,"output mute writes backend");test.check(test.named("quickOutputMute").width===test.named("quickInputMute").width,"mute label change preserves equal width");
            test.capture("02-muted-focus");
            test.press("quickOutputMute");test.check(!audio.muted,"output unmute");
            test.press("quickInputMute");test.check(audio.inputMuted,"input mute");test.check(test.named("quickOutputMute").width===test.named("quickInputMute").width,"input label change preserves equal width");test.press("quickInputMute");
            const inputSlider=test.named("quickInputSlider");inputSlider.forceActiveFocus();keys.keyClick(Qt.Key_Right);keys.wait(80);
            test.check(Math.abs(audio.inputVolume-0.63)<0.001,"input keyboard volume");
            // Actual pointer drag, local feedback, and release flush.
            keys.mousePress(slider,slider.width*0.3,slider.height/2);
            keys.mouseMove(slider,slider.width*0.7,slider.height/2,10);
            test.check(test.named("quickOutputValue").text===Math.round(slider.value*100)+"%","drag value feedback immediate");
            keys.mouseRelease(slider,slider.width*0.7,slider.height/2);keys.wait(80);
            test.check(Math.abs(audio.volume-slider.value)<0.001,"drag reaches backend after release");
            test.press("quickAudioSettings");test.check(test.settingsRequests===1,"settings signal exactly once");
            backend.nodes=({values:[output,input,output2]});keys.wait(80);
            test.check(test.named("quickAudioDevices").visible && popup.height>singleHeight,"multiple devices expand choices");
            test.press("quickAudioDevices");test.press("quickAudioDevices");keys.wait(100);test.capture("03-devices");
            test.press("quickDevice-fixture-usb");
            test.check(audio.selectionActions.actionState==="pending","device needs confirmation");
            test.check(backend.preferredDefaultAudioSink===output,"request has no device mutation");
            test.capture("04-device-review");test.press("selectionCancel");
            test.check(audio.selectionActions.actionState==="idle","cancel leaves backend intact");
            test.press("quickDevice-fixture-usb");test.press("selectionConfirm");
            test.check(backend.preferredDefaultAudioSink===output2,"confirmed device choice reaches backend");
            backend.defaultAudioSink=output2;keys.wait(300);
            test.check(audio.selectionActions.actionState==="succeeded","selection observes backend");
            audio.selectionActions.actionState="idle";
            backend.defaultAudioSink=output;
            backend.nodes=({values:[output,input,output2,input2]});keys.wait(80);
            test.press("quickDevice-fixture-usb-mic");test.check(audio.selectionActions.actionState==="pending","input selection reviewed");test.press("selectionCancel");
            test.check(backend.preferredDefaultAudioSource===input,"input cancellation preserves source");
            test.press("quickDevice-fixture-usb-mic");test.press("selectionConfirm");test.check(backend.preferredDefaultAudioSource===input2,"input confirmation reaches backend");
            backend.defaultAudioSource=input2;keys.wait(300);test.check(audio.selectionActions.actionState==="succeeded","input selection observed");audio.selectionActions.actionState="idle";
            backend.defaultAudioSource=input;backend.nodes=({values:[output,input]});keys.wait(80);test.check(!test.named("quickAudioDevices").visible && popup.height<singleHeight+4,"hotplug returns to compact single-device layout");
            backend.nodes=({values:[output,input,output2]});keys.wait(80);
            test.workWidth=360;test.workHeight=480;keys.wait(80);
            output.description="USB headphones / long endpoint name with <b>literal markup</b>";
            test.capture("05-narrow-short");
            test.named("quickAudioSettings").forceActiveFocus();keys.wait(80);
            test.check(test.inView(test.named("quickAudioSettings")),"scroll reveals focused settings in short output");
            Config.DirectoryStyle.touchMode=true;keys.wait(80);test.capture("06-touch");
            test.check(test.named("quickInputMute").height>=48,"touch target floor");
            Config.DirectoryStyle.touchMode=false;
            const largeType=JSON.parse(JSON.stringify(Config.Skin.registry));
            largeType.persona=Object.assign({},largeType.persona || {},{uiTextScale:1.5,highContrast:true});
            Config.Skin.registry=largeType;keys.wait(80);test.capture("09-large-type-contrast");
            largeType.persona.uiTextScale=1;largeType.persona.highContrast=false;
            Config.Skin.registry=JSON.parse(JSON.stringify(largeType));
            test.workWidth=1920;test.workHeight=1080;

            backend.ready=false;keys.wait(80);test.capture("07-unavailable");
            test.check(!test.named("quickOutputSlider").enabled && !test.named("quickInputMute").enabled,"lost provider disables actions");
            backend.ready=true;backend.nodes=({values:[]});backend.defaultAudioSink=null;backend.defaultAudioSource=null;keys.wait(80);test.capture("08-empty");
            const registry=JSON.parse(JSON.stringify(Config.Skin.registry));registry.persona=Object.assign({},registry.persona || {},{reducedMotion:true});Config.Skin.registry=registry;keys.wait(30);
            test.check(Config.QuickPanelStyle.openMs===0,"reduced motion token");
            popup.forceActiveFocus();keys.keyClick(Qt.Key_Escape);keys.wait(20);test.check(test.closes===1,"escape routes to owner");
            test.press("quickAudioClose");test.check(test.closes===2,"close button routes to owner");
            console.log("PASS: media expand/collapse, facade transports, seek capability/stale-track guard, lost player, marquee left/right/paused/reduced-motion/clipped/inactive states; matched mute/media geometry; Audio quick controls pointer/keyboard gain, immediate drag feedback, mute/input, guarded device apply/cancel, deep link, short/narrow/touch/error/empty and reduced motion; fake PipeWire only");
            Qt.quit();
        }
    }
}
