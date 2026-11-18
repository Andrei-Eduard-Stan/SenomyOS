import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
Window {
    id:test;visible:true;width:600;height:740;color:"#080a0c"
    TestCase {id:input;when:false}
    property var fakeInsights:({payloads:{diagnosticsResult:{data:{title:"Fixture result",output:["Sanitized evidence"]}},reports:{ok:true,data:{exists:true,latest:{profile_label:"Overview"},preview:[{line_no:1,text:"Sanitized preview"}],history_count:1}}},actionState:"idle",busy:false,tasksFor:function(){return [{code:"FIX",title:"Safe task",summary:"Fixture",id:"safe"}];},refresh:function(){},runTask:function(){}})
    DirectoryMetric {id:metric;width:400;height:140;title:"CPU";value:"17%";detail:"Fixture evidence"}
    DirectoryTaskView {id:tasks;width:600;height:740;visible:false;insights:test.fakeInsights;domain:"diagnostics"}
    DirectoryReportsView {id:reports;width:600;height:740;visible:false;insights:test.fakeInsights}
    function capture(name,item){let done=false;item.grabToImage(result=>{result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;});while(!done)input.wait(10);}
    Timer {interval:250;running:true;onTriggered:{
        test.capture("shared-metric",metric);metric.visible=false;tasks.visible=true;input.wait(40);test.capture("shared-tasks",tasks);tasks.visible=false;reports.visible=true;input.wait(40);test.capture("shared-reports",reports);
        console.log("PASS: unchanged default Performance shared metric/task/report projections");Qt.quit();
    }}
}
