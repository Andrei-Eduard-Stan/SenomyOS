"""Actual remaining-panel layouts with only compositor hosting substituted."""
from pathlib import Path
from qa_remaining_hosts import prepare_hosts

def prepare_remaining_panel_hosts(source,work):
    shell=prepare_hosts(source,work)
    popup=shell/'components/BluetoothPopup.qml'
    text=popup.read_text().replace('Interaction.QuickPopoverWindow {','FocusScope {',1).replace('    id:root','''    id:root
    property var targetScreen:({width:1920,height:1080})
    property bool cardShown:true
    readonly property real presentationProgress:cardShown?1:0
    property bool requestedOpen:visible
    property var focusTarget
    property bool keyboardPriority
    function handleEscape(){dismiss();}
    function dismiss(){dismissRequested();}
    signal dismissRequested()''',1).replace('    color:"transparent"','    property color color:"transparent"')
    popup.write_text('\n'.join(line for line in text.splitlines() if not line.strip().startswith('anchor.')))
    return shell
