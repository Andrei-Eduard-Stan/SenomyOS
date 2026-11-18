import QtQuick
import Quickshell
import "services"
Scope {
    id:test
    QtObject {
        id:one;property string dbusName:"org.mpris.MediaPlayer2.one";property int uniqueId:1;property bool isPlaying:true;property string identity:"One";property string trackTitle:"One";property string trackArtist:"Artist";property string trackAlbum:"Album";property string trackArtUrl:"";property bool positionSupported:true;property bool lengthSupported:true;property real position:30;property real length:120;property bool canSeek:true;property bool canControl:true;property bool shuffleSupported:true;property bool shuffle:false;property bool loopSupported:true;property int loopState:0;property bool canTogglePlaying:true;property bool canGoPrevious:true;property bool canGoNext:true
        function togglePlaying(){}function previous(){}function next(){}
    }
    QtObject {
        id:two;property string dbusName:"org.mpris.MediaPlayer2.two";property int uniqueId:1;property bool isPlaying:false;property string identity:"Two";property string trackTitle:"Two";property string trackArtist:"Artist";property string trackAlbum:"Album";property string trackArtUrl:"";property bool positionSupported:true;property bool lengthSupported:true;property real position:50;property real length:240;property bool canSeek:true;property bool canControl:true;property bool shuffleSupported:true;property bool shuffle:false;property bool loopSupported:true;property int loopState:0;property bool canTogglePlaying:true;property bool canGoPrevious:true;property bool canGoNext:true
        function togglePlaying(){}function previous(){}function next(){}
    }
    QtObject {id:backend;property var players:({values:[one,two]})}
    MediaService {id:media;mpris:backend}
    function check(ok,msg){if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw new Error(msg);}}
    Timer {interval:50;running:true;onTriggered:{
        check(media.selectedPlayer===one,"initial playing fallback");check(media.select(two),"select player");check(media.selectedPlayer===two,"player identity is bus name, independent of colliding track IDs");two.uniqueId=2;check(media.selectedPlayer===two,"track change preserves selected player");
        check(media.seek(999) && two.position===240,"seek cap");check(media.shuffle() && two.shuffle,"shuffle");check(media.repeat() && two.loopState===1,"track repeat");check(media.repeat() && two.loopState===2,"playlist repeat");check(media.repeat() && two.loopState===0,"repeat off");two.canSeek=false;check(!media.seek(1),"unsupported seek gate");two.shuffleSupported=false;check(!media.shuffle(),"unsupported shuffle gate");backend.players=({values:[one]});check(media.selectedPlayer===one,"removed player fallback");check(!media.select(two),"stale player selection rejected");
        console.log("PASS: actual MediaService multi-player identity, track changes, seek bounds, loop/shuffle capabilities and removed-player fallback; fake MPRIS only");Qt.quit();
    }
    }
}
