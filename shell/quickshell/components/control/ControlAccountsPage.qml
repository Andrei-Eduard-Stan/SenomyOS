import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import ".."
import "../../config" as Config

FocusScrollArea {
    id:root
    property var service:null
    property int selectedUid:service && Number.isInteger(service.snapshot.currentUid)?service.snapshot.currentUid:-1
    readonly property var selected:service?service.accounts.find(a=>a.uid===selectedUid) || null:null
    readonly property bool locked:!!service && service.locked
    readonly property bool canEditSelected:!!service && service.available && !!selected && selected.managed===true && !locked
    property int draftUid:-1
    property string nameDraft:""
    property string baselineName:""
    property int deferredAccount:-1
    property bool showProvider:false
    property bool showAdministration:false
    property bool showAvatarPath:false
    property string avatarError:""
    property bool inspecting:false
    property bool inspectorStarted:false
    property var avatarInfo:({})
    readonly property bool dirty:!!service && (nameDraft!==baselineName || avatar.text.length>0 || newUser.text.length>0)
    function syncName() {
        if(!selected)return;
        if(draftUid!==selected.uid || nameDraft===baselineName || nameDraft===selected.name) {
            draftUid=selected.uid;baselineName=selected.name;nameDraft=selected.name;
        }
    }
    function load() {draftUid=-1;baselineName=selected?selected.name:"";nameDraft=baselineName;syncName();avatar.text="";newUser.text="";deferredAccount=-1;if(service && service.actionState==="pending")service.cancel();}
    function selectAccount(uid) {if(uid===selectedUid)return;if(dirty){deferredAccount=uid;return;}selectedUid=uid;showAdministration=false;}
    function chooseAvatar(url) {
        const value=String(url);
        if(!value.startsWith("file:///")){avatarError="Choose an image stored on this computer.";return false;}
        try {
            const path=decodeURIComponent(value.slice(7));
            if(/[\u0000-\u001f]/.test(path))throw new Error();
            avatar.text=path;return true;
        } catch(e) {avatarError="The selected file path is invalid.";return false;}
    }
    onSelectedChanged:syncName()
    onVisibleChanged:if(!visible)avatarPicker.close()
    Connections {
        target:root.service
        function onActionStateChanged(){
            if(root.service.actionState!=="succeeded")return;
            if(root.service.operation==="create")newUser.text="";
            if(root.service.operation==="avatar")avatar.text="";
        }
    }
    FileDialog {
        id:avatarPicker
        title:"Choose an account picture"
        parentWindow:root.Window.window
        nameFilters:["PNG images (*.png *.PNG)"]
        fileMode:FileDialog.OpenFile
        onAccepted:{root.chooseAvatar(selectedFile);if(root.visible)pictureButton.forceActiveFocus();}
        onRejected:if(root.visible)pictureButton.forceActiveFocus()
    }
    Timer {
        id:inspectTimer;interval:200
        onTriggered:if(avatar.text && !inspector.running && !root.inspecting){root.inspecting=true;root.inspectorStarted=false;inspector.checkedPath=avatar.text;inspector.exec(["python3",Quickshell.shellDir+"/scripts/account-settings.py","avatar-info",avatar.text]);}
    }
    Process {
        id:inspector
        property string checkedPath:""
        stdout:StdioCollector {}
        onStarted:root.inspectorStarted=true
        onExited:(code,status)=>{
            root.inspecting=false;
            if(checkedPath!==avatar.text){if(avatar.text)inspectTimer.restart();return;}
            try {
                const result=JSON.parse(stdout.text);
                if(code===0 && result.path===avatar.text && result.ok===true){root.avatarInfo=result;root.avatarError="";}
                else if(avatar.text)root.avatarError=code!==0&&result.ok===true?"Picture validator exited unsuccessfully.":result.message || "This picture could not be verified.";
            } catch(e) {if(avatar.text)root.avatarError="Picture validation failed. Choose another PNG image.";}
            if(avatar.text && !root.avatarInfo.path && !root.avatarError)inspectTimer.restart();
        }
    }
    Timer {
        interval:200;running:root.inspecting&&!root.inspectorStarted&&!inspector.running
        onTriggered:{root.inspecting=false;root.avatarError="Picture validator could not start. Check Python before choosing another PNG.";}
    }
    contentHeight:column.implicitHeight
    ScrollBar.vertical:ShellScrollBar {}
    clip:true
    Column {
        id:column;width:parent.width;spacing:16
        Text {width:parent.width;text:"Manage the people who use this computer.";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
        Text {visible:!root.service || !root.service.available;width:parent.width;text:"Account changes are unavailable. You can still review the accounts below.";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.Theme.warning;wrapMode:Text.WordWrap}
        Text {visible:!!root.service && root.service.available && root.service.snapshot.complete!==true;width:parent.width;text:root.service?root.service.snapshot.message:"";textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.Theme.warning;wrapMode:Text.WordWrap}
        ControlWorkspaceButton {
            width:parent.width;text:"Set up account management…"
            visible:!!root.service && !root.service.available
            enabled:!!root.service && root.service.snapshot.providerSetupAvailable===true && !root.locked
            onClicked:root.service.request("setup",null,"")
        }
        Text {width:parent.width;text:"Choose an account";font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
        Flow {width:parent.width;spacing:8
        Repeater {
            model:root.service?root.service.accounts:[]
            ControlWorkspaceButton {
                required property var modelData
                width:Math.min(parent.width,Math.max(160,Math.ceil(minimumContentWidth)));centered:false
                text:(modelData.name || modelData.username)+(modelData.current?" · You":"")
                accessibleLabel:text+". "+modelData.username+" · "+(modelData.administrator===null?"Account type unavailable":modelData.administrator?"Administrator":"Standard")+(modelData.locked===true?" · Locked":"")+(modelData.signedIn?" · Signed in":"")
                active:root.selectedUid===modelData.uid;enabled:!root.locked
                onClicked:root.selectAccount(modelData.uid)
            }
        }
        }
        Column {
            width:parent.width;spacing:8;visible:root.deferredAccount>=0
            Text {width:parent.width;text:"Keep editing, or discard these changes before selecting another account.";textFormat:Text.PlainText;color:Config.Theme.warning;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;wrapMode:Text.WordWrap}
            Flow {
                width:parent.width;spacing:8
                ControlWorkspaceButton {width:Math.min(180,parent.width);text:"Keep editing";onClicked:root.deferredAccount=-1}
                ControlWorkspaceButton {width:Math.min(200,parent.width);text:"Discard & select";onClicked:{const uid=root.deferredAccount;root.load();root.selectedUid=uid;}}
            }
        }
        Column {
            width:parent.width;spacing:12;visible:!!root.selected
            Text {width:parent.width;text:root.selected?(root.selected.name || root.selected.username):"Profile";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Math.round(20*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.ink}
            Row {
                width:parent.width;spacing:16
                Rectangle {
                    width:72;height:72;color:Config.DirectoryStyle.selection
                    Image {
                        anchors.fill:parent;anchors.margins:4
                        source:root.avatarInfo.path?"file://"+encodeURI(root.avatarInfo.path).replace(/#/g,"%23").replace(/\?/g,"%3F"):(root.selected && root.selected.avatar?"file://"+encodeURI(root.selected.avatar).replace(/#/g,"%23").replace(/\?/g,"%3F"):"")
                        sourceSize:Qt.size(72,72);asynchronous:true;fillMode:Image.PreserveAspectFit
                        Accessible.name:"Account picture preview"
                        onStatusChanged:if(status===Image.Error && root.avatarInfo.path){root.avatarInfo=({});root.avatarError="This PNG could not be decoded. Choose another picture.";}
                        Text {anchors.centerIn:parent;visible:parent.status!==Image.Ready;text:root.selected?String(root.selected.name || root.selected.username).slice(0,1).toUpperCase():"";color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:28}
                    }
                }
                ControlWorkspaceButton {id:pictureButton;objectName:"account-picture-choose";width:Math.max(1,Math.min(220,parent.width-88));anchors.verticalCenter:parent.verticalCenter;text:"Choose picture…";enabled:root.canEditSelected;onClicked:avatarPicker.open()}
            }
            Text {width:parent.width;text:root.inspecting?"Checking picture…":root.avatarError || (root.avatarInfo.path?root.avatarInfo.path.split("/").pop()+" · ready to review":"Choose a PNG image up to 2048 × 2048 pixels and 4 MiB.");textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:root.avatarError?Config.Theme.warning:Config.DirectoryStyle.muted;wrapMode:Text.WrapAnywhere;Accessible.role:Accessible.StaticText}
            Flow {
                width:parent.width;spacing:8;visible:avatar.text.length>0
                ControlWorkspaceButton {width:Math.min(180,parent.width);text:"Review picture";enabled:root.canEditSelected && root.avatarInfo.path===avatar.text && !root.inspecting;onClicked:root.service.request("avatar",root.selected,avatar.text)}
                ControlWorkspaceButton {width:Math.min(150,parent.width);text:"Clear selection";enabled:!root.locked;onClicked:avatar.text=""}
            }
            ControlWorkspaceButton {width:Math.min(200,parent.width);text:root.showAvatarPath?"Hide image path":"Enter image path…";onClicked:root.showAvatarPath=!root.showAvatarPath}
            ControlWorkspaceSearch {
                id:avatar;objectName:"account-avatar-path";visible:root.showAvatarPath;width:parent.width;placeholderText:"Local PNG image path"
                Accessible.name:"Account picture file path";enabled:root.canEditSelected
                onTextChanged:{root.avatarInfo=({});root.avatarError="";inspectTimer.restart();}
            }
            Text {text:"Display name";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
            ControlWorkspaceSearch {
                id:displayName;width:parent.width;objectName:"account-display-name"
                text:root.nameDraft;onTextEdited:root.nameDraft=text
                placeholderText:"Name shown at login";Accessible.name:"Account display name"
                enabled:root.canEditSelected
            }
            Flow {
                width:parent.width;spacing:8
                ControlWorkspaceButton {width:Math.min(200,parent.width);text:"Review name change";enabled:root.canEditSelected && displayName.text.trim().length>0 && !!root.selected && displayName.text!==root.selected.name;onClicked:root.service.request("name",root.selected,displayName.text)}
                ControlWorkspaceButton {width:Math.min(180,parent.width);text:"Discard form edits";enabled:root.dirty && !root.locked;onClicked:root.load()}
            }
            Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
            Text {text:"Password";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:18;font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
            Text {width:parent.width;text:"A secure system terminal handles your current and new password.";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
            ControlWorkspaceButton {width:Math.min(260,parent.width);text:"Change password…";enabled:!!root.service && root.service.snapshot.passwordAvailable===true && !!root.selected && (root.selected.current || root.service.snapshot.administrativePasswordAvailable===true) && !root.locked;onClicked:root.service.request("password",root.selected,"")}
        }
        ControlWorkspaceButton {width:parent.width;text:root.showAdministration?"Hide account administration":"Account administration…";active:root.showAdministration;onClicked:root.showAdministration=!root.showAdministration}
        Column {
            width:parent.width;spacing:12;visible:root.showAdministration
            Text {width:parent.width;text:"Account changes require review and system authorization. Removal retains home files.";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
            Flow {
                width:parent.width;spacing:8;visible:!!root.selected && !root.selected.current
                ControlWorkspaceButton {width:Math.min(210,parent.width);text:root.selected && root.selected.locked?"Unlock account…":"Lock account…";enabled:!!root.service && root.service.available && root.service.snapshot.complete && !!root.selected && !root.selected.current && (!root.selected.signedIn || root.selected.locked===true) && !root.locked;onClicked:root.service.request("lock",root.selected,root.selected.locked?"false":"true")}
                ControlWorkspaceButton {width:Math.min(210,parent.width);text:root.selected && root.selected.administrator?"Make standard…":"Make administrator…";enabled:!!root.service && root.service.available && root.service.snapshot.complete && !!root.selected && !root.selected.current && (!root.selected.signedIn || !root.selected.administrator) && !root.locked;onClicked:root.service.request("type",root.selected,root.selected.administrator?"0":"1")}
                ControlWorkspaceButton {width:Math.min(250,parent.width);text:"Remove account…";accentColor:Config.Theme.danger;enabled:!!root.service && root.service.available && root.service.snapshot.complete && !!root.selected && !root.selected.current && !root.selected.signedIn && !root.locked;onClicked:root.service.request("remove",root.selected,"")}
            }
            Text {width:parent.width;visible:!!root.selected && root.selected.current;text:"Your active account cannot be locked, removed or demoted here.";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
            Text {text:"Add a standard account";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
            ControlWorkspaceSearch {id:newUser;width:parent.width;placeholderText:"New username";Accessible.name:"New standard account username";enabled:!!root.service && root.service.available && root.service.snapshot.complete && !root.locked}
            ControlWorkspaceButton {width:Math.min(220,parent.width);text:"Review new account";enabled:!!root.service && root.service.available && root.service.snapshot.complete && !root.locked && /^[a-z_][a-z0-9_-]{0,30}$/.test(newUser.text);onClicked:root.service.request("create",null,newUser.text)}
        }
        Column {
            width:parent.width;spacing:10;visible:!!root.service && root.service.actionState!=="idle"
            ConfirmationFocus {view:parent;actions:root.service;cancelButton:cancel}
            Text {width:parent.width;text:root.service?root.service.operation.toUpperCase()+" · "+(root.service.target?root.service.target.username:root.service.proposed):"";textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink;wrapMode:Text.WordWrap}
            Text {width:parent.width;text:root.service?root.service.message:"";textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.Theme.warning;wrapMode:Text.WordWrap}
            Text {width:parent.width;visible:!!root.service && root.service.actionState==="pending" && ["name","avatar","type","lock"].includes(root.service.operation);text:root.service?"Requested: "+root.service.proposed:"";textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink;wrapMode:Text.WrapAnywhere}
            Flow {
                width:parent.width;spacing:8;visible:!!root.service && root.service.actionState==="pending"
                ControlWorkspaceButton {id:cancel;width:Math.min(160,parent.width);text:"Cancel";onClicked:root.service.cancel()}
                ControlWorkspaceButton {width:Math.min(200,parent.width);text:"Confirm change";onClicked:root.service.confirm()}
            }
        }
        Flow {
            width:parent.width;spacing:8
            ControlWorkspaceButton {width:Math.min(180,parent.width);text:root.service && root.service.loading?"Refreshing…":"Refresh accounts";enabled:!!root.service && !root.service.loading && !root.locked;onClicked:root.service.refresh()}
            ControlWorkspaceButton {width:Math.min(180,parent.width);text:root.showProvider?"Hide technical details":"Technical details";active:root.showProvider;onClicked:root.showProvider=!root.showProvider}
        }
        Text {visible:root.showProvider;width:parent.width;text:(root.service?root.service.snapshot.message:"Account provider unavailable")+". Authentication and passwords remain with the system provider and PAM.";textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
    }
}
