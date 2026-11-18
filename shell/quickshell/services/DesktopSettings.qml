import QtQuick
import Quickshell
import Quickshell.Io
Scope {
    id:root
    property bool active:false
    property string context:""
    property bool queryEnabled:true
    property bool available:false
    property bool loading:false
    property string interpreter:"python3"
    property bool queryPending:false
    property bool capabilityPending:false
    property var defaults:[]
    property var apps:[]
    property var autostart:[]
    property var deployment:({})
    property var capabilities:({})
    property string error:""
    property string capabilityError:""
    property string message:""
    property alias actions:reviews
    readonly property string helper:Qt.resolvedUrl("../scripts/desktop-settings.py").toString().replace("file://","")
    readonly property string capabilityHelper:Qt.resolvedUrl("../scripts/desktop-capabilities.py").toString().replace("file://","")
    DesktopPreferenceActions {id:reviews;runner:action;helper:root.helper;interpreter:root.interpreter;active:root.active;context:root.context;defaults:root.defaults;apps:root.apps;autostart:root.autostart;deployment:root.deployment;onRefreshRequested:root.refresh()}
    function refresh(){
        if(!active||!queryEnabled)return;
        if(!queryPending&&!query.running){loading=true;queryPending=true;query.exec([interpreter,helper,"catalog"]);}
        if(!capabilityPending&&!capabilityQuery.running){capabilityPending=true;capabilityQuery.exec([interpreter,capabilityHelper,"catalog"]);}
    }
    onActiveChanged:if(active)refresh()
    Process {
        id:query;stdout:StdioCollector{id:output}
        onExited:code=>{
            root.queryPending=false;root.loading=false;
            try{const parsed=JSON.parse(output.text);const data=code===0&&parsed.ok?parsed.data:{};
                root.available=Boolean(data.defaults && data.defaults.available);root.defaults=data.defaults?data.defaults.items:[];root.apps=data.defaults?data.defaults.apps:[];root.autostart=data.autostart||[];root.deployment=data.deployment||{};root.error=code===0&&parsed.ok===true?"":(parsed.error||{}).message||"Desktop preference inventory exited unsuccessfully. Refresh to retry.";root.message=data.defaults?data.defaults.message:"";
            }catch(_){root.available=false;root.defaults=[];root.apps=[];root.autostart=[];root.deployment={};root.error="Desktop preference inventory returned invalid data.";}
        }
    }
    Process {id:action;stdout:StdioCollector{id:actionOutput} onExited:code=>reviews.completed(code,actionOutput.text)}
    Process {
        id:capabilityQuery;stdout:StdioCollector{id:capabilityOutput}
        onExited:code=>{root.capabilityPending=false;try{const parsed=JSON.parse(capabilityOutput.text);root.capabilities=code===0&&parsed.ok===true?parsed.data:{};root.capabilityError=code===0&&parsed.ok===true?"":(parsed.error||{}).message||"Desktop integration inventory exited unsuccessfully. Refresh to retry.";}catch(_){root.capabilities={};root.capabilityError="Desktop integration status returned invalid data.";}}
    }
    Timer {
        interval:200;running:root.queryPending&&!query.running||root.capabilityPending&&!capabilityQuery.running
        onTriggered:{
            if(root.queryPending&&!query.running){root.queryPending=false;root.loading=false;root.available=false;root.defaults=[];root.apps=[];root.autostart=[];root.deployment={};root.error="Desktop preference helper could not start. Check Python and refresh.";}
            if(root.capabilityPending&&!capabilityQuery.running){root.capabilityPending=false;root.capabilities={};root.capabilityError="Desktop integration helper could not start. Check Python and refresh; no permission request was made.";}
        }
    }
}
