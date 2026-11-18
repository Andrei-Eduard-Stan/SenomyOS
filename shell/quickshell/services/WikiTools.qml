import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id:root
    property bool active:false
    property bool shortcutsVisible:false
    property string sourceRoot:String(Quickshell.env("SENOMY_SOURCE_ROOT") || Quickshell.shellDir+"/../..")
    property var entries:[]
    property var fontFiles:[]
    property var shortcutRows:[]
    property var shortcuts:({available:false,message:"Open Shortcuts or refresh to read Hyprland."})
    property bool clipboardAvailable:false
    property bool coverageAvailable:false
    property bool loaded:false
    property bool awaiting:false
    property bool ready:false
    readonly property bool busy:worker.running || awaiting
    property string error:""
    property string message:""
    property string copied:""
    property string operation:""
    property var pending:({})
    property int completion:0
    property string lastSucceeded:""
    function request(kind,payload) {
        if(!active || busy || !["catalog","shortcuts","save","remove","favorite","copy"].includes(kind))return false;
        awaiting=true;operation=kind;pending=payload || {};error="";message="";
        worker.stdinEnabled=["save","remove","favorite","copy"].includes(kind);
        worker.exec(["python3","-B",sourceRoot+"/scripts/wiki-tools.py",kind]);return true;
    }
    function refresh(){return request("catalog");}
    function save(entry){return request("save",entry);}
    function remove(id){return request("remove",{id:id});}
    function favorite(id){return request("favorite",{id:id});}
    function copy(text){return request("copy",{text:text});}
    function adopt(data) {
        if(data.entries!==undefined){entries=data.entries;fontFiles=data.fontFiles || [];clipboardAvailable=data.clipboardAvailable===true;coverageAvailable=data.coverageAvailable===true;loaded=true;}
        if(data.shortcuts!==undefined){
            const rows=data.shortcuts.bindings || [];
            if(JSON.stringify(rows)!==JSON.stringify(shortcutRows))shortcutRows=rows;
            shortcuts=data.shortcuts;
        }
    }
    onActiveChanged:if(ready && active)refresh()
    Component.onCompleted:{ready=true;if(active)refresh()}
    onShortcutsVisibleChanged:if(active && shortcutsVisible)request("shortcuts")
    Timer {interval:15000;repeat:true;running:root.active && root.shortcutsVisible;onTriggered:root.request("shortcuts")}
    Timer {id:feedback;interval:3000;onTriggered:root.message=""}
    Timer {interval:800;running:root.awaiting && !worker.running;onTriggered:{root.awaiting=false;root.error="Wiki helper could not start. Check Python and refresh to retry."}}
    Process {
        id:worker
        onStarted:if(stdinEnabled)write(JSON.stringify(root.pending)+"\n")
        stdout:StdioCollector{id:output}
        onExited:code=>{
            root.awaiting=false;
            try {
                const result=JSON.parse(output.text);
                if(code!==0 || result.ok!==true){root.error=result.error || "Wiki utility failed. Retry the action.";return;}
                root.adopt(result.data || {});root.lastSucceeded=root.operation;
                root.message=root.operation==="copy"?"Copied to clipboard":root.operation==="save"?"Saved to your library":root.operation==="remove"?"Removed from your library":root.operation==="favorite"?"Favorites updated":"";
                if(root.operation==="copy")root.copied=root.pending.text;
                feedback.restart();++root.completion;
            }catch(e){root.error="Wiki utility returned no valid result. Refresh to retry.";}
        }
    }
}
