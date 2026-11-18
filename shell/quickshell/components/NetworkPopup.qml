import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Networking
import "interaction" as Interaction
import "../config" as Config

Interaction.QuickPopoverWindow {
    id:root
    required property var network
    signal openSettingsRequested(string route)
    readonly property real availableWidth:(targetScreen || (anchorItem && anchorItem.Window.window))?(targetScreen?targetScreen.width:anchorItem.Screen.width)-2*Config.Theme.screenInset:460
    readonly property real availableHeight:(targetScreen || (anchorItem && anchorItem.Window.window))?(targetScreen?targetScreen.height:anchorItem.Screen.height)-Config.Theme.railHeight-2*Config.Theme.screenInset:700
    readonly property bool locked:network.actions.locked || !!(network.profiles && network.profiles.actions.locked) || !!(network.connectionAttempt && network.connectionAttempt.busy)
    readonly property var connectedWifi:!network.available?null:network.connectedWifi!==undefined?network.connectedWifi:network.sortedWifiNetworks.find(n=>n.connected) || null
    readonly property var choices:network.available && network.wifiEnabled?network.sortedWifiNetworks.filter(n=>n!==connectedWifi && !n.connected):[]
    readonly property bool hasConnection:network.available && !!network.activeConnection
    function signalPercent(choice){const strength=choice?Number(choice.signalStrength):NaN;return Number.isFinite(strength)?Math.round(strength*(strength<=1?100:1)):null;}
    property string filterMode:"all"
    property bool detailsOpen:false
    readonly property var shownChoices:choices.filter(choice=>(filterMode!=="saved" || choice.known) && String(choice.name || "").toLocaleLowerCase().includes(search.text.trim().toLocaleLowerCase()))
    readonly property real actionWidth:Math.ceil(commandMetrics.advanceWidth)+2*Config.DirectoryStyle.controlInset+Config.DirectoryStyle.controlGap
    readonly property string linkState:!network.available?network.detail:!hasConnection?(!network.wifiHardwareEnabled?"Wi-Fi blocked by hardware":network.wifiEnabled?"Not connected":"Wi-Fi off")
        :network.connectivity===NetworkConnectivity.Full?"Connected · Internet available"
        :network.connectivity===NetworkConnectivity.Portal?"Connected · Sign-in required"
        :network.connectivity===NetworkConnectivity.Limited?"Connected · Limited internet access":"Connected · Internet access unverified"
    function activateChoice(choice) {
        if(locked || !network.available || !network.wifiEnabled || !network.wifiHardwareEnabled || choice.stateChanging)return;
        if(choice.known || choice.security===WifiSecurityType.Open)network.activate(choice);
        else network.openSecurePrompt(choice);
    }
    TextMetrics {id:commandMetrics;text:"Connecting…";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
    TextMetrics {id:titleMetrics;text:"// Network";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.QuickPanelStyle.titleSize}
    implicitWidth:Math.min(460,Math.max(1,availableWidth))
    implicitHeight:Math.min(availableHeight,Math.max(180,2*frame.contentInset+header.height+footer.implicitHeight+24+composition.implicitHeight))
    color:"transparent"
    anchor.item:anchorItem
    anchor.edges:Edges.Top
    anchor.gravity:Edges.Top
    anchor.rect.x:anchorItem?anchorItem.width/2:0
    anchor.rect.width:0
    anchor.rect.height:0
    anchor.rect.y:-12
    Interaction.ContentMotion {targetItem:connectionDetails;context:String(root.detailsOpen);active:root.requestedOpen}
    focusTarget:card
    FocusScope {
        id:card;anchors.fill:parent;focus:root.cardShown
        opacity: root.presentationProgress
        Keys.onEscapePressed:root.handleEscape()
        IslandPopupFrame {
            id:frame;anchors.fill:parent;contentInset:24;frameKey:"control"
            Item {
                id:header;width:parent.width
                readonly property bool stacked:titleMetrics.advanceWidth+power.width+close.width+16>width
                height:stacked?2*Config.DirectoryStyle.controlTarget+4:Config.DirectoryStyle.controlTarget
                Text {width:Math.max(1,parent.width-(header.stacked?close.width:power.width+close.width+12));height:Config.DirectoryStyle.controlTarget;text:"// Network";verticalAlignment:Text.AlignVCenter;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Math.round(16*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.ink;elide:Text.ElideRight}
                QuietButton {id:power;objectName:"wifiToggle";x:header.stacked?0:close.x-width-8;y:header.stacked?Config.DirectoryStyle.controlTarget+4:0;width:root.actionWidth;height:Config.DirectoryStyle.controlTarget;text:!root.network.available?"Wi-Fi":root.network.wifiEnabled?"Wi-Fi on":"Wi-Fi off";glyph:"\uf1eb";Accessible.checkable:true;Accessible.checked:root.network.wifiEnabled;enabled:root.network.available && root.network.wifiHardwareEnabled && !root.locked;accessibleLabel:!root.network.available?"Wi-Fi unavailable":!root.network.wifiHardwareEnabled?"Wi-Fi blocked by hardware":root.network.wifiEnabled?"Turn Wi-Fi off":"Turn Wi-Fi on";onClicked:root.network.toggleWifi()}
                QuietButton {id:close;anchors.right:parent.right;width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:"\uf00d";accessibleLabel:"Close Network";onClicked:root.dismiss()}
            }
            Column {
                id:footer;anchors.bottom:parent.bottom;width:parent.width;spacing:12
                IslandRule {width:parent.width;leadingPoint:false}
                QuietButton {objectName:"networkSettings";width:parent.width;height:Config.DirectoryStyle.controlTarget;text:"Network Settings";glyph:"\uf013";onClicked:root.openSettingsRequested("network/wifi")}
            }
            FocusScrollArea {
                id:viewport;objectName:"networkViewport";anchors.fill:parent;anchors.topMargin:header.height+12;anchors.bottomMargin:footer.implicitHeight+12;anchors.leftMargin:-Config.DirectoryStyle.controlInset;anchors.rightMargin:-Config.DirectoryStyle.controlInset
                contentHeight:composition.implicitHeight
                ScrollBar.vertical:ShellScrollBar {}
                Column {
                    id:composition;x:Config.DirectoryStyle.controlInset;width:viewport.width-2*x;spacing:12
                    Row {
                        width:parent.width;spacing:12
                        Text {width:20;height:44;text:root.connectedWifi?"\uf1eb":"\uf0ac";font.family:"Font Awesome 7 Free Solid";font.weight:Font.Black;font.pixelSize:18;color:Config.DirectoryStyle.muted;verticalAlignment:Text.AlignVCenter;Accessible.ignored:true}
                        Column {
                            width:parent.width-32;spacing:6
                            Text {width:parent.width;text:root.network.available?(root.network.activeConnection || "No active connection"):"Network unavailable";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(20*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
                            Text {width:parent.width;text:root.linkState;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:root.network.connectivity===NetworkConnectivity.Portal?Config.Theme.warning:Config.DirectoryStyle.muted}
                        }
                    }
                    Flow {
                        id:linkTools;width:parent.width;spacing:8;visible:root.hasConnection
                        readonly property bool stacked:width<root.actionWidth+200*Config.DirectoryStyle.textScale
                        Text {width:linkTools.stacked?parent.width:Math.max(1,parent.width-root.actionWidth-parent.spacing);height:Math.max(Config.DirectoryStyle.controlTarget,implicitHeight);text:root.connectedWifi && root.signalPercent(root.connectedWifi)!==null?root.signalPercent(root.connectedWifi)+"% signal · "+(root.connectedWifi.security===WifiSecurityType.Open?"Open network":root.connectedWifi.known?"Saved":"Secured"):"Current network link";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;verticalAlignment:Text.AlignVCenter;wrapMode:Text.WordWrap}
                        QuietButton {id:details;objectName:"networkDetails";width:linkTools.stacked?parent.width:root.actionWidth;height:Config.DirectoryStyle.controlTarget;text:"Details";glyph:root.detailsOpen?"\uf077":"\uf078";accessibleLabel:root.detailsOpen?"Hide connection details":"Show connection details";Accessible.expandable:true;Accessible.expanded:root.detailsOpen;onClicked:root.detailsOpen=!root.detailsOpen}
                    }
                    Column {
                        id:connectionDetails
                        width:parent.width;spacing:8;visible:root.detailsOpen && root.hasConnection
                        Text {width:parent.width;text:[root.network.primaryDevice?"Interface · "+root.network.primaryDevice:"",root.connectedWifi?"Security · "+WifiSecurityType.toString(root.connectedWifi.security):""].filter(Boolean).join("\n");font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap;textFormat:Text.PlainText}
                        QuietButton {objectName:"networkDisconnect";width:parent.width;height:Config.DirectoryStyle.controlTarget;visible:!!root.connectedWifi;text:"Disconnect from this network";enabled:!root.locked;onClicked:root.network.activate(root.connectedWifi)}
                    }
                    NetworkQuickActionReview {width:parent.width;actions:root.network.actions}
                    Text {width:parent.width;visible:!!text;text:root.network.connectionAttempt?root.network.connectionAttempt.message || "":"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.Theme.warning;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                    QuietButton {objectName:"networkPortal";width:parent.width;height:Config.DirectoryStyle.controlTarget;visible:!!(root.network.profiles && root.network.profiles.status && root.network.profiles.status.connectivity==="portal");text:"Open network sign-in";glyph:"\uf35d";enabled:visible && !!root.network.profiles.status.portalUri && !root.locked;onClicked:root.network.openPortal()}
                    Text {width:parent.width;visible:!!text;text:root.network.handoffMessage || "";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                    IslandRule {width:parent.width;leadingPoint:false}
                    TextField {
                        id:search;objectName:"networkSearch";width:parent.width;height:Config.DirectoryStyle.controlTarget
                        placeholderText:"Find a nearby network…";Accessible.name:"Filter nearby networks by name";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize
                        enabled:root.network.available && root.network.wifiEnabled;color:Config.DirectoryStyle.ink;placeholderTextColor:Config.DirectoryStyle.muted;selectionColor:Config.DirectoryStyle.selection;selectedTextColor:Config.DirectoryStyle.ink;leftPadding:12;rightPadding:12
                        background:Rectangle {color:Config.DirectoryStyle.selection;border.width:search.visualFocus?1:0;border.color:Config.DirectoryStyle.ink}
                    }
                    Flow {
                        id:filters;width:parent.width;spacing:8
                        TextMetrics {id:filterMeasure;text:"Scanning…";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                        readonly property real cellMinimum:Math.ceil(filterMeasure.advanceWidth)+2*Config.DirectoryStyle.controlInset
                        readonly property int columns:width>=3*cellMinimum+16?3:width>=2*cellMinimum+8?2:1
                        readonly property real cellWidth:Math.floor((width-(columns-1)*spacing)/columns)
                        QuietButton {objectName:"networkFilterAll";width:filters.cellWidth;height:Config.DirectoryStyle.controlTarget;text:"All";enabled:root.network.available && root.network.wifiEnabled;active:root.filterMode==="all";Accessible.checkable:true;Accessible.checked:active;onClicked:root.filterMode="all";Rectangle {anchors.bottom:parent.bottom;anchors.bottomMargin:6;anchors.horizontalCenter:parent.horizontalCenter;width:16;height:1;color:Config.DirectoryStyle.ink;visible:root.filterMode==="all"}}
                        QuietButton {objectName:"networkFilterSaved";width:filters.cellWidth;height:Config.DirectoryStyle.controlTarget;text:"Saved";enabled:root.network.available && root.network.wifiEnabled;active:root.filterMode==="saved";Accessible.checkable:true;Accessible.checked:active;onClicked:root.filterMode="saved";Rectangle {anchors.bottom:parent.bottom;anchors.bottomMargin:6;anchors.horizontalCenter:parent.horizontalCenter;width:16;height:1;color:Config.DirectoryStyle.ink;visible:root.filterMode==="saved"}}
                        QuietButton {objectName:"networkRefresh";width:filters.cellWidth;height:Config.DirectoryStyle.controlTarget;text:root.network.scanning?"Scanning…":"Refresh";enabled:root.network.available && root.network.wifiEnabled && root.network.wifiHardwareEnabled && !root.network.scanning && !root.locked;onClicked:root.network.refreshNetworks()}
                    }
                    Text {width:parent.width;visible:root.shownChoices.length===0;text:!root.network.available?"NetworkManager is unavailable.":!root.network.wifiHardwareEnabled?"Wi-Fi is disabled by hardware.":!root.network.wifiEnabled?"Turn Wi-Fi on to discover networks.":root.network.scanning?"Looking for nearby networks…":search.text.trim()?"No matching networks. Try another name.":root.filterMode==="saved"?"No other saved networks nearby.":"No other networks found. Refresh to scan.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                    FocusDeviceList {
                        id:list;objectName:"networkChoices";x:-Config.DirectoryStyle.controlInset;width:parent.width+2*Config.DirectoryStyle.controlInset;height:Math.min(contentHeight,Math.round(240*Config.DirectoryStyle.textScale));visible:root.shownChoices.length>0;spacing:2;clip:true;model:root.shownChoices
                        ScrollBar.vertical:ShellScrollBar {}
                        delegate:NetworkQuickChoiceRow {
                            required property var modelData;width:list.width;choice:modelData;actionWidth:root.actionWidth
                            canConnect:root.network.available && root.network.wifiEnabled && root.network.wifiHardwareEnabled && !root.locked && (choice.known || choice.security===WifiSecurityType.Open || root.network.authenticationAvailable!==false)
                            onActivated:root.activateChoice(choice)
                        }
                    }
                }
            }
        }
    }
}
