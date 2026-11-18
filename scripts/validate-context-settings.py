#!/usr/bin/env python3
"""Settings overflow contents and pinning on a private native host."""
from pathlib import Path
import os,sys,subprocess,tempfile,shutil,re
from qa_remaining_hosts import prepare_hosts
source=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='overflow-control-') as directory:
 work=Path(directory);copied=prepare_hosts(source,work);runtime=work/'runtime';runtime.mkdir(mode=0o700)
 fixture=(source/'tests/fixtures/control-directory.qml').read_text();fixture=fixture.replace('network: ({connectionAttempt:', 'network: ({profiles:{busy:false,error:"",status:{devices:[]},items:[],actions:{locked:false}},connectionAttempt:')
 fixture=fixture[:fixture.index('    Timer {interval:500')]+'''
    Timer {interval:500;running:true;onTriggered:{
        for(const size of [{w:1120,h:820},{w:390,h:640}]){
            test.width=size.w;test.height=size.h;input.wait(60);
            for(const route of ["devices/displays","network","input"]){
                test.verify(panel.navigateId(route),"route "+route);input.wait(60);
                const menu=input.findChild(panel,"control-page-menu");test.verify(!!menu,"menu owner");
                const trigger=input.findChild(menu,"context-menu-trigger") || input.findChild(menu,"report-menu-control-"+state.controlSection);
                test.verify(!!trigger,"menu trigger");input.mouseClick(trigger,16,16);input.wait(60);
                test.capture("control-"+route.replace("/","-")+"-"+size.w,test.contentItem);
                if(menu.actions!==undefined){const popup=input.findChild(menu,"context-action-popup");console.log("POSITION "+JSON.stringify({anchor:popup.anchorPoint,x:popup.x,y:popup.y,w:popup.width,h:popup.height,trigger:trigger.mapToItem(test.contentItem,0,0)}));}
                input.keyClick(Qt.Key_Escape);input.wait(40);
                if(menu.actions!==undefined){
                    const ids=menu.actions.map(a=>a.id);
                    test.verify(!ids.includes("text")&&!ids.includes("snapshot"),"no generic exports");
                    test.verify(ids.includes("pin"),"pin retained");
                    if(route==="input")test.verify(ids.join()==="pin","input only pin");
                    state.controlPins=["one","two","three","four","five","six","seven","eight"];input.wait(20);test.verify(!menu.invoke("pin"),"pin capacity blocked");state.controlPins=[];
                    test.verify(menu.invoke("pin") && state.controlPins.includes(panel.routeId),"pin uses original session action");
                    test.verify(menu.invoke("pin") && state.controlPins.length===0,"unpin works at same route");
                }
            }
        }
        if(typeof panel.displayEvidence === "function"){
            const original=inventory.displays;
            inventory.displays=[{name:"Fixture-1",width:1920,height:1080,refreshRate:60,scale:1,x:0,y:0,transform:0,disabled:false,mirrorOf:"",key:"PRIVATE-ID",serial:"PRIVATE-SERIAL"}];
            const evidence=panel.displayEvidence();test.verify(evidence.displays[0].width===1920,"observed display fields");test.verify(!JSON.stringify(evidence).includes("PRIVATE"),"display identities excluded");inventory.displays=original;
            test.verify(panel.connectionEvidence().connection===null,"unavailable connection is not fabricated");
        }
        test.verify(test.mutations===0,"no provider writes");
        console.log("PASS: contextual Settings menus at wide/portrait sizes; generic actions absent, real session pin/unpin and capacity guard; no provider mutations");Qt.quit();
    }}
}
'''
 (copied/'overflow-control.qml').write_text(fixture)
 env=dict(os.environ,LANG='C.UTF-8',QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'),SENOMY_QA_OUT=str(out));env.pop('WAYLAND_DISPLAY',None)
 r=subprocess.run(['dbus-run-session','--','qs','-p',str(copied/'overflow-control.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=25);log=r.stdout+r.stderr;(out/'control.log').write_text(log);print(next((line for line in log.splitlines() if 'PASS:' in line), log))
 if r.returncode or 'PASS:' not in log or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign',log):raise SystemExit(log)
