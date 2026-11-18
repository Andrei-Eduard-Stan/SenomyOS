import QtQuick
import QtQuick.Controls
import ".." as UI
import "../../config" as Config

Column {
    id:root;objectName:"quickAudioMedia"
    required property var media
    property bool active:false
    property var viewport:null
    property bool expanded:false
    readonly property var player:media && media.available?media.selectedPlayer:null
    readonly property bool playing:!!player && !!media.playing
    readonly property string title:player?(media.title || media.identity || "Media player"):"Nothing playing"
    readonly property string artist:player?(media.artist || media.identity || ""):"Start playback in a media app"
    readonly property string trackKey:player?String(player.uniqueId || "")+"|"+title+"|"+String(media.duration):""
    readonly property bool seekable:!!player && player.canSeek && player.positionSupported && player.lengthSupported && Number.isFinite(media.duration) && media.duration>0
    readonly property real overflow:Math.max(0,track.implicitWidth-trackViewport.width)
    readonly property bool stripInView:{const y=root.y,scroll=viewport?viewport.contentY:0,h=viewport?viewport.height:0;return !viewport || (y>=scroll && y+strip.height<=scroll+h);}
    readonly property bool controlsInView:{const y=root.y+expandedBody.y,scroll=viewport?viewport.contentY:0,h=viewport?viewport.height:0;return !viewport || (y+expandedBody.height>scroll && y<scroll+h);}
    readonly property bool shouldScroll:root.active && root.visible && root.stripInView && root.playing && !root.expanded && root.overflow>1 && !Config.Motion.reduced
    function resetMarquee(){scrolling.stop();track.x=0;scrolling.running=Qt.binding(function(){return root.shouldScroll;});}
    onTrackKeyChanged:Qt.callLater(resetMarquee)
    onOverflowChanged:Qt.callLater(resetMarquee)
    readonly property bool marqueeRunning:scrolling.running
    readonly property real marqueeOffset:track.x
    spacing:8
    onActiveChanged:if(active)expanded=false
    function clock(value){const seconds=Math.max(0,Math.floor(Number.isFinite(value)?value:0));return Math.floor(seconds/60)+":"+String(seconds%60).padStart(2,"0");}
    Button {
        id:strip;objectName:"quickMediaToggle";width:parent.width;height:Config.DirectoryStyle.controlTarget
        hoverEnabled:true;padding:0
        Accessible.name:(root.expanded?"Collapse":"Expand")+" media controls. "+root.title+(root.player?". "+(root.playing?"Playing":"Paused"):"")
        Accessible.role:Accessible.Button;Accessible.expandable:true;Accessible.expanded:root.expanded
        Keys.onReturnPressed:clicked();Keys.onEnterPressed:clicked()
        onClicked:root.expanded=!root.expanded
        background:Rectangle {color:Config.DirectoryStyle.selection;border.width:strip.visualFocus?1:0;border.color:Config.DirectoryStyle.ink}
        contentItem:Item {
            Text {x:12;width:20;height:parent.height;text:"\uf001";font.family:"Font Awesome 7 Free Solid";font.weight:Font.Black;font.pixelSize:14;color:Config.DirectoryStyle.muted;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignHCenter;Accessible.ignored:true}
            Item {
                id:trackViewport;x:42;width:Math.max(1,parent.width-x-38);height:parent.height;clip:true
                Text {
                    id:track;objectName:"quickMediaMarquee";height:parent.height;width:scrolling.running?implicitWidth:trackViewport.width
                    text:root.player?[root.title,root.media.artist].filter(Boolean).join(" — "):root.title;textFormat:Text.PlainText
                    color:root.player?Config.DirectoryStyle.ink:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize
                    verticalAlignment:Text.AlignVCenter;elide:scrolling.running?Text.ElideNone:Text.ElideRight;Accessible.ignored:true
                }
            }
            Text {anchors.right:parent.right;anchors.rightMargin:14;height:parent.height;text:root.expanded?"\uf077":"\uf078";font.family:"Font Awesome 7 Free Solid";font.weight:Font.Black;font.pixelSize:12;color:Config.DirectoryStyle.muted;verticalAlignment:Text.AlignVCenter;Accessible.ignored:true}
        }
        ToolTip.visible:hovered;ToolTip.text:root.title+"\n"+root.artist;ToolTip.delay:650
    }
    SequentialAnimation {
        id:scrolling;loops:Animation.Infinite
        running:root.shouldScroll
        paused:strip.hovered || strip.visualFocus
        onStopped:track.x=0
        PauseAnimation {duration:1000}
        NumberAnimation {target:track;property:"x";from:0;to:-root.overflow;duration:Math.max(700,Math.min(16000,root.overflow/24*1000));easing.type:Easing.Linear}
        PauseAnimation {duration:1000}
        NumberAnimation {target:track;property:"x";from:-root.overflow;to:0;duration:Math.max(700,Math.min(16000,root.overflow/24*1000));easing.type:Easing.Linear}
    }
    Column {
        id:expandedBody;width:parent.width;visible:root.expanded;spacing:8
        Row {
            width:parent.width;spacing:12
            Item {
                id:cover;width:56;height:56
                Rectangle {anchors.fill:parent;color:Config.DirectoryStyle.selection}
                Image {id:art;anchors.fill:parent;source:root.player?root.media.artwork || "":"";sourceSize:Qt.size(112,112);fillMode:Image.PreserveAspectCrop;asynchronous:true;visible:status===Image.Ready}
                Text {anchors.fill:parent;visible:!art.visible;text:"\uf001";font.family:"Font Awesome 7 Free Solid";font.weight:Font.Black;font.pixelSize:22;color:Config.DirectoryStyle.dim;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignHCenter;Accessible.ignored:true}
            }
            Column {
                width:parent.width-cover.width-parent.spacing;spacing:4
                Text {width:parent.width;text:root.title;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:Font.DemiBold}
                Text {width:parent.width;text:root.artist;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
            }
        }
        Row {
            anchors.horizontalCenter:parent.horizontalCenter;spacing:12
            AudioButton {objectName:"quickMediaPrevious";width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:"\uf048";accessibleLabel:"Previous track";enabled:!!root.player && root.player.canGoPrevious;onClicked:root.media.previous()}
            AudioButton {objectName:"quickMediaPlay";width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:root.playing?"\uf04c":"\uf04b";accessibleLabel:root.playing?"Pause":"Play";active:root.playing;enabled:!!root.player && root.player.canTogglePlaying;onClicked:root.media.toggle()}
            AudioButton {objectName:"quickMediaNext";width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:"\uf051";accessibleLabel:"Next track";enabled:!!root.player && root.player.canGoNext;onClicked:root.media.next()}
        }
        UI.CathedralSlider {
            id:seek;objectName:"quickMediaSeek";width:parent.width;height:Config.DirectoryStyle.controlTarget
            property var dragPlayer:null;property string dragTrack:""
            from:0;to:root.seekable?root.media.duration:1;enabled:root.seekable;visible:!!root.player
            Accessible.name:"Playback position"
            onPressedChanged:{if(pressed){dragPlayer=root.player;dragTrack=root.trackKey;}else if(root.seekable && dragPlayer===root.player && dragTrack===root.trackKey)root.media.seek(value);}
            onMoved:if(!pressed && root.seekable)root.media.seek(value)
            background:Rectangle {x:seek.leftPadding;y:seek.topPadding+seek.availableHeight/2-1;width:seek.availableWidth;height:2;color:Config.DirectoryStyle.rule;Rectangle {width:seek.visualPosition*parent.width;height:parent.height;color:Config.DirectoryStyle.ink}}
            Rectangle {anchors.fill:parent;color:"transparent";border.width:1;border.color:Config.DirectoryStyle.ink;visible:seek.visualFocus}
            handle:Rectangle {x:seek.leftPadding+seek.visualPosition*(seek.availableWidth-width);y:seek.topPadding+seek.availableHeight/2-5;width:4;height:10;color:Config.DirectoryStyle.ink}
        }
        Binding {target:seek;property:"value";when:!seek.pressed;value:root.player && root.player.positionSupported?root.media.position || 0:0;restoreMode:Binding.RestoreNone}
        Text {width:parent.width;visible:!!root.player;text:root.seekable?root.clock(root.media.position)+" / "+root.clock(root.media.duration):"Seeking unavailable from this player";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
    }
    Timer {interval:500;repeat:true;running:root.active && root.expanded && root.visible && root.controlsInView && root.playing && !!root.player && root.player.positionSupported;onTriggered:if(typeof root.player.positionChanged==="function")root.player.positionChanged()}
}
