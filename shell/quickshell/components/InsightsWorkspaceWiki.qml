import QtQuick
import "../config" as Config
import "../services" as Services
Item {
    id:root
    required property var workspace
    Rectangle {anchors.fill:parent;color:Qt.rgba(Config.DirectoryStyle.glass.r,Config.DirectoryStyle.glass.g,Config.DirectoryStyle.glass.b,Config.DirectoryStyle.highContrast?1:0.94)}
    property var tools:nativeTools
    property string section:workspace.readState("wiki","section","articles")
    readonly property var filtered:articleBody.filtered
    readonly property var selected:articleBody.selected
    readonly property bool articleOpen:articleBody.articleOpen
    function back(){return body.item && typeof body.item.back==="function"?body.item.back():false;}
    function select(id){section=id;workspace.remember("wiki","section",id);}
    Services.WikiTools {
        id:nativeTools
        active:root.tools===nativeTools && root.visible && root.workspace.requestedOpen && root.workspace.activeSection==="wiki"
        shortcutsVisible:root.section==="shortcuts"
    }
    Repeater {model:root.tools.fontFiles || [];delegate:Item {id:fontItem;required property string modelData;visible:false;FontLoader {source:fontItem.modelData}}}
    Column {
        id:header;width:parent.width;spacing:12
        InsightsWorkspaceTitle {
            width:parent.width;title:"Wiki";detail:"Read, collect and keep useful things close"
            actions:[QuietButton {text:root.tools.busy?"Refreshing…":"Refresh";enabled:!root.tools.busy && !root.workspace.insights.busy;onClicked:{root.tools.refresh();root.workspace.insights.refresh("wiki",false);}}]
        }
        Flow {
            width:parent.width;spacing:8
            Repeater {
                model:[{id:"articles",label:"Articles"},{id:"emoticons",label:"Emoticons"},{id:"shortcuts",label:"Shortcuts"}]
                delegate:QuietButton {required property var modelData;objectName:"wiki-tab-"+modelData.id;text:modelData.label;active:root.section===modelData.id;Accessible.description:active?"Current Wiki section":"Open Wiki section";onClicked:root.select(modelData.id)}
            }
        }
        Text {width:parent.width;visible:!!root.tools.error;text:root.tools.error;textFormat:Text.PlainText;wrapMode:Text.Wrap;color:Config.Theme.danger;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
        InsightsWorkspaceStatus {width:parent.width;visible:root.section==="articles";workspace:root.workspace;route:"wiki"}
    }
    Item {
        id:body;y:header.height+16;width:parent.width;height:Math.max(1,parent.height-y)
        readonly property var item:root.section==="emoticons"?emoticonBody:root.section==="shortcuts"?shortcutBody:articleBody
        WikiArticles {id:articleBody;anchors.fill:parent;visible:root.section==="articles";workspace:root.workspace}
        WikiEmoticons {id:emoticonBody;anchors.fill:parent;visible:root.section==="emoticons";tools:root.tools}
        WikiShortcuts {id:shortcutBody;anchors.fill:parent;visible:root.section==="shortcuts";tools:root.tools}
    }
}
