import QtQuick
import QtTest
import "../components/DirectoryModel.js" as Directory
import "../services/CpuSample.js" as Samples
import "../components/DirectoryFreshness.js" as Freshness
TestCase {
    name:"DirectoryData"
    function test_navigation(){
        const nodes=Directory.performance();
        const rows=Directory.flatten(nodes,{compute:true,cpu:true},"");
        verify(rows.some(n=>n.id==="cpu/utilisation"));verify(!rows.some(n=>n.id==="gpu/memory"));
        const search=Directory.flatten(nodes,{},"temperature");
        for(const id of ["cpu/thermals","gpu/thermals","storage/health"]){verify(search.some(n=>n.id===id));}
        verify(search.some(n=>n.id==="compute"));compare(Directory.flatten(nodes,{},"no-match").length,0);
        const network=Directory.flatten(nodes,{},"network");
        for(const id of ["network/interfaces","network/traffic","network/connections","network/dns"]){verify(network.some(n=>n.id===id));}
    }
    function test_source_age_and_gaps(){
        compare(Freshness.describe(99000,100000,10000,false),"LIVE · 1s ago");
        compare(Freshness.describe(99000,100000,10000,true),"CACHED · 1s ago");
        compare(Freshness.describe(1000,100000,10000,true),"STALE · 1m ago");
        verify(Freshness.describe(0,100000,10000,true).startsWith("UNAVAILABLE"));
        verify(Freshness.describe(200000,100000,10000,true).startsWith("UNKNOWN"));
        const parts=Freshness.segments([10,20,30,null,40,50],[39000,99000,100000,101000,102000,103000],103000,60000);
        compare(parts.length,2);compare(parts[0].length,2);compare(parts[1].length,2);
        compare(parts[0][0].at,99000);compare(parts[1][0].value,40);
        compare(Freshness.segments([10,20],[99000,100000],100000,60000)[0].length,2);
        const gaps=Freshness.segments([10,20,30],[96000,97000,100000],100000,60000);
        compare(gaps.length,2);
        const missing=Directory.flatten(Directory.performance(),{},"gpu");
        verify(missing.find(n=>n.id==="gpu/thermals").availability==="unavailable");
    }
    function test_core_deltas(){
        const before=Samples.counters("cpu 99 0 0 99\ncpu0 10 0 10 80 0 0 0 0 99 99\ncpu1 0 0 0 100 0 0 0 0\n");
        const after=Samples.counters("cpu0 20 0 20 100 0 0 0 0 120 120\ncpu1 0 0 0 120 0 0 0 0\n");
        compare(Samples.cores(after,before)[0].percent,50);compare(Samples.cores(after,before)[1].percent,0);
        compare(Samples.cores(after,[])[0].percent,null);compare(Samples.cores(before,after)[0].percent,null);
        compare(Samples.counters("invalid").length,0);
    }
    function test_frequency_memory_pressure(){
        compare(Samples.frequency("cpu MHz : 2000\ncpu MHz : 3000").mhz,2500);verify(!Samples.frequency("no MHz on this architecture").available);
        const noSwap=Samples.memory("MemTotal: 100 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB");verify(noSwap.swapAvailable);compare(noSwap.swapTotalKib,0);
        verify(!Samples.memory("").swapAvailable);
        compare(Samples.pressure("some avg10=1.50 avg60=2.00 avg300=0.12 total=1234").avg10,1.5);verify(!Samples.pressure("").available);
    }
}
