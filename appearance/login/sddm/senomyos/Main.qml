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
    property bool sessionStarting:false
    property bool userChooserOpen:false
    property var activePasswordItem:null
    property var accountModel:userModel
    readonly property bool canPowerOff:sddm.canPowerOff===true
    readonly property bool canReboot:sddm.canReboot===true
    readonly property bool capsLock:keyboard.capsLock===true
    readonly property var account:selectedAccount(normalUser)
    readonly property string accountDisplayName:account.realName || normalUser || typedUser
    readonly property string accountIcon:account.icon || ""
    readonly property string fallbackAvatar:config.stringValue("Avatar") || "assets/avatar.png"
    signal credentialsReset()
    signal focusCredentialsRequested()
    onUserChooserOpenChanged:if(userChooserOpen)credentialsReset();else Qt.callLater(()=>focusCredentialsRequested())
    onNormalUserChanged:credentialsReset()
    onTypedUserChanged:credentialsReset()
    onConfirmationActionChanged:if(confirmationAction!=="")credentialsReset()
    Keys.onEscapePressed:event=>{
        if(confirmationAction!==""){confirmationAction="";event.accepted=true;}
        else if(userChooserOpen){userChooserOpen=false;event.accepted=true;}
        else event.accepted=false;
    }
    function selectedAccount(name) {
        if(typeof userModel.count!=="number" || typeof userModel.data!=="function")return {};
        // SDDM 0.21 UserModel: NameRole=257, RealNameRole=258, IconRole=260.
        for(var i=0;i<userModel.count;i++) {
            var row=userModel.index(i,0);
            if(String(userModel.data(row,257))===name) {
                var icon=String(userModel.data(row,260) || "");
                return {realName:String(userModel.data(row,258) || ""),icon:icon.indexOf("file:///")===0?icon:""};
            }
        }
        return {};
    }
    function selectAccount(name) {
        if(authenticating || name===recoveryUser)return false;
        normalUser=String(name);typedUser="";userChooserOpen=false;statusMessage="";
        credentialsReset();Qt.callLater(()=>focusCredentialsRequested());return true;
    }
    function keyboardLayoutLabel() {
        var layouts=keyboard.layouts || [];
        return layouts.length && layouts[keyboard.currentLayout] ? String(layouts[keyboard.currentLayout].shortName).toUpperCase() : "UNAVAILABLE";
    }
    function selectNextKeyboardLayout() {
        if(authenticating || keyboardLayoutCount()<2)return;
        keyboard.currentLayout=(keyboard.currentLayout+1)%keyboardLayoutCount();
    }
    property bool recoveryMode: false
    property bool accessibilityMode: false
    property string statusMessage: ""
    property string confirmationAction: ""
    property string normalUser: userModel.lastUser || config.stringValue("PreviewUser") || ""
    property string typedUser: ""
    property string normalSessionKey: ""
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
        normalSessionKey = sessionKey(normalSessionIndex)
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
        if (recoveryMode || authenticating)
            return
        var next = nextNormalSessionIndex(selectedSessionIndex)
        if (next >= 0) {
            normalSessionIndex = next
            selectedSessionIndex = next
            normalSessionKey = sessionKey(next)
            statusMessage = "SESSION // " + sessionLabel(next)
        }
    }

    function sessionKey(index) {
        if(index<0 || index>=sessionCount())return "";
        const row=sessionModel.index(index,0);
        // SDDM 0.21: directory/file/type roles keep X11/Wayland identities distinct.
        return [257,258,259].map(role=>String(sessionModel.data(row,role) || "")).join("|");
    }
    function selectNormalSession(index) {
        if(authenticating || recoveryMode || index<0 || index>=sessionCount() || sessionIsRecovery(index))return false;
        normalSessionIndex=index;selectedSessionIndex=index;normalSessionKey=sessionKey(index);statusMessage="";return true;
    }
    function keyboardLayoutCurrentIndex(){return keyboard.currentLayout;}
    function keyboardLayoutName(index) {
        const item=(keyboard.layouts || [])[index];return item?String(item.longName || item.shortName).replace(/_/g," "):"Unavailable";
    }
    function selectKeyboardIndex(index) {
        if(authenticating || index<0 || index>=keyboardLayoutCount())return false;
        keyboard.currentLayout=index;statusMessage="";return true;
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
        return recoveryMode ? recoveryUser : (normalUser !== "" ? normalUser : typedUser.trim())
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
        if(authenticating)return;
        userChooserOpen=false;credentialsReset();
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
        if (authenticating || userChooserOpen || confirmationAction!=="" || currentUser() === "" || passwordItem.text === "")
            return
        if (!recoveryMode) {
            if(normalSessionKey) {
                let exact=-1;
                for(let i=0;i<sessionCount();i++)if(!sessionIsRecovery(i) && sessionKey(i)===normalSessionKey){exact=i;break;}
                if(exact<0){statusMessage="Selected session is no longer available. Choose another session.";credentialsReset();return;}
                selectedSessionIndex=exact;normalSessionIndex=exact;
            } else resetNormalSession();
            if(selectedSessionIndex<0 || sessionIsRecovery(selectedSessionIndex)) {
                statusMessage="No desktop session is available.";credentialsReset();return;
            }
        } else if(selectedSessionIndex<0 || !sessionIsRecovery(selectedSessionIndex)) {
            statusMessage="Recovery session is no longer available.";credentialsReset();return;
        }
        if(!recoveryMode && currentUser()===recoveryUser) {
            statusMessage="USE RECOVER FOR THE SEPARATE RECOVERY ACCOUNT";return;
        }
        activePasswordItem=passwordItem;
        authenticating = true
        statusMessage = recoveryMode ? "OPENING RESTRICTED RECOVERY" : "Signing in…"
        try { sddm.login(currentUser(), passwordItem.text, selectedSessionIndex); }
        catch(error) { authenticating=false;statusMessage="Sign-in could not start. Please try again."; }
        finally { credentialsReset(); }
    }

    function executeConfirmation() {
        if(authenticating)return;
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
            root.sessionStarting=true
            root.authenticating=true
            root.credentialsReset()
            root.statusMessage = "Starting session…"
        }

        function onLoginFailed() {
            root.authenticating = false
            root.sessionStarting=false
            root.credentialsReset()
            if(root.activePasswordItem)Qt.callLater(()=>{if(root.activePasswordItem && root.activePasswordItem.visible && root.confirmationAction==="" && !root.userChooserOpen)root.activePasswordItem.forceActiveFocus();})
            root.statusMessage = root.recoveryMode ?
                "Recovery sign-in failed. Try again." : "Sign-in failed. Check your password and try again."
        }

        function onInformationMessage(message) {
            root.statusMessage = String(message).slice(0,256)
        }
    }

    FontLoader { id: headingFace; source: "assets/fonts/BrunoAceSC-Regular.ttf" }
    readonly property bool headingFontReady: headingFace.status === FontLoader.Ready
    readonly property string headingFont: headingFace.status === FontLoader.Ready ? headingFace.name : Theme.headingFont
    Repeater {
        model: screenModel
        Item {
            id: screen
            x: geometry.x; y: geometry.y; width: geometry.width; height: geometry.height
            readonly property bool controlsVisible: width > 0 && height > 0
            // Per-output views remain usable; no cross-runtime focus ownership added.
            AuthBackdrop {
                anchors.fill:parent
                source:config.stringValue("Background") || "assets/background-source.png"
                fallbackSource:config.stringValue("BlurredBackground") || "assets/background.png"
                blurAmount:{const v=parseFloat(config.stringValue("BackgroundBlur"));return isFinite(v)?v:0.85;}
                scrimOpacity:{const v=parseFloat(config.stringValue("BackgroundScrim"));return isFinite(v)?v:0.34;}
                readable:root.accessibilityMode
            }
            CompactLogin { id: login; anchors.fill: parent; controller: root; visible: screen.controlsVisible }
            AccountPicker { anchors.fill: parent; controller: root }
            Connections {
                target: root
                function onCredentialsReset() { login.clearCredentials(); }
                function onFocusCredentialsRequested() { login.focusCredentials(); }
            }
        }
    }
}
