import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components/lens" as Lens
import "config" as Config
Window {
    id:test;visible:true;width:820;height:850;color:"#292b32"
    TestCase {id:keys;when:false}
    property int closes:0
    property int writes:0
    QtObject {id:state;property string lensMode:"apps";property var railWindows:[];property int popupGeneration:1;property bool modalActive:false;function closePopups(){test.closes++;return true;}function allowInteraction(){return true;}}
    QtObject {id:app;function execute(){test.writes++;}}
    QtObject {id:fakeLaunch;property bool busy:false;property int heldSession:-1;property int heldRevision:-1;property int heldGeneration:-1;function request(kind,target,args){test.writes++;return true;}}
    Lens.CommandLensPopup {
        id:popup;x:20;y:20;width:implicitWidth;height:implicitHeight
        coordinator:state;anchorItem:null;applicationLauncher:fakeLaunch
        targetScreen:({width:1920,height:1080})
        applicationRows:[{kind:"apps",id:"apps:firefox",label:"Firefox",detail:"Web Browser",icon:"firefox",object:app},{kind:"apps",id:"apps:files",label:"Files",detail:"File manager",icon:"system-file-manager",object:app}]
        windowRows:[{kind:"windows",id:"window:1",label:"Command Lens — SenomyOS",detail:"Code · Workspace 1 · Focused",icon:"vscode",object:{activate:()=>test.writes++}}]
    }
    function check(ok,message){if(!ok)throw new Error(message);}
    function query(text){popup.content.searchText=text;keys.wait(40);popup.content.searchInput.forceActiveFocus();}
    function capture(name){let done=false;popup.grabToImage(r=>{check(r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture");done=true;});while(!done)keys.wait(20);}
    Timer {interval:250;running:true;onTriggered:{
        try {
            popup.actionsProvider.rows=[{kind:"actions",id:"actions:settings",info:"settings",label:"Settings",detail:"Open the full Settings window",icon:"preferences-system"}];
            keys.wait(100);capture("01-empty");check(popup.height===560,"stable desktop height");
            const openingHeight=popup.height;
            check(popup.mode==="apps" && popup.hasAppUsage && popup.results[0].label==="Firefox","Apps opens ranked by persisted successful launches");
            keys.mouseClick(keys.findChild(popup,"lensAppSort"),65,20);keys.wait(30);check(popup.results[0].label==="Files" && popup.content.searchInput.activeFocus,"sort control and typing focus");
            popup.content.applicationSort="frequent";keys.wait(30);check(popup.results[0].label==="Firefox","frequent option restores ranking");
            query("fire");keys.mouseClick(keys.findChild(popup,"lensClearSearch"),22,22);check(popup.content.searchText==="" && popup.content.searchInput.activeFocus,"clear query control");query("fire");capture("02-apps");check(popup.results.length===1 && popup.height===openingHeight,"single result preserves geometry");
            check(popup.content.searchInput.activeFocus,"search focused");
            keys.keyClick(Qt.Key_Return);check(test.writes===1,"keyboard activates app");
            let activeList=keys.findChild(popup,"lensResults");keys.mouseClick(activeList.currentItem,70,20);check(test.writes===2,"pointer activates app");check(popup.content.searchInput.activeFocus,"pointer keeps search focus");
            popup.filesProvider.rows=[{kind:"files",id:"files:1",info:"/tmp/Design review.pdf",label:"Design review.pdf",detail:"~/Documents/Projects",icon:"application-pdf"}];
            popup.content.selectScope("files");query("Design");capture("03-files");
            activeList=keys.findChild(popup,"lensResults");keys.mouseClick(activeList.currentItem,70,20,Qt.RightButton);keys.wait(30);
            const menu=keys.findChild(activeList.currentItem,"lensContextMenu");check(menu.visible,"file context menu opens");
            const beforeEscape=test.closes;keys.keyClick(Qt.Key_Escape);keys.tryVerify(()=>!menu.visible,1000);check(!menu.visible && test.closes===beforeEscape,"Escape closes the inner context menu only");
            popup.content.selectScope("windows");query("");capture("04-windows");
            popup.content.selectScope("actions");query("settings");capture("05-actions");
            query("zzzz-no-match");capture("06-no-match");check(popup.results.length===0 && popup.height===openingHeight,"empty result preserves geometry");
            popup.applicationRows=Array.from({length:75},(_,i)=>({kind:"apps",id:"app:"+i,label:"Application "+String(i).padStart(2,"0"),detail:"Installed desktop application",icon:"applications-system",object:app}));
            popup.content.selectScope("apps");query("");keys.keyClick(Qt.Key_PageDown);keys.wait(50);check(popup.content.selectedIndex>=Math.max(1,Math.floor(keys.findChild(popup,"lensResults").height/(popup.content.rowHeight+2))),"page down moves one visible page");
            for(let i=0;i<24;i++)keys.keyClick(Qt.Key_Down);keys.wait(50);capture("07-scroll-selection");
            const list=keys.findChild(popup,"lensResults");check(list.contentY>0,"selection scrolls into view");
            const chosen=popup.content.selectedIndex;check(list.currentItem.y>=list.contentY && list.currentItem.y+list.currentItem.height<=list.contentY+list.height+1,"active row wholly visible");
            keys.keyClick(Qt.Key_PageUp);check(popup.content.selectedIndex<chosen,"page up moves selection");
            keys.keyClick(Qt.Key_Tab,Qt.ControlModifier);check(state.lensMode==="files","scope keyboard cycle");
            keys.keyClick(Qt.Key_1,Qt.AltModifier);check(state.lensMode==="all","direct All filter");
            query("f");query("fire");query("zzzz");query("Application 02");check(popup.results[0].label==="Application 02","latest rapid query wins");
            popup.targetScreen=({width:380,height:600});state.lensMode="apps";query("");keys.wait(50);capture("08-narrow");check(popup.width===340 && popup.height<=488,"narrow bounds");
            Config.DirectoryStyle.touchMode=true;popup.targetScreen=({width:720,height:800});keys.wait(50);capture("09-touch");check(popup.content.rowHeight>=44,"touch rows");
            Config.DirectoryStyle.touchMode=false;
            const original=Config.Skin.registry;Config.Skin.registry=Object.assign({},original,{persona:Object.assign({},original.persona || {},{uiTextScale:1.5,reducedMotion:true,highContrast:true})});
            popup.targetScreen=({width:420,height:700});query("Application 02");keys.wait(100);capture("10-large-type");
            Config.Skin.registry=original;popup.targetScreen=({width:1920,height:1080});
            popup.windowRows=[];popup.content.selectScope("windows");query("");capture("11-no-windows");check(popup.results.length===0,"no open windows");
            popup.applicationRows=[];popup.content.selectScope("apps");query("");capture("12-no-applications");check(popup.results.length===0,"missing application index");
            popup.applicationRows=[{kind:"apps",id:"apps:firefox",label:"Firefox",detail:"Web Browser",icon:"firefox",object:app}];
            popup.filesProvider.error="File search unavailable. Other scopes still work.";popup.content.selectScope("all");query("fire");capture("13-partial-provider-error");check(popup.results.length===1 && popup.statusText.includes("unavailable") && popup.height===openingHeight,"provider failure preserves working results and geometry");
            const closesBefore=test.closes;keys.keyClick(Qt.Key_Escape);check(test.closes===closesBefore+1,"escape dismissal");
            // Slow catalogs must neither start before native focus nor delay typing.
            popup.ownsEscape=false;popup.requestedOpen=true;keys.wait(30);
            check(!popup.filesProvider.loading && !popup.actionsProvider.loading,"catalogs wait for native keyboard ownership");
            popup.ownsEscape=true;popup.content.searchInput.forceActiveFocus();keys.wait(20);
            check(popup.filesProvider.loading && popup.actionsProvider.loading,"independent catalogs begin after focus");
            for(const key of [Qt.Key_F,Qt.Key_I,Qt.Key_R,Qt.Key_E])keys.keyClick(key);check(popup.content.searchText==="fire" && popup.results[0].label==="Firefox","typing works before slow providers finish");
            check(popup.height===openingHeight,"loading preserves geometry");
            for(let i=0;i<120 && (popup.filesProvider.loading || popup.actionsProvider.loading);i++)keys.wait(20);
            check(!popup.loading && popup.filesProvider.loadedAt>0 && popup.actionsProvider.loadedAt>0,"slow providers complete");
            const cachedAt=popup.filesProvider.loadedAt,cachedRows=popup.filesProvider.rows;
            popup.requestedOpen=false;popup.requestedOpen=true;keys.wait(30);
            check(popup.filesProvider.rows===cachedRows && popup.filesProvider.loadedAt===cachedAt && !popup.loading,"fresh reopening reuses catalogs without a helper launch");
            popup.filesProvider.refreshIndex(true);keys.wait(30);check(popup.filesProvider.loading,"explicit refresh bypasses freshness");
            console.log("PASS: native-focus startup ordering, typing during slow providers, fixed geometry, fresh catalog reuse and explicit refresh; real Qt keyboard input, app activation, All/scopes, query continuity, page/arrow navigation, selection scrolling, narrow/touch/text states; fake activations only");Qt.quit();
        } catch(error){console.error("FAIL: "+error);Qt.exit(1);}
    }}
}
