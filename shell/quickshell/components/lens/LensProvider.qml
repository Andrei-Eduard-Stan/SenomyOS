import QtQuick
import Quickshell
import Quickshell.Io
import "LensSearch.js" as Search

// Retain bounded catalogs across openings; typing never starts a filesystem process.
QtObject {
    id: root
    required property string kind
    property bool wanted: false
    property int generation: 0
    property var rows: []
    property string notice: ""
    property string error: ""
    readonly property bool loading: listing.running || refresh.running
    readonly property string helper: String(Quickshell.env("SENOMY_SOURCE_ROOT") || "") + "/components/launcher/rofi/scripts/senomy-rofi-" + kind
    property bool refreshed: false
    property double loadedAt: 0
    function reset() { error = ""; refreshed = false; load(); }
    function load(force) {
        if (!wanted || listing.running || refresh.running) return;
        // Match the file helper's freshness window, without spawning processes
        // just to find out that the previous opening's catalog is still fresh.
        if (!force && loadedAt && Date.now() - loadedAt < 30000) return;
        listing.heldGeneration = generation;
        listing.output = "";
        listing.command = ["/usr/bin/env", "ROFI_RETV=0", "ROFI_INFO=", helper].concat(kind === "files" ? ["--cached"] : []);
        listing.running = true;
    }
    onWantedChanged: if (wanted) load()
    onGenerationChanged: reset()
    property Process listing: Process {
        property int heldGeneration: -1
        property string output: ""
        stdout: StdioCollector { onStreamFinished: root.listing.output = text }
        onExited: (code, status) => {
            if (!root.wanted) return;
            if (heldGeneration !== root.generation) { root.load(); return; }
            if (code !== 0) { root.error = "This search provider is unavailable. Other scopes still work."; console.warn("Command Lens " + root.kind + " catalog exit " + code); return; }
            root.error = "";
            root.loadedAt = Date.now();
            root.rows = Search.parse(output, root.kind, Quickshell.env("HOME"));
            const realRows = root.rows.filter(r => r.info !== "__senomy_refresh__");
            root.notice = !realRows.length ? Search.message(output).replace("File list is loading · reopen Files or select Refresh", "File index is warming up…") : output.includes("Bounded result notice") ? "Partial file index · some files may be outside the search limits" : "";
            if (root.kind === "files" && !root.refreshed) root.refreshIndex();
        }
    }
    function refreshIndex(force) {
        if (refresh.running || !wanted) return;
        refreshed = true;
        refresh.heldGeneration = generation;
        refresh.command = force ? ["/usr/bin/env", "ROFI_RETV=1", "ROFI_INFO=__senomy_refresh__", helper, "--cached"] : [helper, "--refresh-cache"];
        refresh.running = true;
    }
    property Process refresh: Process {
        property int heldGeneration: -1
        onExited: (code, status) => {
            if (!root.wanted) return;
            if (heldGeneration !== root.generation) {root.load(); return;}
            if (code !== 0) {root.error = "The file index could not be refreshed."; return;}
            root.load(true);
        }
    }
}
