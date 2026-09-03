import QtQuick
import Quickshell
import "../config" as Config

PrimarySurfaceWindow {
    id: root

    required property var state
    required property var insights
    required property var senomy
    required property var notifications
    required property var battery
    required property var network
    required property var media
    required property var metrics
    property string selectedWikiId: ""

    requestedOpen: state.activePrimary === "insights"
        && state.primaryScreen === (targetScreen ? targetScreen.name : "")
    replacementOpening: state.activePrimary !== "" && state.activePrimary !== "insights"
    title: "SENOMY INSIGHTS"
    eyebrow: "LOCAL SYSTEM BRIEFING"
    activeSection: state.insightsSection
    preferredWidth: 1040
    preferredHeight: 760
    motif: "identity"
    sections: [
        {id: "briefing", label: "BRIEFING"},
        {id: "notifications", label: "NOTIFICATIONS"},
        {id: "timeline", label: "TIMELINE"},
        {id: "updates", label: "UPDATES"},
        {id: "diagnostics", label: "DIAGNOSTICS"},
        {id: "console", label: "CONSOLE"},
        {id: "reports", label: "REPORTS"},
        {id: "wiki", label: "WIKI"}
    ]

    onCloseRequested: state.closePrimary()
    onSectionRequested: section => state.insightsSection = section

    function payload(route) {
        return insights.payloads[route] || ({ok: true, data: {}});
    }

    function data(route) {
        return payload(route).data || ({});
    }

    function briefingObservations() {
        return [
            {label: "SYSTEM HEALTH", value: senomy.systemHealth.toUpperCase()},
            {label: "CPU UTILISATION", value: Math.round(metrics.cpuPercent) + "%"},
            {label: "MEMORY UTILISATION", value: Math.round(metrics.memoryPercent) + "%"},
            {label: "CONNECTIVITY", value: network.detail},
            {label: "POWER", value: battery.detail}
        ];
    }

    function briefingContext() {
        return [
            {label: "LOCAL TIME", value: Qt.formatDateTime(new Date(), "ddd dd MMM · hh:mm")},
            {label: "NOTIFICATIONS", value: notifications.unreadCount + " unread"},
            {label: "KNOWN UPDATES", value: String(data("briefing").known_total_count || 0)},
            {label: "MEDIA", value: media.playing ? media.title : "Quiet"},
            {label: "DATA LOCALITY", value: "Local only"}
        ];
    }

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (root.state.insightsSection) {
            case "notifications": return notificationsPage;
            case "timeline": return timelinePage;
            case "updates": return updatesPage;
            case "diagnostics": return diagnosticsPage;
            case "console": return consolePage;
            case "reports": return reportsPage;
            case "wiki": return wikiPage;
            default: return briefingPage;
            }
        }
    }

    Component {
        id: briefingPage
        Flickable {
            contentHeight: briefingColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: briefingColumn
                width: parent.width
                spacing: 13
                Column {
                    width: parent.width
                    spacing: 9
                    Text {
                        width: parent.width
                        text: root.senomy.state.toUpperCase() + " // LOCAL OBSERVER"
                        color: Config.Theme.accent
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        text: root.senomy.message
                        color: Config.Theme.foreground
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Config.Theme.glassHover
                    }
                    Text {
                        width: parent.width
                        text: "Derived from local shell, media, battery, network, health, and notification state."
                        color: Config.Theme.muted
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                    }
                }
                Row {
                    width: parent.width
                    spacing: 18
                    Column {
                        width: (parent.width - 37) * 0.62
                        spacing: 0
                        Text {
                            height: 34
                            text: "SYSTEM OBSERVATIONS"
                            color: Config.Theme.dim
                            font.family: Config.Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }
                        Repeater {
                            model: root.briefingObservations()
                            delegate: Item {
                                required property var modelData
                                width: parent.width
                                height: 48
                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: Config.Theme.muted
                                    font.family: Config.Theme.fontFamily
                                    font.pixelSize: 9
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * 0.58
                                    text: modelData.value
                                    color: Config.Theme.foreground
                                    font.family: Config.Theme.fontFamily
                                    font.pixelSize: 9
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: Config.Theme.glassHover
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: 1
                        height: 274
                        color: Config.Theme.glassHover
                    }
                    Column {
                        width: (parent.width - 37) * 0.38
                        spacing: 0
                        Text {
                            height: 34
                            text: "SOURCE / FRESHNESS / LOCAL CONTEXT"
                            color: Config.Theme.dim
                            font.family: Config.Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }
                        Repeater {
                            model: root.briefingContext()
                            delegate: Item {
                                required property var modelData
                                width: parent.width
                                height: 48
                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: Config.Theme.muted
                                    font.family: Config.Theme.fontFamily
                                    font.pixelSize: 8
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * 0.54
                                    text: modelData.value
                                    color: modelData.label === "DATA LOCALITY" ? Config.Theme.accent : Config.Theme.foreground
                                    font.family: Config.Theme.fontFamily
                                    font.pixelSize: 8
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: Config.Theme.glassHover
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: notificationsPage
        Column {
            spacing: 10
            Row {
                width: parent.width
                spacing: 10
                SurfaceCard { width: parent.width - 220; title: "NATIVE HISTORY"; value: root.notifications.history.length + " RECORDS"; detail: root.notifications.serverEnabled ? root.notifications.unreadCount + " unread" : "SwayNC still owns notifications" }
                SurfaceButton { anchors.verticalCenter: parent.verticalCenter; width: 100; text: root.notifications.dnd ? "DND ON" : "DND OFF"; active: root.notifications.dnd; enabled: root.notifications.serverEnabled; onClicked: root.notifications.setDnd(!root.notifications.dnd) }
                SurfaceButton { anchors.verticalCenter: parent.verticalCenter; width: 100; text: "CLEAR"; enabled: root.notifications.history.length > 0; onClicked: root.notifications.clearAll() }
            }
            ListView {
                width: parent.width
                height: parent.height - 126
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.notifications.history
                delegate: SurfaceButton {
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.summary
                    detail: modelData.appName + " // " + modelData.body
                    active: modelData.unread
                    onClicked: root.notifications.dismiss(modelData)
                }
            }
            Text {
                visible: root.notifications.history.length === 0
                width: parent.width
                text: root.notifications.serverEnabled ? "No native notification history yet." : "Native history is isolated until notification ownership migration passes."
                color: Config.Theme.muted
                font.family: Config.Theme.fontFamily
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Component {
        id: timelinePage
        Column {
            spacing: 10
            Row {
                width: parent.width
                SurfaceCard { width: parent.width - 120; title: "BOUNDED ACTIVITY TIMELINE"; value: String(root.data("timeline").count || 0) + " EVENTS"; detail: "Local sanitized activity · at most 40 rows" }
                SurfaceButton { anchors.verticalCenter: parent.verticalCenter; width: 110; text: "REFRESH"; onClicked: root.insights.refresh("timeline", false) }
            }
            ListView {
                width: parent.width
                height: parent.height - 130
                spacing: 7
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.data("timeline").entries || []
                delegate: SurfaceButton {
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.time + " // " + modelData.title
                    detail: modelData.source + " // " + modelData.message
                    accentColor: modelData.severity === "error" ? Config.Theme.danger : Config.Theme.accent
                }
            }
        }
    }

    Component {
        id: updatesPage
        Column {
            spacing: 12
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 10
                SurfaceCard { width: (parent.width - 10) / 2; title: "OFFICIAL"; value: (root.data("updates").official || {}).state_label || "NOT CHECKED"; detail: String((root.data("updates").official || {}).count || 0) + " package(s)" }
                SurfaceCard { width: (parent.width - 10) / 2; title: "AUR"; value: (root.data("updates").aur || {}).state_label || "NOT CHECKED"; detail: String((root.data("updates").aur || {}).count || 0) + " package(s)" }
            }
            Row {
                width: parent.width
                spacing: 10
                SurfaceButton { width: (parent.width - 10) / 2; text: "CHECK OFFICIAL"; detail: "Read-only checkupdates/pacman metadata"; enabled: root.insights.actionState !== "running"; onClicked: root.insights.runUpdate("official") }
                SurfaceButton { width: (parent.width - 10) / 2; text: "CHECK AUR"; detail: "Queries AUR for installed foreign packages"; enabled: root.insights.actionState !== "running"; onClicked: root.insights.runUpdate("aur") }
            }
            Text { text: "AVAILABLE PACKAGES"; color: Config.Theme.dim; font.family: Config.Theme.fontFamily; font.pixelSize: 8 }
            ListView {
                width: parent.width
                height: parent.height - 250
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: ((root.data("updates").official || {}).packages || []).concat((root.data("updates").aur || {}).packages || [])
                delegate: SurfaceButton {
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.name
                    detail: modelData.current + " → " + modelData.available + " // " + modelData.source
                }
            }
        }
    }

    Component {
        id: diagnosticsPage
        Column {
            spacing: 10
            Text { text: "ALLOWLISTED READ-ONLY DIAGNOSTICS"; color: Config.Theme.accent; font.family: Config.Theme.fontFamily; font.pixelSize: 9; font.weight: Font.DemiBold }
            Flow {
                width: parent.width
                spacing: 7
                Repeater {
                    model: root.insights.tasksFor("diagnostics")
                    delegate: SurfaceButton {
                        required property var modelData
                        width: 190
                        text: modelData.code + " // " + modelData.title
                        detail: modelData.summary
                        enabled: root.insights.actionState !== "running"
                        onClicked: root.insights.runTask("diagnostics", modelData.id)
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: Config.Theme.surfaceHover }
            Text { text: ((root.data("diagnosticsResult").title || "Awaiting task")).toUpperCase(); color: Config.Theme.foreground; font.family: Config.Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold }
            ListView {
                width: parent.width
                height: Math.max(120, parent.height - 340)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.data("diagnosticsResult").output || []
                delegate: Text {
                    required property var modelData
                    width: ListView.view.width
                    text: typeof modelData === "string" ? modelData : modelData.text || JSON.stringify(modelData)
                    color: Config.Theme.muted
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 8
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }

    Component {
        id: consolePage
        Column {
            spacing: 10
            Text { text: "CURATED CONSOLE // NO ARBITRARY COMMAND ENTRY"; color: Config.Theme.accent; font.family: Config.Theme.fontFamily; font.pixelSize: 9; font.weight: Font.DemiBold }
            Flow {
                width: parent.width
                spacing: 7
                Repeater {
                    model: root.insights.tasksFor("console")
                    delegate: SurfaceButton {
                        required property var modelData
                        width: 176
                        text: modelData.code + " // " + modelData.title
                        detail: modelData.summary
                        enabled: root.insights.actionState !== "running"
                        onClicked: root.insights.runTask("console", modelData.id)
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: Config.Theme.surfaceHover }
            Text { text: ((root.data("consoleResult").title || "Console standing by")).toUpperCase(); color: Config.Theme.foreground; font.family: Config.Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold }
            ListView {
                width: parent.width
                height: Math.max(120, parent.height - 390)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.data("consoleResult").output || []
                delegate: Text {
                    required property var modelData
                    width: ListView.view.width
                    text: typeof modelData === "string" ? modelData : modelData.text || JSON.stringify(modelData)
                    color: Config.Theme.muted
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 8
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }

    Component {
        id: reportsPage
        Column {
            spacing: 12
            SurfaceCard {
                width: parent.width
                title: "PRIVATE EVIDENCE REPORTS"
                value: root.data("reports").exists ? (root.data("reports").latest.profile_label || "READY") : "NONE"
                detail: String(root.data("reports").history_count || 0) + " retained report(s) · mode 0600 · no automatic upload"
            }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: ["overview", "performance", "network", "power", "full"]
                    delegate: SurfaceButton {
                        required property string modelData
                        width: 130
                        text: "GENERATE " + modelData.toUpperCase()
                        enabled: root.insights.actionState !== "running"
                        onClicked: root.insights.generateReport(modelData)
                    }
                }
                SurfaceButton { width: 130; text: "OPEN LATEST"; enabled: Boolean(root.data("reports").exists); onClicked: root.insights.openLatestReport() }
            }
            Text { text: "LATEST PREVIEW"; color: Config.Theme.dim; font.family: Config.Theme.fontFamily; font.pixelSize: 8 }
            ListView {
                width: parent.width
                height: parent.height - 240
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.data("reports").preview || []
                delegate: Text {
                    required property var modelData
                    width: ListView.view.width
                    text: String(modelData.line_no).padStart(3, "0") + "  " + modelData.text
                    color: Config.Theme.muted
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 8
                }
            }
        }
    }

    Component {
        id: wikiPage
        Row {
            id: wikiLayout
            spacing: 10
            readonly property var articles: root.data("wiki").articles || []
            readonly property var selectedArticle: articles.find(article => article.id === root.selectedWikiId)
                || (articles.length > 0 ? articles[0] : null)
            ListView {
                width: 190
                height: parent.height
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: wikiLayout.articles
                delegate: SurfaceButton {
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.title
                    detail: modelData.category_title
                    active: wikiLayout.selectedArticle && wikiLayout.selectedArticle.id === modelData.id
                    onClicked: root.selectedWikiId = modelData.id
                }
            }
            Rectangle { width: 1; height: parent.height; color: Config.Theme.surfaceHover }
            Flickable {
                width: parent.width - 201
                height: parent.height
                contentHeight: articleColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: articleColumn
                    width: parent.width
                    spacing: 8
                    Text {
                        width: parent.width
                        text: wikiLayout.selectedArticle ? wikiLayout.selectedArticle.title : "WIKI UNAVAILABLE"
                        color: Config.Theme.foreground
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        width: parent.width
                        text: wikiLayout.selectedArticle ? wikiLayout.selectedArticle.summary : "No local article catalog was returned."
                        color: Config.Theme.muted
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                    }
                    Repeater {
                        model: wikiLayout.selectedArticle ? wikiLayout.selectedArticle.blocks : []
                        delegate: Text {
                            required property var modelData
                            width: articleColumn.width
                            text: modelData.text || (modelData.items ? modelData.items.map(item => "• " + item.text).join("\n") : "")
                            visible: text.length > 0
                            color: modelData.type === "heading" ? Config.Theme.accent : Config.Theme.muted
                            font.family: Config.Theme.fontFamily
                            font.pixelSize: modelData.type === "heading" ? 11 : 9
                            font.weight: modelData.type === "heading" ? Font.DemiBold : Font.Normal
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }
}
