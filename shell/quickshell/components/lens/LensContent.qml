import QtQuick
import Quickshell
import QtQuick.Controls
import ".." as UI
import "../../config" as Config
import "LensSearch.js" as Search

FocusScope {
    id: root
    required property var lens
    onSearchTextChanged: lens.inputRevision++
    property alias searchText: query.text
    property alias searchInput: query
    property alias selectedIndex: list.currentIndex
    property string selectionId: ""
    property string applicationSort: "frequent"
    readonly property int rowHeight: Math.max(Config.DirectoryStyle.controlTarget, Math.ceil((Math.max(Config.DirectoryStyle.bodySize, Math.round(16*Config.DirectoryStyle.textScale)) + Config.DirectoryStyle.detailSize) * 1.2 + 2 + 2 * Config.DirectoryStyle.controlVerticalInset))
    function resetSelection() {selectionId="";list.currentIndex=lens.results.length?0:-1;list.positionViewAtBeginning();}
    function moveSelection(delta) {
        if (!lens.results.length) return;
        list.currentIndex=Math.max(0,Math.min(lens.results.length-1,list.currentIndex+delta));
        selectionId=lens.results[list.currentIndex].id;
        list.positionViewAtIndex(list.currentIndex,ListView.Contain);
    }
    function selectScope(scope) {lens.setMode(scope);query.forceActiveFocus();}
    Connections {
        target: root.lens
        function onResultsChanged() {
            const index=root.selectionId?root.lens.results.findIndex(r=>r.id===root.selectionId):-1;
            list.currentIndex=index>=0?index:root.lens.results.length?0:-1;
            if(list.currentIndex>=0)list.positionViewAtIndex(list.currentIndex,ListView.Contain);
        }
    }
    Keys.onEscapePressed: lens.handleEscape()
    Keys.onPressed: event => {
        const direction=(event.key===Qt.Key_Tab && (event.modifiers & Qt.ControlModifier)) ? (event.modifiers & Qt.ShiftModifier ? -1 : 1)
            : (event.modifiers & Qt.AltModifier) && event.key===Qt.Key_Right ? 1
            : (event.modifiers & Qt.AltModifier) && event.key===Qt.Key_Left ? -1 : 0;
        if(direction) {const modes=["all","apps","files","windows","actions"];selectScope(modes[(modes.indexOf(lens.mode)+direction+5)%5]);event.accepted=true;}
        else if(event.key===Qt.Key_PageDown || event.key===Qt.Key_PageUp) {moveSelection((event.key===Qt.Key_PageDown?1:-1)*Math.max(1,Math.floor(list.height/(root.rowHeight+2))));event.accepted=true;}
        else if ((event.modifiers & Qt.AltModifier) && event.key>=Qt.Key_1 && event.key<=Qt.Key_5) {selectScope(["all","apps","files","windows","actions"][event.key-Qt.Key_1]);event.accepted=true;}
    }
    Shortcut {sequence:"Alt+1";enabled:lens.cardShown;onActivated:root.selectScope("all")}
    Shortcut {sequence:"Alt+2";enabled:lens.cardShown;onActivated:root.selectScope("apps")}
    Shortcut {sequence:"Alt+3";enabled:lens.cardShown;onActivated:root.selectScope("files")}
    Shortcut {sequence:"Alt+4";enabled:lens.cardShown;onActivated:root.selectScope("windows")}
    Shortcut {sequence:"Alt+5";enabled:lens.cardShown;onActivated:root.selectScope("actions")}
    // The host retains the surface until this shared progress reaches zero.
    visible: lens.cardShown || lens.presentationProgress > 0
    opacity: lens.presentationProgress
    transform: Translate { y: (1-lens.presentationProgress)*Config.Motion.travel }
    LensFrame {
        id:frame
        anchors.fill:parent
        contentInset:root.width<400?16:24
        Column {
            anchors.fill:parent;spacing:0
            Item {
                id:header;width:parent.width;height:Math.max(Config.DirectoryStyle.controlTarget, Math.round(24*Config.DirectoryStyle.textScale))
                Text {
                    id:title;anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter
                    text:"// Command Lens";color:Config.DirectoryStyle.ink
                    font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Math.round((root.width<400?13:16)*Config.DirectoryStyle.textScale)
                    width:Math.min(implicitWidth,parent.width-closeButton.width-16);elide:Text.ElideRight
                }
                Rectangle {
                    anchors.left:title.right;anchors.leftMargin:14;anchors.right:closeButton.left;anchors.rightMargin:14
                    anchors.verticalCenter:parent.verticalCenter;height:1;color:Config.DirectoryStyle.rule
                    Rectangle {width:3;height:3;y:-1;color:Config.DirectoryStyle.muted}
                }
                UI.DashboardButton {id:closeButton;anchors.right:parent.right;width:Config.DirectoryStyle.controlTarget;height:parent.height;headerControl:true;text:"×";accessibleLabel:"Close Command Lens";onClicked:lens.dismiss()}
            }
            Item {width:1;height:8}
            TextField {
                id:query;objectName:"lensSearch";width:parent.width;height:Math.max(Config.DirectoryStyle.controlTarget, Math.round(32*Config.DirectoryStyle.textScale)+32)
                Accessible.name:"Search Command Lens";Accessible.description:"Search all providers or choose a scope. Arrow keys select; Enter opens; Alt 1 to 5 filters."
                placeholderText:lens.mode==="all"?"Search apps, files, windows…":"Search "+lens.mode+"…"
                font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round((root.width<400?21:25)*Config.DirectoryStyle.textScale)
                color:Config.DirectoryStyle.ink;placeholderTextColor:Config.DirectoryStyle.dim;selectionColor:Config.DirectoryStyle.selection;selectedTextColor:Config.DirectoryStyle.ink
                leftPadding:Config.DirectoryStyle.controlInset+24+Config.DirectoryStyle.controlGap;rightPadding:query.text?52:12;selectByMouse:true
                background:Item {
                    Canvas {
                        x:Config.DirectoryStyle.controlInset;anchors.verticalCenter:parent.verticalCenter;width:24;height:24
                        onPaint:{const c=getContext("2d");c.reset();c.strokeStyle=Config.DirectoryStyle.muted;c.lineWidth=1.5;c.beginPath();c.arc(9.5,9.5,6.5,0,Math.PI*2);c.moveTo(14.5,14.5);c.lineTo(21,21);c.stroke();}
                    }
                    Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:1;color:query.activeFocus?Config.DirectoryStyle.muted:Config.DirectoryStyle.rule}
                }
                UI.DashboardButton {
                    objectName:"lensClearSearch";anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter
                    width:Config.DirectoryStyle.controlTarget;height:Config.DirectoryStyle.controlTarget
                    visible:!!query.text;text:"×";accessibleLabel:"Clear search";headerControl:true
                    onClicked:{query.text="";query.forceActiveFocus();}
                    ToolTip.visible:pointerHovered;ToolTip.text:"Clear search";ToolTip.delay:500
                }
                onTextChanged:root.resetSelection()
                Keys.onDownPressed:root.moveSelection(1)
                Keys.onUpPressed:root.moveSelection(-1)
                Keys.onReturnPressed:event=>lens.activate(list.currentIndex,!!(event.modifiers & Qt.ControlModifier) && !!(event.modifiers & Qt.ShiftModifier))
                Keys.onEscapePressed:lens.handleEscape()
            }
            Item {width:1;height:8}
            Flow {
                id:filters;width:parent.width;spacing:4
                readonly property int columns:width >= 5*(tabMeasure.advanceWidth+2*Config.DirectoryStyle.controlInset)+16 ? 5 : width >= 3*(tabMeasure.advanceWidth+2*Config.DirectoryStyle.controlInset)+8 ? 3 : 2
                TextMetrics {id:tabMeasure;text:"Windows";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.max(12,Config.DirectoryStyle.bodySize-1)}
                Repeater {
                    model:["all","apps","files","windows","actions"]
                    delegate:Button {
                        id:filter
                        required property string modelData
                        width:Math.floor((filters.width-(filters.columns-1)*filters.spacing)/filters.columns);height:Config.DirectoryStyle.controlTarget
                        leftPadding:Config.DirectoryStyle.controlInset;rightPadding:Config.DirectoryStyle.controlInset
                        Accessible.name:"Search "+modelData;Accessible.description:"Alt+"+(["all","apps","files","windows","actions"].indexOf(modelData)+1)
                        Accessible.checkable:true;Accessible.checked:lens.mode===modelData
                        text:modelData[0].toUpperCase()+modelData.slice(1)
                        hoverEnabled:true
                        onClicked:root.selectScope(modelData)
                        background:Rectangle {color:lens.mode===filter.modelData?Config.DirectoryStyle.selection:"transparent";border.width:0}
                        UI.ButtonHoverFrame { focused: filter.visualFocus; selected: false; anchors.fill: parent; engaged: filter.enabled && filter.hovered }
                        Rectangle { anchors.bottom:parent.bottom; anchors.horizontalCenter:parent.horizontalCenter; width:16;height:1;visible:lens.mode===filter.modelData;color:Config.DirectoryStyle.ink }
                        contentItem:Text {text:filter.text;color:lens.mode===filter.modelData || filter.hovered?Config.DirectoryStyle.ink:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Math.max(11,Math.round(11*Config.DirectoryStyle.textScale));font.weight:lens.mode===filter.modelData?Font.DemiBold:Font.Normal;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
                    }
                }
            }
            Item {width:1;height:16}
            Item {
                id:section;width:parent.width;height:lens.mode==="apps"?48:28
                Column {
                    anchors.left:parent.left;anchors.right:sortButton.left;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;spacing:4
                    Text {width:parent.width;text:query.text.trim()?"SEARCH RESULTS":lens.mode==="apps" && root.applicationSort==="frequent" && lens.hasAppUsage?"FREQUENT APPS":lens.mode==="all"?"WINDOWS & SHORTCUTS":lens.mode==="apps"?"APPLICATIONS":lens.mode.toUpperCase();color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Math.max(11,Math.round(11*Config.DirectoryStyle.textScale));elide:Text.ElideRight}
                    Text {visible:lens.mode==="apps";width:parent.width;text:String(lens.results.length)+(lens.results.length>=200?" shown":query.text.trim()?(lens.results.length===1?" match":" matches"):(lens.results.length===1?" application":" applications"));color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;elide:Text.ElideRight}
                }
                UI.DashboardButton {
                    id:sortButton;objectName:"lensAppSort";anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter
                    visible:lens.mode==="apps";width:visible?(root.width<400?108:136):0;height:Config.DirectoryStyle.controlTarget
                    text:(root.width<400?"":"Sort: ")+(root.applicationSort==="frequent"?"Frequent":"A–Z");labelSize:Config.DirectoryStyle.detailSize
                    accessibleLabel:"Sort applications: "+(root.applicationSort==="frequent"?"frequent launches; switch to alphabetical":"alphabetical; switch to frequent launches")
                    onClicked:{root.applicationSort=root.applicationSort==="frequent"?"alphabetical":"frequent";root.resetSelection();query.forceActiveFocus();}
                    ToolTip.visible:pointerHovered;ToolTip.text:"Switch between frequent launches and alphabetical order";ToolTip.delay:500
                }
            }
            Item {
                width:parent.width;height:Math.max(0,parent.height-y-12-footer.height)
                ListView {
                    id:list;objectName:"lensResults";anchors.fill:parent;clip:true;spacing:2;model:lens.results;currentIndex:0;highlight:null;boundsBehavior:Flickable.StopAtBounds
                    Accessible.name:"Command Lens results";Accessible.role:Accessible.List
                    onCurrentIndexChanged:if(currentIndex>=0)positionViewAtIndex(currentIndex,ListView.Contain)
                    delegate:LensResult {required property var modelData;required property int index;row:modelData;width:list.width;height:root.rowHeight;selected:ListView.isCurrentItem;compact:root.width<400;showKind:lens.mode==="all";onChosen:reveal=>{list.currentIndex=index;root.selectionId=modelData.id;lens.activate(index,reveal);}}
                    ScrollBar.vertical:UI.ShellScrollBar {}
                }
                Column {
                    visible:!lens.results.length;anchors.centerIn:parent;width:parent.width;spacing:6
                    Text {width:parent.width;text:lens.loading?"Searching local sources…":query.text.trim()?"No matches for “"+query.text+"”":lens.mode==="windows"?"No open windows":lens.mode==="apps"?"No indexed applications":"No results";textFormat:Text.PlainText;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;elide:Text.ElideMiddle}
                    Text {width:parent.width;text:lens.loading?"":query.text.trim()?"Try another query or scope.":"Choose another scope.";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:12;wrapMode:Text.WordWrap}
                }
            }
            Item {width:1;height:12}
            Column {
                id:footer;width:parent.width;spacing:6
                Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
                Text {visible:!!lens.statusText;width:parent.width;text:lens.statusText;textFormat:Text.PlainText;color:lens.providerError?Config.Theme.warning:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:Text.WordWrap}
                Text {visible:lens.mode==="apps" && !query.text.trim() && !lens.hasAppUsage && !lens.statusText;width:parent.width;text:"Launch an app to build your frequent list.";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:Text.WordWrap}
                Row {
                    width:parent.width;spacing:8
                    Text {width:Math.max(0,parent.width-hints.width-8);text:lens.activating?"Opening…":list.currentIndex>=0?"↵  "+Search.effect(lens.results[list.currentIndex]):"Type to search";color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:12;elide:Text.ElideRight}
                    Text {id:hints;text:root.width<420?"↑↓  ·  ESC":"↑↓ Select   Ctrl+Tab Scope   Esc Close";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
                }
                Text {visible:lens.mode==="files" && root.width>=420;width:parent.width;text:"Ctrl+Shift+Enter  Reveal location · Right-click  File details";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:11;elide:Text.ElideRight}
            }
        }
    }
}
