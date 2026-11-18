import QtQuick
import "../interaction" as Interaction
import QtQuick.Controls
import Quickshell
import ".." as UI
import "../../config" as Config
import "LensSearch.js" as Search

ItemDelegate {
    id: root
    required property var row
    property bool selected: false
    property bool compact: false
    property bool showKind: true
    readonly property string secondaryText: Search.secondary(row)
    signal chosen(bool reveal)
    implicitHeight: Math.max(Config.DirectoryStyle.controlTarget, labels.implicitHeight + 2 * Config.DirectoryStyle.controlVerticalInset)
    leftPadding: Config.DirectoryStyle.controlInset
    rightPadding: Config.DirectoryStyle.controlInset
    topPadding: Config.DirectoryStyle.controlVerticalInset
    bottomPadding: Config.DirectoryStyle.controlVerticalInset
    hoverEnabled: true
    focusPolicy: Qt.NoFocus // Search retains typing focus; arrows own current row.
    opacity: enabled ? 1 : 0.46
    Accessible.role: Accessible.ListItem
    Accessible.name: row.label + (secondaryText ? ", " + secondaryText : "")
    Accessible.description: row.kind === "files" ? row.info : row.kind
    Accessible.selected: selected
    onClicked: chosen(false)
    background: Rectangle {
        anchors.fill: parent; anchors.margins: 2
        color: root.selected ? Config.DirectoryStyle.selection : "transparent"
    }
    UI.ButtonHoverFrame { anchors.fill: parent; focused: root.visualFocus; engaged: root.enabled && root.hovered }
    contentItem: Item {
        Item {
            id: iconBox
            width: 24; height: 24; anchors.verticalCenter: parent.verticalCenter
            Image {
                id: icon; anchors.fill: parent; sourceSize: Qt.size(32,32)
                source: !root.row.icon ? "" : root.row.icon.startsWith("/") ? "file://" + root.row.icon : root.row.icon.startsWith("file://") ? root.row.icon : Quickshell.iconPath(root.row.icon, true)
                visible: status === Image.Ready; fillMode: Image.PreserveAspectFit
            }
            UI.DashboardIcon {
                anchors.fill:parent;visible:!icon.visible;color:Config.DirectoryStyle.muted
                text:root.row.kind==="files"?"\uf15b":root.row.kind==="windows"?"\uf2d2":root.row.kind==="apps" && root.row.icon==="system-file-manager"?"\uf07b":root.row.kind==="actions"?"\uf013":"\uf00a"
            }
        }
        Column {
            id: labels
            anchors.left: iconBox.right; anchors.leftMargin: Config.DirectoryStyle.controlGap
            anchors.right: kindLabel.left; anchors.rightMargin: Config.DirectoryStyle.controlGap
            anchors.verticalCenter: parent.verticalCenter; spacing: 2
            Text { objectName:"resultTitle"; width:parent.width; text:root.row.label; textFormat:Text.PlainText; color:Config.DirectoryStyle.ink; font.family:Config.DirectoryStyle.bodyFont; font.pixelSize:Math.max(Config.DirectoryStyle.bodySize,Math.round(16*Config.DirectoryStyle.textScale)); font.weight:root.selected?Font.DemiBold:Font.Normal; elide:Text.ElideMiddle }
            Text { width:parent.width; visible:!!text; text:root.secondaryText; textFormat:Text.PlainText; color:Config.DirectoryStyle.muted; font.family:root.row.kind==="files"?Config.DirectoryStyle.dataFont:Config.DirectoryStyle.bodyFont; font.pixelSize:Config.DirectoryStyle.detailSize; elide:Text.ElideMiddle }
        }
        Text {
            id:kindLabel; anchors.right:parent.right; anchors.verticalCenter:parent.verticalCenter
            text:root.compact || !root.showKind ? "" : ({apps:"App",files:"File",windows:"Window",actions:"Action"})[root.row.kind] || ""
            color:Config.DirectoryStyle.dim; font.family:Config.DirectoryStyle.dataFont; font.pixelSize:Math.max(11,Math.round(11*Config.DirectoryStyle.textScale))
        }
    }
    ToolTip.visible: hovered && row.kind === "files"
    ToolTip.delay: 650
    ToolTip.text: row.info || ""
    function closeInteractionChildren() { menu.close(); }
    TapHandler { enabled:root.row.kind==="files" && root.row.info!=="__senomy_refresh__"; acceptedButtons:Qt.RightButton; onTapped:(point,button)=>menu.popup(root,point.position.x,point.position.y) }
    Menu {
        enter: Interaction.MenuMotion {}
        exit: Interaction.MenuMotion { opening: false }
        id:menu; objectName:"lensContextMenu"
        parent: Overlay.overlay
        width:Math.max(1,Math.min(360,parent?parent.width-16:360))
        padding:10
        background:UI.ShellSurfaceFrame {contentInset:0;perimeterCorner:16;backdropColor:Config.DirectoryStyle.glass;stateColor:"transparent";animate:false}
        UI.ShellMenuItem { text:"Open file location"; visible:root.row.kind==="files" && root.row.info!=="__senomy_refresh__"; height:visible?implicitHeight:0; onTriggered:root.chosen(true) }
        UI.ShellMenuItem { text:root.row.info || root.row.detail || root.row.label; enabled:false }
    }
}
