#!/usr/bin/env python3
"""Keep the real directory layout, replacing only the compositor window host."""
from pathlib import Path

PROPERTIES = """import QtQuick
import Quickshell
import "../config" as Config
import "DirectoryFrameGeometry.js" as FrameGeometry
FocusScope {
 id:root
 property var targetScreen
 property var interactionCoordinator:null
 property bool requestedOpen:true
 property bool surfaceShown:requestedOpen
 function revealContent(){}
 readonly property real presentationProgress:surfaceShown?1:0
 property bool replacementOpening:false
 property string title:""
 property string eyebrow:""
 property var sections:[]
 property string activeSection:""
 property int preferredWidth:1580
 property int preferredHeight:820
 property string motif:""
 property string frameKey:""
 readonly property bool narrowLayout:width<900
 property bool directoryOpen:false
 readonly property int sidebarWidth:238
 onActiveNodeChanged:if(narrowLayout)directoryOpen=false
 property var directoryNodes:[]
 property string activeNode:activeSection
 property var navigationTelemetry:({})
 property bool touchMode:false
 property string breadcrumb:""
 property string statusLine:""
 readonly property var navigation:narrowLayout?drawerNavigation:directoryNavigation
 property alias contentArea:body
 property alias captureItem:surface
 default property alias bodyData:body.data
 signal surfaceRequested(string kind)
 signal closeRequested()
 signal sectionRequested(string section)
 signal nodeRequested(var node)
"""

def directory_host(shell):
    actual=(Path(shell)/"components/DirectorySurfaceWindow.qml").read_text()
    return PROPERTIES+actual[actual.index("    FocusScope {\n        id: surface"):]


def insights_workspace_host(shell):
    """Retain the scoped Insights layout; substitute only native window hosting."""
    actual=(Path(shell)/"components/InsightsWorkspaceWindow.qml").read_text()
    properties=PROPERTIES.replace("readonly property bool narrowLayout:width<900", "readonly property bool narrowLayout:width<900*Config.DirectoryStyle.textScale").replace("readonly property int sidebarWidth:238", "readonly property int sidebarWidth:Math.round(184*Config.DirectoryStyle.textScale)").replace(" property var targetScreen", " property var backHandler:null\n property var targetScreen", 1)
    return properties+actual[actual.index("    FocusScope {\n        id: surface"):]


def performance_workspace_host(shell):
    """Keep the real scoped Performance layout; replace compositor hosting only."""
    actual=(Path(shell)/"components/PerformanceWorkspaceWindow.qml").read_text()
    properties=PROPERTIES.replace("readonly property bool narrowLayout:width<900", "readonly property bool narrowLayout:width<900*Config.DirectoryStyle.textScale").replace("readonly property int sidebarWidth:238", "readonly property int sidebarWidth:Math.round(260*Config.DirectoryStyle.textScale)").replace(" property var targetScreen", " property string directoryQuery:\"\"\n property var directoryExpansion:({compute:true,tools:true})\n property var backHandler:null\n property var targetScreen", 1)
    return properties+actual[actual.index("    FocusScope {\n        id: surface"):]
