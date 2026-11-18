import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components" as UI
import "components/DirectoryModel.js" as Directory
import "config" as Config
Window {
 id:test;visible:true;width:620;height:600;color:"#111218"
 property int step:0;property int index:0;property string phase:"menu-open";property int pending:0
 TestCase {id:input;when:false}
 UI.PerformanceWorkspaceNavigation {id:nav;x:24;y:24;width:280;height:540;nodes:Directory.performance();activeNode:"overview";expanded:({});onExpansionRequested:value=>expanded=value;onQueryEdited:text=>query=text}
 UI.ContextActionMenu {id:menu;x:540;y:500;actions:[{id:"copy",label:"Copy details"},{id:"inspect",label:"Inspect"}];onActionRequested:action=>{console.error("FAIL: unexpected action");Qt.exit(1)}}
 function capture(){const path=Quickshell.env("SENOMY_QA_OUT")+"/"+phase+"-"+String(index++).padStart(3,"0")+".png";pending++;test.contentItem.grabToImage(r=>{r.saveToFile(path);pending--;});}
 Timer {interval:20;repeat:true;running:test.step>0 && test.step<6;onTriggered:if(test.index<12)test.capture()}
 Timer {interval:300;repeat:true;running:true;onTriggered:{
  test.index=0;
  if(test.step===0){test.phase="menu-open";menu.open();}
  if(test.step===1){test.phase="menu-close";const popup=input.findChild(menu,"context-action-popup");popup.close();}
  if(test.step===2){test.phase="directory-open";nav.expanded={compute:true,cpu:true};}
  if(test.step===3){test.phase="directory-close";nav.expanded={};}
  if(test.step===4){test.phase="directory-reversal";nav.expanded={compute:true,cpu:true};}
  if(test.step===5){test.phase="reduced";Config.Skin.registry=Object.assign({},Config.Skin.registry,{persona:Object.assign({},Config.Skin.registry.persona||{},{reducedMotion:true})});nav.expanded={};menu.open();test.capture();}
  if(test.step===6){if(test.pending)return;console.log("PASS: captured actual Qt menu and retained directory motion, including reduced mode; inert actions");Qt.quit();}
  test.step++;
 }}
}
