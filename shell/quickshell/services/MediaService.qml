import Quickshell
import Quickshell.Services.Mpris

Scope {
    id: root

    readonly property var players: Mpris.players.values
    property string selectedId: ""
    readonly property var selectedPlayer: {
        const selected = players.find(player => player.uniqueId === selectedId);
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

    function select(player) {
        if (!player)
            return false;
        selectedId = player.uniqueId;
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
