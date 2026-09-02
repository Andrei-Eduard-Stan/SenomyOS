import QtQuick
import Quickshell
import "../config" as Config

PrimarySurfaceWindow {
    id: root

    required property var state
    required property var performance
    required property var metrics
    required property var battery
    required property var network

    requestedOpen: state.activePrimary === "performance"
        && state.primaryScreen === (targetScreen ? targetScreen.name : "")
    title: "PERFORMANCE"
    eyebrow: "CATHEDRAL DECK // CONDITIONAL TELEMETRY"
    activeSection: state.performanceSection
    preferredWidth: 1180
    preferredHeight: 800
    sections: [
        {id: "overview", label: "OVERVIEW"},
        {id: "cpu", label: "CPU / GPU"},
        {id: "memory", label: "MEMORY"},
        {id: "storage", label: "STORAGE"},
        {id: "network", label: "NETWORK"},
        {id: "processes", label: "PROCESSES"},
        {id: "benchmarks", label: "BENCHMARKS"}
    ]

    onCloseRequested: state.closePrimary()
    onSectionRequested: section => state.performanceSection = section

    function formatBytes(bytes) {
        const value = Number(bytes) || 0;
        if (value >= 1099511627776)
            return (value / 1099511627776).toFixed(1) + " TiB";
        if (value >= 1073741824)
            return (value / 1073741824).toFixed(1) + " GiB";
        if (value >= 1048576)
            return (value / 1048576).toFixed(1) + " MiB";
        return Math.round(value / 1024) + " KiB";
    }

    function peak(values, floor) {
        return Math.max(floor || 1, ...(values || [0]));
    }

    Binding {
        target: root.performance
        property: "benchmarkPageActive"
        value: root.requestedOpen && root.state.performanceSection === "benchmarks"
    }
    Component.onDestruction: root.performance.benchmarkPageActive = false

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (root.state.performanceSection) {
            case "cpu": return cpuPage;
            case "memory": return memoryPage;
            case "storage": return storagePage;
            case "network": return networkPage;
            case "processes": return processesPage;
            case "benchmarks": return benchmarksPage;
            default: return overviewPage;
            }
        }
    }

    Component {
        id: overviewPage
        Flickable {
            contentHeight: overviewColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: overviewColumn
                width: parent.width
                spacing: 11
                Grid {
                    width: parent.width
                    columns: 4
                    columnSpacing: 8
                    SurfaceCard { width: (parent.width - 24) / 4; title: "CPU"; value: Math.round(root.metrics.cpuPercent) + "%"; detail: "60-sample bounded history" }
                    SurfaceCard { width: (parent.width - 24) / 4; title: "MEMORY"; value: Math.round(root.metrics.memoryPercent) + "%"; detail: root.metrics.uptimeLabel + " uptime" }
                    SurfaceCard { width: (parent.width - 24) / 4; title: "NETWORK"; value: Math.round(root.metrics.networkRxKib) + " KiB/s"; detail: "RX · TX " + Math.round(root.metrics.networkTxKib) + " KiB/s" }
                    SurfaceCard { width: (parent.width - 24) / 4; title: "POWER"; value: root.battery.label; detail: root.battery.detail }
                }
                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 10
                    HistoryChart { width: (parent.width - 10) / 2; values: root.performance.cpuHistory; label: "CPU UTILISATION"; currentLabel: Math.round(root.metrics.cpuPercent) + "%" }
                    HistoryChart { width: (parent.width - 10) / 2; values: root.performance.memoryHistory; lineColor: Config.Theme.cyan; label: "MEMORY UTILISATION"; currentLabel: Math.round(root.metrics.memoryPercent) + "%" }
                    HistoryChart { width: (parent.width - 10) / 2; values: root.performance.rxHistory; maximum: root.peak(root.performance.rxHistory, 10); lineColor: Config.Theme.success; label: "NETWORK RECEIVE"; currentLabel: Math.round(root.metrics.networkRxKib) + " KiB/s" }
                    HistoryChart { width: (parent.width - 10) / 2; values: root.performance.txHistory; maximum: root.peak(root.performance.txHistory, 10); lineColor: Config.Theme.amber; label: "NETWORK TRANSMIT"; currentLabel: Math.round(root.metrics.networkTxKib) + " KiB/s" }
                }
                Grid {
                    width: parent.width
                    columns: 3
                    columnSpacing: 8
                    SurfaceCard { width: (parent.width - 16) / 3; title: "HOST"; value: (root.performance.details.health || {}).hostname || "LOADING"; detail: (root.performance.details.health || {}).kernel || "Detailed inventory pending" }
                    SurfaceCard { width: (parent.width - 16) / 3; title: "STORAGE"; value: String((root.performance.details.storage || {}).percent || 0) + "%"; detail: root.formatBytes((root.performance.details.storage || {}).used_bytes) + " used" }
                    SurfaceCard { width: (parent.width - 16) / 3; title: "SERVICES"; value: String((root.performance.details.services || {}).failed_total || 0) + " FAILED"; detail: (root.performance.details.services || {}).user_state || "loading" }
                }
                Text {
                    visible: root.performance.error.length > 0
                    width: parent.width
                    text: root.performance.error
                    color: Config.Theme.danger
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    Component {
        id: cpuPage
        Flickable {
            contentHeight: cpuColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: cpuColumn
                width: parent.width
                spacing: 11
                HistoryChart { width: parent.width; height: 210; values: root.performance.cpuHistory; label: "CPU // ONE SAMPLE PER SECOND WHILE DASHBOARD IS OPEN"; currentLabel: Math.round(root.metrics.cpuPercent) + "%" }
                Grid {
                    width: parent.width
                    columns: 3
                    columnSpacing: 8
                    SurfaceCard { width: (parent.width - 16) / 3; title: "MODEL"; value: (root.performance.details.cpu_inventory || {}).model || "UNAVAILABLE"; detail: String((root.performance.details.cpu_inventory || {}).logical_cpus || 0) + " logical CPUs" }
                    SurfaceCard { width: (parent.width - 16) / 3; title: "TOPOLOGY"; value: String((root.performance.details.cpu_inventory || {}).physical_cores || 0) + " CORES"; detail: String((root.performance.details.cpu_inventory || {}).threads_per_core || 0) + " thread(s) per core" }
                    SurfaceCard { width: (parent.width - 16) / 3; title: "THERMAL"; value: ((root.performance.details.health || {}).temperature || {}).available ? ((root.performance.details.health || {}).temperature.celsius + " °C") : "UNAVAILABLE"; detail: ((root.performance.details.health || {}).temperature || {}).source || "No fabricated reading" }
                }
                SurfaceCard {
                    width: parent.width
                    title: "GRAPHICS"
                    value: (root.performance.details.graphics || {}).available ? ((root.performance.details.graphics || {}).driver || "DETECTED") : "UNAVAILABLE"
                    detail: (root.performance.details.graphics || {}).device || "No supported GPU source returned data; no value is fabricated."
                }
                Text { text: "TEMPERATURE SENSORS"; color: Config.Theme.dim; font.family: Config.Theme.fontFamily; font.pixelSize: 8 }
                Repeater {
                    model: (root.performance.details.sensors || {}).temperatures || []
                    delegate: SurfaceButton {
                        required property var modelData
                        width: cpuColumn.width
                        text: modelData.source + " // " + modelData.label
                        detail: modelData.celsius + " °C" + (modelData.critical_celsius ? " · critical " + modelData.critical_celsius + " °C" : "")
                    }
                }
            }
        }
    }

    Component {
        id: memoryPage
        Column {
            spacing: 12
            HistoryChart { width: parent.width; height: 260; values: root.performance.memoryHistory; lineColor: Config.Theme.cyan; label: "MEMORY UTILISATION // BOUNDED 60 SAMPLES"; currentLabel: Math.round(root.metrics.memoryPercent) + "%" }
            Grid {
                width: parent.width
                columns: 3
                columnSpacing: 8
                SurfaceCard { width: (parent.width - 16) / 3; title: "CURRENT"; value: Math.round(root.metrics.memoryPercent) + "%"; detail: "From /proc/meminfo" }
                SurfaceCard { width: (parent.width - 16) / 3; title: "PROCESSES SHOWN"; value: String(root.performance.processes.length); detail: "Bounded top-process view" }
                SurfaceCard { width: (parent.width - 16) / 3; title: "SAMPLER"; value: root.performance.active ? "ACTIVE" : "STOPPED"; detail: "Level 2 lifecycle" }
            }
            Text {
                width: parent.width
                text: "Memory uses MemAvailable when present and falls back to free + buffers + cached. Process enumeration runs only while this dashboard is active."
                color: Config.Theme.muted
                font.family: Config.Theme.fontFamily
                font.pixelSize: 9
                wrapMode: Text.WordWrap
            }
        }
    }

    Component {
        id: storagePage
        Flickable {
            contentHeight: storageColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: storageColumn
                width: parent.width
                spacing: 11
                Grid {
                    width: parent.width
                    columns: 3
                    columnSpacing: 8
                    SurfaceCard { width: (parent.width - 16) / 3; title: "ROOT USAGE"; value: String((root.performance.details.storage || {}).percent || 0) + "%"; detail: (root.performance.details.storage || {}).mount || "/" }
                    SurfaceCard { width: (parent.width - 16) / 3; title: "USED"; value: root.formatBytes((root.performance.details.storage || {}).used_bytes); detail: "of " + root.formatBytes((root.performance.details.storage || {}).total_bytes) }
                    SurfaceCard { width: (parent.width - 16) / 3; title: "FILESYSTEM"; value: (root.performance.details.storage || {}).filesystem || "UNKNOWN"; detail: (root.performance.details.storage || {}).source || "Source unavailable" }
                }
                Text { text: "PHYSICAL DEVICES"; color: Config.Theme.dim; font.family: Config.Theme.fontFamily; font.pixelSize: 8 }
                Repeater {
                    model: (root.performance.details.storage || {}).devices || []
                    delegate: SurfaceButton {
                        required property var modelData
                        width: storageColumn.width
                        text: modelData.name + " // " + (modelData.model || "Unknown model")
                        detail: root.formatBytes(modelData.size_bytes) + " · " + (modelData.transport || "unknown transport") + " · " + modelData.partition_count + " partition(s)"
                    }
                }
            }
        }
    }

    Component {
        id: networkPage
        Column {
            spacing: 11
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 10
                HistoryChart { width: (parent.width - 10) / 2; height: 220; values: root.performance.rxHistory; maximum: root.peak(root.performance.rxHistory, 10); lineColor: Config.Theme.success; label: "RECEIVE"; currentLabel: Math.round(root.metrics.networkRxKib) + " KiB/s" }
                HistoryChart { width: (parent.width - 10) / 2; height: 220; values: root.performance.txHistory; maximum: root.peak(root.performance.txHistory, 10); lineColor: Config.Theme.amber; label: "TRANSMIT"; currentLabel: Math.round(root.metrics.networkTxKib) + " KiB/s" }
            }
            Grid {
                width: parent.width
                columns: 3
                columnSpacing: 8
                SurfaceCard { width: (parent.width - 16) / 3; title: "CONNECTION"; value: root.network.label; detail: root.network.detail }
                SurfaceCard { width: (parent.width - 16) / 3; title: "TCP ESTABLISHED"; value: String((((root.performance.details.sockets || {}).tcp || {}).established) || 0); detail: String((((root.performance.details.sockets || {}).tcp || {}).listening) || 0) + " listening" }
                SurfaceCard { width: (parent.width - 16) / 3; title: "SOCKETS"; value: String((root.performance.details.sockets || {}).used || 0); detail: String((root.performance.details.sockets || {}).udp_in_use || 0) + " UDP in use" }
            }
            Text {
                width: parent.width
                text: JSON.stringify(root.performance.details.network || {}, null, 2)
                color: Config.Theme.muted
                font.family: Config.Theme.fontFamily
                font.pixelSize: 8
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 12
                elide: Text.ElideRight
            }
        }
    }

    Component {
        id: processesPage
        Column {
            spacing: 8
            Row {
                width: parent.width
                Repeater {
                    model: [
                        {label: "RANK", width: 52}, {label: "PROCESS", width: 250},
                        {label: "PID", width: 74}, {label: "CPU", width: 78},
                        {label: "MEM", width: 100}, {label: "STATE", width: 70},
                        {label: "USER", width: 110}
                    ]
                    delegate: Text {
                        required property var modelData
                        width: modelData.width
                        text: modelData.label
                        color: Config.Theme.dim
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: Config.Theme.surfaceHover }
            ListView {
                width: parent.width
                height: parent.height - 40
                spacing: 5
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.performance.processes
                delegate: Rectangle {
                    id: processRow
                    required property var modelData
                    width: ListView.view.width
                    height: 45
                    radius: 12
                    color: Config.Theme.surfaceRaised
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        Repeater {
                            model: [
                                {text: String(processRow.modelData.rank), width: 52},
                                {text: processRow.modelData.name, width: 250},
                                {text: String(processRow.modelData.pid), width: 74},
                                {text: processRow.modelData.cpu_percent.toFixed(1) + "%", width: 78},
                                {text: processRow.modelData.memory_mib.toFixed(1) + " MiB", width: 100},
                                {text: processRow.modelData.state, width: 70},
                                {text: processRow.modelData.user, width: 110}
                            ]
                            delegate: Text {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                width: modelData.width
                                text: modelData.text
                                color: Config.Theme.foreground
                                font.family: Config.Theme.fontFamily
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: benchmarksPage
        Flickable {
            contentHeight: benchmarkColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: benchmarkColumn
                width: parent.width
                spacing: 12
                SurfaceCard {
                    width: parent.width
                    title: "LEVEL 3 // EXPLICIT ACTION"
                    value: (root.performance.benchmarkStatus.state_label || "READY") + " · " + String(root.performance.benchmarkStatus.progress || 0) + "%"
                    detail: root.performance.benchmarkStatus.message || "No benchmark has run yet."
                    valueColor: root.performance.benchmarkStatus.state === "running" ? Config.Theme.warning : Config.Theme.foreground
                }
                Text {
                    width: parent.width
                    text: "Benchmarks are finite, unprivileged, thermally watched, and may produce sustained CPU, memory, compression, storage, and process-launch load. They are never started by automated QA."
                    color: Config.Theme.muted
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                }
                Row {
                    visible: root.performance.benchmarkActionState !== "pending"
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: ["quick", "standard"]
                        delegate: SurfaceButton {
                            required property string modelData
                            width: (parent.width - 120) / 2
                            text: "REQUEST " + modelData.toUpperCase()
                            detail: {
                                const plan = root.performance.benchmarkPlans[modelData];
                                return plan ? "~" + plan.estimated_seconds + " s · thermal stop " + plan.thermal_limit_c + " °C" : "Loading bounded plan";
                            }
                            enabled: root.performance.benchmarkStatus.state !== "running"
                                && root.performance.benchmarkActionState !== "running"
                            onClicked: root.performance.requestBenchmark(modelData)
                        }
                    }
                    SurfaceButton {
                        width: 110
                        text: "STOP"
                        accentColor: Config.Theme.danger
                        enabled: root.performance.benchmarkStatus.state === "running"
                        onClicked: root.performance.stopBenchmark()
                    }
                }
                Column {
                    visible: root.performance.benchmarkActionState === "pending"
                    width: parent.width
                    spacing: 10
                    Text {
                        width: parent.width
                        text: "CONFIRM " + root.performance.pendingBenchmark.toUpperCase() + " BENCHMARK?"
                        color: Config.Theme.warning
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    Row {
                        width: parent.width
                        spacing: 10
                        SurfaceButton { width: (parent.width - 10) / 2; text: "CANCEL"; onClicked: root.performance.cancelBenchmarkRequest() }
                        SurfaceButton { width: (parent.width - 10) / 2; text: "START BOUNDED LOAD"; active: true; accentColor: Config.Theme.warning; onClicked: root.performance.confirmBenchmark() }
                    }
                }
                Text { text: "BENCHMARK LOG"; color: Config.Theme.dim; font.family: Config.Theme.fontFamily; font.pixelSize: 8 }
                Repeater {
                    model: root.performance.benchmarkStatus.logs || []
                    delegate: Text {
                        required property string modelData
                        width: benchmarkColumn.width
                        text: modelData
                        color: Config.Theme.muted
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 8
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }
        }
    }
}
