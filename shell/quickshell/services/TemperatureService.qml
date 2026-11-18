import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property var readings: ({})
    property double now: Date.now()
    readonly property var current: Object.values(readings).filter(r=>now-r.at<30000)
    readonly property bool available: current.length>0
    readonly property real celsius: available ? Math.max.apply(null,current.map(r=>r.value)) : 0
    FolderListModel {
        id: zones
        folder: "file:///sys/class/thermal"
        nameFilters: ["thermal_zone*"]
        showDirs: true; showFiles: false; showDotAndDotDot: false
    }
    Instantiator {
        model: zones
        delegate: QtObject {
            id: zone
            required property url fileUrl
            property FileView kind: FileView { path: zone.fileUrl+"/type"; blockLoading:true; printErrors:false }
            readonly property bool supported: /cpu|package|x86_pkg|soc/i.test(kind.text())
            property FileView temperature: FileView {
                path: zone.supported ? zone.fileUrl+"/temp" : ""
                printErrors:false
                onLoaded: {
                    const raw=text().trim();
                    const value=raw.length ? Number(raw)/1000 : NaN;
                    const next=Object.assign({},root.readings);
                    if(Number.isFinite(value) && value>-30 && value<150) next[String(zone.fileUrl)]={value:value,at:Date.now()};
                    else delete next[String(zone.fileUrl)];
                    root.readings=next;
                }
                onLoadFailed: error => {
                    const next=Object.assign({},root.readings);delete next[String(zone.fileUrl)];root.readings=next;
                }
            }
            property Timer poll: Timer { interval:10000; running:zone.supported; repeat:true; onTriggered:zone.temperature.reload() }
        }
    }
    Timer { interval:10000;running:true;repeat:true;onTriggered:root.now=Date.now() }
}
