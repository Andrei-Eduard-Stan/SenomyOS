pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "SkinSchema.js" as Schema
import "SkinPreferences.js" as Preferences

// Release art remains relative to its immutable manifest. Explicit saves use
// versioned XDG overrides; loading never migrates user preferences.
Singleton {
    id: root
    property var registry: ({})
    property url manifestUrl: "file://" + Quickshell.shellDir + "/../../appearance/skins/default.json"
    property string error: ""
    property int revision: 0
    property bool saving: false
    property string saveStatus: ""
    property string preferenceVersion: "absent"
    property bool refreshPending: false
    readonly property string preferencePath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME")+"/.config")+"/senomyos/appearance.json"
    function refreshPreferences() {
        if(preferenceProcess.running) { refreshPending=true; return; }
        preferenceProcess.exec(["timeout","8s","python3","-B",Quickshell.shellDir+"/../../scripts/senomy-preferences.py","read","--base",decodeURIComponent(String(manifestUrl).replace(/^file:\/\//, ""))]);
    }
    readonly property string defaultMode: registry.defaultMode || "native"
    function frame(key) { return registry.frames && registry.frames[key] || {}; }
    function resolve(source) {
        if(!source) return "";
        const url = new URL(source, String(manifestUrl)).toString();
        return url + (url.indexOf("?")>=0 ? "&" : "?") + "skinRevision=" + revision;
    }
    function mode(spec) { return !spec.mode || spec.mode === "inherit" ? defaultMode : spec.mode; }
    function savePreferences(key, background, persona) {
        if(saving || !registry.schemaVersion || error) return false;
        try {
            if(preferenceProcess.running) return false;
            Preferences.merge(registry,key,background,persona);
            saving=true;
            saveStatus="Saving…";
            preferenceProcess.command=["timeout","8s","python3","-B",Quickshell.shellDir+"/../../scripts/senomy-preferences.py","save","--base",decodeURIComponent(String(manifestUrl).replace(/^file:\/\//, ""))];
            preferenceProcess.running=true;
            preferenceProcess.write(JSON.stringify({expected:preferenceVersion,key:key,background:background,persona:persona})+"\n");
            return true;
        } catch(e) {
            saving=false;
            saveStatus="Not saved: "+e;
            return false;
        }
    }
    FileView {
        path: Quickshell.shellDir + "/../../appearance/tokens.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const tokens = JSON.parse(text());
                root.manifestUrl = "file://" + Quickshell.shellDir + "/../../appearance/" + (tokens.skin && tokens.skin.manifest || "skins/default.json");
            } catch (e) { root.error = "Invalid appearance tokens: " + e; }
        }
    }
    FileView {
        id: manifestFile
        path: root.manifestUrl
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const next = JSON.parse(text());
                Schema.validate(next);
                root.revision += 1;
                root.registry = next;
                root.error = "";
                root.refreshPreferences();
            } catch (e) { root.error = "Keeping last valid skin: " + e; console.warn(root.error); }
        }
        onLoadFailed: error => { root.error = "Skin unavailable; using last valid skin/native fallback"; console.warn(root.error); }
    }
    FileView {
        path: root.preferencePath
        watchChanges: true
        onFileChanged: { reload(); root.refreshPreferences(); }
        onLoaded: root.refreshPreferences()
    }
    Timer {
        interval:250;running:root.saving;repeat:true
        onTriggered: if(!preferenceProcess.running && root.saving) {
            root.saving=false;root.saveStatus="Preference helper could not start; no save was verified.";
        }
    }
    Process {
        id: preferenceProcess
        stdinEnabled: true
        stdout: StdioCollector { id: preferenceOutput }
        onExited: code => {
            const wasSaving=root.saving;
            root.saving=false;
            try {
                const result=JSON.parse(preferenceOutput.text);
                if(code!==0 || !result.ok) throw new Error(result.error || "Preference helper failed");
                Schema.validate(result.registry);
                root.registry=result.registry; root.preferenceVersion=result.version;
                root.revision+=1; root.error="";
                if(wasSaving) root.saveStatus="Saved";
            } catch(e) {
                root.error="Keeping last valid appearance: "+e;
                if(wasSaving) root.saveStatus="Not saved: "+e;
            }
            if(root.refreshPending) { root.refreshPending=false; root.refreshPreferences(); }
        }
    }
}
