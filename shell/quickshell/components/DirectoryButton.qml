import QtQuick
import QtQuick.Controls
import "../config" as Config
Rectangle {
    id: root
    property string frameKey:"button"
    property string iconName:""
    property string text:""
    property string detail:""
    property bool iconOnly:false
    readonly property real contentInset: iconOnly ? 0 : Config.DirectoryStyle.contentInsetFor(width, height)
    readonly property real minimumContentWidth:Math.ceil(labelMetrics.advanceWidth)+Config.DirectoryStyle.controlGap+2*Config.DirectoryStyle.controlInset
    TextMetrics {id:labelMetrics;text:root.text;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:root.labelSize}
    property int labelSize:Config.DirectoryStyle.bodySize
    property bool centered:false
    property bool wrapDetail:false
    property bool wrapLabel:true
    property int detailWrapMode:Text.WordWrap
    property bool active:false
    // The centre-out border provides pointer feedback without filling the tile.
    readonly property bool pointerHovered:enabled && hover.containsMouse
    property color accentColor:Config.DirectoryStyle.ink
    signal clicked()
    activeFocusOnTab:enabled
    implicitWidth:148;implicitHeight:Math.max(Config.DirectoryStyle.controlTarget,labelColumn.implicitHeight+2*Config.DirectoryStyle.controlVerticalInset)
    color:"transparent"
    border.width:0
    border.color:Config.DirectoryStyle.ink
    opacity:enabled?1:0.4
    Accessible.role:Accessible.Button;Accessible.name:text+" "+detail
    Accessible.onPressAction:if(enabled)clicked()
    Keys.onReturnPressed:if(enabled)clicked()
    Keys.onSpacePressed:if(enabled)clicked()
    Column {
        id:labelColumn
        x:root.contentInset;anchors.verticalCenter:parent.verticalCenter;width:Math.max(0,parent.width-2*root.contentInset);spacing:4
        Text {width:parent.width;text:root.text;textFormat:Text.PlainText;color:root.active?root.accentColor:Config.DirectoryStyle.ink;opacity:Config.DirectoryStyle.highContrast || root.pointerHovered || root.activeFocus || root.active?1:0.86;Behavior on opacity {NumberAnimation {duration:Config.Motion.duration(80)}}
            font.weight:root.active?Font.DemiBold:Font.Normal;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:root.iconOnly?24:root.labelSize;horizontalAlignment:root.iconOnly || root.centered?Text.AlignHCenter:Text.AlignLeft;wrapMode:root.wrapLabel?Text.Wrap:Text.NoWrap;elide:root.wrapLabel?Text.ElideNone:Text.ElideRight}
        Text {width:parent.width;text:root.detail;textFormat:Text.PlainText;visible:text.length>0;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:root.wrapDetail?root.detailWrapMode:Text.NoWrap;elide:root.wrapDetail?Text.ElideNone:Text.ElideRight}
    }
    ButtonHoverFrame { focusTarget: root; pointerTarget: hover; selected: root.active;anchors.fill:parent;engaged:root.pointerHovered}
    MouseArea {id:hover;anchors.fill:parent;hoverEnabled:true;cursorShape:root.enabled?Qt.PointingHandCursor:Qt.ArrowCursor;onClicked:if(root.enabled){root.forceActiveFocus();root.clicked();}}
}
