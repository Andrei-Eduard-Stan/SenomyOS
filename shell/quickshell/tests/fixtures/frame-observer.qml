import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "config" as Config
Window {
    id:test;visible:true;width:320;height:200;color:"black"
    TestCase {id:input;when:false}
    Rectangle {id:card;width:100;height:100;color:"white";opacity:0}
    NumberAnimation {id:reveal;target:card;property:"opacity";from:0;to:1;duration:190}
    FrameObserver {id:observer;targetItem:test.contentItem;key:"fixture";requested:false}
    FrameObserver {id:lateObserver;targetItem:null;key:"late-window";requested:false}
    function check(ok,msg){if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw Error(msg);}}
    Timer {interval:250;running:true;onTriggered:{
        Config.RenderMetrics.start();observer.requested=true;reveal.start();input.wait(260);
        Config.RenderMetrics.pageReady("fixture");observer.contentKey="second";observer.requested=false;
        const snapshot=Config.RenderMetrics.snapshot(),row=snapshot.transitions[0];
        test.check(snapshot.transitions[1].origin==="content-change","route changes have their own transition record");
        test.check(row && row.origin==="request" && row.closed,"request origin and close recorded");
        test.check(row.firstFrameMs!==null && row.frameIntervalsMs.length>0,"actual queued-frame callbacks recorded");
        lateObserver.requested=true;input.wait(30);lateObserver.targetItem=test.contentItem;card.color="red";input.wait(60);
        const delayed=Config.RenderMetrics.snapshot().transitions.filter(row=>row.key==="late-window");
        test.check(delayed.length===1 && delayed[0].origin==="request" && delayed[0].firstFrameMs>=30,"native window arrival preserves the request clock");lateObserver.requested=false;
        const count=row.frameIntervalsMs.length;Config.RenderMetrics.stop();reveal.restart();input.wait(230);test.check(Config.RenderMetrics.snapshot().transitions[0].frameIntervalsMs.length===count,"stopped observer does not record");
        console.log("RESULT "+JSON.stringify(snapshot));console.log("PASS: passive frame observation, opening timing, bounded intervals and no recording after stop");Qt.quit();
    }}
}
