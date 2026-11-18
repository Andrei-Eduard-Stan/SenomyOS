.pragma library
function counters(text) {
    return text.split("\n").filter(line=>/^cpu[0-9]+\s/.test(line)).map(line=>{
        const parts=line.trim().split(/\s+/), values=parts.slice(1,9).map(Number);
        return {id:Number(parts[0].slice(3)),total:values.reduce((a,b)=>a+b,0),idle:values[3]+(values[4] || 0)};
    }).filter(cpu=>Number.isFinite(cpu.total) && Number.isFinite(cpu.idle));
}
function cores(current, previous) {
    return current.map(cpu=>{
        const last=previous.find(item=>item.id===cpu.id), delta=last?cpu.total-last.total:0;
        return {id:cpu.id,percent:delta>0&&cpu.idle>=last.idle&&cpu.idle-last.idle<=delta?Math.max(0,Math.min(100,100*(delta-(cpu.idle-last.idle))/delta)):null};
    });
}
function frequency(text) {
    const values=[];
    text.split("\n").forEach(line=>{const m=line.match(/^cpu MHz\s*:\s*([0-9.]+)/);if(m && Number(m[1])>0)values.push(Number(m[1]));});
    return {available:values.length>0,mhz:values.length?values.reduce((a,b)=>a+b,0)/values.length:null,source:"/proc/cpuinfo / mean reported MHz"};
}
function memory(text) {
    const fields={};text.split("\n").forEach(line=>{const m=line.match(/^([A-Za-z_]+):\s+(\d+)/);if(m)fields[m[1]]=Number(m[2]);});
    const available=fields.MemAvailable!==undefined?fields.MemAvailable:[fields.MemFree,fields.Buffers,fields.Cached].every(Number.isFinite)?fields.MemFree+fields.Buffers+fields.Cached:NaN;
    const valid=Number.isFinite(fields.MemTotal)&&fields.MemTotal>0&&Number.isFinite(available)&&available>=0&&available<=fields.MemTotal;
    const swap=Number.isFinite(fields.SwapTotal)&&Number.isFinite(fields.SwapFree)&&fields.SwapFree<=fields.SwapTotal;
    return {available:valid,totalKib:valid?fields.MemTotal:null,swapAvailable:swap,swapTotalKib:swap?fields.SwapTotal:null,swapUsedKib:swap?fields.SwapTotal-fields.SwapFree:null};
}
function pressure(text) {
    const m=text.match(/^some avg10=([0-9.]+) avg60=([0-9.]+) avg300=([0-9.]+) total=(\d+)/m);
    return {available:!!m,avg10:m?Number(m[1]):null,avg60:m?Number(m[2]):null,source:"/proc/pressure/memory / some stall %"};
}
