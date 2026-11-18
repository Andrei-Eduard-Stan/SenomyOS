import QtQuick
import Quickshell
import "components/lens" as Lens
import "components/lens/LensSearch.js" as Search
Scope {
    QtObject {id:state;property string lensMode:"apps";property int closes:0;property bool blocked:false;property var railWindows:[];property int popupGeneration:1;property bool modalActive:false;function closePopups(){if(!blocked)closes++;return !blocked;}function allowInteraction(){return !blocked;}}
    QtObject {id:app;property int calls:0;function execute(){calls++;}}
    QtObject {id:window;property int calls:0;function activate(){calls++;}}
    QtObject {id:fakeLaunch;property bool busy:false;property string target:"";property int heldSession:-1;property int heldRevision:-1;property int heldGeneration:-1;function request(kind,value,args){if(kind!=="desktop")throw Error("Wrong launch kind");target=value;app.calls++;return true;}}
    Lens.CommandLensPopup {id:lens;anchorItem:null;requestedOpen:false;providersReady:requestedOpen;coordinator:state;applicationLauncher:fakeLaunch
        applicationRows:[{kind:"apps",id:"app:1",label:"Test App",detail:"Fixture",object:({id:"fixture"})}];windowRows:[{kind:"windows",id:"window:1",label:"Test Window",detail:"Fixture",object:window}]}
    function check(value,message){if(!value)throw new Error(message);}
    property int attempts:0
    property int phase:0
    Timer {id:providers;interval:50;repeat:true;onTriggered:{
        try {
            if(++attempts>100)throw new Error("provider timeout");
            if(Quickshell.env("SENOMY_LENS_TEST_FAILURE")==="1") {
                if(lens.actionsProvider.error) {check(lens.results.some(r=>r.kind==="apps"),"other providers survive failure");check(lens.statusText.includes("unavailable"),"partial availability feedback");console.log("PASS: failed provider stays isolated and working providers still search");Qt.quit();}return;
            }
            if(phase===0 && lens.filesProvider.rows.length){check(lens.filesProvider.rows[0].info==="/tmp/a file with spaces", "file provider identity");lens.activate(0,true);phase=1;}
            else if(phase===1 && !lens.activating){state.lensMode="actions";phase=2;}
            else if(phase===2 && lens.actionsProvider.rows.length){lens.activate(0);phase=3;}
            else if(phase===3 && lens.providerError.includes("Fixture selection failed")){lens.activate(0);lens.content.searchText="a newer search";phase=4;}
            else if(phase===4 && !lens.activating){check(!lens.providerError,"old activation cannot replace new query feedback");lens.content.searchText="";lens.activate(0);lens.requestedOpen=false;lens.requestedOpen=true;state.lensMode="apps";phase=5;}
            else if(phase===5 && !lens.activating){check(!lens.providerError && lens.content.searchText==="","new opening rejects old activation callback");console.log("PASS: provider processes, exact reveal, inline failure, latest-input/opening guards; fake providers only");Qt.quit();}
        } catch(error){console.error("FAIL: "+error);Qt.exit(1);}
    }}
    Timer {interval:200;running:true;onTriggered:{
        try {
            check(lens.matches("Firefox browser","ffbr"),"tight label subsequence");check(!lens.matches("Firefox","zz"),"missing query");
            const rows=Search.parse("\0prompt\x1fFILES\n/path with spaces\0display\x1fTitle\x1ficon\x1ffolder\x1finfo\x1f/path with spaces\nNotice\0nonselectable\x1ftrue\x1finfo\x1fignored\n", "files", "/home/test");
            check(rows.length===1 && rows[0].info==="/path with spaces" && rows[0].label==="path with spaces","structured identity and basename");
            const action=Search.parse('Settings Open controls\0display\x1f<span weight="bold">Settings</span> · <span>Open &amp; manage</span>\x1finfo\x1fsettings\x1fmeta\x1fconfiguration',"actions","")[0];
            check(action.label==="Settings" && action.detail==="Open & manage" && Search.score(action,"configuration")>=0,"plain labels and action keywords");
            const ranking=[{id:"1",kind:"apps",label:"Firefox"},{id:"2",kind:"apps",label:"Fire fox"},{id:"3",kind:"apps",label:"Firefox Browser"}];
            check(Search.search(ranking,"firefox","all",false)[0].id==="1","exact beats prefix and fuzzy");
            check(Search.search(ranking,"","all",false).length===0,"no fabricated history or empty app dump");
            check(Search.search(ranking.concat(ranking),"","apps",true).length===3,"explicit app browse and deduplication");
            const apps=[{id:"apps:alpha",kind:"apps",label:"Alpha"},{id:"apps:zulu",kind:"apps",label:"Zulu"},{id:"apps:omega",kind:"apps",label:"Omega"}];
            const usage={zulu:{count:9,lastOpened:10},omega:{count:9,lastOpened:20}};
            check(Search.search(apps,"","apps",true,usage,"frequent").map(r=>r.label).join(",")==="Omega,Zulu,Alpha","frequency then recency then unlaunched");
            check(Search.search(apps,"","apps",true,usage,"alphabetical")[0].label==="Alpha","explicit alphabetical sort");
            check(Search.search(apps,"alpha","apps",true,usage,"frequent")[0].label==="Alpha","query relevance overrides popularity");
            check(Search.search(apps,"","apps",true,{},"frequent")[0].label==="Alpha","first-use alphabetical fallback");
            state.blocked=true;lens.activate(0);check(app.calls===0,"modal blocks activation");
            state.blocked=false;lens.activate(0);check(app.calls===1 && fakeLaunch.target==="fixture.desktop","typed GIO desktop activation uses native ID plus suffix");
            state.lensMode="windows";lens.activate(0);check(window.calls===1,"window activation");
            lens.content.searchText="keep query";state.lensMode="apps";check(lens.content.searchText==="keep query","scope retains query");
            lens.content.searchText="";
            console.log("PASS: native compilation, provider parsing, exact/prefix/keyword/fuzzy ranking, deduplication and guarded fake activations");lens.requestedOpen=true;state.lensMode=Quickshell.env("SENOMY_LENS_TEST_FAILURE")==="1"?"all":"files";lens.content.searchText=Quickshell.env("SENOMY_LENS_TEST_FAILURE")==="1"?"Test":"";providers.start();
        } catch(error){console.error("FAIL: "+error);Qt.exit(1);}
    }}
}
