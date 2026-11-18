import QtQuick
import QtTest
import "../config" as Config
TestCase {
    name:"RenderMetrics"
    function cleanup(){Config.RenderMetrics.stop();}
    function test_passive_and_stopped(){
        Config.RenderMetrics.stop();compare(Config.RenderMetrics.begin("fixture","request"),null);
        Config.RenderMetrics.start();const row=Config.RenderMetrics.begin("fixture","request");
        verify(row!==null);row.requestedAt=Date.now()-20;Config.RenderMetrics.frame(row);
        verify(row.firstFrameMs>=20);Config.RenderMetrics.stop();const count=row.intervals.length;Config.RenderMetrics.frame(row);compare(row.intervals.length,count);
    }
    function test_bounds_and_stale_rows(){
        Config.RenderMetrics.start();const old=Config.RenderMetrics.begin("fixture","request");Config.RenderMetrics.start();Config.RenderMetrics.frame(old);compare(Config.RenderMetrics.snapshot().transitions.length,0);
        for(let i=0;i<64;i++)verify(Config.RenderMetrics.begin("fixture","request")!==null);
        compare(Config.RenderMetrics.begin("overflow","request"),null);compare(Config.RenderMetrics.snapshot().droppedTransitions,1);
        const row=Config.RenderMetrics.transitions[0];row.lastFrameAt=Date.now();row.intervals=Array(2048).fill(16);Config.RenderMetrics.frame(row);compare(row.intervals.length,2048);
    }
    function test_missing_and_sample_statistics(){
        Config.RenderMetrics.start();const row=Config.RenderMetrics.begin("fixture","request");
        compare(Config.RenderMetrics.snapshot().transitions[0].firstFrameMs,null);
        row.intervals=[16,17,16,40,16];Config.RenderMetrics.pageReady("fixture");
        const summary=Config.RenderMetrics.snapshot().transitions[0];compare(summary.p50IntervalMs,16);compare(summary.p95IntervalMs,40);verify(summary.pageReadyMs!==null);
        row.closed=true;const count=row.intervals.length;Config.RenderMetrics.frame(row);compare(row.intervals.length,count);
    }
}
