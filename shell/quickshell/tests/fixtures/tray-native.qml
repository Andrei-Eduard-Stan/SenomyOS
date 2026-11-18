import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Services.SystemTray
import "components"
Window {
 id:test;visible:true;width:420;height:480;color:"#0a0c0f"
 TestCase {id:input;when:false}
 TrayContents {id:tray;anchors.fill:parent;anchors.margins:20}
 function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
 function waitFor(fn,message){console.log("CHECK: "+message);for(let i=0;i<150&&!fn();i++)input.wait(20);check(fn(),message);}
 Timer {interval:150;running:true;onTriggered:{
  test.waitFor(()=>tray.items.length===1,"native status notifier registered");
  input.mouseClick(input.findChild(tray,"tray-item-menu-0"));
  test.waitFor(()=>tray.menuEntries.length===4,"native DBus menu entries loaded");
  test.check(tray.menuEntries[0].text==="&Open native window","native label received");
  test.check(!tray.menuEntries[1].enabled,"native disabled state received");
  test.check(tray.menuEntries[2].checkState===Qt.Checked,"native checked state received");
  test.check(tray.menuEntries[3].hasChildren,"native submenu flag received");input.wait(60);
  input.mouseClick(input.findChild(tray,"tray-menu-command-3"));test.check(tray.menuStack.length===2,"native submenu click navigates");
  test.waitFor(()=>tray.menuEntries.length===1&&tray.menuEntries[0].text==="Nested native command","native lazy submenu loaded");
  test.waitFor(()=>!!input.findChild(tray,"tray-menu-command-0"),"native submenu command rendered");input.wait(50);
  let done=false;test.contentItem.grabToImage(r=>{test.check(r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/tray-native-submenu.png"),"native capture");done=true;});for(let i=0;i<100&&!done;i++)input.wait(10);
  const nested=input.findChild(tray,"tray-menu-command-0");nested.forceActiveFocus();input.keyClick(Qt.Key_Return);input.wait(80);
  test.check(!tray.menuOpen,"native trigger returns to application list");
  console.log("PASS: real private D-Bus status item, lazy root/submenu loading, checked/disabled states and keyboard trigger");Qt.quit();
 }}
}
