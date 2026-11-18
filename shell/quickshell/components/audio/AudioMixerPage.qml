import QtQuick
import QtQuick.Window
import QtQuick.Controls
import ".."
import "../../config" as Config
Column {
    id:root
    required property var audio
    property bool recording:false
    signal directionRequested(bool recording)
    property string search:""
    property string sortBy:"name"
    property bool grouped:true
    readonly property var rows:{
        const list=(recording?audio.recordingStreams || []:audio.playbackStreams || []).filter(n=>(audio.appName(n)+" "+audio.nodeName(n)).toLowerCase().indexOf(search.toLowerCase())>=0).slice();
        list.sort((a,b)=>grouped?audio.appName(a).localeCompare(audio.appName(b)) || audio.nodeName(a).localeCompare(audio.nodeName(b)):sortBy==="volume"?b.audio.volume-a.audio.volume:audio.nodeName(a).localeCompare(audio.nodeName(b)));
        return list;
    }
    width:parent.width;height:parent.height;spacing:8
    Row {
        width:parent.width;spacing:8
        ControlWorkspaceButton {width:(parent.width-8)/2;text:"Playback";active:!root.recording;onClicked:{root.recording=false;root.directionRequested(false)}}
        ControlWorkspaceButton {width:(parent.width-8)/2;text:"Recording";active:root.recording;onClicked:{root.recording=true;root.directionRequested(true)}}
    }
    ControlWorkspaceSearch {objectName:"audioStreamSearch";width:parent.width;placeholderText:"Search app or stream…";Accessible.name:"Search audio streams";onTextChanged:root.search=text}
    Flow {
        width:parent.width;spacing:8
        ShellCheckBox {width:parent.width<420?parent.width:(parent.width-8)/2;text:"Group by app";checked:root.grouped;onToggled:root.grouped=checked}
        ShellComboBox {width:parent.width<420?parent.width:(parent.width-8)/2;model:["Name","Volume"];enabled:!root.grouped;Accessible.name:"Audio stream sort";onActivated:index=>root.sortBy=index===1?"volume":"name"}
    }
    AudioLabel {text:root.rows.length+(root.rows.length===1?" stream":" streams")+(root.recording?" · Recording":" · Playback")}
    AudioLabel {visible:root.audio.preferenceMessage.length>0;text:root.audio.preferenceMessage}
    Connections {target:root.Window.window;function onActiveFocusItemChanged(){Qt.callLater(list.revealFocus);}}
    ListView {
        id:list;width:parent.width;height:Math.max(0,parent.height-y);clip:true;spacing:16;model:root.rows
        boundsBehavior:Flickable.StopAtBounds;ScrollBar.vertical:ShellScrollBar {}activeFocusOnTab:true
        Keys.onDownPressed:incrementCurrentIndex();Keys.onUpPressed:decrementCurrentIndex()
        delegate:AudioStreamRow {
            required property var modelData;required property int index
            width:ListView.view.width;audio:root.audio;node:modelData;recording:root.recording
            onNavigate:direction=>{list.currentIndex=Math.max(0,Math.min(list.count-1,index+direction));list.positionViewAtIndex(list.currentIndex,ListView.Contain);Qt.callLater(()=>{if(list.currentItem)list.currentItem.forceActiveFocus();});}
            groupLabel:root.grouped && (index===0 || root.audio.appName(root.rows[index-1])!==root.audio.appName(modelData))?root.audio.appName(modelData):""
        }
        AudioLabel {anchors.centerIn:parent;width:parent.width;visible:root.rows.length===0;text:root.search?"No streams match your search":root.recording?"No recording streams · activity appears when an app records":"No playback streams · start playback in an app";horizontalAlignment:Text.AlignHCenter}
        function revealFocus() {
            const focus=list.Window.window?list.Window.window.activeFocusItem:null;let item=focus;
            while(item && item!==list.contentItem)item=item.parent;
            if(item && focus){const p=focus.mapToItem(list.contentItem,0,0);if(p.y<contentY)contentY=p.y;else if(p.y+focus.height>contentY+height)contentY=Math.min(Math.max(0,contentHeight-height),p.y+focus.height-height);}
        }
    }
}
