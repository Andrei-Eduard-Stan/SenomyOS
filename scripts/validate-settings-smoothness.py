#!/usr/bin/env python3
"""Actual Settings pages with fake providers: async loading, resize/text/touch and draft guards."""
from pathlib import Path
import argparse,os,re,signal,subprocess,tempfile
from qa_remaining_hosts import prepare_hosts
repo=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('shell',nargs='?',type=Path,default=repo/'shell/quickshell')
parser.add_argument('out',nargs='?',type=Path,default=repo/'docs/qa/smoothness-20261108/settings')
args=parser.parse_args();source=args.shell.resolve();out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='senomy-settings-smoothness-') as directory:
    work=Path(directory);shell=prepare_hosts(source,work);runtime=work/'runtime';runtime.mkdir(mode=0o700)
    fixture=(source/'tests/fixtures/control-directory.qml').read_text().split('    Timer {interval:500',1)[0]
    fixture=fixture.replace('import "services"','import "services"\nimport "config" as Config')
    fixture=fixture.replace('network: ({connectionAttempt:', 'network: ({profiles:{busy:false,error:"",status:{devices:[]},items:[],actions:{locked:false}},connectionAttempt:')
    fixture+='''
    function waitReady(){
        const loader=input.findChild(panel,"control-page-loader");
        test.verify(loader.asynchronous,"page creation is asynchronous");
        for(let i=0;i<200&&loader.status!==Loader.Ready;i++)input.wait(10);
        test.verify(loader.status===Loader.Ready && !!loader.item,"page becomes ready");input.wait(20);return loader;
    }
    function controlBounds(item){
        if(!item.visible)return;
        if(item.activeFocusOnTab && item.enabled && item.width>0){
            const p=item.mapToItem(panel.contentArea,0,0);
            test.verify(p.x>=-1 && p.x+item.width<=panel.contentArea.width+1,"horizontal control bounds "+item.objectName);
        }
        for(const child of item.children)controlBounds(child);
    }
    Timer {interval:400;running:true;onTriggered:{
        const original=Config.Skin.registry,loads=[];
        for(const profile of [{scale:1,touch:false},{scale:1.5,touch:false},{scale:1.5,touch:true}]){
            Config.Skin.registry=Object.assign({},original,{persona:Object.assign({},original.persona||{},{uiTextScale:profile.scale,reducedMotion:true})});
            Config.DirectoryStyle.touchMode=profile.touch;
            for(const width of [390,640,1120]){
                test.width=width;test.height=740;input.wait(30);
                for(const route of ["overview","devices/displays","audio/diagnostics","input"]){
                    const started=Date.now();test.verify(panel.navigateId(route),"navigate "+route);test.waitReady();loads.push({width:width,scale:profile.scale,touch:profile.touch,route:route,readyMs:Date.now()-started});
                    test.controlBounds(panel.contentArea);
                    const trigger=input.findChild(panel,"context-menu-trigger");test.verify(trigger.width>=38 && (!profile.touch || trigger.height>=48),"header menu touch target");
                    if(route==="devices/displays"&&profile.scale===1.5)test.capture("settings-displays-"+width+"-"+(profile.touch?"touch":"text"),panel);
                }
            }
        }
        // Closing during incubation must release the subtree, including queued work.
        for(let i=0;i<20;i++){
            state.activePrimary="control";panel.navigateId(i%2?"devices/displays":"input");
            state.activePrimary="";input.wait(5);
            const loader=input.findChild(panel,"control-page-loader");test.verify(loader.status===Loader.Null && loader.item===null,"close cancels incubation and releases page");
        }
        state.activePrimary="control";
        // Replacing an unfinished load must admit only the final route.
        for(const route of ["appearance/backgrounds","audio/diagnostics","devices/displays","input","overview","input"])
            test.verify(panel.navigateId(route),"rapid route accepted");
        test.waitReady();test.verify(panel.routeId==="input" && !!input.findChild(panel.contentArea,"control-keyboard-layout"),"latest route wins async replacement");
        const keyboard=input.findChild(panel.contentArea,"control-keyboard-layout");keyboard.forceActiveFocus();input.wait(40);
        let ancestor=keyboard.parent;while(ancestor && ancestor!==panel.contentArea){if(ancestor.clip){const p=keyboard.mapToItem(ancestor,0,0);test.verify(p.y>=-1 && p.y+keyboard.height<=ancestor.height+1,"large-text keyboard focus is scrolled into view");}ancestor=ancestor.parent;}
        panel.navigateId("appearance/backgrounds");test.waitReady();
        const field=input.findChild(panel.contentArea,"backgroundSource");test.verify(!!field,"draft field");field.forceActiveFocus();input.keyClick(Qt.Key_A);input.wait(40);
        test.verify(!panel.navigateId("input") && panel.deferredNode==="input","dirty page is guarded during async navigation");
        test.verify(test.mutations===0,"no provider writes");
        Config.Skin.registry=original;Config.DirectoryStyle.touchMode=false;
        console.log("RESULT "+JSON.stringify({loads:loads}));console.log("PASS: 36 real Settings page loads, 390/640/1120 widths, 100/150 percent type, touch targets, rapid replacement/close cancellation, keyboard scrolling and dirty-draft guard; no provider mutations");Qt.quit();
    }}
}
'''
    (shell/'settings-smoothness.qml').write_text(fixture)
    env=dict(os.environ,LANG='C.UTF-8',QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'),SENOMY_QA_OUT=str(out))
    for key in ['WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(key,None)
    process=subprocess.Popen(['dbus-run-session','--','qs','-p',str(shell/'settings-smoothness.qml'),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
    try:stdout,stderr=process.communicate(timeout=45)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid,signal.SIGTERM)
        try:stdout,stderr=process.communicate(timeout=3)
        except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL);stdout,stderr=process.communicate()
        (out/'settings.log').write_text(stdout+stderr);raise SystemExit('Private Settings fixture timed out')
    log=stdout+stderr;(out/'settings.log').write_text(log)
    if process.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign',log):raise SystemExit(log)
    print(next(line for line in log.splitlines() if 'PASS:' in line))
