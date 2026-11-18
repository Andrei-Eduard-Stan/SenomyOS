import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Services.SystemTray
import "components"
import "config" as Config
Window {
    id: test; visible: true; width: 900; height: 800; color: "white"
    property int activations: 0
    property int secondary: 0
    property int scrolls: 0
    property int commands: 0
    property int closes: 0
    property bool emptyMenu: false
    property real workWidth: 1920
    property real workHeight: 1080
    TestCase { id: input; when: false }
    Repeater { model: 35; Text { required property int index; y: index * 22; text: "BUSY APPLICATION BACKGROUND / TEXT MUST NOT BLEED THROUGH THE TRAY // 1234567890"; color: "black"; font.pixelSize: 20 } }
    QtObject {
        id: app
        property string id: "fixture"
        property string title: "Fixture application"
        property string tooltipTitle: ""
        property string icon: ""
        property int status: Status.Active
        property bool hasMenu: true
        property bool onlyMenu: false
        property var menu: null
        function activate() { test.activations++; }
        function secondaryActivate() { test.secondary++; }
        function scroll(delta, horizontal) { test.scrolls++; }
    }
    QtObject { id: open; property string text: "&Open && inspect"; property bool enabled: true; property bool isSeparator: false; property bool hasChildren: false; property int buttonType: 0; property int checkState: 0; function triggered() { test.commands++; } }
    QtObject { id: separator; property bool isSeparator: true; property bool enabled: false }
    QtObject { id: disabled; property string text: "Unavailable command"; property bool enabled: false; property bool isSeparator: false; property bool hasChildren: false; property int buttonType: 0; property int checkState: 0; function triggered() { test.commands+=100; } }
    QtObject { id: check; property string text: "Keep running"; property bool enabled: true; property bool isSeparator: false; property bool hasChildren: false; property int buttonType: QsMenuButtonType.CheckBox; property int checkState: Qt.Checked; function triggered() { test.commands++; } }
    QtObject { id: radio; property string text: "Selected mode"; property bool enabled: true; property bool isSeparator: false; property bool hasChildren: false; property int buttonType: QsMenuButtonType.RadioButton; property int checkState: Qt.Checked; function triggered() { test.commands++; } }
    QtObject { id: folder; property string text: "More &commands"; property bool enabled: true; property bool isSeparator: false; property bool hasChildren: true; property int buttonType: 0; property int checkState: 0 }
    QtObject { id: deeper; property string text: "Deeper menu"; property bool enabled: true; property bool isSeparator: false; property bool hasChildren: true; property int buttonType: 0; property int checkState: 0 }
    QtObject { id: leaf; property string text: "TEST FIXTURE · nested command"; property bool enabled: true; property bool isSeparator: false; property bool hasChildren: false; property int buttonType: 0; property int checkState: 0; function triggered() { test.commands++; } }
    QtObject { id: provider; property var entries: test.emptyMenu ? [] : contents.menuStack.length > 2 ? [leaf] : contents.menuStack.length > 1 ? [leaf, deeper] : [open,separator,disabled,check,radio,folder] }
    TrayPopup {
        id: popup; x: 20; y: 20; width: implicitWidth; height: implicitHeight
        availableWidth: test.workWidth - 40; availableHeight: test.workHeight - 112
        onDismissRequested: test.closes++
    }
    readonly property var contents: input.findChild(popup, "tray-contents")
    function verify(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message); } }
    function named(name) { const result = input.findChild(popup,name); verify(result !== null, "exists: " + name); return result; }
    function click(name, button) { const item = named(name); input.mouseClick(item,item.width/2,item.height/2,button || Qt.LeftButton); input.wait(50); }
    function capture(name) { if(name==="04-deep-menu" || name==="02-root-menu") {const h=named("tray-header"),i=named("tray-identity");console.log("GEOMETRY "+name+" "+JSON.stringify({header:{y:h.y,h:h.height},identity:{x:i.x,y:i.y,h:i.height,ih:i.implicitHeight},children:i.children.map(t=>({text:t.text,y:t.y,h:t.height,ih:t.implicitHeight,visible:t.visible}))}));} let done = false; popup.grabToImage(result => { verify(result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture"); done = true; }); while (!done) input.wait(10); }
    Timer {
        interval: 200; running: true
        onTriggered: {
            const defaultRegistry=Config.Skin.registry;
            test.requestActivate();input.wait(30);
            const overview=[app,{id:"vault",title:"KeePassXC",tooltipTitle:"",icon:"file:///usr/share/icons/hicolor/scalable/apps/keepassxc.svg",status:Status.NeedsAttention,hasMenu:true,onlyMenu:true,menu:null,activate:function(){test.activations++;},secondaryActivate:function(){},scroll:function(){}},{id:"capture",title:"Flameshot",tooltipTitle:"",icon:"file:///usr/share/icons/hicolor/scalable/apps/flameshot.svg",status:Status.Passive,hasMenu:true,onlyMenu:false,menu:null,activate:function(){test.activations++;},secondaryActivate:function(){},scroll:function(){}}];
            app.title="VLC media player";app.icon="file:///usr/share/icons/Papirus/48x48/apps/vlc.svg";contents.items=overview;input.wait(100);
            verify(popup.width===360 && popup.height<=210,"three-app chooser stays compact");capture("00-overview");
            contents.focusInitial();input.keyClick(Qt.Key_Right);input.wait(30);
            verify(named("tray-app-1").activeFocus && activations===0 && !contents.menuOpen,"Right focuses the next app without invoking it");
            input.keyClick(Qt.Key_Left);input.wait(30);verify(named("tray-app-0").activeFocus,"Left returns app focus");
            app.title="Fixture application";app.icon="";
            contents.items = [app]; contents.menuProvider = provider; input.wait(100); contents.focusInitial(); input.wait(30);
            const initialRow=named("tray-app-0"),initialCue=initialRow.background;
            verify(initialRow.activeFocus && !initialRow.visualFocus && !initialRow.visualFocus,"automatic app focus stays quiet without hover");capture("00-quiet-initial-focus");
            input.keyClick(Qt.Key_Down);input.wait(30);verify(initialRow.visualFocus && initialRow.visualFocus,"keyboard navigation reveals the focused row: focus="+initialRow.activeFocus+" visual="+initialRow.visualFocus+" reason="+initialRow.focusReason+" cue="+initialRow.visualFocus+" active="+(test.activeFocusItem?test.activeFocusItem.objectName:"none"));capture("00-keyboard-focus");
            contents.focusInitial();input.wait(30);verify(!initialRow.visualFocus && !initialRow.visualFocus,"reopening clears a previous keyboard cue");
            verify(popup.width === 240 && popup.height <= 220, "compact icon-sized single app " + popup.height); capture("01-single-app");input.mouseMove(named("tray-app-0"),named("tray-app-0").width/2,20);input.wait(40);capture("01-pointer-hover");
            click("tray-app-0"); verify(activations === 1, "whole app row activates once");
            const row = named("tray-app-0"); input.mouseClick(row,20,row.height/2,Qt.MiddleButton); verify(secondary === 1, "secondary activation");
            input.mouseWheel(row,row.width/2,24,0,120); verify(scrolls === 1, "icon wheel retains native action");
            row.forceActiveFocus(); input.keyClick(Qt.Key_Return); input.keyClick(Qt.Key_Space); verify(activations === 3, "Enter and Space each activate once");
            const visited=[]; for(let i=0;i<8;i++) {input.keyClick(Qt.Key_Tab);input.wait(5);visited.push(test.activeFocusItem ? test.activeFocusItem.objectName : "");}
            verify(visited.includes("tray-close") && visited.includes("tray-app-0"), "Tab reaches close and unified row");
            row.forceActiveFocus(); input.keyClick(Qt.Key_F10,Qt.ShiftModifier); input.wait(70); verify(contents.menuOpen,"Shift F10 opens inline menu");
            verify(named("tray-menu-command-0").label === "Open & inspect", "native mnemonic escaping");
            verify(!named("tray-menu-command-2").enabled && named("tray-menu-command-3").entry.checkState === Qt.Checked, "disabled/checked native state");
            capture("02-root-menu");
            const menuList=named("tray-menu-list"); menuList.forceActiveFocus(); input.keyClick(Qt.Key_Down); verify(menuList.currentIndex === 3, "arrows skip separator and disabled command");
            contents.invoke(disabled); contents.invoke(separator); verify(commands===0,"disabled/separator never execute");
            click("tray-menu-command-5"); verify(contents.menuStack.length===2,"submenu opens");
            const menuHeight=popup.height; capture("03-submenu");
            click("tray-menu-command-1"); verify(contents.menuStack.length===3 && popup.height===menuHeight,"deeper menu retains menu geometry"); capture("04-deep-menu");
            input.keyClick(Qt.Key_Escape); verify(contents.menuStack.length===2 && closes===0,"Escape backs out one submenu");
            input.wait(30); named("tray-menu-list").forceActiveFocus(); input.keyClick(Qt.Key_Left); verify(contents.menuStack.length===1,"Left returns to root menu");
            input.wait(40); click("tray-menu-command-0"); input.wait(40); verify(commands===1 && !contents.menuOpen,"command invokes once and restores apps");
            verify(named("tray-app-0").activeFocus,"return focus goes to originating app");verify(!named("tray-app-0").visualFocus,"menu return restores logical focus without a false hover");
            app.onlyMenu=true; click("tray-app-0"); verify(contents.menuOpen && activations===3,"menu-only item opens menu instead of inert activation"); contents.resetMenu(); app.onlyMenu=false;
            click("tray-app-0",Qt.RightButton); verify(contents.menuOpen,"right click menu"); contents.resetMenu();
            app.hasMenu=false; input.wait(30); click("tray-app-0",Qt.RightButton); verify(secondary===2 && !row.menuAvailable,"no-menu secondary fallback");
            app.onlyMenu=true; input.wait(30); verify(!named("tray-app-0").enabled,"unavailable menu-only item disabled"); app.onlyMenu=false;app.hasMenu=true;
            verify(input.findChild(popup,"tray-item-menu-0")===null,"separate Menu button removed");
            const beforeHold=activations;input.mousePress(row,row.width/2,row.height/2);input.wait(900);input.mouseRelease(row,row.width/2,row.height/2);input.wait(50);
            verify(contents.menuOpen && activations===beforeHold,"hold opens menu without app activation");contents.resetMenu();input.wait(40);
            app.status=Status.NeedsAttention; input.wait(30); verify(named("tray-app-0").attention && named("tray-app-0").detail==="Needs attention","attention has text and marker"); capture("05-attention");
            app.status=Status.Passive; input.wait(30); capture("06-passive"); app.status=Status.Active;
            app.title="Very long application title with <b>literal markup</b> and enough characters to require elision"; input.wait(30); capture("07-long-label"); app.title="Fixture application";
            emptyMenu=true; click("tray-app-0",Qt.RightButton); input.wait(1550); verify(named("tray-menu-retry").visible,"empty menu offers retry after loading timeout"); capture("08-empty-menu");
            click("tray-menu-retry"); verify(contents.menuOpen,"retry retains menu context"); emptyMenu=false; input.wait(60); verify(contents.menuEntries.length===6,"late menu data replaces empty state");
            contents.items=[]; input.wait(50); verify(!contents.menuOpen && contents.menuStack.length===0,"selected item removal closes menu and releases all openers"); capture("09-no-items");
            const many=Array.from({length:18},(_,i)=>({id:"shared-id",title:"TEST FIXTURE app "+(i+1),tooltipTitle:"",icon:"",status:Status.Active,hasMenu:false,onlyMenu:false,menu:null,activate:function(){test.activations++;},secondaryActivate:function(){test.secondary++;},scroll:function(){test.scrolls++;}}));
            contents.items=many; input.wait(80); verify(named("tray-item-list").count===18,"distinct registrations with equal app IDs retained");
            contents.focusInitial(); input.keyClick(Qt.Key_End); input.wait(50); verify(named("tray-item-list").currentIndex===17,"End reaches last app"); input.keyClick(Qt.Key_Up); input.wait(40); verify(named("tray-item-list").currentIndex===17-named("tray-item-list").columns,"Up moves app focus by grid row");
            input.keyClick(Qt.Key_Home); input.wait(50); verify(named("tray-item-list").currentIndex===0,"Home returns first app"); capture("10-many-items");
            const first=named("tray-app-0"), beforeScrolls=scrolls;input.mouseWheel(first,first.width-20,first.height/2,0,-120); input.wait(60); verify(scrolls===beforeScrolls && named("tray-item-list").contentY>0,"label wheel scrolls list without changing app state");
            workWidth=360;workHeight=480;input.wait(80);verify(popup.width===320&&popup.height<=368,"narrow short work area bounded");
            const resizedList=named("tray-item-list"),resizedApp=named("tray-app-0"),resizedPoint=resizedApp.mapToItem(resizedList,0,0);
            verify(resizedPoint.y>=0 && resizedPoint.y+resizedApp.height<=resizedList.height+1,"resize keeps the focused app fully visible");capture("11-narrow-short");
            contents.items=[app];contents.focusInitial();Config.DirectoryStyle.touchMode=true;input.wait(60);verify(named("tray-touch-menu-0").width>=48&&named("tray-app-0").height>=48,"touch targets");capture("12-touch");click("tray-touch-menu-0");verify(contents.menuOpen,"integrated touch menu action");contents.resetMenu();input.wait(40);
            workWidth=1920;workHeight=1080;Config.DirectoryStyle.touchMode=false;
            const registry=JSON.parse(JSON.stringify(Config.Skin.registry));registry.persona=Object.assign({},registry.persona||{},{uiTextScale:1.5,highContrast:true,reducedMotion:true});Config.Skin.registry=registry;input.wait(60);capture("13-large-type");verify(Config.QuickPanelStyle.openMs===0,"reduced motion");
            contents.items=many;workWidth=360;workHeight=600;input.wait(80);contents.focusInitial();input.keyClick(Qt.Key_End);input.wait(50);
            const list=named("tray-item-list"),focused=test.activeFocusItem,point=focused.mapToItem(list,0,0);
            verify(focused.objectName==="tray-app-17" && point.y>=0 && point.y+focused.height<=list.height+1,"last focused app fully visible at narrow large type");capture("14-narrow-large-focus");
            contents.items=[app];workWidth=1920;workHeight=1080;input.wait(60);
            Config.Skin.registry=defaultRegistry;
            contents.items=overview;input.wait(60);click("tray-app-1",Qt.RightButton);verify(contents.selectedItem===overview[1],"right click retains exact application identity");verify(named("tray-menu-title").text==="// KeePassXC","per-app menu heading uses shared style and identity");capture("15-second-app-menu");contents.resetMenu();contents.items=[app];input.wait(40);
            click("tray-app-0",Qt.RightButton);popup.requestedOpen=false;input.wait(40);verify(!contents.menuOpen&&contents.menuStack.length===0,"closing surface releases menu session");popup.requestedOpen=true;input.wait(40);
            click("tray-close");verify(closes===1,"close routes to shared owner");popup.forceActiveFocus();input.keyClick(Qt.Key_Escape);verify(closes===2,"Escape routes to owner when no menu is open");
            console.log("PASS: tray composition, primary/secondary/wheel actions, keyboard/focus, checked/disabled/only-menu states, deep menus/back, retry, hot removal, duplicate app IDs, list scrolling, short/narrow/touch/text scale and reduced motion. Fixture actions only.");Qt.quit();
        }
    }
}
