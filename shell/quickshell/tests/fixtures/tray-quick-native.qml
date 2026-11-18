import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
Window {
    id:test;visible:true;width:432;height:500;color:"#0a0c0f"
    TestCase {id:input;when:false}
    TrayContents {id:tray;anchors.fill:parent;anchors.margins:24}
    function verify(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
    function waitFor(predicate,message){for(let i=0;i<150&&!predicate();i++)input.wait(20);verify(predicate(),message);}
    function named(name){const item=input.findChild(tray,name);verify(!!item,"exists "+name);return item;}
    function click(name,button){const item=named(name);input.mouseClick(item,item.width/2,item.height/2,button || Qt.LeftButton);input.wait(60);}
    function capture(name){let done=false;test.contentItem.grabToImage(r=>{verify(r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture");done=true;});while(!done)input.wait(10);}
    Timer {interval:150;running:true;onTriggered:{
        waitFor(()=>tray.items.length===1,"private native status registration");
        click("tray-app-0");const row=named("tray-app-0");input.mouseClick(row,20,row.height/2,Qt.MiddleButton);input.mouseWheel(row,row.width/2,24,0,120);input.wait(60);
        click("tray-app-0",Qt.RightButton);waitFor(()=>tray.menuEntries.length===4,"native root menu loads");
        verify(!tray.menuEntries[1].enabled&&tray.menuEntries[2].checkState===Qt.Checked,"native state preserved");capture("native-root");
        click("tray-menu-command-3");waitFor(()=>tray.menuStack.length===2&&tray.menuEntries.length===2,"first native submenu");
        click("tray-menu-command-1");waitFor(()=>tray.menuStack.length===3&&tray.menuEntries.length===1&&tray.menuEntries[0].text==="Deep native command","third-level native submenu retains all ancestors");capture("native-deep-menu");
        click("tray-menu-back");waitFor(()=>tray.menuStack.length===2&&tray.menuEntries.length===2,"native Back restores parent");
        click("tray-menu-command-1");waitFor(()=>tray.menuStack.length===3&&tray.menuEntries.length===1,"native deep submenu reopens");
        const command=named("tray-menu-command-0");command.forceActiveFocus();input.keyClick(Qt.Key_Return);input.wait(80);
        verify(!tray.menuOpen&&tray.menuStack.length===0,"native command returns to app list and releases openers");
        verify(named("tray-app-0").activeFocus,"native command restores originating app focus");
        console.log("PASS: actual private SNI activation/secondary/wheel, QsMenuOpener root and three levels, checked/disabled state, back/reopen, command delivery and focus cleanup. No live bus used.");Qt.quit();
    }}
}
