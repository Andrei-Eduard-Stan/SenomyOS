import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import "../config" as Config

FocusScrollArea {
    id: root
    property var skin: Config.Skin
    property bool dirty: false
    property string part:"overview"
    property string loadedKey: ""
    readonly property string selectedKey: surface.currentText
    contentHeight: body.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function load() {
        if (!selectedKey) return;
        const bg=skin.registry.backgrounds[selectedKey] || {};
        const persona=skin.registry.persona || {};
        source.text=bg.source || "";
        scaling.currentIndex=bg.scaling === "fit" ? 1 : 0;
        imageOpacity.value=Math.round((bg.imageOpacity === undefined ? 1 : bg.imageOpacity)*100);
        scrim.value=Math.round((bg.scrimOpacity || 0)*100);
        reduced.checked=persona.reducedMotion === true;
        hoverExpand.checked=persona.hoverExpansionEnabled !== false;
        textSize.value=persona.railTextPx || 12;
        uiText.value=Math.round((persona.uiTextScale || 1)*100);
        highContrast.checked=persona.highContrast===true;
        loadedKey=selectedKey;
        dirty=false;
    }
    Component.onCompleted: Qt.callLater(load)
    Connections {
        target: root.skin
        function onRevisionChanged() { if(!root.dirty) Qt.callLater(root.load); }
        function onSaveStatusChanged() { if(root.skin.saveStatus === "Saved") root.dirty=false; }
    }
    FileDialog {
        id: picker
        title: "Choose a surface background"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.svg *.webp)"]
        onAccepted: { source.text=String(selectedFile); root.dirty=true; }
    }

    ScrollBar.vertical: ShellScrollBar {}
    component Label: Text {
        x:Config.DirectoryStyle.controlInset;width:Math.max(1,parent.width-2*x)
        textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.ink
        font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize
    }
    component Help: Label {color:Config.DirectoryStyle.muted;font.pixelSize:Config.DirectoryStyle.detailSize;lineHeight:1.25}
    Column {
        id: body;width:parent.width;spacing:Config.DirectoryStyle.sectionGap
        Column {
            width:parent.width;spacing:Config.DirectoryStyle.controlGap;visible:root.part!=="motion"
            Label {visible:root.part==="overview";text:"Surface background";font.weight:Font.DemiBold;font.pixelSize:Config.DirectoryStyle.bodySize+2}
            Help {text:"Choose a surface and image, then save. Clear the image to restore its normal fill."}
            Label {text:"Surface"}
            ShellComboBox {
                id:surface;width:parent.width;model:Object.keys(root.skin.registry.backgrounds || {}).sort()
                displayText:currentText.replace(/[-_]/g," ").replace(/^./,c=>c.toUpperCase())
                enabled:!root.dirty && !root.skin.saving
                onCurrentTextChanged:Qt.callLater(root.load)
                Accessible.name:"Surface to customize"
            }
            Label {text:"Background image"}
            ShellTextField {
                id:source;objectName:"backgroundSource";width:parent.width
                placeholderText:"Image path or file URL";onTextEdited:root.dirty=true
                Accessible.name:"Background image path"
            }
            Flow {
                width:parent.width;spacing:Config.DirectoryStyle.controlGap
                DashboardButton {width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:"Choose image…";centered:false;onClicked:picker.open()}
                DashboardButton {width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:"Clear image";centered:false;enabled:!!source.text;onClicked:{source.text="";root.dirty=true;}}
            }
            Help {visible:!source.text;text:"No image selected. The surface uses its normal fill."}
            Rectangle {
                visible:!!source.text;x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;height:160;color:Config.DirectoryStyle.glass;clip:true
                SurfaceBackground {id:preview;anchors.fill:parent;spec:({source:source.text,scaling:scaling.currentIndex===1?"fit":"crop",imageOpacity:imageOpacity.value/100,scrimOpacity:scrim.value/100})}
                Text {visible:!preview.imageReady;anchors.centerIn:parent;width:parent.width-32;wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter;text:"Image unavailable or loading. The existing fill remains.";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
            }
            Label {text:"Image placement"}
            ShellComboBox {id:scaling;width:parent.width;model:["Fill and crop","Fit complete image"];onActivated:root.dirty=true;Accessible.name:"Image scaling"}
            Grid {
                x:Config.DirectoryStyle.controlInset;width:Math.max(1,parent.width-2*x);columns:width<480*Config.DirectoryStyle.textScale?1:2
                columnSpacing:Config.DirectoryStyle.sectionGap;rowSpacing:Config.DirectoryStyle.controlGap
                Column {width:parent.columns===1?parent.width:(parent.width-parent.columnSpacing)/2;spacing:8
                    Text {width:parent.width;text:"Image opacity (%)";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink;wrapMode:Text.WordWrap}
                    ShellSpinBox {id:imageOpacity;objectName:"control-image-opacity";width:Math.min(parent.width,180);from:0;to:100;value:100;onValueModified:root.dirty=true;Accessible.name:"Image opacity in percent"}
                }
                Column {width:parent.columns===1?parent.width:(parent.width-parent.columnSpacing)/2;spacing:8
                    Text {width:parent.width;text:"Dark overlay (%)";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink;wrapMode:Text.WordWrap}
                    ShellSpinBox {id:scrim;objectName:"control-image-scrim";width:Math.min(parent.width,180);from:0;to:100;onValueModified:root.dirty=true;Accessible.name:"Dark overlay in percent"}
                }
            }
        }
        Column {
            width:parent.width;spacing:Config.DirectoryStyle.controlGap;visible:root.part!=="backgrounds"
            Label {visible:root.part==="overview";text:"Motion and readability";font.weight:Font.DemiBold;font.pixelSize:Config.DirectoryStyle.bodySize+2}
            ShellCheckBox {id:reduced;objectName:"control-reduced-motion";width:parent.width;text:"Reduce Senomy animations";onToggled:root.dirty=true}
            ShellCheckBox {id:hoverExpand;objectName:"control-hover-expansion";width:parent.width;text:"Expand Senomy after hovering";onToggled:root.dirty=true}
            ShellCheckBox {id:highContrast;objectName:"control-high-contrast";width:parent.width;text:"Stronger contrast in Settings and system surfaces";onToggled:root.dirty=true}
            Grid {
                x:Config.DirectoryStyle.controlInset;width:Math.max(1,parent.width-2*x);columns:width<480*Config.DirectoryStyle.textScale?1:2
                columnSpacing:Config.DirectoryStyle.sectionGap;rowSpacing:Config.DirectoryStyle.controlGap
                Column {width:parent.columns===1?parent.width:(parent.width-parent.columnSpacing)/2;spacing:8
                    Text {width:parent.width;text:"Interface text size (%)";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink;wrapMode:Text.WordWrap}
                    ShellSpinBox {id:uiText;objectName:"control-ui-text-scale";width:Math.min(parent.width,180);from:100;to:150;stepSize:10;value:100;onValueModified:root.dirty=true;Accessible.name:"Interface text size in percent"}
                }
                Column {width:parent.columns===1?parent.width:(parent.width-parent.columnSpacing)/2;spacing:8
                    Text {width:parent.width;text:"Rail text size (px)";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink;wrapMode:Text.WordWrap}
                    ShellSpinBox {id:textSize;objectName:"control-rail-text";width:Math.min(parent.width,180);from:10;to:16;value:12;onValueModified:root.dirty=true;Accessible.name:"Rail text size in pixels"}
                }
            }
        }
        Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
        Flow {
            width:parent.width;spacing:Config.DirectoryStyle.controlGap
            DashboardButton {
                objectName:"appearanceApply";width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:"Save settings";centered:false
                enabled:root.dirty && !!root.loadedKey && !root.skin.saving && !root.skin.error
                onClicked:root.skin.savePreferences(root.loadedKey,
                    {source:source.text.trim(),scaling:scaling.currentIndex===1?"fit":"crop",imageOpacity:imageOpacity.value/100,scrimOpacity:scrim.value/100},
                    {reducedMotion:reduced.checked,hoverExpansionEnabled:hoverExpand.checked,railTextPx:textSize.value,uiTextScale:uiText.value/100,highContrast:highContrast.checked})
            }
            DashboardButton {width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:"Discard edits";centered:false;enabled:root.dirty && !root.skin.saving;onClicked:root.load()}
        }
        Help {text:root.skin.error || root.skin.saveStatus || (root.dirty?"Unsaved changes":"Changes apply after saving.");color:root.skin.error?Config.Theme.danger:Config.DirectoryStyle.muted}
    }
}
