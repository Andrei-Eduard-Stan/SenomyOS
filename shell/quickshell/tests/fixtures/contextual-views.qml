import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
Window {
    id:test;visible:true;width:600;height:740;color:"#080a0c"
    property int refreshes:0
    property int opens:0
    property int runs:0
    property int generations:0
    TestCase {id:input;when:false}
    QtObject {
        id:insights
        property string actionMessage:""
        property string actionDomain:""
        property var statuses:({})
        property bool busy:false
        property string actionState:"idle"
        property var payloads:({diagnosticsResult:{data:{title:"Fixture result",output:["Sanitized evidence"]}},reports:{ok:true,data:{exists:true,latest:{profile_label:"Overview"},preview:[{line_no:1,text:"Sanitized preview"}],history_count:1}}})
        function tasksFor(domain){return [{code:"FIX",title:"Safe task",summary:"Fixture",id:"safe"}];}
        function refresh(domain,force){test.check(domain==="diagnostics"&&!force,"refresh route");test.refreshes++;}
        function runTask(domain,id){test.runs++;}
        function openLatestReport(){test.opens++;}
        function generateReport(profile){test.generations++;}
    }
    DirectoryTaskView {id:tasks;width:parent.width;height:parent.height;contextualActions:true;insights:insights;domain:"diagnostics"}
    DirectoryReportsView {id:reports;width:parent.width;height:parent.height;visible:false;contextualActions:true;insights:insights}
    function check(ok,msg){if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw Error(msg);}}
    function findText(item,text){if(item.text===text)return item;for(const child of item.children){const found=findText(child,text);if(found)return found;}return null;}
    function capture(name){let done=false;test.contentItem.grabToImage(result=>{result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;});while(!done)input.wait(10);}
    Timer {interval:350;running:true;onTriggered:{
        const tasksTrigger=input.findChild(tasks,"context-menu-trigger");const tasksMenu=tasksTrigger.parent;
        test.check(tasksTrigger.width>=38 && tasksTrigger.height>=38,"relocated menu has visible target allocation");
        test.check(!test.findText(tasks,"REFRESH TASKS").visible,"task refresh relocated");
        tasksMenu.open();input.wait(50);test.capture("04-insights-diagnostics-menu");input.keyClick(Qt.Key_Escape);input.wait(20);
        test.check(tasksMenu.invoke("refresh") && test.refreshes===1,"refresh invokes existing service");
        insights.busy=true;input.wait(20);test.check(!tasksMenu.invoke("refresh"),"busy refresh blocked");insights.busy=false;
        const task=test.findText(tasks,"FIX // Safe task");test.check(task.visible && task.enabled,"primary run control stays direct");input.mouseClick(task,20,20);test.check(test.runs===1,"primary run works");
        tasks.visible=false;reports.visible=true;input.wait(40);
        const reportMenu=input.findChild(reports,"context-menu-trigger").parent;
        test.check(!test.findText(reports,"OPEN LATEST").visible,"open latest relocated");
        test.check(!input.findChild(reports,"report-menu-private-evidence-reports").visible,"redundant summary menu removed");
        reportMenu.open();input.wait(50);test.capture("05-insights-reports-menu");input.keyClick(Qt.Key_Escape);input.wait(20);
        test.check(reportMenu.invoke("open") && test.opens===1,"open uses existing report service");
        const generate=test.findText(reports,"GENERATE OVERVIEW");test.check(generate.visible && generate.enabled,"primary report generation stays direct");input.mouseClick(generate,20,20);test.check(test.generations===1,"generation works");
        insights.actionState="running";input.wait(20);test.check(!reportMenu.invoke("open"),"running open blocked");insights.actionState="idle";
        insights.payloads={reports:{ok:true,data:{exists:false}}};input.wait(20);test.check(!reportMenu.invoke("open")&&!reportMenu.invoke("copy")&&!reportMenu.invoke("text"),"missing report cannot invoke any result action");
        console.log("PASS: actual Insights task/report views, relocated refresh/open callbacks, busy/empty guards and direct run/generate controls");Qt.quit();
    }}
}
