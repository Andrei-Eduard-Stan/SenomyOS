import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtTest
import Quickshell
import Quickshell.Services.SystemTray
import "components"
import "components/audio" as Audio
import "components/calendar" as CalendarUi
import "components/tray" as Tray
import "components/lens" as Lens
import "config" as Config
Window {
 id:test; visible:true; width:1120; height:1000; color:Config.DirectoryStyle.glass
 property int activations:0
 TestCase {id:input;when:false}
 Rectangle {anchors.fill:parent;color:Config.DirectoryStyle.glass}
 Text {x:24;y:18;text:"SENOMYOS / SHARED CENTRE-OUT HOVER";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:16;color:Config.DirectoryStyle.ink}
 Grid {
  x:24;y:55;columns:3;columnSpacing:24;rowSpacing:16
  Item {width:338;height:118;Text {text:"ACTION";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   ShellButton { id:action; objectName:"sample-action"; y:26; width:338; height:64;  text:"REVIEW & APPLY"; onClicked:test.activations++ }
  }
  Item {width:338;height:118;Text {text:"HEADER";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   ShellButton { id:header; objectName:"sample-header"; y:26; width:338; height:64;  text:"BACK"; headerControl:true; onClicked:test.activations++ }
  }
  Item {width:338;height:118;Text {text:"DESTINATION";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   DirectoryButton { id:destination; objectName:"sample-destination"; y:26; width:338; height:64;  text:"Audio diagnostics"; detail:"Output, input and collected evidence"; onClicked:test.activations++ }
  }
  Item {width:338;height:118;Text {text:"LEGACY";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   ExpandedButton { id:legacy; objectName:"sample-legacy"; y:26; width:338; height:64;  text:"Copy report"; subtle:true; onClicked:test.activations++ }
  }
  Item {width:338;height:118;Text {text:"COMBO";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   ShellComboBox { id:combo; objectName:"sample-combo"; y:26; width:338; height:64;  model:["Balanced", "Performance", "Quiet"] }
  }
  Item {width:338;height:118;Text {text:"CHECK";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   ShellCheckBox { id:checkbox; objectName:"sample-check"; y:26; width:338; height:64;  text:"Allow amplification" }
  }
  Item {width:338;height:118;Text {text:"COMMAND";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   SessionCommand { id:command; objectName:"sample-command"; y:26; width:338; height:64;  text:"LOCK SESSION"; icon:""; onClicked:test.activations++ }
  }
  Item {width:338;height:118;Text {text:"SEGMENTS";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   SessionSegments { id:segments; objectName:"sample-segments"; y:26; width:338; height:64;  choices:[{id:"now",label:"Now"},{id:"later",label:"Later"}]; value:"later" }
  }
  Item {width:338;height:118;Text {text:"CONTROLS";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   SystemControlsIsland { id:controls; objectName:"sample-controls"; y:26;  width:338; height:64; audio:({available:true,muted:false,volume:0.3}); network:({available:true,detail:"Fixture network",connectivityName:"Full"}); battery:({available:true,detail:"Fixture power",charging:false,percentage:0.7}); onOpenControl:section=>test.activations++ }
  }
  Item {width:338;height:118;Text {text:"CLOCK";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   ClockIsland { id:clock; objectName:"sample-clock"; y:26;  width:184; height:64; notifications:({unreadCount:3,dnd:false}); onToggleCalendar:test.activations++ }
  }
  Item {width:338;height:118;Text {text:"WORKSPACE";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   WorkspaceChip { id:workspace; objectName:"sample-workspace"; y:26;  width:58; height:64; workspace:({id:1,active:false,toplevels:{values:[]},activate:()=>test.activations++}) }
  }
  Item {width:338;height:118;Text {text:"POWER";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   PowerIsland { id:power; objectName:"sample-power"; y:26;  width:64; height:64; powerService:({hasSchedule:false,schedule:{label:""},remainingText:"",progress:0,remainingSeconds:1000}); onTogglePower:test.activations++ }
  }
  Item {width:338;height:118;Text {text:"DEVICE";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   Audio.QuickAudioDevice { id:device; objectName:"sample-device"; y:26; height:64;  width:338; audio:({ready:true,source:null,sink:null,actionsLocked:false,selectOutput:()=>test.activations++}); node:({name:"fixture",description:"Speakers",ready:true}) }
  }
  Item {width:338;height:118;Text {text:"DATE";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   CalendarUi.CalendarDayCell { id:dayCell; objectName:"sample-date"; y:26; height:64;  width:48; date:new Date(2026,10,8); today:true; onClicked:test.activations++ }
  }
  Item {width:338;height:118;Text {text:"TRAY";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   Tray.TrayMenuRow { id:tray; objectName:"sample-tray"; y:26; width:338; height:64;  label:"Open application"; entry:({enabled:true,isSeparator:false,buttonType:0,hasChildren:false,icon:""}); onClicked:test.activations++ }
  }
  Item {width:338;height:118;Text {text:"LENS";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   Lens.LensResult { id:lens; objectName:"sample-lens"; y:26; width:338; height:64;  row:({kind:"apps",label:"Calculator",detail:"Fixture application",id:"app",info:""}); onChosen:location=>test.activations++ }
  }
  Item {width:338;height:118;Text {text:"MENUITEM";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   ShellMenuItem { id:menuitem; objectName:"sample-menuitem"; y:26; width:338; height:64;  text:"Copy diagnostic evidence"; onTriggered:test.activations++ }
  }
  Item {width:338;height:118;Text {text:"OVERFLOW";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
   ContextActionMenu { id:overflow; objectName:"sample-overflow"; y:26;  actions:[{id:"copy",label:"Copy evidence"},{id:"disabled",label:"Unavailable",enabled:false,reason:"Fixture"}]; onActionRequested:action=>test.activations++ }
  }
 }
 function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw Error(message);}}
 function capture(name){let done=false;test.contentItem.grabToImage(result=>{test.check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture "+name);done=true;});for(let i=0;i<100&&!done;i++)input.wait(10);test.check(done,"capture completed");}
 function captureItem(name,item){let done=false;item.grabToImage(result=>{test.check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture "+name);done=true;});for(let i=0;i<100&&!done;i++)input.wait(10);test.check(done,"item capture completed");}
 function chromeCount(item){
  if(!item.visible||item.opacity===0)return 0;
  let count=0;
  if(item.border!==undefined && (item.border.width>0 || (item.color!==undefined && item.color.a>0)))count++;
  for(const child of item.children)count+=chromeCount(child);
  return count;
 }
 Item {id:focusSink;x:1090;y:880;width:20;height:10}
 function reset(){input.mouseMove(test.contentItem,1110,890);focusSink.forceActiveFocus();input.wait(240);}
 function fixFrame(item){return input.findChild(item,"button-hover-frame");}
 function frame(item){return input.findChild(item,"button-hover-frame");}
 MachineStateIsland { id:machine; y:910;x:24; width:360;height:64; senomy:({state:"nominal",attentionState:"normal",message:"Fixture status"});metrics:({ready:true,cpuPercent:7,memoryPercent:17,memoryTotalKib:1000,temperatureAvailable:true,temperatureCelsius:40,uptimeDetailedLabel:"4h",uptimeLabel:"4h"}) }
 Timer {interval:350;running:true;onTriggered:{
  const original=Config.Skin.registry;
  Config.Skin.registry=Object.assign({},original,{persona:Object.assign({},original.persona||{},{reducedMotion:false})});
  const targets=[action,header,destination,legacy,combo,checkbox,command,input.findChild(segments,"session-mode-now"),input.findChild(controls,"rail-control-control"),input.findChild(clock,"rail-calendar-button"),device,dayCell,tray,lens,menuitem,input.findChild(overflow,"context-menu-trigger")];
  test.reset();test.capture("01-rest");const records=[];
  for(let i=0;i<targets.length;i++){
   const item=targets[i];test.check(!!item,"target "+i);
   const f=test.frame(item);test.check(!!f,"shared frame "+i);
   const g=input.findChild(f,"button-hover-geometry");test.check(g.item===null,"no idle geometry "+i);
   test.check(f.inset>=5.9,"inward hover margin "+i);
   const bounds=[item.x,item.y,item.width,item.height],fill=item.color===undefined?null:String(item.color);
   input.mouseMove(item,item.width/2,item.height/2);input.wait(60);
   const early=f.progress;test.check(early>0&&early<1,"border expands over time "+i+" progress "+f.progress);
   if(i===0)test.capture("02-expanding");
   input.wait(180);test.check(f.progress===1&&g.item!==null,"completed perimeter "+i);
   test.check(bounds.join() === [item.x,item.y,item.width,item.height].join(),"no layout movement "+i);
   if(fill!==null)test.check(fill===String(item.color),"no hover fill "+i);
   records.push({index:i,name:item.objectName,earlyProgress:early,progress:f.progress,width:item.width,height:item.height});
   if(i===0 || i>=8)test.capture("03-hover-"+i);
   test.reset();test.check(f.progress===0&&g.item===null,"leave releases geometry "+i);
  }
  // Native pressed states must not paint a wash or a second rectangular perimeter.
  for(const target of [action,header,destination,legacy,command,input.findChild(segments,"session-mode-now"),device,dayCell,tray,menuitem]){
   test.reset();input.mouseMove(target,target.width/2,target.height/2);input.wait(220);
   const baselineChrome=test.chromeCount(target);test.check(baselineChrome===(target===dayCell?1:0),"only semantic markers before press "+target.objectName);
   input.mousePress(target,target.width/2,target.height/2);input.wait(30);
   test.check(test.chromeCount(target)===baselineChrome,"no press overlay or square border "+target.objectName);
   if(target===action)test.capture("07-pressed-no-overlay");
   input.mouseRelease(test.contentItem,1110,890);test.reset();
  }
  test.reset();command.focusForReason(Qt.PopupFocusReason);input.wait(30);test.check(command.activeFocus&&!command.visualFocus&&test.frame(command).progress===0,"automatic Power command focus is quiet");test.captureItem("15-session-automatic-focus",command);
  command.focusForReason(Qt.TabFocusReason);input.wait(30);test.check(command.visualFocus&&test.frame(command).progress===1,"Power command keyboard focus remains visible");test.captureItem("16-session-keyboard-focus",command);test.reset();
  // Active workspaces use brightness, with no persistent selected outline.
  workspace.workspace=Object.assign({},workspace.workspace,{active:true});test.reset();test.check(workspace.opacity===1&&input.findChild(workspace,"button-hover-frame")===null&&input.findChild(workspace,"workspace-reflective-frame").glow===0,"active workspace is brighter without selected outline");test.captureItem("08-workspace-active",workspace);
  workspace.workspace=Object.assign({},workspace.workspace,{active:false});test.reset();test.check(workspace.opacity<1&&input.findChild(workspace,"workspace-reflective-frame").glow===0,"inactive workspace is dimmer without selected outline");test.captureItem("09-workspace-inactive",workspace);
  const workspaceFrame=input.findChild(workspace,"workspace-reflective-frame"),workspaceClients=Config.ReflectionLight.activeClients;
  const workspaceBounds=[workspace.x,workspace.y,workspace.width,workspace.height].join();
  input.mouseMove(workspace,25,30);input.wait(60);test.check(workspaceFrame.glow>0&&workspaceFrame.glow<1,"workspace fades its existing border instead of tracing an outline");test.captureItem("12-workspace-glow-enter",workspace);
  input.wait(180);test.check(workspaceFrame.glow===1&&input.findChild(workspace,"button-hover-frame")===null,"workspace uses the same settled glow as power");test.captureItem("13-workspace-glow-hover",workspace);
  input.wait(300);test.check(Config.ReflectionLight.activeClients===workspaceClients&&workspaceFrame.glow===1,"held workspace glow adds no continuous clock");test.check(workspaceBounds===[workspace.x,workspace.y,workspace.width,workspace.height].join(),"workspace glow preserves layout");
  test.reset();test.check(workspaceFrame.glow===0,"workspace glow settles after exit");
  workspace.forceActiveFocus();input.wait(220);test.check(workspaceFrame.glow===1,"workspace keyboard focus uses the same glow");test.captureItem("14-workspace-glow-focus",workspace);test.reset();
  const workspaceBefore=test.activations;input.mouseClick(workspace,25,30);workspace.forceActiveFocus();input.keyClick(Qt.Key_Space);test.check(test.activations===workspaceBefore+2,"workspace pointer and keyboard actions remain");test.reset();
  workspace.enabled=false;input.mouseMove(workspace,25,30);input.wait(220);test.check(workspaceFrame.glow===0,"disabled workspace does not glow");workspace.enabled=true;test.reset();
  const powerFrame=input.findChild(power,"power-reflective-frame"),clients=Config.ReflectionLight.activeClients;
  test.check(powerFrame.glow===0,"power glow rests");test.captureItem("10-power-rest",power);
  input.mouseMove(power,30,30);input.wait(240);test.check(powerFrame.glow===1&&input.findChild(power,"button-hover-frame")===null,"power intensifies its existing perimeter only");test.captureItem("11-power-hover",power);
  input.wait(300);test.check(Config.ReflectionLight.activeClients===clients,"held power highlight adds no continuous reflection clock");test.reset();test.check(powerFrame.glow===0,"power glow settles after exit");
  // Persistent selection uses exactly the completed hover geometry, with no hover needed.
  test.reset();action.active=true;input.wait(15);test.check(fixFrame(action).selected && fixFrame(action).progress===1 && action.border.width===0,"selected action snaps to inner chamfer outline");
  test.capture("05-selected-action");input.mouseMove(action,100,30);input.wait(40);test.reset();test.check(fixFrame(action).progress===1,"selection remains after pointer exit");
  action.enabled=false;input.wait(15);test.check(fixFrame(action).progress===1,"disabled selection remains truthful");action.enabled=true;action.active=false;test.reset();test.check(fixFrame(action).progress===0,"deselection releases outline");
  test.check(input.findChild(power,"button-hover-frame")===null && input.findChild(machine,"button-hover-frame")===null,"power and centre component have no angular hover, including arrow regions");
  const powerBefore=test.activations;input.mouseClick(power,30,30);power.forceActiveFocus();input.keyClick(Qt.Key_Space);test.check(test.activations===powerBefore+2,"power pointer/keyboard actions remain");test.reset();
  controls.networkOpen=true;input.wait(15);test.check(fixFrame(input.findChild(controls,"rail-control-network")).progress===1,"Rail open state uses completed inner outline");controls.networkOpen=false;
  clock.notificationsOpen=true;input.wait(15);test.check(fixFrame(input.findChild(clock,"rail-notification-button")).progress===1,"notification selected outline stays complete");clock.notificationsOpen=false;
  device.audio=Object.assign({},device.audio,{sink:device.node});input.wait(15);test.check(!device.enabled && fixFrame(device).progress===1,"current audio endpoint remains visibly selected while unavailable for re-selection");
  device.audio=Object.assign({},device.audio,{sink:null});test.reset();
  const selectedSegments=input.findChild(segments,"session-mode-later");test.check(fixFrame(selectedSegments).progress===1,"selected segment remains outlined");
  for(const state of [{target:destination,key:"active"},{target:command,key:"selected"},{target:dayCell,key:"selected"},{target:lens,key:"selected"}]){state.target[state.key]=true;input.wait(15);test.check(fixFrame(state.target).progress===1,"shared selected outline "+state.key);state.target[state.key]=false;test.reset();}
  for(const touch of [false,true])for(const compact of [false,true]){
   Config.DirectoryStyle.touchMode=touch;clock.compact=compact;clock.width=clock.implicitWidth;input.wait(15);
   for(const count of [0,1,9,10,99,100,9999]){
    clock.notifications={unreadCount:count,dnd:false};input.wait(15);
    const bellButton=input.findChild(clock,"rail-notification-button"),bellIcon=input.findChild(clock,"rail-notification-bell"),badge=input.findChild(clock,"rail-notification-badge");
    const middle=bellIcon.mapToItem(bellButton,bellIcon.width/2,bellIcon.height/2);
    test.check(bellIcon.width===28 && Math.abs(middle.x-bellButton.width/2)<0.1 && Math.abs(middle.y-bellButton.height/2)<0.1,"bell stays enlarged and centred regardless of count");
    test.check(badge.visible===(count>0) && badge.width===badge.height && badge.radius===badge.width/2,"badge is a true circle");
    test.check(badge.width===(count>99?22:count>9?18:14),"smaller bounded count badge");
    const corner=badge.mapToItem(bellButton,0,0);test.check(corner.x>=0 && corner.y>=0 && corner.x+badge.width<=bellButton.width && corner.y+badge.height<=bellButton.height,"badge stays in target");
   }
  }
  Config.DirectoryStyle.touchMode=false;clock.compact=false;clock.width=clock.implicitWidth;clock.notifications={unreadCount:2,dnd:false};test.capture("06-bell-and-selection");
  // Rapid reversal must continue from the current trace rather than pop or run forever.
  const f=test.frame(action);
  for(let i=0;i<10;i++){input.mouseMove(action,100,30);input.wait(35);input.mouseMove(test.contentItem,1110,890);input.wait(25);}
  input.wait(250);test.check(f.progress===0&&input.findChild(f,"button-hover-geometry").item===null,"rapid reversal settles");
  action.enabled=false;input.mouseMove(action,100,30);input.wait(230);test.check(f.progress===0,"disabled has no hover");
  const count=test.activations;input.mouseClick(action,100,30);test.check(test.activations===count,"disabled has no action");action.enabled=true;
  test.reset();action.forceActiveFocus(Qt.TabFocusReason);input.keyClick(Qt.Key_Space);test.check(test.activations===count+1,"keyboard activation once");
  test.check(f.focused && f.progress===1 && action.border.width===0,"keyboard focus uses only the shared angular outline");
  test.reset();input.mouseClick(action,100,30);test.check(test.activations===count+2,"pointer passes through decoration once");input.mouseMove(test.contentItem,1110,890);input.wait(250);test.check(action.activeFocus && !f.focused && action.border.width===0,"pointer click leaves no separate focus/selection border");
  // Offscreen QtTest may retain the clicked MouseArea's hover cache after a
  // synthetic move. Independently verify the supplied hover-signal lifetime.
  f.engaged=false;input.wait(250);test.check(f.progress===0,"click focus cannot keep the hover outline alive");f.engaged=Qt.binding(()=>action.pointerHovered);
  Config.Skin.registry=Object.assign({},original,{persona:Object.assign({},original.persona||{},{reducedMotion:true})});
  test.reset();input.mouseMove(workspace,25,30);input.wait(15);test.check(workspaceFrame.glow===1,"workspace reduced-motion glow is immediate");test.reset();input.mouseMove(action,100,30);input.wait(15);test.check(f.progress===1,"reduced motion immediate");
  dayCell.selected=true;input.mouseMove(dayCell,20,20);input.wait(15);test.check(test.frame(dayCell).selected && test.frame(dayCell).progress===1 && Qt.colorEqual(test.frame(dayCell).strokeColor,Config.DirectoryStyle.muted),"selected date uses completed hover outline");test.capture("04-selected-date");dayCell.selected=false;
  Config.Skin.registry=Object.assign({},original,{persona:Object.assign({},original.persona||{},{reducedMotion:true,highContrast:true})});
  test.check(Qt.colorEqual(f.strokeColor,Config.DirectoryStyle.ink),"high-contrast border uses ink");
  action.visible=false;input.wait(15);test.check(input.findChild(f,"button-hover-geometry").item===null,"hiding releases geometry");action.visible=true;
  test.reset();Config.Skin.registry=original;
  console.log("RESULT "+JSON.stringify(records));console.log("PASS: 16 shared-outline button families plus workspace/power border glows, centre-out animation/reversal, shared border, steady fills/layout, idle release, disabled/hidden, pointer/keyboard and reduced motion; selected outlines, inward geometry, centred bell/counts/touch, press chrome removal, keyboard outline, workspace brightness, hover/focus glow, finite idle behavior and existing power-frame glow; fake actions only");Qt.quit();
 }}
}
