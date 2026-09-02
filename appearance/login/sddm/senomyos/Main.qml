import QtQuick 2.15
import SddmComponents 2.0
import "Theme.js" as Theme

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#08090b"

    property color backgroundColor: Theme.background
    property color surfaceColor: Theme.surface
    property color raisedColor: Theme.surfaceRaised
    property color foregroundColor: Theme.foreground
    property color mutedColor: Theme.muted
    property color dimColor: Theme.dim
    property color accentColor: Theme.accent
    property color dangerColor: Theme.danger
    property color successColor: Theme.success
    property string fontFamily: Theme.fontFamily

    property date now: new Date()
    property bool authenticating: false
    property bool recoveryMode: false
    property bool accessibilityMode: false
    property string statusMessage: ""
    property string confirmationAction: ""
    property string normalUser: userModel.lastUser || config.stringValue("PreviewUser") || ""
    property string typedUser: ""
    property int normalSessionIndex: -1
    property int selectedSessionIndex: -1
    property string recoveryUser: config.stringValue("RecoveryUser") || "senomy-recovery"
    property string recoverySession: config.stringValue("RecoverySession") || "Senomy Recovery"
    property bool recoveryOffered: config.boolValue("ShowRecovery")

    function sessionCount() {
        return sessionModel.count === undefined ? 0 : sessionModel.count
    }

    function sessionName(index) {
        if (index < 0 || index >= sessionCount())
            return "SESSION"
        var modelIndex = sessionModel.index(index, 0)
        var value = sessionModel.data(modelIndex, 260)
        return value === undefined || value === null ? "SESSION" : String(value)
    }

    function sessionLabel(index) {
        var name = sessionName(index)
        return name.toLowerCase().indexOf("hyprland") >= 0 ? "HYPRLAND" : name.toUpperCase()
    }

    function sessionIsRecovery(index) {
        return sessionName(index).toLowerCase() === recoverySession.toLowerCase()
    }

    function normalSessionCount() {
        var count = 0
        for (var index = 0; index < sessionCount(); index++) {
            if (!sessionIsRecovery(index))
                count++
        }
        return count
    }

    function preferredNormalSessionIndex() {
        var last = sessionModel.lastIndex
        if (last >= 0 && last < sessionCount() && !sessionIsRecovery(last))
            return last

        for (var index = 0; index < sessionCount(); index++) {
            if (sessionName(index).toLowerCase() === "hyprland")
                return index
        }
        for (var fallback = 0; fallback < sessionCount(); fallback++) {
            if (!sessionIsRecovery(fallback))
                return fallback
        }
        return -1
    }

    function resetNormalSession() {
        normalSessionIndex = preferredNormalSessionIndex()
        selectedSessionIndex = normalSessionIndex
    }

    function nextNormalSessionIndex(current) {
        var count = sessionCount()
        if (count <= 0)
            return -1
        for (var offset = 1; offset <= count; offset++) {
            var candidate = (Math.max(-1, current) + offset) % count
            if (!sessionIsRecovery(candidate))
                return candidate
        }
        return -1
    }

    function selectNextNormalSession() {
        if (recoveryMode)
            return
        var next = nextNormalSessionIndex(selectedSessionIndex)
        if (next >= 0) {
            normalSessionIndex = next
            selectedSessionIndex = next
            statusMessage = "SESSION // " + sessionLabel(next)
        }
    }

    function keyboardLayoutCount() {
        return keyboard.layouts && keyboard.layouts.length !== undefined ? keyboard.layouts.length : 0
    }

    function keyboardLayoutIndex(shortName) {
        var wanted = String(shortName).toLowerCase()
        for (var index = 0; index < keyboardLayoutCount(); index++) {
            if (String(keyboard.layouts[index].shortName).toLowerCase() === wanted)
                return index
        }
        return -1
    }

    function keyboardLayoutSelected(shortName) {
        return keyboardLayoutIndex(shortName) === keyboard.currentLayout
    }

    function selectKeyboardLayout(shortName) {
        var index = keyboardLayoutIndex(shortName)
        if (index < 0) {
            statusMessage = "KEYBOARD LAYOUT UNAVAILABLE"
            return
        }
        keyboard.currentLayout = index
        statusMessage = "KEYBOARD // " + String(keyboard.layouts[index].shortName).toUpperCase()
    }

    function recoverySessionIndex() {
        var wanted = recoverySession.toLowerCase()
        for (var index = 0; index < sessionCount(); index++) {
            if (sessionName(index).toLowerCase() === wanted)
                return index
        }
        return -1
    }

    function currentUser() {
        return recoveryMode ? recoveryUser : (normalUser !== "" ? normalUser : typedUser)
    }

    function activateUtility(action, passwordItem) {
        if (action === "ACCESS")
            accessibilityMode = !accessibilityMode
        else if (action === "RECOVER" || action === "BACK")
            beginRecovery(passwordItem)
        else
            confirmationAction = action === "POWER" ? "power" : "restart"
    }

    function beginRecovery(passwordItem) {
        if (recoveryMode) {
            recoveryMode = false
            resetNormalSession()
            statusMessage = ""
            passwordItem.text = ""
            passwordItem.forceActiveFocus()
            return
        }

        var index = recoverySessionIndex()
        if (index < 0) {
            statusMessage = "RECOVERY RUNTIME NOT INSTALLED"
            return
        }

        recoveryMode = true
        selectedSessionIndex = index
        statusMessage = "ENTER THE SEPARATE RECOVERY CREDENTIAL"
        passwordItem.text = ""
        passwordItem.forceActiveFocus()
    }

    function attemptLogin(passwordItem) {
        if (authenticating || currentUser() === "" || passwordItem.text === "")
            return
        if (!recoveryMode) {
            if (selectedSessionIndex < 0 || sessionIsRecovery(selectedSessionIndex))
                resetNormalSession()
            if (selectedSessionIndex < 0 || sessionIsRecovery(selectedSessionIndex)) {
                statusMessage = "NORMAL SESSION UNAVAILABLE"
                return
            }
        }
        authenticating = true
        statusMessage = recoveryMode ? "OPENING RESTRICTED RECOVERY" : "AUTHENTICATING"
        sddm.login(currentUser(), passwordItem.text, selectedSessionIndex)
    }

    function executeConfirmation() {
        var action = confirmationAction
        confirmationAction = ""
        if (action === "power" && sddm.canPowerOff)
            sddm.powerOff()
        else if (action === "restart" && sddm.canReboot)
            sddm.reboot()
    }

    Component.onCompleted: resetNormalSession()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            root.authenticating = false
            root.statusMessage = "AUTHENTICATED"
        }

        function onLoginFailed() {
            root.authenticating = false
            root.statusMessage = root.recoveryMode ?
                "RECOVERY AUTHENTICATION FAILED" : "AUTHENTICATION FAILED"
        }

        function onInformationMessage(message) {
            root.statusMessage = String(message).toUpperCase()
        }
    }

    Repeater {
        model: screenModel

        Item {
            id: screen
            x: geometry.x
            y: geometry.y
            width: geometry.width
            height: geometry.height

            property bool isPrimary: index === screenModel.primary
            property real scaleUnit: Math.min(width / 1920, height / 1080)
            property bool narrow: width < 900

            Image {
                anchors.fill: parent
                source: config.stringValue("Background") || "assets/background.png"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            Rectangle {
                anchors.fill: parent
                color: root.backgroundColor
                opacity: root.accessibilityMode ? 0.58 : 0.34
            }

            Item {
                id: rail
                visible: screen.isPrimary && !screen.narrow
                x: (screen.width - width) / 2
                y: screen.height - height - (32 * screen.scaleUnit)
                width: 1856 * screen.scaleUnit
                height: 170 * screen.scaleUnit

                property real pad: 34 * screen.scaleUnit
                property real frameGap: 22 * screen.scaleUnit
                property real iconSize: 28 * screen.scaleUnit
                property real targetSize: 54 * screen.scaleUnit
                property real bodySize: (root.accessibilityMode ? 18 : 16) * screen.scaleUnit
                property real metaSize: (root.accessibilityMode ? 14 : 12) * screen.scaleUnit

                FrameSurface {
                    x: 0
                    width: 408 * screen.scaleUnit
                    height: rail.height
                    opticalScale: screen.scaleUnit
                    motif: "controls"
                    surfaceColor: root.surfaceColor
                    accentColor: root.accentColor
                    dangerColor: root.dangerColor
                    focused: utilityZone.activeFocus
                }

                FrameSurface {
                    x: 430 * screen.scaleUnit
                    width: 284 * screen.scaleUnit
                    height: rail.height
                    opticalScale: screen.scaleUnit
                    motif: "identity"
                    surfaceColor: root.surfaceColor
                    accentColor: root.accentColor
                    dangerColor: root.dangerColor
                    attention: root.recoveryMode
                }

                FrameSurface {
                    x: 736 * screen.scaleUnit
                    width: 654 * screen.scaleUnit
                    height: rail.height
                    opticalScale: screen.scaleUnit
                    motif: "junction"
                    motifAnchor: "bottom"
                    surfaceColor: root.surfaceColor
                    accentColor: root.accentColor
                    dangerColor: root.dangerColor
                    focused: passwordInput.activeFocus || signInButton.activeFocus
                    attention: root.authenticating
                }

                FrameSurface {
                    x: 1412 * screen.scaleUnit
                    width: 202 * screen.scaleUnit
                    height: rail.height
                    opticalScale: screen.scaleUnit
                    motif: "diagnostic-tick"
                    motifAnchor: "bottom"
                    surfaceColor: root.surfaceColor
                    accentColor: root.accentColor
                    dangerColor: root.dangerColor
                    focused: sessionZone.activeFocus
                }

                FrameSurface {
                    x: 1636 * screen.scaleUnit
                    width: 220 * screen.scaleUnit
                    height: rail.height
                    opticalScale: screen.scaleUnit
                    motif: "clock-notification"
                    motifAnchor: "bottom"
                    surfaceColor: root.surfaceColor
                    accentColor: root.accentColor
                    dangerColor: root.dangerColor
                }

                Rectangle {
                    visible: false
                    x: rail.width * 0.225
                    width: 1
                    height: rail.height - (54 * screen.scaleUnit)
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#28ffffff"
                }

                Rectangle {
                    visible: false
                    x: rail.width * 0.39
                    width: 1
                    height: rail.height - (54 * screen.scaleUnit)
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#28ffffff"
                }

                Rectangle {
                    visible: false
                    x: rail.width * 0.755
                    width: 1
                    height: rail.height - (54 * screen.scaleUnit)
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#28ffffff"
                }

                Rectangle {
                    visible: false
                    x: rail.width * 0.875
                    width: 1
                    height: rail.height - (54 * screen.scaleUnit)
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#28ffffff"
                }

                Item {
                    id: utilityZone
                    x: rail.pad
                    width: (408 * screen.scaleUnit) - (rail.pad * 2)
                    height: parent.height

                    Text {
                        x: 0
                        y: 30 * screen.scaleUnit
                        text: "SENOMY  //  "
                        color: root.foregroundColor
                        font.family: root.fontFamily
                        font.pixelSize: rail.bodySize
                        font.weight: Font.Medium
                        font.letterSpacing: 1.2 * screen.scaleUnit
                    }

                    Text {
                        x: 116 * screen.scaleUnit
                        y: 30 * screen.scaleUnit
                        text: root.recoveryMode ? "RECOVERY" : "AUTH"
                        color: root.accentColor
                        font.family: root.fontFamily
                        font.pixelSize: rail.bodySize
                        font.weight: Font.Medium
                        font.letterSpacing: 1.2 * screen.scaleUnit
                    }

                    Row {
                        y: 76 * screen.scaleUnit
                        spacing: 9 * screen.scaleUnit

                        Item {
                            width: 72 * screen.scaleUnit
                            height: 82 * screen.scaleUnit
                            opacity: sddm.canPowerOff ? 1 : 0.35
                            activeFocusOnTab: sddm.canPowerOff

                            Rectangle {
                                anchors.fill: parent
                                radius: 4 * screen.scaleUnit
                                color: "transparent"
                                border.width: parent.activeFocus ? 1 : 0
                                border.color: root.accentColor
                            }

                            Image {
                                width: rail.iconSize
                                height: rail.iconSize
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: "assets/icons/power.svg"
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 45 * screen.scaleUnit
                                text: "POWER"
                                color: root.mutedColor
                                font.family: root.fontFamily
                                font.pixelSize: rail.metaSize
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: sddm.canPowerOff
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.confirmationAction = "power"
                            }
                            Keys.onReturnPressed: root.confirmationAction = "power"
                            Keys.onEnterPressed: root.confirmationAction = "power"
                            Keys.onSpacePressed: root.confirmationAction = "power"
                        }

                        Item {
                            width: 72 * screen.scaleUnit
                            height: 82 * screen.scaleUnit
                            opacity: sddm.canReboot ? 1 : 0.35
                            activeFocusOnTab: sddm.canReboot

                            Rectangle {
                                anchors.fill: parent
                                radius: 4 * screen.scaleUnit
                                color: "transparent"
                                border.width: parent.activeFocus ? 1 : 0
                                border.color: root.accentColor
                            }

                            Image {
                                width: rail.iconSize
                                height: rail.iconSize
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: "assets/icons/restart.svg"
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 45 * screen.scaleUnit
                                text: "RESTART"
                                color: root.mutedColor
                                font.family: root.fontFamily
                                font.pixelSize: rail.metaSize
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: sddm.canReboot
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.confirmationAction = "restart"
                            }
                            Keys.onReturnPressed: root.confirmationAction = "restart"
                            Keys.onEnterPressed: root.confirmationAction = "restart"
                            Keys.onSpacePressed: root.confirmationAction = "restart"
                        }

                        Item {
                            width: 72 * screen.scaleUnit
                            height: 82 * screen.scaleUnit
                            activeFocusOnTab: true

                            Rectangle {
                                anchors.fill: parent
                                radius: 4 * screen.scaleUnit
                                color: "transparent"
                                border.width: parent.activeFocus ? 1 : 0
                                border.color: root.accentColor
                            }

                            Image {
                                width: rail.iconSize
                                height: rail.iconSize
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: "assets/icons/accessibility.svg"
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 45 * screen.scaleUnit
                                text: "ACCESS"
                                color: root.accessibilityMode ? root.accentColor : root.mutedColor
                                font.family: root.fontFamily
                                font.pixelSize: rail.metaSize
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.accessibilityMode = !root.accessibilityMode
                            }
                            Keys.onReturnPressed: root.accessibilityMode = !root.accessibilityMode
                            Keys.onEnterPressed: root.accessibilityMode = !root.accessibilityMode
                            Keys.onSpacePressed: root.accessibilityMode = !root.accessibilityMode
                        }

                        Item {
                            visible: root.recoveryOffered
                            width: 72 * screen.scaleUnit
                            height: 82 * screen.scaleUnit
                            activeFocusOnTab: visible

                            Rectangle {
                                anchors.fill: parent
                                radius: 4 * screen.scaleUnit
                                color: "transparent"
                                border.width: parent.activeFocus ? 1 : 0
                                border.color: root.accentColor
                            }

                            Image {
                                width: rail.iconSize
                                height: rail.iconSize
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: "assets/icons/recovery.svg"
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 45 * screen.scaleUnit
                                text: root.recoveryMode ? "BACK" : "RECOVER"
                                color: root.recoveryMode ? root.accentColor : root.mutedColor
                                font.family: root.fontFamily
                                font.pixelSize: rail.metaSize
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.beginRecovery(passwordInput)
                            }
                            Keys.onReturnPressed: root.beginRecovery(passwordInput)
                            Keys.onEnterPressed: root.beginRecovery(passwordInput)
                            Keys.onSpacePressed: root.beginRecovery(passwordInput)
                        }
                    }
                }

                Item {
                    id: identityZone
                    x: 430 * screen.scaleUnit
                    width: 284 * screen.scaleUnit
                    height: parent.height

                    Rectangle {
                        width: 86 * screen.scaleUnit
                        height: width
                        radius: width / 2
                        x: 36 * screen.scaleUnit
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.raisedColor
                        border.width: 1
                        border.color: "#3dffffff"

                        Image {
                            anchors.fill: parent
                            anchors.margins: 6 * screen.scaleUnit
                            source: config.stringValue("Avatar") || "assets/avatar.png"
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Text {
                        x: 142 * screen.scaleUnit
                        y: 74 * screen.scaleUnit
                        width: identityZone.width - x - (12 * screen.scaleUnit)
                        text: root.recoveryMode ? "RECOVERY" : root.normalUser.toUpperCase()
                        visible: root.recoveryMode || root.normalUser !== ""
                        color: root.foregroundColor
                        font.family: root.fontFamily
                        font.pixelSize: (root.accessibilityMode ? 28 : 25) * screen.scaleUnit
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        x: 142 * screen.scaleUnit
                        y: 78 * screen.scaleUnit
                        text: "USERNAME"
                        visible: !root.recoveryMode && root.normalUser === "" && desktopUsername.text === ""
                        color: root.dimColor
                        font.family: root.fontFamily
                        font.pixelSize: 18 * screen.scaleUnit
                    }

                    TextInput {
                        id: desktopUsername
                        x: 142 * screen.scaleUnit
                        y: 70 * screen.scaleUnit
                        width: identityZone.width - x - (12 * screen.scaleUnit)
                        height: 38 * screen.scaleUnit
                        visible: !root.recoveryMode && root.normalUser === ""
                        color: root.foregroundColor
                        selectionColor: root.accentColor
                        selectedTextColor: root.backgroundColor
                        font.family: root.fontFamily
                        font.capitalization: Font.AllUppercase
                        font.pixelSize: (root.accessibilityMode ? 28 : 25) * screen.scaleUnit
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.typedUser
                        focus: screen.isPrimary && !screen.narrow && visible
                        clip: true
                        onTextChanged: root.typedUser = text
                        KeyNavigation.tab: passwordInput
                        Keys.onReturnPressed: passwordInput.forceActiveFocus()
                        Keys.onEnterPressed: passwordInput.forceActiveFocus()
                    }

                    Rectangle {
                        x: 142 * screen.scaleUnit
                        y: 114 * screen.scaleUnit
                        width: 70 * screen.scaleUnit
                        height: 2 * screen.scaleUnit
                        color: root.accentColor
                    }
                }

                Item {
                    id: authenticationZone
                    x: 736 * screen.scaleUnit
                    width: 654 * screen.scaleUnit
                    height: parent.height

                    Text {
                        x: 28 * screen.scaleUnit
                        y: 47 * screen.scaleUnit
                        text: root.recoveryMode ? "RECOVERY PASSWORD" : "PASSWORD"
                        color: root.mutedColor
                        font.family: root.fontFamily
                        font.pixelSize: rail.metaSize
                        font.letterSpacing: 1.5 * screen.scaleUnit
                    }

                    Rectangle {
                        id: passwordFrame
                        x: 28 * screen.scaleUnit
                        y: 78 * screen.scaleUnit
                        width: authenticationZone.width - (230 * screen.scaleUnit)
                        height: 58 * screen.scaleUnit
                        radius: 4 * screen.scaleUnit
                        color: "#7a0f1115"
                        border.width: passwordInput.activeFocus ? 2 : 1
                        border.color: passwordInput.activeFocus ? root.accentColor : "#5cffffff"

                        TextInput {
                            id: passwordInput
                            anchors.left: parent.left
                            anchors.right: visibilityButton.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 18 * screen.scaleUnit
                            anchors.rightMargin: 10 * screen.scaleUnit
                            height: 42 * screen.scaleUnit
                            color: root.foregroundColor
                            selectionColor: root.accentColor
                            selectedTextColor: root.backgroundColor
                            font.family: root.fontFamily
                            font.pixelSize: (root.accessibilityMode ? 20 : 18) * screen.scaleUnit
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: visibilityButton.revealed ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "•"
                            enabled: !root.authenticating
                            focus: screen.isPrimary && !screen.narrow && root.currentUser() !== ""
                            KeyNavigation.backtab: desktopUsername.visible ? desktopUsername : passwordInput
                            clip: true
                            Keys.onReturnPressed: root.attemptLogin(passwordInput)
                            Keys.onEnterPressed: root.attemptLogin(passwordInput)
                        }

                        Item {
                            id: visibilityButton
                            property bool revealed: false
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 52 * screen.scaleUnit
                            activeFocusOnTab: true

                            Image {
                                width: 22 * screen.scaleUnit
                                height: width
                                anchors.centerIn: parent
                                source: "assets/icons/password-hidden.svg"
                                opacity: visibilityButton.revealed ? 1 : 0.72
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: visibilityButton.revealed = !visibilityButton.revealed
                            }
                            Keys.onReturnPressed: visibilityButton.revealed = !visibilityButton.revealed
                            Keys.onEnterPressed: visibilityButton.revealed = !visibilityButton.revealed
                            Keys.onSpacePressed: visibilityButton.revealed = !visibilityButton.revealed
                        }
                    }

                    Rectangle {
                        id: signInButton
                        x: authenticationZone.width - (184 * screen.scaleUnit)
                        y: 78 * screen.scaleUnit
                        width: 156 * screen.scaleUnit
                        height: 58 * screen.scaleUnit
                        radius: 4 * screen.scaleUnit
                        color: root.authenticating ? "#746fbe" : root.accentColor
                        opacity: passwordInput.text === "" ? 0.55 : 1
                        activeFocusOnTab: passwordInput.text !== "" && !root.authenticating
                        border.width: activeFocus ? 2 : 0
                        border.color: root.foregroundColor

                        Row {
                            anchors.centerIn: parent
                            spacing: 9 * screen.scaleUnit

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.authenticating ? "WAIT" : (root.recoveryMode ? "CONTINUE" : "SIGN IN")
                                color: root.backgroundColor
                                font.family: root.fontFamily
                                font.pixelSize: rail.bodySize
                                font.weight: Font.Medium
                                font.letterSpacing: 1.1 * screen.scaleUnit
                            }

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20 * screen.scaleUnit
                                height: width
                                source: "assets/icons/next.svg"
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: passwordInput.text !== "" && !root.authenticating
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.attemptLogin(passwordInput)
                        }
                        Keys.onReturnPressed: root.attemptLogin(passwordInput)
                        Keys.onEnterPressed: root.attemptLogin(passwordInput)
                        Keys.onSpacePressed: root.attemptLogin(passwordInput)
                    }

                    Text {
                        x: 28 * screen.scaleUnit
                        y: 148 * screen.scaleUnit
                        width: parent.width - (56 * screen.scaleUnit)
                        text: root.statusMessage
                        color: root.statusMessage.indexOf("FAILED") >= 0 || root.statusMessage.indexOf("NOT INSTALLED") >= 0 ?
                            root.dangerColor : root.mutedColor
                        font.family: root.fontFamily
                        font.pixelSize: rail.metaSize
                        elide: Text.ElideRight
                    }
                }

                Item {
                    id: sessionZone
                    x: 1412 * screen.scaleUnit
                    width: 202 * screen.scaleUnit
                    height: parent.height
                    activeFocusOnTab: !root.recoveryMode && root.normalSessionCount() > 1

                    Image {
                        x: 30 * screen.scaleUnit
                        width: 24 * screen.scaleUnit
                        height: width
                        anchors.verticalCenter: parent.verticalCenter
                        source: "assets/icons/session.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        x: 66 * screen.scaleUnit
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - (28 * screen.scaleUnit)
                        text: root.recoveryMode ? root.recoverySession.toUpperCase() : root.sessionLabel(root.selectedSessionIndex)
                        color: root.foregroundColor
                        font.family: root.fontFamily
                        font.pixelSize: rail.bodySize
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.recoveryMode && root.normalSessionCount() > 1
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.selectNextNormalSession()
                    }
                    Keys.onReturnPressed: root.selectNextNormalSession()
                    Keys.onEnterPressed: root.selectNextNormalSession()
                    Keys.onSpacePressed: root.selectNextNormalSession()
                }

                Item {
                    id: clockZone
                    x: 1636 * screen.scaleUnit
                    width: 220 * screen.scaleUnit
                    height: parent.height

                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 5 * screen.scaleUnit

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.formatDateTime(root.now, "HH:mm")
                            color: root.foregroundColor
                            font.family: root.fontFamily
                            font.pixelSize: (root.accessibilityMode ? 30 : 27) * screen.scaleUnit
                            font.weight: Font.Medium
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.formatDateTime(root.now, "ddd  dd  MMM").toUpperCase()
                            color: root.accentColor
                            font.family: root.fontFamily
                            font.pixelSize: rail.metaSize
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5 * screen.scaleUnit

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20 * screen.scaleUnit
                                height: width
                                source: "assets/icons/keyboard.svg"
                                fillMode: Image.PreserveAspectFit
                            }

                            Repeater {
                                model: [{ "code": "gb", "label": "UK" }, { "code": "us", "label": "US" }]

                                Rectangle {
                                    property bool available: root.keyboardLayoutIndex(modelData.code) >= 0
                                    width: 40 * screen.scaleUnit
                                    height: 27 * screen.scaleUnit
                                    radius: 3 * screen.scaleUnit
                                    color: root.keyboardLayoutSelected(modelData.code) ? "#229892e8" : "transparent"
                                    border.width: activeFocus || root.keyboardLayoutSelected(modelData.code) ? 1 : 0
                                    border.color: root.accentColor
                                    opacity: available ? 1 : 0.35
                                    activeFocusOnTab: available

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: root.keyboardLayoutSelected(modelData.code) ? root.foregroundColor : root.mutedColor
                                        font.family: root.fontFamily
                                        font.pixelSize: rail.metaSize
                                        font.weight: Font.Medium
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: parent.available
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.selectKeyboardLayout(modelData.code)
                                    }
                                    Keys.onReturnPressed: root.selectKeyboardLayout(modelData.code)
                                    Keys.onEnterPressed: root.selectKeyboardLayout(modelData.code)
                                    Keys.onSpacePressed: root.selectKeyboardLayout(modelData.code)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.confirmationAction !== ""
                    anchors.fill: parent
                    radius: 28 * screen.scaleUnit
                    color: "#fa08090b"
                    border.width: 0
                    z: 20

                    FrameSurface {
                        anchors.fill: parent
                        opticalScale: screen.scaleUnit
                        motif: "diagnostic-tick"
                        motifAnchor: "bottom"
                        surfaceColor: root.surfaceColor
                        accentColor: root.accentColor
                        dangerColor: root.dangerColor
                        critical: true
                    }

                    Text {
                        x: 42 * screen.scaleUnit
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.confirmationAction === "power" ?
                            "POWER OFF THIS DEVICE?" : "RESTART THIS DEVICE?"
                        color: root.foregroundColor
                        font.family: root.fontFamily
                        font.pixelSize: (root.accessibilityMode ? 21 : 18) * screen.scaleUnit
                        font.weight: Font.Medium
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 38 * screen.scaleUnit
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14 * screen.scaleUnit

                        Rectangle {
                            width: 138 * screen.scaleUnit
                            height: 54 * screen.scaleUnit
                            radius: 4 * screen.scaleUnit
                            color: root.raisedColor
                            border.width: 1
                            border.color: "#52ffffff"
                            activeFocusOnTab: parent.parent.parent.visible

                            Text {
                                anchors.centerIn: parent
                                text: "CANCEL"
                                color: root.foregroundColor
                                font.family: root.fontFamily
                                font.pixelSize: rail.bodySize
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.confirmationAction = ""
                            }
                            Keys.onReturnPressed: root.confirmationAction = ""
                            Keys.onEnterPressed: root.confirmationAction = ""
                            Keys.onSpacePressed: root.confirmationAction = ""
                        }

                        Rectangle {
                            width: 164 * screen.scaleUnit
                            height: 54 * screen.scaleUnit
                            radius: 4 * screen.scaleUnit
                            color: root.dangerColor
                            activeFocusOnTab: parent.parent.parent.visible

                            Text {
                                anchors.centerIn: parent
                                text: "CONFIRM"
                                color: root.backgroundColor
                                font.family: root.fontFamily
                                font.pixelSize: rail.bodySize
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.executeConfirmation()
                            }
                            Keys.onReturnPressed: root.executeConfirmation()
                            Keys.onEnterPressed: root.executeConfirmation()
                            Keys.onSpacePressed: root.executeConfirmation()
                        }
                    }
                }
            }

            Item {
                id: narrowPanel
                visible: screen.isPrimary && screen.narrow
                anchors.centerIn: parent
                width: Math.min(parent.width - 32, 520)
                height: Math.min(parent.height - 32, 650)

                FrameSurface {
                    anchors.fill: parent
                    motif: "identity"
                    surfaceColor: root.surfaceColor
                    accentColor: root.accentColor
                    dangerColor: root.dangerColor
                    focused: narrowPassword.activeFocus
                    attention: root.recoveryMode || root.authenticating
                }

                Text {
                    x: 24
                    y: 22
                    text: root.recoveryMode ? "SENOMY // RECOVERY" : "SENOMY // AUTH"
                    color: root.foregroundColor
                    font.family: root.fontFamily
                    font.pixelSize: root.accessibilityMode ? 18 : 15
                    font.letterSpacing: 1.2
                }

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 76
                    width: 108
                    height: 108
                    source: config.stringValue("Avatar") || "assets/avatar.png"
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 194
                    text: root.recoveryMode ? "RECOVERY" : root.normalUser.toUpperCase()
                    visible: root.recoveryMode || root.normalUser !== ""
                    color: root.foregroundColor
                    font.family: root.fontFamily
                    font.pixelSize: root.accessibilityMode ? 25 : 22
                    font.weight: Font.Medium
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 199
                    text: "USERNAME"
                    visible: !root.recoveryMode && root.normalUser === "" && narrowUsername.text === ""
                    color: root.dimColor
                    font.family: root.fontFamily
                    font.pixelSize: 17
                }

                TextInput {
                    id: narrowUsername
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 190
                    width: parent.width - 96
                    height: 40
                    visible: !root.recoveryMode && root.normalUser === ""
                    horizontalAlignment: TextInput.AlignHCenter
                    color: root.foregroundColor
                    selectionColor: root.accentColor
                    selectedTextColor: root.backgroundColor
                    font.family: root.fontFamily
                    font.capitalization: Font.AllUppercase
                    font.pixelSize: root.accessibilityMode ? 25 : 22
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.typedUser
                    focus: screen.isPrimary && screen.narrow && visible
                    clip: true
                    onTextChanged: root.typedUser = text
                    KeyNavigation.tab: narrowPassword
                    Keys.onReturnPressed: narrowPassword.forceActiveFocus()
                    Keys.onEnterPressed: narrowPassword.forceActiveFocus()
                }

                Text {
                    x: 28
                    y: 250
                    text: root.recoveryMode ? "RECOVERY PASSWORD" : "PASSWORD"
                    color: root.mutedColor
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.letterSpacing: 1.2
                }

                Rectangle {
                    id: narrowSignInButton
                    x: 28
                    y: 278
                    width: parent.width - 56
                    height: 54
                    radius: 4
                    color: root.raisedColor
                    border.width: narrowPassword.activeFocus ? 2 : 1
                    border.color: narrowPassword.activeFocus ? root.accentColor : "#52ffffff"

                    TextInput {
                        id: narrowPassword
                        anchors.fill: parent
                        anchors.margins: 14
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: root.foregroundColor
                        font.family: root.fontFamily
                        font.pixelSize: root.accessibilityMode ? 20 : 17
                        verticalAlignment: TextInput.AlignVCenter
                        focus: screen.isPrimary && screen.narrow && root.currentUser() !== ""
                        KeyNavigation.backtab: narrowUsername.visible ? narrowUsername : narrowPassword
                        Keys.onReturnPressed: root.attemptLogin(narrowPassword)
                        Keys.onEnterPressed: root.attemptLogin(narrowPassword)
                    }
                }

                Rectangle {
                    x: 28
                    y: 348
                    width: parent.width - 56
                    height: 54
                    radius: 4
                    color: root.accentColor
                    opacity: narrowPassword.text === "" ? 0.55 : 1
                    activeFocusOnTab: narrowPassword.text !== "" && !root.authenticating
                    border.width: activeFocus ? 2 : 0
                    border.color: root.foregroundColor

                    Text {
                        anchors.centerIn: parent
                        text: root.recoveryMode ? "CONTINUE" : "SIGN IN"
                        color: root.backgroundColor
                        font.family: root.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: narrowPassword.text !== "" && !root.authenticating
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.attemptLogin(narrowPassword)
                    }
                    Keys.onReturnPressed: root.attemptLogin(narrowPassword)
                    Keys.onEnterPressed: root.attemptLogin(narrowPassword)
                    Keys.onSpacePressed: root.attemptLogin(narrowPassword)
                }

                Text {
                    x: 28
                    y: 418
                    width: parent.width - 56
                    text: root.statusMessage
                    color: root.statusMessage.indexOf("FAILED") >= 0 || root.statusMessage.indexOf("NOT INSTALLED") >= 0 ?
                        root.dangerColor : root.mutedColor
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Row {
                    id: narrowKeyboardRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: narrowUtilityRow.top
                    anchors.bottomMargin: 16
                    spacing: 8

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: width
                        source: "assets/icons/keyboard.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    Repeater {
                        model: [{ "code": "gb", "label": "UK" }, { "code": "us", "label": "US" }]

                        Rectangle {
                            property bool available: root.keyboardLayoutIndex(modelData.code) >= 0
                            width: 72
                            height: 38
                            radius: 4
                            color: root.keyboardLayoutSelected(modelData.code) ? "#229892e8" : root.raisedColor
                            border.width: 1
                            border.color: activeFocus || root.keyboardLayoutSelected(modelData.code) ? root.accentColor : "#38ffffff"
                            opacity: available ? 1 : 0.35
                            activeFocusOnTab: available

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: root.keyboardLayoutSelected(modelData.code) ? root.foregroundColor : root.mutedColor
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: parent.available
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.selectKeyboardLayout(modelData.code)
                            }
                            Keys.onReturnPressed: root.selectKeyboardLayout(modelData.code)
                            Keys.onEnterPressed: root.selectKeyboardLayout(modelData.code)
                            Keys.onSpacePressed: root.selectKeyboardLayout(modelData.code)
                        }
                    }
                }

                Row {
                    id: narrowUtilityRow
                    x: 28
                    y: parent.height - 104
                    width: parent.width - 56
                    spacing: 8

                    Repeater {
                        model: ["ACCESS", root.recoveryMode ? "BACK" : "RECOVER", "RESTART", "POWER"]

                        Rectangle {
                            width: (narrowUtilityRow.width - (narrowUtilityRow.spacing * 3)) / 4
                            height: 52
                            radius: 4
                            color: root.raisedColor
                            border.width: 1
                            border.color: activeFocus || modelData === "RECOVER" || modelData === "BACK" ? root.accentColor : "#38ffffff"
                            activeFocusOnTab: true

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: root.mutedColor
                                font.family: root.fontFamily
                                font.pixelSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateUtility(modelData, narrowPassword)
                            }
                            Keys.onReturnPressed: root.activateUtility(modelData, narrowPassword)
                            Keys.onEnterPressed: root.activateUtility(modelData, narrowPassword)
                            Keys.onSpacePressed: root.activateUtility(modelData, narrowPassword)
                        }
                    }
                }

                Rectangle {
                    visible: root.confirmationAction !== ""
                    anchors.fill: parent
                    radius: 28
                    color: "#fa08090b"
                    border.width: 0
                    z: 20

                    FrameSurface {
                        anchors.fill: parent
                        motif: "diagnostic-tick"
                        motifAnchor: "bottom"
                        surfaceColor: root.surfaceColor
                        accentColor: root.accentColor
                        dangerColor: root.dangerColor
                        critical: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 178
                        text: root.confirmationAction === "power" ? "POWER OFF THIS DEVICE?" : "RESTART THIS DEVICE?"
                        color: root.foregroundColor
                        font.family: root.fontFamily
                        font.pixelSize: root.accessibilityMode ? 20 : 17
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 248
                        spacing: 12

                        Rectangle {
                            width: 150
                            height: 54
                            radius: 4
                            color: root.raisedColor
                            border.width: activeFocus ? 2 : 1
                            border.color: activeFocus ? root.accentColor : "#52ffffff"
                            activeFocusOnTab: parent.parent.visible

                            Text {
                                anchors.centerIn: parent
                                text: "CANCEL"
                                color: root.foregroundColor
                                font.family: root.fontFamily
                                font.pixelSize: 14
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.confirmationAction = ""
                            }
                            Keys.onReturnPressed: root.confirmationAction = ""
                            Keys.onEnterPressed: root.confirmationAction = ""
                            Keys.onSpacePressed: root.confirmationAction = ""
                        }

                        Rectangle {
                            width: 150
                            height: 54
                            radius: 4
                            color: root.dangerColor
                            border.width: activeFocus ? 2 : 0
                            border.color: root.foregroundColor
                            activeFocusOnTab: parent.parent.visible

                            Text {
                                anchors.centerIn: parent
                                text: "CONFIRM"
                                color: root.backgroundColor
                                font.family: root.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.executeConfirmation()
                            }
                            Keys.onReturnPressed: root.executeConfirmation()
                            Keys.onEnterPressed: root.executeConfirmation()
                            Keys.onSpacePressed: root.executeConfirmation()
                        }
                    }
                }
            }
        }
    }
}
