import Quickshell
import Quickshell.Services.Mpris

Scope {
    id: root

    property var mpris: Mpris
    readonly property var players: mpris.players.values
    property string selectedId: ""
    readonly property var selectedPlayer: {
        const selected = players.find(player => player.dbusName === selectedId);
        if (selected)
            return selected;
        const playing = players.find(player => player.isPlaying);
        return playing || (players.length > 0 ? players[0] : null);
    }
    readonly property bool available: selectedPlayer !== null
    readonly property bool playing: available && selectedPlayer.isPlaying
    readonly property string identity: available ? selectedPlayer.identity : "No active player"
    readonly property string title: available && selectedPlayer.trackTitle
        ? selectedPlayer.trackTitle : "Nothing playing"
    readonly property string artist: available && selectedPlayer.trackArtist
        ? selectedPlayer.trackArtist : ""
    readonly property string album: available && selectedPlayer.trackAlbum
        ? selectedPlayer.trackAlbum : ""
    readonly property string artwork: available && selectedPlayer.trackArtUrl
        ? selectedPlayer.trackArtUrl : ""
    readonly property real position: available && selectedPlayer.positionSupported
        ? selectedPlayer.position : 0
    readonly property real duration: available && selectedPlayer.lengthSupported
        ? selectedPlayer.length : 0

    function seek(value) { if(!available || !selectedPlayer.canSeek || !selectedPlayer.positionSupported || !selectedPlayer.lengthSupported || !Number.isFinite(value))return false;selectedPlayer.position=Math.max(0,Math.min(duration,value));return true; }
    function shuffle() { if(!available || !selectedPlayer.canControl || !selectedPlayer.shuffleSupported)return false;selectedPlayer.shuffle=!selectedPlayer.shuffle;return true; }
    function repeat() { if(!available || !selectedPlayer.canControl || !selectedPlayer.loopSupported)return false;selectedPlayer.loopState=selectedPlayer.loopState===MprisLoopState.None?MprisLoopState.Track:selectedPlayer.loopState===MprisLoopState.Track?MprisLoopState.Playlist:MprisLoopState.None;return true; }
    function select(player) {
        if (!player || players.indexOf(player)<0)
            return false;
        selectedId = player.dbusName;
        return true;
    }

    function toggle() {
        if (!available || !selectedPlayer.canTogglePlaying)
            return false;
        selectedPlayer.togglePlaying();
        return true;
    }

    function previous() {
        if (!available || !selectedPlayer.canGoPrevious)
            return false;
        selectedPlayer.previous();
        return true;
    }

    function next() {
        if (!available || !selectedPlayer.canGoNext)
            return false;
        selectedPlayer.next();
        return true;
    }
}
