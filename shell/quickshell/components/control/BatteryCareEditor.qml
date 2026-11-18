import QtQuick
import QtQuick.Controls
import ".."
import "../../config" as Config

Column {
    id: root
    required property var care
    spacing: 10
    function value(n, suffix) { return n !== null && n !== undefined && Number.isFinite(Number(n)) && Number(n) >= 0 ? (Math.round(n*100)/100) + suffix : "Unavailable"; }
    Text {
        width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
        color: Config.Theme.muted; font.family: Config.Theme.fontFamily; font.pixelSize: 11
        text: "CAPACITY SOURCES & BATTERY CARE · " + (root.care.snapshot.observedAt ? "snapshot " + new Date(root.care.snapshot.observedAt*1000).toLocaleString() : "Refresh to inspect") + ". UPower supplies the energy-weighted aggregate and can retain a different full-capacity reference. Pack full/charging state and the aggregate estimate are distinct; neither is a lifespan prediction."
    }
    Repeater {
        model: root.care.packs
        delegate: Column {
            id: packView
            required property var modelData
            width: parent.width; spacing: 8
            DashboardCard {
                width: parent.width; implicitHeight: 270; wrapDetail: true
                title: packView.modelData.name + " · CAPACITY PROVENANCE"
                value: root.value(packView.modelData.healthPercent,"% capacity ratio")
                detail: "Kernel full/design: " + root.value(packView.modelData.kernel.fullWh," Wh") + " / " + root.value(packView.modelData.kernel.designWh," Wh") + ". UPower full/design: " + root.value(packView.modelData.upower.EnergyFull," Wh") + " / " + root.value(packView.modelData.upower.EnergyFullDesign," Wh") + (packView.modelData.capacityMismatch ? ". INCONSISTENT full-capacity references; aggregate follows UPower." : ".") + " Cycles: kernel " + root.value(packView.modelData.kernel.cycles,"") + ", UPower " + root.value(packView.modelData.upower.ChargeCycles,"") + ". Ratio source: " + packView.modelData.healthBasis + ". Reported capacity only; no condition score or lifespan estimate. " + (packView.modelData.sourceWarnings || []).join(" ")
            }
            Text {
                width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
                color: Config.Theme.muted; font.family: Config.Theme.fontFamily; font.pixelSize: 11
                text: "Effective kernel thresholds " + packView.modelData.effective.map(n=>root.value(n,"%")).join(" / ") + ". Managed TLP configuration: " + (packView.modelData.configured ? packView.modelData.configured.join("/") : "not set") + ". UPower preset " + root.value(packView.modelData.upower.ChargeStartThreshold,"") + "/" + root.value(packView.modelData.upower.ChargeEndThreshold,"") + " · enabled: " + (packView.modelData.upower.ChargeThresholdEnabled === false ? "no" : packView.modelData.upower.ChargeThresholdEnabled === true ? "yes" : "unknown") + ". " + packView.modelData.reason
            }
            ShellCheckBox {
                objectName: "care-select-" + packView.modelData.name
                width: parent.width; text: "Edit " + packView.modelData.name
                enabled: root.care.fresh && packView.modelData.supported && !root.care.locked
                checked: root.care.draft(packView.modelData).selected
                onToggled: root.care.edit(packView.modelData,"selected",checked)
            }
            Flow {
                width: parent.width; spacing: 12
                enabled: root.care.draft(packView.modelData).selected && !root.care.locked
                Text { text: "START %"; color: Config.Theme.muted; font.family: Config.Theme.fontFamily; height:44; verticalAlignment:Text.AlignVCenter }
                ShellSpinBox {
                    objectName: "care-start-" + packView.modelData.name
                    width: 110; from: 0; to: 99; editable: true
                    value: root.care.draft(packView.modelData).start || 0
                    onValueModified: root.care.edit(packView.modelData,"start",value)
                }
                Text { text: "STOP %"; color: Config.Theme.muted; font.family: Config.Theme.fontFamily; height:44; verticalAlignment:Text.AlignVCenter }
                ShellSpinBox {
                    objectName: "care-stop-" + packView.modelData.name
                    width: 110; from: 1; to: 100; editable: true
                    value: root.care.draft(packView.modelData).stop || 100
                    onValueModified: root.care.edit(packView.modelData,"stop",value)
                }
            }
        }
    }
    ShellCheckBox {
        objectName: "care-persistent"
        width: parent.width; text: "Save thresholds in TLP configuration (otherwise runtime only)"
        enabled: !root.care.locked && (root.care.snapshot.persistentAvailable === true || root.care.persistentChoice)
        checked: root.care.persistentChoice
        onToggled: root.care.persistentChoice = checked
    }
    Text {
        width: parent.width; wrapMode: Text.WordWrap; textFormat:Text.PlainText
        color: Config.Theme.muted; font.family: Config.Theme.fontFamily; font.pixelSize: 11
        text: (root.care.snapshot.persistenceReason || "") + (root.care.installed ? "" : " Apply unavailable: reviewed root-owned helper awaits separate system deployment approval. Drafting changes performs no hardware operation.")
    }
    Flow {
        width: parent.width; spacing: 8
        DashboardButton { objectName:"care-refresh"; text:"REFRESH CARE"; enabled:!root.care.busy; onClicked:root.care.refresh() }
        DashboardButton { objectName:"care-apply"; text:"REVIEW APPLY"; enabled:root.care.fresh && root.care.installed && !root.care.busy && !root.care.blocked && (!root.care.persistentChoice || root.care.snapshot.persistentAvailable === true); onClicked:root.care.requestApply() }
        DashboardButton { objectName:"care-recovery-records"; text:"RECOVERY RECORDS"; enabled:root.care.installed && !root.care.busy && !root.care.blocked; onClicked:root.care.requestHistory() }
        DashboardButton { objectName:"care-restore"; text:"REVIEW RESTORE"; enabled:root.care.fresh && root.care.installed && !root.care.busy && !root.care.blocked && !!root.care.lastReceipt && root.care.lastReceipt.restorableToken === root.care.snapshot.token; onClicked:root.care.requestRestore() }
    }
    Text {
        width:parent.width; visible:!root.care.locked && !!root.care.message; wrapMode:Text.WordWrap; textFormat:Text.PlainText
        color:Config.Theme.muted; font.family:Config.Theme.fontFamily; font.pixelSize:11; text:root.care.message
    }
}
