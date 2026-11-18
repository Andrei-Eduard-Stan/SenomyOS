import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "config" as Config
Window {
 id:test;visible:true;width:420;height:500;color:"#090b0e"
 property int invoked:0
 property int secondary:0
 property int activated:0
 property int dismissals:0
 TestCase {id:input;when:false}
 QtObject {id:workspace;property int number:1;property bool active:true;property var toplevels:({values:[]});function activate(){test.activated++;}}
 WorkspaceChip {id:chip;x:12;y:12;workspace:({id:workspace.number,active:workspace.active,toplevels:workspace.toplevels,activate:()=>test.activated++})}
 QtObject {id:trayApp;property var item:({id:"fixture",title:"A long application name for menu testing",tooltipTitle:"",icon:"",status:0,hasMenu:true,onlyMenu:false,menu:null,activate:()=>test.activated++,secondaryActivate:()=>test.secondary++,scroll:(delta,horizontal)=>{}})}
 QtObject {id:fakeMenu;property var entries:tray.menuStack.length>1?[submenu]:[command,separator,disabled,checkbox,folder];}
 QtObject {id:command;property bool isSeparator:false;property bool enabled:true;property string text:"&Open window";property bool hasChildren:false;property int buttonType:0;property int checkState:0;function triggered(){test.invoked++;}}
 QtObject {id:separator;property bool isSeparator:true;property bool enabled:false;property string text:"";property bool hasChildren:false;property int buttonType:0;property int checkState:0;function triggered(){test.invoked+=100;}}
 QtObject {id:disabled;property bool isSeparator:false;property bool enabled:false;property string text:"Unavailable command";property bool hasChildren:false;property int buttonType:0;property int checkState:0;function triggered(){test.invoked+=100;}}
 QtObject {id:checkbox;property bool isSeparator:false;property bool enabled:true;property string text:"Keep running";property bool hasChildren:false;property int buttonType:QsMenuButtonType.CheckBox;property int checkState:Qt.Checked;function triggered(){test.invoked++;}}
 QtObject {id:folder;property bool isSeparator:false;property bool enabled:true;property string text:"More &commands";property bool hasChildren:true;property int buttonType:0;property int checkState:0;function triggered(){test.invoked+=100;}}
 QtObject {id:submenu;property bool isSeparator:false;property bool enabled:true;property string text:"Nested command";property bool hasChildren:false;property int buttonType:0;property int checkState:0;function triggered(){test.invoked++;}}
 TrayContents {id:tray;x:16;y:100;width:test.width-32;height:test.height-116;items:[trayApp.item];menuProvider:fakeMenu;onDismissRequested:test.dismissals++}
 function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
 function capture(name){let done=false;test.contentItem.grabToImage(r=>{check(r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture");done=true;});for(let i=0;i<100&&!done;i++)input.wait(10);check(done,"capture finished");}
 Timer {interval:300;running:true;onTriggered:{
  for(const width of [54,58])for(const count of [0,1,2,3,4,12,1000]){
   chip.preferredWidth=width;workspace.toplevels={values:Array.from({length:count},(_,i)=>({lastIpcObject:{class:i%2?"firefox":"code"}}))};input.wait(15);
   test.check(chip.windowCount===count&&chip.visibleToplevels.length===Math.min(1,count),"first application only");
   const summary=input.findChild(chip,"workspace-window-summary"),badge=input.findChild(chip,"workspace-remaining-count");
   test.check(summary.width<=chip.width-10&&summary.mapToItem(chip,0,0).x>=5,"summary stays inside chamfer margins");
   test.check(badge.visible===(count>1)&&badge.text==="+"+Math.max(0,count-1),"remaining count exact");
   if(count===4)test.capture("workspace-four-"+width);
  }
  workspace.toplevels={values:[]};test.check(chip.windowCount===0&&!input.findChild(chip,"workspace-remaining-count").visible,"removed windows clear badge");
  const icon=input.findChild(tray,"tray-item-list").itemAtIndex(0).children[0];
  input.mouseClick(icon,icon.width/2,icon.height/2,Qt.RightButton);input.wait(40);test.check(tray.menuOpen&&test.dismissals===0,"right click keeps parent and opens inline menu");test.capture("tray-menu-420");
  const disabledButton=input.findChild(tray,"tray-menu-command-2");test.check(!disabledButton.enabled,"disabled native command stays disabled");
  tray.invoke(disabled);tray.invoke(separator);test.check(test.invoked===0,"invalid command never activated");
  input.mouseClick(input.findChild(tray,"tray-menu-command-4"));input.wait(25);test.check(tray.menuStack.length===2&&test.invoked===0,"submenu navigation does not trigger parent");
  test.capture("tray-submenu");input.findChild(tray,"tray-menu-list").forceActiveFocus();input.keyClick(Qt.Key_Left);test.check(tray.menuStack.length===1,"keyboard back restores parent menu");
  const first=input.findChild(tray,"tray-menu-command-0");first.forceActiveFocus();input.keyClick(Qt.Key_Return);test.check(test.invoked===1&&!tray.menuOpen&&test.dismissals===0,"keyboard command invokes once and returns to items");
  input.wait(50);input.mouseClick(input.findChild(tray,"tray-item-menu-0"));input.wait(25);test.check(tray.menuOpen,"visible menu alternative");
  test.width=280;test.height=360;input.wait(30);test.capture("tray-menu-280");
  tray.items=[];test.check(!tray.menuOpen,"unregistered selected item closes menu safely");test.capture("tray-empty-280");
  tray.items=[trayApp.item];tray.openMenu(trayApp.item);tray.surfaceOpen=false;test.check(!tray.menuOpen&&tray.menuStack.length===0,"closing surface releases native menu ownership");
  console.log("PASS: workspace bounds at 0/1/2/3/4/12/1000 windows, inline tray right click, command states, submenus, keyboard and removal");Qt.quit();
 }}
}
