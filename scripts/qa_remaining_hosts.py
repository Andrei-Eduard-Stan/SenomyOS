#!/usr/bin/env python3
"""Actual native surface layouts, replacing only compositor window hosting.

No shell services or notification bus owner are started by these UI fixtures.
"""
from pathlib import Path
import re
import shutil

def prepare_hosts(shell, test):
    shell=Path(shell);test=Path(test)
    (test/'shell').mkdir(exist_ok=True)
    shutil.copytree(shell,test/'shell/quickshell',symlinks=True)
    for name in ['assets','appearance']:
        (test/name).symlink_to(shell.parents[1]/name,target_is_directory=True)
    c=test/'shell/quickshell/components'
    common='''import QtQuick
    import QtQuick.Controls
    import QtQuick.Window
    import Quickshell
    import "../config" as Config
    import "audio" as Audio
    FocusScope {
     id:root
     property var targetScreen: ({name:"fixture",width:1920,height:1080})
     property bool reducedMotion:false
     property var interactionCoordinator:null
     property bool fullSettings:false
     property int settingsPreferredWidth:1280
     property int settingsPreferredHeight:860
     signal modeRequested(bool full)
     property var nativeSettingsWindow:({maximized:false})
     property bool settingsMaximized:false
     function setSettingsMaximized(value){settingsMaximized=value;}
     property bool requestedOpen:true
     property bool replacementOpening:false
     property bool cardShown:true
     readonly property real presentationProgress: fixtureMotion.progress
     property QtObject fixtureMotion: QtObject { property real progress:root.cardShown?1:0; Behavior on progress {NumberAnimation {duration:root.cardShown?Config.Motion.compactMs:Config.Motion.closeMs}} }
     property bool surfaceShown:true
 function revealContent(){}
     property string title:""
     property string eyebrow:""
     property string activeSection:"overview"
     property string frameKey:""
     property string motif:""
     property var sections:[]
     property var navigationNodes:[]
     property string searchQuery:""
     property string activeNode:"overview"
     signal nodeRequested(var node)
     property int preferredWidth:1120
     property int preferredHeight:820
     property real anchorCenterX:width/2
     property real surfaceLeft:0
     property int implicitWidth:1120
     property int implicitHeight:820
     property var anchorItem:null
     property real availableWidth:width
     property real availableHeight:height
     function dismiss(){dismissRequested();return true;}
     function handleEscape(){dismissRequested();}
     signal dismissRequested()
     signal closeRequested()
     signal sectionRequested(string section)
    '''.replace('     property int implicitWidth:1120\n     property int implicitHeight:820\n','')
    actual=(c/'DashboardWindow.qml').read_text();body=actual[actual.index('    FocusScope {\n        id: surface'):].replace('        parent: root.fullSettings ? settingsNative.contentItem : root.contentItem\n', '')
    (c/'DashboardWindow.qml').write_text(common+''' readonly property int sidebarWidth:SIDEBAR_VALUE
     readonly property bool narrowLayout:width<850*Config.DirectoryStyle.textScale
     property bool navigationOpen:false
     onActiveSectionChanged:if(narrowLayout)navigationOpen=false
     readonly property var navigation:narrowLayout ? drawerNav : nav
     property alias contentArea:body
     default property alias bodyData:body.data
    '''.replace('SIDEBAR_VALUE',re.search(r'readonly property int sidebarWidth: (.+)',actual).group(1))+body.replace('                    DashboardNavigation {\n                        anchors.fill:parent;anchors.margins:8','                    DashboardNavigation {\n                        id:drawerNav\n                        anchors.fill:parent;anchors.margins:8'))
    # Popup actual layout and animation remain; only compositor hosting/grabs/timers
    # are omitted. Data/actions come exclusively from fixture objects.
    for name,props in [('VolumePopup','property var audio\n property var media:null\n signal openAudioRequested()'),('PowerPopup','property var powerService'),('NotificationCenter','property var notifications\n property string clearContext:"notifications:fixture"\n signal openHistoryRequested()'),('TrayPopup',''),('CalendarPopup','')]:
     actual=(c/(name+'.qml')).read_text();inner=actual[actual.index('    FocusScope {\n        id: card'):]
     extra=props+'\n'
     if name=='CalendarPopup':
      extra+='property var calendarService:null\n readonly property int displayedYear: CalendarState.Navigation.monthStart.getFullYear()\n readonly property int displayedMonth: CalendarState.Navigation.monthStart.getMonth()\n signal openCalendarRequested(string route)\n'
     nativeimports='import Quickshell.Services.SystemTray\n' if name=='TrayPopup' else ''
     if name=='CalendarPopup': nativeimports+='import \"calendar\" as CalendarUi\nimport \"../services/calendar\" as CalendarState\n'
     if name=='NotificationCenter': nativeimports+='import \"notifications\" as Notifications\n'
     (c/(name+'.qml')).write_text(nativeimports+common+extra+inner)
    # Panel-based toast: replace only outer window declarations with an
    # item host, retain all state behavior and actual content.
    for name in ['NotificationToast']:
     s=(c/(name+'.qml')).read_text();s=s.replace('PanelWindow {','FocusScope {',1)
     a=s.index('    screen: targetScreen');b=s.index('    Connections {',a)
     old=s[a:b]
     fields=[]
     for line in old.splitlines():
      if line.strip().startswith(('readonly property','implicitWidth:','implicitHeight:')):fields.append(line)
     # State controllers occur before the native screen declarations.
     s=s[:a]+'\n'.join(fields)+'\n'+s[b:]
     (c/(name+'.qml')).write_text(s)
    return test/"shell/quickshell"
