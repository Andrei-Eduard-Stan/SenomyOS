import QtQuick
import Quickshell
import Quickshell.Io
import "CpuSample.js" as Samples
Scope {
    id:root
    property bool active:false
    property var previous:[]
    property var cores:[]
    property var frequency:({available:false,mhz:null})
    property var memory:({available:false,swapAvailable:false})
    property var pressure:({available:false})
    property double observedAt:0
    property string error:""
    property var baseFrequency:({available:false,mhz:null,source:"sysfs cpufreq/base_frequency"})
    onActiveChanged:{previous=[];cores=[];if(active)refresh();}
    function consumeStat(text) {const current=Samples.counters(text);cores=Samples.cores(current,previous);previous=current;if(current.length)observedAt=Date.now();error=current.length?"":"Per-core counters unavailable";}
    function refresh(){stat.reload();info.reload();mem.reload();psi.reload();base.reload();}
    FileView {id:stat;path:root.active?"/proc/stat":"";printErrors:false;onLoaded:if(root.active)root.consumeStat(text());onLoadFailed:{root.cores=[];root.error="Per-core counters unavailable";}}
    FileView {id:info;path:root.active?"/proc/cpuinfo":"";printErrors:false;onLoaded:if(root.active)root.frequency=Samples.frequency(text());onLoadFailed:root.frequency=({available:false,mhz:null})}
    FileView {id:mem;path:root.active?"/proc/meminfo":"";printErrors:false;onLoaded:if(root.active)root.memory=Samples.memory(text());onLoadFailed:root.memory=({available:false,swapAvailable:false})}
    FileView {id:psi;path:root.active?"/proc/pressure/memory":"";printErrors:false;onLoaded:if(root.active)root.pressure=Samples.pressure(text());onLoadFailed:root.pressure=({available:false})}
    FileView {id:base;path:root.active && root.cores.length?"/sys/devices/system/cpu/cpu"+root.cores[0].id+"/cpufreq/base_frequency":"";printErrors:false;onLoaded:{const khz=Number(text().trim());root.baseFrequency=({available:khz>0,mhz:khz>0?khz/1000:null,source:"sysfs cpufreq/base_frequency"});}onLoadFailed:root.baseFrequency=({available:false,mhz:null,source:"sysfs cpufreq/base_frequency"})}
    Timer {interval:1000;repeat:true;running:root.active;onTriggered:root.refresh()}
}
