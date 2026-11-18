import QtQuick
import "../config" as Config
import "DirectoryFreshness.js" as Freshness
FocusScrollArea {
    id:root
    objectName:"cpu-object-page"
    required property var performance
    required property var metrics
    property string view:"utilisation"
    property double now:Date.now()
    onVisibleChanged: if(visible) now=Date.now()
    Timer {interval:1000;running:root.visible;repeat:true;triggeredOnStart:true;onTriggered:root.now=Date.now()}
    readonly property var inventory:performance.details.cpu_inventory || ({})
    readonly property var health:performance.details.health || ({})
    readonly property var thermal:metrics.temperatureAvailable!==undefined?({available:metrics.temperatureAvailable===true,celsius:metrics.temperatureCelsius,source:"CPU/SOC thermal zones / hottest supported sensor"}):(health.temperature || {available:false})
    property int inspectedCoreId:-1
    readonly property int selectedCoreId:inspectedCoreId>=0?inspectedCoreId:(telemetry.cores.length?telemetry.cores[0].id:-1)
    readonly property var telemetry:({cores:performance.telemetry && performance.telemetry.cores || [],frequency:performance.telemetry && performance.telemetry.frequency || {available:false},baseFrequency:performance.telemetry && performance.telemetry.baseFrequency || {available:false}})
    readonly property var storage:performance.details.storage || ({})
    signal processRequested(int pid,string name)
    property string sortKey:"cpu"
    readonly property var sortedProcesses:(performance.processes || []).slice().sort((a,b)=>sortKey==="name"?String(a.name).localeCompare(String(b.name)):Number(b[sortKey==="memory"?"memory_mib":"cpu_percent"] || 0)-Number(a[sortKey==="memory"?"memory_mib":"cpu_percent"] || 0)).slice(0,8)
    contentHeight:content.implicitHeight
    clip:true
    function bytes(value){return value===undefined || value===null?"Unavailable":(value/1073741824).toFixed(1)+" GiB";}
    Column {
        id:content;width:parent.width;spacing:12
        Grid {
            columns:width<480?1:2;rowSpacing:12
            width:parent.width;spacing:24
            Column {
                width:parent.columns===1?parent.width:Math.max(100,parent.width*0.42);spacing:5
                ExpandedLabel {text:"CPU";font.pixelSize:28}
                Text {width:parent.width;text:root.inventory.model || root.metrics.cpuModel || "CPU inventory collecting";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12}
            }
            Column {
                width:parent.columns===1?parent.width:Math.max(80,parent.width*0.58-24);spacing:6
                Text {width:parent.width;text:"ARCH  "+(root.inventory.architecture || "Unavailable")+"    LOGICAL  "+(root.inventory.logical_cpus ?? "—");color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12;wrapMode:Text.WordWrap}
                Text {width:parent.width;text:"PHYSICAL  "+(root.inventory.physical_cores && root.inventory.sockets?root.inventory.physical_cores*root.inventory.sockets:"—")+"    VIRTUALISATION  "+(root.inventory.virtualization || "Unavailable");color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12;wrapMode:Text.WordWrap}
                Text {width:parent.width;text:"HOST  "+(root.health.hostname || "—")+"    KERNEL  "+(root.health.kernel || "—");color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12;wrapMode:Text.WordWrap}
                Text {width:parent.width;text:"UP  "+root.metrics.uptimeLabel+"    "+((root.performance.details.services || {}).available?((root.performance.details.services || {}).failed_total>0?"ATTENTION":"OPERATIONAL"):"HEALTH UNAVAILABLE");color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12;wrapMode:Text.WordWrap}
            }
        }
        DirectoryFreshness {visible:root.view!=="utilisation";width:parent.width;source:"INVENTORY";observedAt:root.performance.detailsObservedAt || 0;staleAfter:10000}
        Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
        Grid {
            visible:root.view==="utilisation" || root.view==="processes";width:parent.width;columns:width<670?1:2;columnSpacing:24;rowSpacing:16
            DirectoryChart { windowSeconds: root.performance.historySeconds || 60;
                visible:root.view==="utilisation";width:parent.columns===1?parent.width:(parent.width-24)*0.68;height:Config.DirectoryStyle.touchMode?380:340
                label:"CPU UTILISATION";currentLabel:root.metrics.ready?Math.round(root.metrics.cpuPercent)+"%":"COLLECTING";timestamps:root.performance.sampleTimes || [];values:root.performance.cpuHistory
            }
            Item {
                id:processModule
                visible:root.view==="utilisation" || root.view==="processes"
                width:parent.columns===1 || root.view==="processes"?parent.width:(parent.width-24)*0.32;height:Config.DirectoryStyle.touchMode?380:340
                Text {x:4;y:12;objectName:"process-sample-heading";text:"TOP PROCESSES / "+(root.sortKey==="memory"?"MEMORY":root.sortKey.toUpperCase());width:parent.width-48;elide:Text.ElideRight;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.headingFont;font.pixelSize: 13}
                ComponentReportMenu {anchors.right:parent.right;anchors.top:parent.top;componentKey:"top-processes";targetItem:processModule;report:({sort:root.sortKey,processes:root.sortedProcesses,observedAt:root.performance.processesObservedAt || 0})}
                Row {x:4;y:42;width:parent.width-8;spacing:4
                    Repeater {model:[{id:"name",label:"NAME"},{id:"cpu",label:"CPU %"},{id:"memory",label:"MiB"}]
                        DirectoryButton {required property var modelData;width:modelData.id==="name"?Math.max(20,processModule.width-160):(modelData.id==="cpu"?80:64);height:Config.DirectoryStyle.touchMode?48:36;text:modelData.label;active:root.sortKey===modelData.id;onClicked:root.sortKey=modelData.id}
                    }
                }
                DirectoryFreshness {x:4;y:Config.DirectoryStyle.touchMode?96:82;width:parent.width-8;source:"SAMPLE";observedAt:root.performance.processesObservedAt || 0;staleAfter:10000;font.pixelSize:11}
                FocusScrollArea {
                    x:4;y:Config.DirectoryStyle.touchMode?120:108;width:parent.width-8;height:parent.height-y
                    contentHeight:processRows.implicitHeight;clip:true
                    Column {
                        id:processRows;width:parent.width;spacing:4
                        Repeater {model:root.sortedProcesses
                            Rectangle {
                                id:processRow;required property var modelData
                                objectName:"cpu-process-"+modelData.pid
                                width:parent.width;height:Config.DirectoryStyle.touchMode?48:25
                                color:"transparent"
                                border.width:0;border.color:Config.DirectoryStyle.ink
                                activeFocusOnTab:true;Accessible.role:Accessible.Button
                                Accessible.name:"Inspect process "+modelData.pid+" "+modelData.name
                                function inspect(){root.processRequested(modelData.pid,modelData.name);}
                                Keys.onReturnPressed:inspect();Keys.onSpacePressed:inspect()
                                Row {anchors.verticalCenter:parent.verticalCenter;width:parent.width;spacing:4
                                    Text {width:Math.max(20,parent.width-152);text:processRow.modelData.pid+" "+processRow.modelData.name;textFormat:Text.PlainText;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;elide:Text.ElideRight}
                                    Text {width:80;text:Number(processRow.modelData.cpu_percent || 0).toFixed(1)+"%";color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;horizontalAlignment:Text.AlignRight}
                                    Text {width:64;text:processRow.modelData.memory_mib!==undefined && processRow.modelData.memory_mib!==null && Number.isFinite(Number(processRow.modelData.memory_mib))?Math.round(Number(processRow.modelData.memory_mib)).toString():"—";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;horizontalAlignment:Text.AlignRight}
                                }
                                ButtonHoverFrame { focusTarget: processRow; pointerTarget: processMouse; anchors.fill: parent; engaged: processRow.enabled && processMouse.containsMouse }
                                MouseArea {id:processMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:{processRow.forceActiveFocus();processRow.inspect();}}
                            }
                        }
                        Text {visible:root.sortedProcesses.length===0;width:parent.width;text:"Process sample collecting or unavailable";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12}
                    }
                }
            }
        }
        Grid {
            width:parent.width;columns:width<670?1:3;columnSpacing:24;rowSpacing:16
            CoreBars {visible:root.view==="utilisation" || root.view==="cores";width:root.view==="cores"?parent.width:parent.columns===1?parent.width:(parent.width-48)*0.48;cores:root.telemetry.cores || [];implicitHeight:148+Math.max(0,Math.ceil((cores.length*22)/Math.max(1,width))-1)*104}
            SegmentMetric {
                visible:root.view==="utilisation" || root.view==="frequency"
                width:root.view==="frequency"?parent.width:parent.columns===1?parent.width:(parent.width-48)*0.26
                title:"FREQUENCY";value:root.telemetry.frequency.available?(root.telemetry.frequency.mhz/1000).toFixed(2)+" GHz":"Unavailable"
                detail:root.telemetry.baseFrequency.available?"Base "+(root.telemetry.baseFrequency.mhz/1000).toFixed(2)+" GHz":"Mean reported MHz · base unavailable"
                fraction:root.telemetry.frequency.available && root.inventory.max_mhz>0?root.telemetry.frequency.mhz/root.inventory.max_mhz:-1
                lowLabel:"0 GHz";highLabel:root.inventory.max_mhz>0?(root.inventory.max_mhz/1000).toFixed(1)+" GHz":"Scale unavailable"
            }
            SegmentMetric {
                visible:root.view==="utilisation" || root.view==="thermals"
                width:root.view==="thermals"?parent.width:parent.columns===1?parent.width:(parent.width-48)*0.26
                title:"THERMALS";value:root.thermal.available?root.thermal.celsius+" °C":"Unavailable"
                detail:(root.thermal.source || "No supported sensor")+" // "+(root.metrics.temperatureAvailable!==undefined?"SESSION SENSOR · 10s source cadence":Freshness.describe(root.performance.detailsObservedAt || 0,root.now,10000,false))
                fraction:root.thermal.available?root.thermal.celsius/100:-1;lowLabel:"0 °C";highLabel:"100 °C scale"
            }
        }
        Column {
            width:parent.width;spacing:10
            visible:["cores","frequency","thermals"].includes(root.view)
            Text {
                width:parent.width
                text:root.view==="thermals"?"HISTORY // shared CPU/SOC sensor · sensor read every 10s":root.view==="frequency"?"HISTORY // mean reported CPU frequency · source read every 5s":"HISTORY // per-core CPU counter deltas · shared session sampler"
                color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;wrapMode:Text.WordWrap
            }
            Flow {
                visible:root.view==="cores";width:parent.width;spacing:8
                Repeater {model:root.telemetry.cores
                    DirectoryButton {required property var modelData;objectName:"cpu-core-history-"+modelData.id;width:88;height:48;text:"CORE "+modelData.id;active:root.selectedCoreId===modelData.id;onClicked:root.inspectedCoreId=modelData.id}
                }
            }
            DirectoryChart {
                width:parent.width;height:300
                windowSeconds:root.performance.historySeconds || 60
                timestamps:root.performance.sampleTimes || []
                values:root.view==="thermals"?(root.performance.temperatureHistory || []):root.view==="frequency"?(root.performance.frequencyHistory || []):typeof root.performance.coreHistory==="function"?root.performance.coreHistory(root.selectedCoreId):[]
                label:root.view==="thermals"?"CPU/SOC TEMPERATURE HISTORY":root.view==="frequency"?"CPU FREQUENCY HISTORY":"CORE "+root.selectedCoreId+" UTILISATION HISTORY"
                unit:root.view==="thermals"?"°C":root.view==="frequency"?"GHz":"%"
                minimum:root.view==="thermals"?Math.min(0,...values.filter(v=>v!==null && Number.isFinite(v))):0
                maximum:root.view==="frequency"?Math.max(1,Number(root.inventory.max_mhz || 0)/1000,...values.filter(v=>v!==null && Number.isFinite(v))):root.view==="thermals"?Math.max(100,...values.filter(v=>v!==null && Number.isFinite(v))):100
            }
        }
        Column {
            visible:root.view==="thermals";width:parent.width;spacing:8
            Repeater {model:(root.performance.details.sensors || {}).temperatures || []
                DirectoryButton {required property var modelData;width:parent.width;text:modelData.source+" / "+modelData.label;detail:modelData.celsius+" °C"+(modelData.critical_celsius?" · critical "+modelData.critical_celsius+" °C":"")}
            }
        }
        Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule;visible:root.view==="utilisation"}
        Grid {
            visible:root.view==="utilisation";width:parent.width;columns:width<670?1:3;columnSpacing:24;rowSpacing:12
            DirectoryMetric {implicitHeight:110;width:(parent.width-24*(parent.columns-1))/parent.columns;title:"MEMORY";value:root.metrics.memoryTotalKib>0?Math.round(root.metrics.memoryPercent)+"%":"Unavailable";detail:root.metrics.memoryTotalKib>0?root.bytes(root.metrics.memoryUsedKib*1024)+" / "+root.bytes(root.metrics.memoryTotalKib*1024):"Memory source collecting";fraction:root.metrics.memoryTotalKib>0?root.metrics.memoryPercent/100:-1}
            DirectoryMetric {implicitHeight:110;width:(parent.width-24*(parent.columns-1))/parent.columns;title:"STORAGE";value:root.storage.percent!==undefined && root.storage.percent!==null?root.storage.percent+"%":"Unavailable";detail:root.bytes(root.storage.used_bytes)+" / "+root.bytes(root.storage.total_bytes);fraction:root.storage.percent!==undefined && root.storage.percent!==null?root.storage.percent/100:-1}
            DirectoryMetric {implicitHeight:110;width:(parent.width-24*(parent.columns-1))/parent.columns;title:"NETWORK";value:root.metrics.ready?root.metrics.networkRxKib.toFixed(1)+" KiB/s":"Collecting";detail:"RX · TX "+root.metrics.networkTxKib.toFixed(1)+" KiB/s";extraReport:({rxKib:root.metrics.networkRxKib,txKib:root.metrics.networkTxKib})}
        }
    }
}
