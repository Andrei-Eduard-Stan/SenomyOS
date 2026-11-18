import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

FocusScope {
    id:root
    required property var controller
    visible:controller.userChooserOpen
    z:40
    onVisibleChanged:if(visible){search.text="";close.forceActiveFocus();}
    function matches(name,realName){const q=search.text.trim().toLowerCase();return name!==controller.recoveryUser && (!q || (name+" "+realName).toLowerCase().indexOf(q)>=0);}
    function firstMatch(){for(let i=0;i<controller.accountModel.count;i++){const row=controller.accountModel.index(i,0),name=String(controller.accountModel.data(row,257)||""),realName=String(controller.accountModel.data(row,258)||"");if(matches(name,realName)){controller.selectAccount(name);return;}}}
    Rectangle {anchors.fill:parent;color:"#e6080a0c";MouseArea {anchors.fill:parent;onClicked:root.controller.userChooserOpen=false}}
    Item {
        anchors.centerIn:parent;width:Math.min(480,Math.max(1,parent.width-32));height:Math.min(600,Math.max(1,parent.height-32))
        FrameSurface {anchors.fill:parent;surfaceColor:Theme.background;artwork:false}
        MouseArea {anchors.fill:parent}
        Column {
            anchors.fill:parent;anchors.margins:20;spacing:12
            Row {width:parent.width
                Text {width:parent.width-80;height:48;text:"Choose account";font.family:root.controller.headingFont;font.pixelSize:18;color:Theme.foreground;verticalAlignment:Text.AlignVCenter;wrapMode:Text.Wrap}
                GreeterButton {id:close;objectName:"account-picker-close";width:80;height:48;quiet:true;text:"Back";onClicked:root.controller.userChooserOpen=false}
            }
            GreeterField {id:search;objectName:"account-picker-search";width:parent.width;placeholderText:"Search accounts…";Accessible.name:"Search accounts";Keys.onReturnPressed:root.firstMatch();Keys.onEnterPressed:root.firstMatch()}
            ListView {
                id:list;objectName:"login-account-list";width:parent.width;height:Math.max(1,parent.height-48-search.height-other.height-36)
                model:root.controller.accountModel;clip:true;boundsBehavior:Flickable.StopAtBounds
                ScrollBar.vertical:ScrollBar {}
                delegate:Item {
                    required property int index
                    required property string name
                    required property string realName
                    width:list.width;height:root.matches(name,realName)?72:0;visible:height>0
                    GreeterButton {
                        objectName:"login-user-"+parent.name;width:parent.width-10;height:64;alignment:Text.AlignLeft
                        text:(parent.realName || parent.name)+(parent.realName && parent.realName!==parent.name?"\n"+parent.name:"")
                        fontPixelSize:root.controller.accessibilityMode?16:14;selected:root.controller.normalUser===parent.name
                        onClicked:root.controller.selectAccount(parent.name)
                        onActiveFocusChanged:if(activeFocus)list.positionViewAtIndex(index,ListView.Contain)
                    }
                }
            }
            GreeterButton {id:other;objectName:"login-other-account";width:parent.width;text:"Other account";fontPixelSize:root.controller.accessibilityMode?16:14;onClicked:root.controller.selectAccount("")}
        }
    }
    Keys.onEscapePressed:controller.userChooserOpen=false
}
