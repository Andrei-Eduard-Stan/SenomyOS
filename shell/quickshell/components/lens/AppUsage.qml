import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id:root
    function refresh(){history.reload();}
    property var apps: ({})
    property string error: ""
    property FileView history: FileView {
        path:(Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME")+"/.local/state")+"/senomyos/app-usage/history.json"
        watchChanges:true;printErrors:false
        onFileChanged:reload()
        onLoaded:{
            try {
                const raw=text();if(raw.length>262144)throw new Error("size");
                const data=JSON.parse(raw);
                if(data.schemaVersion!==1 || !data.apps || typeof data.apps!=="object" || Array.isArray(data.apps) || Object.keys(data.apps).length>512)throw new Error("schema");
                const clean={};
                for(const key of Object.keys(data.apps)) {
                    const row=data.apps[key];
                    if(!/^[A-Za-z0-9_][A-Za-z0-9_.+@-]{0,254}$/.test(key) || !row || !Number.isInteger(row.count) || row.count<1 || row.count>2147483647 || !Number.isInteger(row.lastOpened) || row.lastOpened<0)throw new Error("entry");
                    clean[key]={count:row.count,lastOpened:row.lastOpened};
                }
                root.apps=clean;root.error="";
            }catch(_){root.apps={};root.error="App history is unreadable. Applications are listed alphabetically.";}
        }
        onLoadFailed:{root.apps={};root.error="";}
    }
}
