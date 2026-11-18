//@ pragma UseQApplication
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components" as UI
import "config" as Config
Window {
 id:test;visible:true;width:460;height:160;color:"#303039"
 property int checks:0
 property int expandedActions:0
 property int performanceActions:0
 TestCase {id:input;when:false}
 UI.MachineStateIsland {
  id:island;x:24;y:48;expanded:true
  senomy:({state:"nominal",attentionState:"normal",message:"Power connected · system monitoring active"})
  metrics:({ready:true,cpuPercent:7,memoryPercent:17,memoryTotalKib:1000,temperatureAvailable:true,temperatureCelsius:40,uptimeDetailedLabel:"4h"})
  onToggleExpanded:++test.expandedActions
  onTogglePerformance:++test.performanceActions
 }
 function check(ok,message){++checks;if(!ok)throw new Error(message);}
 function capture(name){let done=false;island.grabToImage(r=>done=r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"));for(let i=0;i<100&&!done;i++)input.wait(10);check(done,"capture "+name);}
 Timer {interval:200;running:true;onTriggered:{try{
  const registry=Config.Skin.registry,records=[];
  for(const touch of [false,true])for(const font of [12,16])for(const width of [360,238,178,138]){
   Config.DirectoryStyle.touchMode=touch;Config.Skin.registry=Object.assign({},registry,{persona:Object.assign({},registry.persona||{},{reducedMotion:true,railTextPx:font})});island.width=width;
   island.senomy=({state:"nominal",attentionState:"normal",message:"Power connected · system monitoring active"});input.wait(35);
   const message=input.findChild(island,"senomy-message-preview"),left=input.findChild(island,"senomy-expand-left"),right=input.findChild(island,"senomy-expand-right");
   check(message.width>0,"message retains an allocation");check(right.x-message.x-message.width>=8,"message clears right arrow");
   if(left){check(message.x-left.x-left.width>=8,"message clears left arrow");check(Math.abs(message.x+message.width/2-island.width/2)<.1,"symmetric text stays centred");}
   check(message.lineCount<=2&&message.height>=message.contentHeight,"bounded message lines fit vertically");
   check(right.width===(touch?48:24),"target follows touch profile");
   const name="message-"+(touch?"touch":"pointer")+"-"+font+"-"+width;
   capture(name);records.push({name:name,width:width,touch:touch,font:font,truncated:message.truncated,lines:message.lineCount,messageX:message.x,messageWidth:message.width});
  }
  Config.DirectoryStyle.touchMode=false;island.width=360;
  island.senomy=({state:"critical",attentionState:"warning",message:"Battery critically low · save your work and connect external power before the session ends"});input.wait(30);capture("message-long-critical");
  island.senomy=({state:"nominal",attentionState:"normal",message:"VeryLongUnbrokenStatusIdentifierThatMustNeverPaintAcrossEitherArrowControl"});input.wait(30);capture("message-unbroken");
  const right=input.findChild(island,"senomy-expand-right");right.forceActiveFocus(Qt.TabFocusReason);input.keyClick(Qt.Key_Space);check(expandedActions===1&&performanceActions===0,"arrow keyboard action does not activate dashboard");
  input.mouseClick(right,right.width/2,right.height/2);check(expandedActions===2&&performanceActions===0,"arrow pointer action is delivered once");
  Config.Skin.registry=registry;Config.DirectoryStyle.touchMode=false;
  console.log("GEOMETRY "+JSON.stringify(records));console.log("PASS: "+checks+" message layout/input checks across 32 width/font/input profiles, long and unbroken text; inert actions only");Qt.quit();
 }catch(e){console.error("FAIL: "+e.message+"\n"+e.stack);Qt.exit(1);}}}
}
