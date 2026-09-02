import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import "../config" as Config

PopupWindow {
    id: root

    required property var anchorItem
    property bool requestedOpen: false
    property bool cardShown: false
    property int displayedYear: new Date().getFullYear()
    property int displayedMonth: new Date().getMonth()
    signal dismissRequested()

    readonly property var now: new Date()
    readonly property string monthTitle: Qt.formatDate(new Date(displayedYear, displayedMonth, 1), "MMMM yyyy")
    readonly property var days: buildDays()

    implicitWidth: 430
    implicitHeight: 470
    color: "transparent"
    visible: requestedOpen || cardShown || closeTimer.running
    grabFocus: false

    anchor.item: anchorItem
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Top | Edges.Left
    anchor.rect.y: -12

    function buildDays() {
        const result = [];
        const firstDay = new Date(displayedYear, displayedMonth, 1);
        const leading = (firstDay.getDay() + 6) % 7;
        const daysInMonth = new Date(displayedYear, displayedMonth + 1, 0).getDate();
        const previousMonthDays = new Date(displayedYear, displayedMonth, 0).getDate();
        for (let index = 0; index < 42; index++) {
            let year = displayedYear;
            let month = displayedMonth;
            let day = index - leading + 1;
            let current = true;
            if (day < 1) {
                month -= 1;
                if (month < 0) {
                    month = 11;
                    year -= 1;
                }
                day = previousMonthDays + day;
                current = false;
            } else if (day > daysInMonth) {
                day -= daysInMonth;
                month += 1;
                if (month > 11) {
                    month = 0;
                    year += 1;
                }
                current = false;
            }
            result.push({
                day: day,
                current: current,
                today: year === now.getFullYear() && month === now.getMonth() && day === now.getDate()
            });
        }
        return result;
    }

    function openAnimated() {
        closeTimer.stop();
        displayedYear = now.getFullYear();
        displayedMonth = now.getMonth();
        revealTimer.restart();
    }

    function closeAnimated() {
        revealTimer.stop();
        cardShown = false;
        closeTimer.restart();
    }

    onRequestedOpenChanged: {
        if (requestedOpen)
            openAnimated();
        else
            closeAnimated();
    }

    onAnchorItemChanged: {
        if (!anchorItem)
            dismissRequested();
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        active: root.cardShown
        onCleared: if (root.requestedOpen) root.dismissRequested()
    }

    Timer {
        id: revealTimer
        interval: 1
        onTriggered: {
            root.cardShown = root.requestedOpen;
            if (root.cardShown)
                card.forceActiveFocus();
        }
    }

    Timer {
        id: closeTimer
        interval: Config.Theme.popupCloseMs
    }

    FocusScope {
        id: card
        anchors.fill: parent
        focus: true
        opacity: root.cardShown ? 1 : 0
        transform: Translate {
            y: root.cardShown ? 0 : 10
            Behavior on y {
                NumberAnimation { duration: Config.Theme.popupOpenMs; easing.type: Easing.OutCubic }
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.popupOpenMs; easing.type: Easing.OutCubic }
        }

        Keys.onEscapePressed: root.dismissRequested()

        SenomyFrame {
            anchors.fill: parent
            tier: "standard"
            motif: "clock-notification"
            active: true

            Column {
                anchors.fill: parent
                spacing: 14

                Row {
                    width: parent.width
                    height: 58
                    spacing: 12

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 126
                        spacing: 3
                        Text {
                            text: "TEMPORAL INDEX // LOCAL"
                            color: Config.Theme.accent
                            font.family: Config.Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.monthTitle.toUpperCase()
                            color: Config.Theme.foreground
                            font.family: Config.Theme.fontFamily
                            font.pixelSize: 19
                            font.weight: Font.DemiBold
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Repeater {
                            model: [
                                { glyph: "󰅁", delta: -1, tip: "Previous month" },
                                { glyph: "󰅂", delta: 1, tip: "Next month" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                width: 50
                                height: 44
                                radius: 13
                                color: navArea.containsMouse ? Config.Theme.surfaceHover : Config.Theme.surfaceRaised
                                border.width: 1
                                border.color: Config.Theme.dim
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.glyph
                                    color: Config.Theme.foreground
                                    font.family: Config.Theme.fontFamily
                                    font.pixelSize: 16
                                }
                                MouseArea {
                                    id: navArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const next = new Date(root.displayedYear, root.displayedMonth + modelData.delta, 1);
                                        root.displayedYear = next.getFullYear();
                                        root.displayedMonth = next.getMonth();
                                    }
                                }
                                ToolTip.visible: navArea.containsMouse
                                ToolTip.delay: 450
                                ToolTip.text: modelData.tip
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Config.Theme.surfaceRaised
                }

                Grid {
                    width: parent.width
                    columns: 7
                    columnSpacing: 5
                    rowSpacing: 5

                    Repeater {
                        model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
                        delegate: Text {
                            required property string modelData
                            width: (parent.width - 30) / 7
                            height: 24
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData
                            color: Config.Theme.dim
                            font.family: Config.Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }
                    }

                    Repeater {
                        model: root.days
                        delegate: Rectangle {
                            required property var modelData
                            width: (parent.width - 30) / 7
                            height: 42
                            radius: 12
                            color: modelData.today ? Config.Theme.accent
                                : dayArea.containsMouse ? Config.Theme.surfaceHover : Config.Theme.surfaceRaised
                            border.width: modelData.current ? 1 : 0
                            border.color: modelData.today ? Config.Theme.accent : Config.Theme.surfaceHover
                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                color: modelData.today ? Config.Theme.background
                                    : modelData.current ? Config.Theme.foreground : Config.Theme.dim
                                font.family: Config.Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: modelData.today ? Font.Bold : Font.Normal
                            }
                            MouseArea {
                                id: dayArea
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 28
                    spacing: 8
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: Config.Theme.success
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(root.now, "dddd, dd MMMM yyyy").toUpperCase()
                        color: Config.Theme.muted
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 9
                    }
                }
            }
        }
    }
}
