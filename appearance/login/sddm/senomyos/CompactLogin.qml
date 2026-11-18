import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

FocusScope {
    id:root
    required property var controller
    property alias passwordItem:password
    property bool revealed:false
    property string choiceKind:""
    readonly property real textScale:controller.accessibilityMode?1.18:1
    readonly property int safe:width<500?16:32
    function clearCredentials(){password.text="";revealed=false;}
    function focusCredentials(){if(controller.confirmationAction!=="" || controller.userChooserOpen || controller.authenticating)return;if(username.visible)username.forceActiveFocus();else password.forceActiveFocus();revealFocused();}
    function ensureVisible(item){
        choices.forceLayout();options.forceLayout();form.forceLayout();stack.forceLayout();
        const p=item.mapToItem(scroll.contentItem,0,0),safe=8;
        const maximum=Math.max(0,scroll.contentHeight-scroll.height);
        if(p.y<scroll.contentY+safe)scroll.contentY=Math.max(0,p.y-safe);
        else if(p.y+item.height>scroll.contentY+scroll.height-safe)scroll.contentY=Math.min(maximum,p.y+item.height-scroll.height+safe);
    }
    function revealOptions(){Qt.callLater(()=>{choices.forceLayout();options.forceLayout();form.forceLayout();stack.forceLayout();root.ensureVisible(options);});}
    function revealFocused(){Qt.callLater(()=>{if(password.activeFocus)ensureVisible(password);else if(username.activeFocus)ensureVisible(username);});}
    onWidthChanged:revealFocused()
    onHeightChanged:revealFocused()
    onTextScaleChanged:revealFocused()
    onVisibleChanged:if(visible)Qt.callLater(()=>focusCredentials())
    Component.onCompleted:Qt.callLater(()=>focusCredentials())
    Keys.onEscapePressed:event=>{if(choiceKind!==""){choiceKind="";event.accepted=true;}else event.accepted=false;}
    Row {
        x:root.safe;y:20;spacing:10
        Image {width:24;height:32;source:"assets/senomyos-mark.png";fillMode:Image.PreserveAspectFit}
        Text {height:32;text:"SenomyOS";font.family:controller.headingFont;font.pixelSize:17;color:Theme.foreground;verticalAlignment:Text.AlignVCenter}
    }
    Flickable {
        id:scroll
        objectName:"credential-viewport"
        onHeightChanged:root.revealFocused()
        onContentHeightChanged:root.revealFocused()
        anchors.fill:parent;anchors.leftMargin:root.safe;anchors.rightMargin:root.safe;anchors.topMargin:68;anchors.bottomMargin:20
        contentWidth:width;contentHeight:Math.max(height,stack.implicitHeight)
        boundsBehavior:Flickable.StopAtBounds;clip:true
        enabled:controller.confirmationAction==="" && !controller.userChooserOpen
        ScrollBar.vertical:ScrollBar {policy:scroll.contentHeight>scroll.height?ScrollBar.AsNeeded:ScrollBar.AlwaysOff}
        Column {
            id:stack;onImplicitHeightChanged:root.revealFocused();width:Math.min(480,scroll.width);x:(scroll.width-width)/2;y:Math.max(0,(scroll.height-implicitHeight)/2);spacing:12
            Column {
                width:parent.width;spacing:4
                Text {width:parent.width;text:Qt.formatDateTime(controller.now,"HH:mm");color:Theme.foreground;font.family:Theme.valueFont;font.pixelSize:(root.height<600?34:52)*root.textScale;horizontalAlignment:Text.AlignHCenter}
                Text {width:parent.width;text:Qt.formatDateTime(controller.now,"dddd, d MMMM");color:Theme.foreground;font.family:Theme.bodyFont;font.pixelSize:14*root.textScale;horizontalAlignment:Text.AlignHCenter}
            }
            Item {width:1;height:8}
            Item {
                id:card;objectName:"authentication-surface";width:parent.width;height:form.implicitHeight+40
                FrameSurface {anchors.fill:parent;surfaceColor:controller.accessibilityMode?"#f4080a0c":"#a6080a0c";artwork:!controller.accessibilityMode;critical:controller.statusMessage.toLowerCase().indexOf("failed")>=0}
                Column {
                    id:form;x:20;y:20;width:parent.width-40;spacing:14
                    Column {
                        width:parent.width;spacing:2
                        Text {width:parent.width;text:controller.recoveryMode?"Account recovery":controller.accountDisplayName || "Other account";textFormat:Text.PlainText;wrapMode:Text.Wrap;font.family:controller.headingFont;font.pixelSize:21*root.textScale;color:Theme.foreground}
                        GreeterButton {objectName:"compact-account-picker";height:36;width:parent.width;padding:4;quiet:true;alignment:Text.AlignLeft;fontPixelSize:13*root.textScale;text:controller.recoveryMode?"Separate recovery credential":"Change account";enabled:!controller.recoveryMode && !controller.authenticating;onClicked:{root.choiceKind="";controller.userChooserOpen=true;}}
                    }
                    GreeterField {
                        id:username;objectName:"compact-username";width:parent.width
                        visible:!controller.recoveryMode && controller.normalUser===""
                        text:controller.typedUser;onTextEdited:controller.typedUser=text
                        placeholderText:"Username";Accessible.name:"Username"
                        enabled:!controller.authenticating;font.pixelSize:17*root.textScale
                        KeyNavigation.tab:password;onActiveFocusChanged:if(activeFocus)root.ensureVisible(this)
                        Keys.onReturnPressed:password.forceActiveFocus();Keys.onEnterPressed:password.forceActiveFocus()
                    }
                    Row {
                        width:parent.width;spacing:8
                        Text {width:parent.width-(caps.visible?caps.implicitWidth+8:0);text:controller.recoveryMode?"Recovery password":"Password";font.family:Theme.bodyFont;font.pixelSize:14*root.textScale;color:Theme.foreground}
                        Text {id:caps;visible:controller.capsLock;text:"Caps Lock on";font.family:Theme.bodyFont;font.pixelSize:13*root.textScale;color:Theme.warning}
                    }
                    Item {
                        width:parent.width;height:56
                        GreeterField {
                            id:password;objectName:"compact-password";anchors.fill:parent;rightPadding:70
                            echoMode:root.revealed?TextInput.Normal:TextInput.Password;passwordCharacter:"•"
                            inputMethodHints:Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText
                            font.pixelSize:18*root.textScale;enabled:!controller.authenticating;warning:controller.capsLock
                            Accessible.name:controller.recoveryMode?"Recovery password":"Password"
                            onActiveFocusChanged:if(activeFocus)root.ensureVisible(this)
                            Keys.onReturnPressed:controller.attemptLogin(password);Keys.onEnterPressed:controller.attemptLogin(password)
                        }
                        GreeterButton {id:reveal;objectName:"compact-reveal";anchors.right:parent.right;anchors.rightMargin:4;anchors.verticalCenter:parent.verticalCenter;width:60;height:48;quiet:true;fontPixelSize:13;text:root.revealed?"Hide":"Show";enabled:!controller.authenticating;onClicked:root.revealed=!root.revealed;onActiveFocusChanged:if(activeFocus)root.ensureVisible(this)}
                    }
                    GreeterButton {
                        objectName:"compact-sign-in";width:parent.width;height:52;highlighted:true;fontPixelSize:16*root.textScale
                        text:controller.authenticating?(controller.sessionStarting?"Starting session…":"Signing in…"):controller.recoveryMode?"Continue to recovery":"Sign in"
                        enabled:!controller.authenticating && controller.currentUser()!=="" && password.text!==""
                        onClicked:controller.attemptLogin(password);onActiveFocusChanged:if(activeFocus)root.ensureVisible(this)
                    }
                    Text {objectName:"compact-status";width:parent.width;visible:text!=="";text:controller.statusMessage;textFormat:Text.PlainText;wrapMode:Text.Wrap;color:text.toLowerCase().indexOf("failed")>=0?Theme.danger:Theme.muted;font.family:Theme.bodyFont;font.pixelSize:14*root.textScale;Accessible.role:Accessible.StaticText}
                    Rectangle {width:parent.width;height:1;color:"#40626b78"}
                    Row {
                        width:parent.width;spacing:8
                        GreeterButton {objectName:"compact-session";width:(parent.width-8)/2;height:64;selected:root.choiceKind==="session";fontPixelSize:13*root.textScale;text:"Session\n"+controller.sessionName(controller.selectedSessionIndex);enabled:!controller.authenticating && !controller.recoveryMode && controller.normalSessionCount()>1;onClicked:{root.choiceKind=root.choiceKind==="session"?"":"session";root.revealOptions();} onActiveFocusChanged:if(activeFocus)root.ensureVisible(this)}
                        GreeterButton {objectName:"compact-layout";width:(parent.width-8)/2;height:64;selected:root.choiceKind==="layout";fontPixelSize:13*root.textScale;text:"Keyboard\n"+controller.keyboardLayoutLabel();enabled:!controller.authenticating && controller.keyboardLayoutCount()>1;onClicked:{root.choiceKind=root.choiceKind==="layout"?"":"layout";root.revealOptions();} onActiveFocusChanged:if(activeFocus)root.ensureVisible(this)}
                    }
                    Column {
                        id:options;objectName:"greeter-inline-choices";width:parent.width;spacing:8;visible:root.choiceKind!==""
                        Row {width:parent.width
                            Text {width:parent.width-72;height:48;text:root.choiceKind==="session"?"Choose session":"Choose keyboard layout";font.family:Theme.bodyFont;font.pixelSize:14*root.textScale;color:Theme.foreground;verticalAlignment:Text.AlignVCenter;wrapMode:Text.Wrap}
                            GreeterButton {width:72;height:48;quiet:true;text:"Close";onClicked:root.choiceKind=""}
                        }
                        Flickable {
                            width:parent.width;height:Math.min(184,choices.implicitHeight);contentWidth:width;contentHeight:choices.implicitHeight;clip:true;boundsBehavior:Flickable.StopAtBounds
                            ScrollBar.vertical:ScrollBar {}
                            Column {id:choices;width:parent.width-10;spacing:4
                                Repeater {
                                    model:root.choiceKind==="session"?controller.sessionCount():controller.keyboardLayoutCount()
                                    GreeterButton {
                                        required property int index
                                        objectName:root.choiceKind==="session"?"session-choice-"+index:"layout-choice-"+index
                                        width:choices.width;height:52;alignment:Text.AlignLeft
                                        visible:root.choiceKind!=="session" || !controller.sessionIsRecovery(index)
                                        selected:root.choiceKind==="session"?index===controller.selectedSessionIndex:index===controller.keyboardLayoutCurrentIndex()
                                        text:root.choiceKind==="session"?controller.sessionName(index):controller.keyboardLayoutName(index)
                                        fontPixelSize:14*root.textScale
                                        onClicked:{if(root.choiceKind==="session")controller.selectNormalSession(index);else controller.selectKeyboardIndex(index);root.choiceKind="";password.forceActiveFocus();}
                                        onActiveFocusChanged:if(activeFocus){const list=parent.parent;const p=mapToItem(list.contentItem,0,0);if(p.y<list.contentY)list.contentY=p.y;else if(p.y+height>list.contentY+list.height)list.contentY=p.y+height-list.height;root.ensureVisible(options);}
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Grid {
                width:parent.width;columns:width<400?2:4;spacing:4
                Repeater {
                    model:["ACCESS",controller.recoveryMode?"BACK":"RECOVER","RESTART","POWER"]
                    GreeterButton {
                        required property string modelData
                        width:(parent.width-(parent.columns-1)*parent.spacing)/parent.columns;height:48;quiet:true;fontPixelSize:13*root.textScale
                        visible:modelData!=="RECOVER" || controller.recoveryOffered
                        text:modelData==="ACCESS"?"Readability":modelData==="RECOVER"?"Recovery":modelData==="BACK"?"Back to login":modelData==="RESTART"?"Restart":"Power off"
                        enabled:!controller.authenticating && (modelData!=="POWER" || controller.canPowerOff) && (modelData!=="RESTART" || controller.canReboot)
                        selected:modelData==="ACCESS" && controller.accessibilityMode
                        onClicked:controller.activateUtility(modelData,password);onActiveFocusChanged:if(activeFocus)root.ensureVisible(this)
                    }
                }
            }
        }
    }
    Item {
        anchors.fill:parent;visible:controller.confirmationAction!=="";z:30
        onVisibleChanged:if(visible)cancel.forceActiveFocus();else if(root.visible)Qt.callLater(()=>root.focusCredentials())
        Rectangle {anchors.fill:parent;color:"#ed080a0c";MouseArea {anchors.fill:parent}}
        Item {
            anchors.centerIn:parent;width:Math.min(420,parent.width-32);height:review.implicitHeight+40
            FrameSurface {anchors.fill:parent;surfaceColor:Theme.background;artwork:false}
            Column {id:review;x:20;y:20;width:parent.width-40;spacing:16
                Text {width:parent.width;text:controller.confirmationAction==="power"?"Power off this device?":"Restart this device?";textFormat:Text.PlainText;color:Theme.foreground;font.family:controller.headingFont;font.pixelSize:20;wrapMode:Text.Wrap}
                Row {width:parent.width;spacing:8
                    GreeterButton {id:cancel;objectName:"compact-confirm-cancel";width:(parent.width-8)/2;text:"Cancel";KeyNavigation.tab:confirm;KeyNavigation.backtab:confirm;onClicked:controller.confirmationAction=""}
                    GreeterButton {id:confirm;objectName:"compact-confirm-apply";width:(parent.width-8)/2;text:controller.confirmationAction==="power"?"Power off":"Restart";destructive:true;KeyNavigation.tab:cancel;KeyNavigation.backtab:cancel;onClicked:controller.executeConfirmation()}
                }
            }
        }
    }
}
