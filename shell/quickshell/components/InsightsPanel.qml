import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config" as Config
import "notifications" as Notifications
import "DirectoryFreshness.js" as Freshness
import "BriefingModel.js" as BriefingModel

InsightsWorkspaceWindow {
    interactionCoordinator: state
    frameKey: "insights"
    id: root

    required property var state
    required property var insights
    required property var senomy
    required property var notifications
    required property var battery
    required property var network
    required property var media
    required property var metrics
    property string selectedWikiId: ""
    property bool showChangeDetails:false
    property bool showSystemDetails:false
    property bool showSources:false
    property var openingSnapshot: ({})
    property double briefingNow:Date.now()
    Timer {interval:1000;running:root.requestedOpen;repeat:true;onTriggered:root.briefingNow=Date.now()}
    Connections {
        target:root
        function onRequestedOpenChanged(){if(root.requestedOpen){root.briefingNow=Date.now();root.openingSnapshot=root.currentSnapshot();}}
    }
    Component.onCompleted:if(requestedOpen)openingSnapshot=currentSnapshot()
    function currentSnapshot(){return {cpu:metrics.ready?metrics.cpuPercent:null,memory:metrics.memoryTotalKib>0?metrics.memoryPercent:null,unread:notifications.unreadCount,network:network.detail,networkKey:network.activeConnection!==undefined?[network.activeConnection,network.primaryDevice,network.connectionStateName,network.connectivityName].join("/"):network.detail,power:battery.detail,at:Date.now()};}
    function updateSource(kind){return data("briefing")[kind] || {};}
    function updateAge(kind){const p=updateSource(kind);return p.ok===true?Freshness.describe(Number(p.checked_at)*1000,briefingNow,3600000,true):"UNAVAILABLE · "+(p.state_label || "Not checked");}
    readonly property var attention:attentionItems()
    readonly property var priorityAttention:attention.length?attention[0]:null
    function attentionItems(){
        return BriefingModel.queue(senomy.systemHealth,senomy.message,notifications,network,data("briefing"),briefingNow);
    }
    function changes(){
        const before=openingSnapshot,after=currentSnapshot(),rows=[];
        if(!before.at)return [{label:"BASELINE",value:"Waiting for opening observation"}];
        if(before.cpu!==null && after.cpu!==null)rows.push({label:"CPU",value:(after.cpu-before.cpu>=0?"+":"")+(after.cpu-before.cpu).toFixed(1)+" percentage points"});
        if(before.memory!==null && after.memory!==null)rows.push({label:"MEMORY",value:(after.memory-before.memory>=0?"+":"")+(after.memory-before.memory).toFixed(1)+" percentage points"});
        rows.push({label:"UNREAD",value:(after.unread-before.unread>=0?"+":"")+(after.unread-before.unread)+" notifications"});
        rows.push({label:"CONNECTION",value:after.networkKey===before.networkKey?"Unchanged":after.network});
        rows.push({label:"POWER",value:after.power===before.power?"Unchanged":after.power});
        return rows;
    }

    requestedOpen: !state.capturePaused && state.activePrimary === "insights"
        && state.primaryScreen === (targetScreen ? targetScreen.name : "")
    replacementOpening: state.activePrimary !== "" && state.activePrimary !== "insights"
    title: "SENOMY INSIGHTS"
    eyebrow: "LOCAL SYSTEM BRIEFING"
    activeSection: state.insightsSection
    motif: "identity"
    sections: [
        {id: "briefing", label: "Briefing", glyph:"\uf0e7"},
        {id: "notifications", label: "Notifications", glyph:"\uf0f3"},
        {id: "timeline", label: "Timeline", glyph:"\uf017"},
        {id: "updates", label: "Updates", glyph:"\uf2f1"},
        {id: "diagnostics", label: "Diagnostics", glyph:"\uf0f1"},
        {id: "console", label: "Console", glyph:"\uf120"},
        {id: "reports", label: "Reports", glyph:"\uf15c"},
        {id: "wiki", label: "Wiki", glyph:"\uf02d"}
    ]

    directoryNodes: sections.map(section=>Object.assign({},section,{route:section.id,badge:section.id==="notifications" && notifications.serverEnabled!==false && notifications.unreadCount>0?String(notifications.unreadCount):""}))
    breadcrumb: "SENOMY_systems / insights / "+state.insightsSection
    statusLine: "LOCAL SYSTEM BRIEFING"
    onCloseRequested: state.closePrimary()
    onSurfaceRequested: kind => state.showPrimary(kind, targetScreen ? targetScreen.name : "", kind === "performance" ? state.performanceSection : state.insightsSection)
    onSectionRequested: section => {if(state.allowInteraction())state.insightsSection = section;}

    function payload(route) {
        return insights.payloads[route] || ({ok: false, data: {}, error:{message:"No collected data yet."}});
    }

    function data(route) {
        return payload(route).data || ({});
    }

    function briefingObservations() {
        return [
            {label:"HEALTH",value:String(senomy.systemHealth || "Unknown").toUpperCase(),detail:"Local system state"},
            {label:"CPU",value:metrics.ready?Math.round(metrics.cpuPercent)+"%":"Unavailable",detail:"Current utilisation"},
            {label:"MEMORY",value:metrics.memoryTotalKib>0?Math.round(metrics.memoryPercent)+"%":"Unavailable",detail:"Physical memory used"},
            {label:"NETWORK",value:network.connectionStateName || network.label || network.detail || "Unavailable",detail:(network.connectionStateName || network.label)?network.detail:""},
            {label:"POWER",value:battery.label || battery.detail || "Unavailable",detail:battery.label?battery.detail:""}
        ];
    }
    function compactChanges(){
        const before=openingSnapshot,after=currentSnapshot();
        if(!before.at)return "Waiting for opening observation";
        const rows=changes().filter(row=>row.label==="CPU"?before.cpu!==null && after.cpu!==null && Math.abs(after.cpu-before.cpu)>=5:row.label==="MEMORY"?before.memory!==null && after.memory!==null && Math.abs(after.memory-before.memory)>=1:row.label==="UNREAD"?after.unread!==before.unread:row.value!=="Unchanged");
        return rows.length?rows.map(row=>row.label+" / "+row.value).join(" · "):"No notable changes since opening";
    }

    function briefingContext() {
        return [
            {label: "LOCAL TIME", value: Qt.formatDateTime(new Date(), "ddd dd MMM · hh:mm")},
            {label: "Notifications", glyph:"\uf0f3", value: notifications.unreadCount + " unread"},
            {label:"OFFICIAL UPDATES",value:updateAge("official")},
            {label:"AUR UPDATES",value:updateAge("aur")},
            {label: "MEDIA", value: media.playing ? media.title : "Quiet"},
            {label: "DATA LOCALITY", value: "Local only"}
        ];
    }


    property var pageState: ({})
    function readState(route,key,fallback){const saved=pageState[route] || {};return saved[key]===undefined?fallback:saved[key];}
    function remember(route,key,value){const next=Object.assign({},pageState);next[route]=Object.assign({},next[route] || {});next[route][key]=value;pageState=next;}
    function navigate(route){if(state.allowInteraction())state.insightsSection=route;}
    backHandler:function(){return page.item && typeof page.item.back==="function"?page.item.back():false;}
    Loader {
        id:page;objectName:"insights-route-page";onLoaded:root.revealContent();anchors.fill:parent
        active:root.state.activePrimary==="insights" && root.state.primaryScreen===(root.targetScreen?root.targetScreen.name:"")
        sourceComponent:{switch(root.state.insightsSection){
          case "notifications":return inboxPage;case "timeline":return timelinePage;case "updates":return updatesPage;
          case "diagnostics":return diagnosticsPage;case "console":return consolePage;case "reports":return reportsPage;case "wiki":return wikiPage;default:return briefingPage;
        }}
    }
    Component {id:briefingPage;InsightsWorkspaceBriefing {workspace:root}}
    Component {id:inboxPage;InsightsWorkspaceInbox {workspace:root}}
    Component {id:timelinePage;InsightsWorkspaceTimeline {workspace:root}}
    Component {id:updatesPage;InsightsWorkspaceUpdates {workspace:root}}
    Component {id:diagnosticsPage;InsightsWorkspaceTasks {workspace:root;domain:"diagnostics"}}
    Component {id:consolePage;InsightsWorkspaceTasks {workspace:root;domain:"console"}}
    Component {id:reportsPage;InsightsWorkspaceReports {workspace:root}}
    Component {id:wikiPage;InsightsWorkspaceWiki {workspace:root}}
}
