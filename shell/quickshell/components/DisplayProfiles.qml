pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../config" as Config

Column {
    id:root
    required property var inventory
    signal review(string operation,var argument,string text)
    spacing:8
    Text {width:parent.width;text:"Save the confirmed running setup. Profiles match serial-backed display identities across connector changes. Ambiguous or incomplete setups require review; docking suggests a profile rather than disabling screens automatically.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.pixelSize:12}
    DashboardButton {visible:root.inventory.legacyDefaultsPending===true;text:"IMPORT OLD DEFAULTS";onClicked:root.review("profile-import-legacy",{},"Import connector-based startup defaults as a reviewable profile. Original settings are preserved and no outputs change until you preview the imported profile.")}
    ShellTextField {id:name;width:parent.width;placeholderText:"Profile name";maximumLength:80;Accessible.name:"Display profile name"}
    DashboardButton {width:200;text:"SAVE CURRENT SETUP";enabled:name.text.trim().length>0;onClicked:root.review("profile-save",{name:name.text},"Save the running display layout, preferred display and workspace policy as “"+name.text+"”. Apply and Keep draft edits first.")}
    Repeater {
        model:root.inventory.profiles
        Column {
            id:profile
            required property var modelData
            width:root.width;spacing:6
            Text {width:parent.width;text:profile.modelData.name+" · "+profile.modelData.displayCount+" displays · "+(profile.modelData.match==="matched"?"connected setup matches":"different / incomplete setup");color:Config.DirectoryStyle.ink;font.pixelSize:13;textFormat:Text.PlainText}
            Flow {
                width:parent.width;spacing:8
                DashboardButton {text:"PREVIEW PROFILE";onClicked:root.review("profile-apply",{id:profile.modelData.id},"Apply “"+profile.modelData.name+"” temporarily. Keep/Revert and automatic recovery remain active.")}
                DashboardButton {text:"RENAME";enabled:name.text.trim().length>0;onClicked:root.review("profile-rename",{id:profile.modelData.id,name:name.text},"Rename “"+profile.modelData.name+"” to “"+name.text+"”.")}
                DashboardButton {text:"DELETE";onClicked:root.review("profile-delete",{id:profile.modelData.id},"Delete saved profile “"+profile.modelData.name+"”. The current layout stays unchanged.")}
            }
        }
    }
}
