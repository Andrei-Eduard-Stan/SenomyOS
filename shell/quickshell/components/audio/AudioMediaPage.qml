import QtQuick
import Quickshell.Services.Mpris
import ".."
Column {
    id:root
    required property var media
    property bool compact:false
    readonly property var player:media && media.available?media.selectedPlayer:null
    property var seekPlayer:null
    property var seekTrack:null
    onPlayerChanged:seekPlayer=null
    width:parent.width;spacing:10
    function timeLabel(value) {const seconds=Math.max(0,Math.floor(value));return Math.floor(seconds/60)+":"+String(seconds%60).padStart(2,"0");}
    Timer {interval:500;repeat:true;running:root.visible && !root.compact && root.player!==null && root.player.isPlaying && root.player.positionSupported;onTriggered:if(typeof root.player.positionChanged==="function")root.player.positionChanged()}
    AudioLabel {text:root.player?(root.player.isPlaying?"PLAYING // ":"PAUSED // ")+root.media.identity:"NO MEDIA PLAYER · start a player to use media controls"}
    ShellComboBox {visible:!root.compact && root.media!==null && root.media.players!==undefined && root.media.players.length>1;width:parent.width;textRole:"identity";model:root.media?root.media.players || []:[];currentIndex:root.media && root.media.players?root.media.players.indexOf(root.player):-1;Accessible.name:"Media player";onActivated:index=>root.media.select(root.media.players[index])}
    Row {
        width:parent.width;spacing:10
        Image {visible:!root.compact && root.player!==null && root.media.artwork.length>0;width:64;height:64;source:visible?root.media.artwork:"";sourceSize.width:128;sourceSize.height:128;fillMode:Image.PreserveAspectFit;asynchronous:true}
        Column {width:parent.width-(parent.children[0].visible?74:0);spacing:4;AudioLabel{text:root.player?root.media.title:""}AudioLabel{text:root.player?root.media.artist:""}}
    }
    Row {
        width:parent.width;spacing:8;visible:root.player!==null
        DashboardButton {width:(parent.width-16)/3;text:"PREV";enabled:root.player!==null && root.player.canGoPrevious;onClicked:root.media.previous()}
        DashboardButton {width:(parent.width-16)/3;text:root.media && root.media.playing?"PAUSE":"PLAY";enabled:root.player!==null && root.player.canTogglePlaying;onClicked:root.media.toggle()}
        DashboardButton {width:(parent.width-16)/3;text:"NEXT";enabled:root.player!==null && root.player.canGoNext;onClicked:root.media.next()}
    }
    Column {
        width:parent.width;visible:!root.compact && root.player!==null;spacing:6
        CathedralSlider {id:seekSlider;width:parent.width;from:0;to:root.media?Math.max(1,root.media.duration || 0):1;enabled:root.player!==null && root.player.canSeek && root.player.positionSupported && root.player.lengthSupported;Accessible.name:"Media seek position";onMoved:if(!pressed)root.media.seek(value);onPressedChanged:if(pressed){root.seekPlayer=root.player;root.seekTrack=root.player?root.player.uniqueId:null;}else if(root.seekPlayer===root.player && root.player!==null && root.seekTrack===root.player.uniqueId)root.media.seek(value)}
        Binding {target:seekSlider;property:"value";value:root.media?root.media.position || 0:0;when:!seekSlider.pressed;restoreMode:Binding.RestoreNone}
        AudioLabel {text:root.player && root.player.positionSupported?root.timeLabel(root.media.position)+" / "+(root.player.lengthSupported?root.timeLabel(root.media.duration):"unknown duration"):"Seek position unavailable"}
        Row {
            width:parent.width;spacing:8
            DashboardButton {width:(parent.width-8)/2;text:"SHUFFLE";active:root.player!==null && root.player.shuffleSupported && root.player.shuffle;enabled:root.player!==null && root.player.canControl && root.player.shuffleSupported;onClicked:root.media.shuffle()}
            DashboardButton {width:(parent.width-8)/2;text:root.player && root.player.loopSupported?"REPEAT / "+MprisLoopState.toString(root.player.loopState):"REPEAT";enabled:root.player!==null && root.player.canControl && root.player.loopSupported;onClicked:root.media.repeat()}
        }
    }
}
