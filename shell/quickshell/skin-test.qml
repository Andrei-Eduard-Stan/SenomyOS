import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services" as Services
import "config" as Config
import "services/SystemHealth.js" as Health
import "config/SkinSchema.js" as Schema

Window {
 id: test
 visible:true; width:1000;height:700;color:"#15151a"
 TestCase { id: input; name:"SkinInput"; when:false }
 property int phase:0
 property string out:Quickshell.env("SENOMY_QA_OUT")
 property var metrics:({ready:true,cpuPercent:20,memoryPercent:30,memoryTotalKib:16000000,memoryUsedKib:4800000,uptimeDetailedLabel:"02:14:09",temperatureAvailable:true,temperatureCelsius:49})
 property var battery:({available:true,onBattery:true,percentage:.5})
 property var network:({available:true,connectivityName:"Full"})
 property var message:({state:"idle",message:"System steady",attentionState:"clear"})
 property int clicks:0
 property var snapshot:null
 Rectangle {
  id:whitePreview;x:570;y:115;width:410;height:88;color:"white"
  MachineStateIsland {anchors.centerIn:parent;metrics:test.metrics;senomy:test.message}
 }
 PersonaBackground {
  id:backgroundTest;visible:false;width:360;height:64
  spec:({source:"../../assets/senomy/senomy_machine_medallion.png",scaling:"fit"})
 }
 Services.TemperatureService { id: temperature }
 Services.ShellState { id: ui }
 QtObject { id: batteryObject; property bool available:true; property bool onBattery:true; property real percentage:0.5 }
 Services.SenomyState { id: senomy; shellState:ui;media:({});battery:batteryObject;network:test.network;metrics:test.metrics;notifications:({}) }
 function check(ok, label) { if(!ok) throw new Error(label); }
 function activation() { island.expanded=false;ui.showPrimary("performance","fixture","overview");test.clicks++; }
 Column {
  id: capture; anchors.fill:parent;anchors.margins:20;spacing:16
  Text { text:"SINGLE-SOURCE ART / FIXED CORNERS AND CRESTS";color:"white";font.pixelSize:16 }
  Row {
   spacing:16
   SenomyFrame { id: small; frameKey:"workspace";width:54;height:64;Text { anchors.centerIn:parent;text:"IV";color:"white" } }
   SenomyFrame { id: wide; frameKey:"workspace";width:240;height:64;Text { anchors.centerIn:parent;text:"ADAPTIVE WIDTH";color:"white" } }
   SenomyFrame { id: stateFrame;frameKey:"context";width:300;height:64;active:true }
  }
  MachineStateIsland { id:island; performanceOpen:ui.activePrimary==="performance"; metrics:test.metrics;senomy:test.message;onTogglePerformance:test.activation();onToggleExpanded:expanded=!expanded }
  Row {
   spacing:12
   MachineStateIsland { width:178;ultraCompact:true; metrics:test.metrics;senomy:test.message }
   MachineStateIsland { width:138;microCompact:true; metrics:test.metrics;senomy:test.message }
  }
  Row {
   spacing:12
   SurfaceButton {text:"Native control";active:true}
   SurfaceCard {title:"Telemetry";value:"30%";detail:"Artwork owns its frame"}
   HistoryChart { width:300;values:[12,14,35,22,40];label:"LIVE DATA";currentLabel:"40%" }
  }
  SenomyFrame { id: panel;frameKey:"calendar";tier:"standard";width:600;height:190;Text {anchors.centerIn:parent;text:"ONE PANEL SVG · FLEXIBLE CENTRE";color:"white"} }
 }
 Timer {
  interval:600;repeat:true;running:true
  onTriggered: {
   try {
    if(test.phase===0) {
     test.check(Config.Skin.error==="",Config.Skin.error);
     test.check(small.useArt && wide.useArt && panel.useArt,"art ready at chip, wide, panel dimensions");
     test.check(wide.skinSpec.fixedCenterWidth===10,"crest contract loaded");
     test.check(wide.artRenderer.xs[0].length===16 && wide.artRenderer.xs[2].length===10 && wide.artRenderer.xs[4].length===16,"fixed corners and crest do not stretch");
     let rejected=false;
     try { Schema.validate({schemaVersion:1,defaultMode:"art",frames:{bad:{source:"x",logicalSize:[20,20],scaling:"nine-slice",insets:{left:12,right:12,top:1,bottom:1}}}}); } catch(e) { rejected=true; }
     test.check(rejected,"invalid insets rejected before publication");
     test.check(!island.useArt && !island.nativeFrameEnabled,"Senomy remains borderless");
     test.check(island.portraitSize===island.height-10 && island.portraitCenterX===island.width/2,"avatar uses full height at the true centre");
     test.check(island.textSize===12,"consistent Rail typography");
     test.check(backgroundTest.imageReady,"background image support");
     whitePreview.grabToImage(r=>r.saveToFile(test.out+"/senomy-white-background.png"));
     test.snapshot={message:senomy.message};
     island.expanded=true;
     test.check(island.messagePreview,"expansion switches to the system message");
     input.mouseClick(island,30,20);
     test.check(!island.expanded && ui.activePrimary==="performance","expanded activation opens dashboard");
     test.check(!island.messagePreview,"closing expanded context restores the portrait even with dashboard open");
     ui.closePrimary();
     test.check(!island.messagePreview,"dashboard close restores default layout");
     island.expanded=true;island.expanded=false;
     test.check(!island.messagePreview,"collapse without dashboard restores default layout");
     island.forceActiveFocus();input.keyClick(Qt.Key_Return);
     test.check(test.clicks===2,"pointer and keyboard route to dashboard");
     input.mouseClick(island,30,30);
     test.check(test.clicks===3,"main activation remains beside arrow regions");
     input.mouseClick(island,island.width-18,island.height/2);
     test.check(island.expanded && test.clicks===3,"explicit expansion remains a separate control");
     input.mouseClick(island,35,35);
     test.check(ui.activePrimary==="performance","repeated activation never closes dashboard");
     test.check(senomy.message===test.snapshot.message,"activation retains message");
     capture.grabToImage(r=>r.saveToFile(test.out+"/skin-art.png"));
    } else if(test.phase===1) {
     ui.closePrimary();
     small.borderType="native";wide.borderType="native";panel.borderType="native";
     backgroundTest.spec={source:"file:///nonexistent-senomy-background.png"};
     stateFrame.skinSpec=Object.assign({},stateFrame.skinSpec,{variants:{active:"file:///nonexistent-senomy-qa-state.svg"}});
     test.message={state:"battery-low",message:"Battery low. Get us a charger.",attentionState:"warning"};
    } else if(test.phase===2) {
     test.check(!backgroundTest.imageReady,"missing background leaves native backing");
     test.check(!small.useArt&&!wide.useArt,"native fallback switch");
     test.check(stateFrame.useArt,"missing state artwork inherits normal artwork");
     capture.grabToImage(r=>r.saveToFile(test.out+"/skin-native.png"));
     wide.borderType="art";wide.artSource="file:///nonexistent-senomy-qa-frame.svg";
    } else if(test.phase===3) {
     test.check(!wide.useArt,"missing art preserves native frame");
     const m=Object.assign({},test.metrics);const b=Object.assign({},test.battery);const n=test.network;
     let model=Health.createResolver();
     b.percentage=.05;
     test.check(Health.resolve(model,m,b,n,[{id:"event",message:"Complete",priority:300,expiresAt:90000}],false,0).id==="battery-critical","critical beats completion");
     b.percentage=.09;
     test.check(Health.resolve(model,m,b,n,[],false,1000).id==="battery-critical","critical recovery hysteresis");
     b.onBattery=false;
     test.check(Health.resolve(model,m,b,n,[],false,2000).id==="power","plugged warning clears");
     b.available=false;m.cpuPercent=95;model=Health.createResolver();
     test.check(Health.resolve(model,m,b,n,[],false,0).id!=="cpu-high","brief CPU spike ignored");
     test.check(Health.resolve(model,m,b,n,[],false,11000).id==="cpu-high","sustained CPU warning");
     m.cpuPercent=85;
     test.check(Health.resolve(model,m,b,n,[],false,12000).id==="cpu-high","CPU hysteresis");
     m.cpuPercent=50;
     test.check(Health.resolve(model,m,b,n,[],false,13000).id==="nominal","CPU recovers");
     test.check(Health.resolve(model,m,b,n,[{id:"event",message:"Complete",priority:300,expiresAt:15000}],false,14000).id==="event","event selected");
     test.check(Health.resolve(model,m,b,n,[{id:"event",message:"Complete",priority:300,expiresAt:15000}],false,16000).id==="nominal","event expiry");
     b.available=true;b.onBattery=true;b.percentage=.15;
     test.check(Health.resolve(model,m,b,n,[],true,17000).id==="battery-low","expected load cannot hide battery warning");
     console.log("PASS: sliced frames, native/missing fallback, persistent status, idempotent dashboard, priority, hysteresis, expiry; temperature available="+temperature.available);
     Qt.quit();
    }
    test.phase++;
   } catch(e) {console.error("FAIL: "+e);Qt.exit(1);}
  }
 }
}