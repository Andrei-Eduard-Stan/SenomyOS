import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower
import ".."
import "../../config" as Config

FocusScrollArea {
    id: root
    required property var inputSettings
    property string part: "overview"
    readonly property var prefs: inputSettings && inputSettings.preferences ? inputSettings.preferences : null
    property double clock: Date.now()
    signal destinationRequested(string id)
    function value(key,fallback) { return prefs && prefs.draft[key] !== undefined ? prefs.draft[key] : fallback; }
    function canEdit(key) { return !!prefs && prefs.available && !prefs.locked && prefs.capabilities[key] === true; }
    function edit(key,value) { if (prefs) prefs.edit(key,value); }
    Timer { interval: 1000; running: !!root.prefs && root.prefs.pendingToken.length > 0; repeat: true; onTriggered: root.clock=Date.now() }
    ScrollBar.vertical: ShellScrollBar {}
    contentHeight: inputColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Column {
        id: inputColumn
        width: parent.width
        spacing: 12
        ControlWorkspaceButton { width:parent.width; text:"DISPLAY PROJECTION · SUPER + CTRL + P"; onClicked:root.destinationRequested("devices/displays") }
        DashboardCard {
            width: parent.width
            visible: root.part === "pointer" || root.part === "keyboard"
            title: "GLOBAL INPUT DEFAULTS"
            value: root.prefs && root.prefs.available ? "COMPOSITOR VALUES READ" : "EFFECTIVE VALUES UNAVAILABLE"
            detail: "Applies globally, not to a selected device. Device overrides can take precedence; physical behavior needs hardware verification. Drafts are inactive until previewed and confirmed."
        }
        Column {
            width: parent.width; spacing: 12; visible: root.part === "pointer"
            DashboardCard {
                width: parent.width; title: "POINTER SENSITIVITY"
                value: Number(root.value("sensitivity",0)).toFixed(2)
                detail: "Draft · -1 slower / +1 faster · previous values return if preview expires"
            }
            CathedralSlider {
                objectName: "control-pointer-sensitivity"; width: parent.width
                from:-1; to:1; stepSize:0.1; value:root.value("sensitivity",0)
                enabled:root.canEdit("sensitivity"); onMoved:root.edit("sensitivity",Math.round(value*10)/10)
                Accessible.name:"Global pointer sensitivity draft"
            }
            ControlWorkspaceButton {
                width:parent.width; objectName:"control-left-handed"
                text:active ? "LEFT HANDED ON" : "LEFT HANDED OFF"
                active:root.value("leftHanded",false); enabled:root.canEdit("leftHanded")
                onClicked:root.edit("leftHanded",!active)
            }
            Row {
                width:parent.width; spacing:10
                ControlWorkspaceButton {
                    width:(parent.width-10)/2; objectName:"control-natural-scroll"
                    text:active ? "TOUCHPAD NATURAL ON" : "TOUCHPAD NATURAL OFF"
                    active:root.value("naturalScroll",false); enabled:root.canEdit("naturalScroll")
                    onClicked:root.edit("naturalScroll",!active)
                }
                ControlWorkspaceButton {
                    width:(parent.width-10)/2; objectName:"control-tap-click"
                    text:active ? "TAP TO CLICK ON" : "TAP TO CLICK OFF"
                    active:root.value("tapToClick",false); enabled:root.canEdit("tapToClick")
                    onClicked:root.edit("tapToClick",!active)
                }
            }
            ControlWorkspaceButton {
                width:parent.width; objectName:"control-disable-while-typing"
                text:active ? "TOUCHPAD PAUSES WHILE TYPING" : "TOUCHPAD ACTIVE WHILE TYPING"
                active:root.value("disableWhileTyping",false); enabled:root.canEdit("disableWhileTyping")
                onClicked:root.edit("disableWhileTyping",!active)
            }
            Text { text:"Touchpad scroll factor · " + Number(root.value("touchpadScrollFactor",1)).toFixed(1); color:Config.Theme.muted }
            CathedralSlider {
                width:parent.width; objectName:"control-touchpad-scroll-factor"; from:0; to:2; stepSize:0.1
                value:root.value("touchpadScrollFactor",1); enabled:root.canEdit("touchpadScrollFactor")
                onMoved:root.edit("touchpadScrollFactor",Math.round(value*10)/10)
                Accessible.name:"Global touchpad scroll factor draft"
            }
            ControlWorkspaceButton {
                width:parent.width; objectName:"control-mouse-natural-scroll"
                text:active ? "MOUSE NATURAL SCROLL ON" : "MOUSE NATURAL SCROLL OFF"
                active:root.value("mouseNaturalScroll",false); enabled:root.canEdit("mouseNaturalScroll")
                onClicked:root.edit("mouseNaturalScroll",!active)
            }
            Text { text:"Mouse / pointing stick scroll factor · " + Number(root.value("mouseScrollFactor",1)).toFixed(1); color:Config.Theme.muted }
            CathedralSlider {
                width:parent.width; objectName:"control-mouse-scroll-factor"; from:0; to:2; stepSize:0.1
                value:root.value("mouseScrollFactor",1); enabled:root.canEdit("mouseScrollFactor")
                onMoved:root.edit("mouseScrollFactor",Math.round(value*10)/10)
                Accessible.name:"Global mouse scroll factor draft"
            }
        }
        Column {
            width:parent.width; spacing:12; visible:root.part === "keyboard"
            Text { width:parent.width; wrapMode:Text.WordWrap; text:"KEYBOARD // SYSTEM XKB CATALOG"; color:Config.Theme.dim; font.family:Config.Theme.fontFamily; font.pixelSize:10 }
            DashboardCard {
                width:parent.width; visible:!!root.prefs && root.prefs.firstRun
                title:"KEYBOARD PREFERENCES NOT VERIFIED AND SAVED"
                value:root.prefs ? root.prefs.persistence.toUpperCase() : "UNAVAILABLE"
                detail:"Review current values, preview, then confirm. Legacy preferences are preserved and never automatically replayed."
            }
            ShellComboBox {
                id:keyboardLayout; objectName:"control-keyboard-layout"; width:parent.width
                model:root.prefs ? (root.prefs.layouts.indexOf(root.value("layout","")) >= 0 ? root.prefs.layouts : [root.value("layout","")].concat(root.prefs.layouts)) : []
                currentIndex:Math.max(0,model.indexOf(root.value("layout","")))
                enabled:root.canEdit("layout") && model.length>0
                onActivated:root.edit("layout",currentText)
                Accessible.name:"Global primary keyboard layout draft"
            }
            ShellComboBox {
                objectName:"control-keyboard-variant"; width:parent.width
                model:["default"].concat(root.prefs && root.prefs.variants[root.value("layout","")] ? root.prefs.variants[root.value("layout","")].filter(v=>v!=="") : [])
                currentIndex:Math.max(0,model.indexOf(root.value("variant","") || "default"))
                enabled:root.canEdit("variant")
                onActivated:root.edit("variant",currentText === "default" ? "" : currentText)
                Accessible.name:"Global keyboard variant draft"
            }
            ControlWorkspaceButton {
                width:parent.width; objectName:"control-us-fallback"
                text:active ? "US FALLBACK LAYOUT ON" : "US FALLBACK LAYOUT OFF"
                active:root.value("usFallback",false); enabled:root.canEdit("usFallback") && root.value("layout","")!=="us"
                onClicked:root.edit("usFallback",!active)
            }
            Text { width:parent.width; wrapMode:Text.WordWrap; color:Config.Theme.muted; text:"Observed global layouts: " + (root.prefs ? root.prefs.rawOptions["input:kb_layout"] || "unavailable" : "unavailable") + " · variants: " + (root.prefs ? root.prefs.rawOptions["input:kb_variant"] || "default" : "unavailable") }
            Text { width:parent.width; wrapMode:Text.WordWrap; text:"Super + Space switches the configured layouts. Existing shortcuts, XKB options and device overrides are preserved."; color:Config.Theme.muted }
            Row {
                width:parent.width; spacing:10
                Column {
                    width:(parent.width-10)/2; spacing:4
                    Text { text:"Repeat rate / second"; color:Config.Theme.muted }
                    ShellSpinBox {
                        objectName:"control-repeat-rate"; width:parent.width; from:0; to:200
                        value:root.value("repeatRate",25); editable:true; enabled:root.canEdit("repeatRate")
                        onValueModified:root.edit("repeatRate",value)
                        Accessible.name:"Global keyboard repeat rate draft"
                    }
                }
                Column {
                    width:(parent.width-10)/2; spacing:4
                    Text { text:"Repeat delay (ms)"; color:Config.Theme.muted }
                    ShellSpinBox {
                        objectName:"control-repeat-delay"; width:parent.width; from:0; to:2000; stepSize:50
                        value:root.value("repeatDelay",600); editable:true; enabled:root.canEdit("repeatDelay")
                        onValueModified:root.edit("repeatDelay",value)
                        Accessible.name:"Global keyboard repeat delay draft"
                    }
                }
            }
        }
        Column {
            width:parent.width; spacing:12; visible:root.part === "pointer" || root.part === "keyboard"
            Text {
                width:parent.width; wrapMode:Text.WordWrap; color:Config.Theme.muted
                text:root.prefs && root.prefs.persistenceReady ? "Reload persistence hook is active. Saving follows verification and confirmation." : "Reload persistence hook is inactive. Confirmation keeps runtime values temporarily; no preference will be saved."
            }
            Text {
                width:parent.width; wrapMode:Text.WordWrap; color:Config.Theme.muted
                text:root.prefs && root.prefs.dirty ? "Draft changes: " + Object.keys(root.prefs.draft).filter(k=>root.prefs.draft[k] !== root.prefs.effective[k]).map(k=>k + " = " + root.prefs.draft[k]).join(" · ") : "No unapplied draft changes."
            }
            ControlWorkspaceButton {
                objectName:"control-input-preview"; width:parent.width
                text:root.prefs && root.prefs.busy ? "WAITING FOR INPUT CONTROLLER…" : "PREVIEW INPUT CHANGES"
                enabled:!!root.prefs && root.prefs.available && !root.prefs.locked && !root.prefs.staleDraft && (root.prefs.dirty || root.prefs.firstRun)
                onClicked:root.prefs.applyDraft(root.part)
                Accessible.name:"Preview global input changes before saving"
            }
            Row {
                width:parent.width; spacing:10; visible:!!root.prefs && root.prefs.pendingToken.length>0
                ControlWorkspaceButton {
                    objectName:"control-input-confirm"; width:(parent.width-10)/2
                    text:"KEEP (" + Math.max(0,Math.ceil(((root.prefs ? root.prefs.pending.deadline : 0)-root.clock)/1000)) + "s)"
                    enabled:!!root.prefs && !root.prefs.busy; onClicked:root.prefs.confirm()
                }
                ControlWorkspaceButton {
                    objectName:"control-input-revert"; width:(parent.width-10)/2; text:"REVERT NOW"
                    enabled:!!root.prefs && !root.prefs.busy; onClicked:root.prefs.revert()
                }
            }
            ControlWorkspaceButton {
                objectName:"control-input-discard"; width:parent.width; text:"DISCARD DRAFT / READ CURRENT VALUES"
                enabled:!!root.prefs && !root.prefs.locked
                onClicked:{root.prefs.resetDraft();root.prefs.refresh();}
            }
            Text {
                width:parent.width; wrapMode:Text.WordWrap; color:Config.Theme.muted; font.family:Config.Theme.fontFamily; font.pixelSize:10
                text:root.prefs ? root.prefs.message + (root.prefs.staleDraft ? " Configuration changed externally. Discard the stale draft and review current values." : "") + (root.prefs.externalConflict ? " Runtime differs from saved preferences; reopening Settings will not overwrite it. Saved values replay on configuration reload." : "") : "Input state unavailable."
            }
        }
        Column {
            width: parent.width
            spacing: 12
            visible: root.part === "methods"
            NativeInputToolsView {
                width: parent.width
                settings: root.inputSettings
            }
            ControlWorkspaceButton {
                width: parent.width
                text: "OPEN INPUT DEVICE INVENTORY"
                onClicked: root.destinationRequested("devices/inputs")
            }
            ControlWorkspaceButton {
                width: parent.width
                text: "MICROPHONE CONTROLS › AUDIO"
                onClicked: root.destinationRequested("audio/overview/microphone")
            }
        }
        ControlRouteTiles {
            width: parent.width
            visible: root.part === "overview"
            entries: [
                {
                    id: "input/pointer",
                    label: "POINTER & TOUCHPAD",
                    detail: "Sensitivity, scroll and tap"
                },
                {
                    id: "input/keyboard",
                    label: "KEYBOARD LAYOUTS",
                    detail: "Layout and key repeat"
                },
                {
                    id: "input/methods",
                    label: "INPUT METHODS & OSK",
                    detail: "Native input tools and on-screen keyboard"
                }
            ]
            onActivated: id => root.destinationRequested(id)
        }
    }
}
