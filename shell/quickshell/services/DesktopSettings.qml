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
    DesktopPreferenceActions {id:reviews;runner:action;helper:root.helper;active:root.active;context:root.context;defaults:root.defaults;apps:root.apps;autostart:root.autostart;deployment:root.deployment;onRefreshRequested:root.refresh()}
    function refresh(){
        if(!active||!queryEnabled)return;
        if(!query.running){loading=true;query.exec(["python3",helper,"catalog"]);}
        if(!capabilityQuery.running)capabilityQuery.exec(["python3",capabilityHelper,"catalog"]);
    }
    onActiveChanged:if(active)refresh()
    Process {
        id:query;stdout:StdioCollector{id:output}
        onExited:code=>{
            root.loading=false;
            try{const parsed=JSON.parse(output.text);const data=code===0&&parsed.ok?parsed.data:{};
                root.available=Boolean(data.defaults && data.defaults.available);root.defaults=data.defaults?data.defaults.items:[];root.apps=data.defaults?data.defaults.apps:[];root.autostart=data.autostart||[];root.deployment=data.deployment||{};root.error=parsed.ok?"":(parsed.error||{}).message||"Desktop preferences unavailable.";root.message=data.defaults?data.defaults.message:"";
            }catch(_){root.available=false;root.defaults=[];root.apps=[];root.autostart=[];root.deployment={};root.error="Desktop preference inventory returned invalid data.";}
        }
    }
    Process {id:action;stdout:StdioCollector{id:actionOutput} onExited:code=>reviews.completed(code,actionOutput.text)}
    Process {
        id:capabilityQuery;stdout:StdioCollector{id:capabilityOutput}
        onExited:code=>{try{const parsed=JSON.parse(capabilityOutput.text);root.capabilities=code===0&&parsed.ok?parsed.data:{};root.capabilityError=parsed.ok?"":(parsed.error||{}).message||"Desktop integration status unavailable.";}catch(_){root.capabilities={};root.capabilityError="Desktop integration status returned invalid data.";}}
    }
}
