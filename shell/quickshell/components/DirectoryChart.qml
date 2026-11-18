import QtQuick
import "../config" as Config
import "DirectoryFreshness.js" as Freshness

FocusScope {
    id: root
    objectName:"history-chart-"+label
    activeFocusOnTab:true
    Accessible.role:Accessible.Chart
    Accessible.name:label+" history. Use Left and Right to inspect samples."
    property bool compact: false
    readonly property real headerBottom: Math.max(chartTitle.y+chartTitle.height,chartValue.y+chartValue.height)
    property int windowSeconds: 60
    readonly property int windowMs: Math.max(60,Math.min(900,windowSeconds))*1000
    property string unit:"%"
    property int inspectedIndex:-1
    property double inspectedAt:0
    onInspectedIndexChanged: {inspectedAt=validSample(inspectedIndex)?Number(timestamps[inspectedIndex]):0;chart.requestPaint();}
    readonly property var recordedParts:timestamps.length===values.length?Freshness.segments(values,timestamps,now,root.windowMs):[]
    readonly property int recordedSamples:recordedParts.reduce((total,part)=>total+part.length,0)
    readonly property int recordedSeconds:Math.min(root.windowSeconds,Math.round(recordedParts.reduce((total,part)=>total+(part.length>1?part[part.length-1].at-part[0].at:0),0)/1000))
    readonly property string collectionLabel:values.length && timestamps.length!==values.length?"HISTORY // SAMPLE TIMES UNAVAILABLE":recordedSamples===0?"WAITING FOR LIVE SAMPLES":"HISTORY // "+recordedSeconds+"/"+windowSeconds+"s · "+recordedSamples+" sample"+(recordedSamples===1?"":"s")
    readonly property string sampleReadout: inspectedIndex>=0 && validSample(inspectedIndex)?Number(values[inspectedIndex]).toFixed(unit==="GHz"?3:1)+" "+unit+"  //  "+Qt.formatDateTime(new Date(Number(timestamps[inspectedIndex])),"hh:mm:ss.zzz"):""
    function axisLabel(index){
        const tick=(maximum-minimum)/4;
        const decimals=tick>0 && (tick<1 || Math.abs(tick-Math.round(tick))>0.000001)?(tick<0.1?2:1):0;
        return (maximum-index*tick).toFixed(decimals);
    }
    function validSample(i){return timestamps.length===values.length && i>=0 && i<values.length && values[i]!==null && Number.isFinite(Number(values[i])) && Number(timestamps[i])>0 && now-Number(timestamps[i])>=0 && now-Number(timestamps[i])<=root.windowMs;}
    function inspectAt(x){let best=-1,distance=Infinity;for(let i=0;i<values.length;i++){if(!validSample(i))continue;const dx=Math.abs(x-chart.width*(1-(now-Number(timestamps[i]))/root.windowMs));if(dx<distance){best=i;distance=dx;}}inspectedIndex=best;chart.requestPaint();}
    function step(direction){let i=inspectedIndex<0?(direction<0?values.length:-1):inspectedIndex;for(i+=direction;i>=0 && i<values.length;i+=direction){if(validSample(i)){inspectedIndex=i;chart.requestPaint();return;}}}
    onActiveFocusChanged:{if(activeFocus && inspectedIndex<0)step(-1);else if(!activeFocus && !inspectionMouse.containsMouse){inspectedIndex=-1;chart.requestPaint();}}
    Keys.onLeftPressed:step(-1)
    Keys.onRightPressed:step(1)
    Keys.onPressed:event=>{if(event.key===Qt.Key_Home){inspectedIndex=-1;step(1);event.accepted=true;}else if(event.key===Qt.Key_End){inspectedIndex=-1;step(-1);event.accepted=true;}}
    Keys.onEscapePressed:event=>{if(inspectedIndex>=0){inspectedIndex=-1;chart.requestPaint();}else event.accepted=false;}

    property var values: []
    property var timestamps: []
    property double now:Date.now()
    onVisibleChanged: if(visible) now=Date.now()
    onTimestampsChanged: {const selected=inspectedAt;now=Date.now();if(selected>0)inspectedIndex=timestamps.findIndex(at=>Number(at)===selected);chart.requestPaint();}
    Timer {interval:1000;running:root.visible;repeat:true;triggeredOnStart:true;onTriggered:{root.now=Date.now();chart.requestPaint();}}
    property real minimum: 0
    property real maximum: 100
    property color lineColor: Config.DirectoryStyle.ink
    property string label: ""
    property string currentLabel: ""

    implicitWidth: 320
    implicitHeight: 220
    onValuesChanged: chart.requestPaint()
    onMinimumChanged: chart.requestPaint()
    onMaximumChanged: chart.requestPaint()
    onLineColorChanged: chart.requestPaint()

    Text {
        id:chartTitle
        width:Math.max(0,root.width-chartValue.width-74)
        wrapMode:Text.Wrap
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 12
        text: root.label
        color: Config.DirectoryStyle.muted
        font.family: Config.DirectoryStyle.headingFont
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }
    Text {
        id:chartValue
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        anchors.rightMargin: 50
        text: root.currentLabel
        color: root.lineColor
        font.family: Config.DirectoryStyle.valueFont
        font.pixelSize: 18
        font.weight: Font.DemiBold
    }

    Canvas {
        id: chart
        anchors.fill: parent
        anchors.leftMargin: 38
        anchors.rightMargin: 18
        anchors.topMargin: root.headerBottom+(root.compact && !root.activeFocus && root.inspectedIndex<0?28:48)
        anchors.bottomMargin: 28
        antialiasing: true
        onPaint: {
            const context = getContext("2d");
            context.reset();
            context.strokeStyle = Qt.rgba(Config.Theme.dim.r, Config.Theme.dim.g, Config.Theme.dim.b, 0.22);
            context.lineWidth = 1;
            for (let line = 1; line < 4; line++) {
                const y = height * line / 4;
                context.beginPath();
                context.moveTo(0, y);
                context.lineTo(width, y);
                context.stroke();
            }
            for (let line = 1; line < 6; line++) {
                const x = width * line / 6;
                context.beginPath();
                context.moveTo(x, 0);
                context.lineTo(x, height);
                context.stroke();
            }
            if (!root.values || root.values.length < 1 || root.maximum <= root.minimum)
                return;

            if(root.validSample(root.inspectedIndex)){
                const selectedX=width*(1-(root.now-Number(root.timestamps[root.inspectedIndex]))/root.windowMs);
                context.strokeStyle=Config.DirectoryStyle.muted;context.beginPath();context.moveTo(selectedX,0);context.lineTo(selectedX,height);context.stroke();
            }
            const parts=root.recordedParts;
            for(const part of parts){
            const points = [];
            for (let index = 0; index < part.length; index++) {
                const value = Math.max(root.minimum, Math.min(root.maximum, part[index].value));
                points.push({
                    x: width * (1 - (root.now-part[index].at)/root.windowMs),
                    y: height - height * (value - root.minimum) / (root.maximum - root.minimum)
                });
            }

            if(points.length<2)continue;
            const fill = context.createLinearGradient(0, 0, 0, height);
            fill.addColorStop(0, Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.16));
            fill.addColorStop(1, Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.015));
            context.fillStyle = fill;
            context.beginPath();
            context.moveTo(points[0].x, height);
            for (let point of points)
                context.lineTo(point.x, point.y);
            context.lineTo(points[points.length - 1].x, height);
            context.closePath();
            context.fill();

            context.strokeStyle = root.lineColor;
            context.lineWidth = 1.4;
            context.beginPath();
            for (let index = 0; index < points.length; index++) {
                const x = points[index].x;
                const y = points[index].y;
                if (index === 0)
                    context.moveTo(x, y);
                else
                    context.lineTo(x, y);
            }
            context.stroke();
            }
            if(root.validSample(root.inspectedIndex)){
                const selectedX=width*(1-(root.now-Number(root.timestamps[root.inspectedIndex]))/root.windowMs);
                const selectedValue=Math.max(root.minimum,Math.min(root.maximum,Number(root.values[root.inspectedIndex])));
                const selectedY=height-height*(selectedValue-root.minimum)/(root.maximum-root.minimum);
                context.beginPath();context.arc(selectedX,selectedY,4,0,Math.PI*2);context.fillStyle=Config.DirectoryStyle.ink;context.fill();
            }
        }
    }
    Rectangle {x:chart.x;y:chart.y;width:chart.width;height:chart.height;color:"transparent";border.width:root.activeFocus?1:0;border.color:Config.DirectoryStyle.muted}
    Text {x:38;y:root.headerBottom+8;width:Math.max(0,parent.width-56);elide:Text.ElideRight;text:root.collectionLabel;color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
    Text {visible:!root.compact || root.activeFocus || root.inspectedIndex>=0;x:38;y:root.headerBottom+26;width:Math.max(0,parent.width-56);elide:Text.ElideRight;text:root.sampleReadout || (root.activeFocus?"ARROW KEYS / INSPECT SAMPLES":"HOVER OR TAP / INSPECT SAMPLES");color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
    Text {
        objectName:"history-collecting-note"
        readonly property real availableWidth:root.recordedParts.length?chart.width*Math.max(0,1-(root.now-root.recordedParts[0][0].at)/root.windowMs)-20:0
        visible:!root.compact && root.recordedSamples>=2 && availableWidth>=140
        x:chart.x+10;y:chart.y+12;width:Math.max(0,Math.min(chart.width*0.5,availableWidth))
        text:"HISTORY COLLECTING";elide:Text.ElideRight
        color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11
    }
    MouseArea {
        id:inspectionMouse;x:chart.x;y:chart.y;width:chart.width;height:chart.height
        hoverEnabled:true;preventStealing:false
        onPositionChanged:mouse=>root.inspectAt(mouse.x)
        onClicked:mouse=>{root.forceActiveFocus();root.inspectAt(mouse.x);}
        onExited:if(!root.activeFocus){root.inspectedIndex=-1;chart.requestPaint();}
    }
    Repeater {
        model: 5
        Text {
            required property int index
            x: 8; y: chart.y-6 + index * chart.height / 4
            text: root.axisLabel(index)
            color: Config.DirectoryStyle.muted; font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 12
        }
    }
    Repeater {
        model: Array.from({length:5},(_,i)=>i===4?"now":Math.round(root.windowSeconds*(4-i)/4)+"s")
        Text {
            required property string modelData
            required property int index
            width: 40
            x: 38 + index * (root.width - 56) / 4 - (index === 0 ? 0 : index === 4 ? width : width / 2)
            y: root.height - 20
            text: modelData; color: Config.DirectoryStyle.muted; font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 12
            horizontalAlignment: index === 4 ? Text.AlignRight : Text.AlignLeft
        }
    }
    Text { visible: root.recordedSamples < 2; x:chart.x;y:chart.y+chart.height/2-implicitHeight/2;width:chart.width;wrapMode:Text.Wrap;horizontalAlignment:Text.AlignHCenter;text:root.recordedSamples===1?"FIRST SAMPLE RECEIVED":"WAITING FOR LIVE SAMPLES"; color: Config.DirectoryStyle.muted; font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 13 }
    ComponentReportMenu {anchors.right:parent.right;anchors.top:parent.top;componentKey:root.label.toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/^-|-$/g,"").slice(0,63) || "history";targetItem:root;report:({label:root.label,current:root.currentLabel,unit:root.unit,source:"SystemMetrics / shared session history",minimum:root.minimum,maximum:root.maximum,history:root.values,timestamps:root.timestamps,windowSeconds:root.windowSeconds})}
}
