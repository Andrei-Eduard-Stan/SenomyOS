"""Actual input page in an offscreen window, using the production state model
and inert responses. No input/compositor/IME/session endpoint is inherited.
"""
from pathlib import Path
import os,shutil,subprocess,tempfile,unittest
ROOT=Path(__file__).parents[1]
FIXTURE='''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components/control"
import "services"
Window {
    id:root; visible:true; width:390; height:760
    property int phase:0
    property int ticks:0
    property int mutations:0
    property int queries:0
    function check(ok,msg){if(!ok){console.log("FAIL "+msg);Qt.quit();throw new Error(msg);}}
    function values(){return {sensitivity:0,naturalScroll:false,tapToClick:true,layout:"gb",variant:"",usFallback:true,repeatRate:25,repeatDelay:600,mouseNaturalScroll:false,mouseScrollFactor:1,touchpadScrollFactor:1,disableWhileTyping:true,leftHanded:false};}
    InputPreferences {
        id:model
        onDispatch:(verb,payload,serial)=>{
            if(verb==="get")root.queries++;else root.mutations++;
            let v=root.values();let caps={};Object.keys(v).forEach(k=>caps[k]=true);
            let r={schemaVersion:2,ok:verb==="get",state:verb==="get"?"observed":"rejected",message:verb==="get"?"":"Hyprland rejected the change. No preference was saved.",effective:v,rawOptions:{"input:kb_layout":"gb,us","input:kb_variant":","},available:true,capabilities:caps,devices:[],fingerprint:"fixture",saved:{},persistence:"not-saved",firstRun:false,layouts:["gb","us"],variants:{gb:["","intl"],us:[""]},pending:{state:"none",token:""},requestId:String(serial)};
            Qt.callLater(()=>model.consume(JSON.stringify(r),verb==="get"?0:1,serial));
        }
    }
    QtObject { id:provider; property var preferences:model; property bool editorAvailable:false; property bool engineInstalled:false; property string nativeToolsMessage:""; property bool nativeToolsBusy:false; property var oskCapabilities:null; property var oskAutomatic:null; property var oskController:null }
    ControlInputPage { id:page; anchors.fill:parent; inputSettings:provider; part:"pointer" }
    TestCase { id:input; when:false }
    function geometry(){
        for(const name of ["control-pointer-sensitivity","control-natural-scroll","control-tap-click","control-repeat-rate","control-repeat-delay","control-keyboard-layout","control-keyboard-variant","control-input-preview"]){
            const item=input.findChild(page,name);check(!!item,"missing control "+name);
            if(item.visible){const pos=item.mapToItem(page,0,0);check(pos.x>=-1 && pos.x+item.width<=page.width+1,"horizontal overflow "+name);check(item.height>=40,"target height "+name);}
        }
    }
    Component.onCompleted:model.active=true
    Timer { interval:100; repeat:true; running:true; onTriggered:{
        root.ticks++;if(root.ticks>60){root.check(false,"deadline");return;}
        if(model.busy)return;
        if(root.phase===0){
            root.check(model.available,"initial read");root.geometry();
            const slider=input.findChild(page,"control-pointer-sensitivity");root.check(slider.enabled,"pointer enabled");input.mousePress(slider,slider.width/2,slider.height/2);input.mouseMove(slider,slider.width*0.7,slider.height/2);input.mouseRelease(slider,slider.width*0.7,slider.height/2);
            root.check(model.dirty && model.sensitivity===0 && root.mutations===0,"draft is inactive");
            const button=input.findChild(page,"control-input-preview");page.contentY=Math.max(0,button.mapToItem(page.contentItem,0,0).y-100);root.phase++;return;
        }
        if(root.phase===1){const b=input.findChild(page,"control-input-preview");input.mouseClick(b,b.width/2,b.height/2);root.phase++;return;}
        if(root.phase===2){
            root.check(model.state==="rejected" && model.draft.sensitivity===0,"rejected draft restored");
            root.check(input.findChild(page,"control-pointer-sensitivity").value===0,"slider rebound after refusal");
            page.part="keyboard";page.contentY=0;root.width=794;root.phase++;return;
        }
        if(root.phase===3){
            root.geometry();root.check(input.findChild(page,"control-repeat-delay").value===600,"repeat delay in actual milliseconds");const rate=input.findChild(page,"control-repeat-rate");root.check(rate.value===25,"initial repeat rate");rate.forceActiveFocus();input.keyClick(Qt.Key_Up);
            root.check(model.draft.repeatRate===26 && model.repeatRate===25,"rate draft");model.applyDraft("keyboard");root.phase++;return;
        }
        if(root.phase===4){
            root.check(model.state==="rejected" && input.findChild(page,"control-repeat-rate").value===25,"spinbox rebound after refusal");
            root.width=390;page.visible=false;model.active=false;root.phase++;return;
        }
        if(root.phase===5){page.visible=true;model.active=true;root.phase++;return;}
        if(root.phase===6){
            root.geometry();root.check(root.queries===2,"one query per open");root.check(root.mutations===2,"no duplicate submit");
            if(Quickshell.env("SENOMY_WP02_QA_OUT")){page.grabToImage(result=>{result.saveToFile(Quickshell.env("SENOMY_WP02_QA_OUT")+"/input-keyboard-390.png");root.width=794;page.part="pointer";page.contentY=0;root.phase++;});root.phase=99;return;}
            console.log("PASS production input page: drafts/refusal/rebind/close-reopen/390-794 geometry; no hardware calls");Qt.quit();return;
        }
        if(root.phase===100){page.grabToImage(result=>{result.saveToFile(Quickshell.env("SENOMY_WP02_QA_OUT")+"/input-pointer-794.png");console.log("PASS production input page: drafts/refusal/rebind/close-reopen/390-794 geometry; no hardware calls");Qt.quit();});root.phase=101;}
    }}
}
'''
class InputPageTests(unittest.TestCase):
    def test_native_page_with_inert_controller(self):
        with tempfile.TemporaryDirectory(prefix='senomy-wp02-page-') as temporary:
            p=Path(temporary);shell=p/'shell/quickshell';shutil.copytree(ROOT,shell,ignore=shutil.ignore_patterns('__pycache__'))
            # Read-only appearance fixture copy; no live file is watched or written.
            live=Path(os.environ.get('SENOMY_WP02_APPEARANCE_SOURCE',str(ROOT.parents[1]/'appearance')))
            if live.exists():
                shutil.copytree(live,p/'appearance',ignore=shutil.ignore_patterns('qa','mockups'))
                artwork=live.parent/'assets/senomy_island_expanded'
                if artwork.exists():shutil.copytree(artwork,p/'assets/senomy_island_expanded')
            (shell/'input-test.qml').write_text(FIXTURE);(p/'runtime').mkdir(mode=0o700)
            env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(p/'runtime'),XDG_CONFIG_HOME=str(p/'config'),XDG_STATE_HOME=str(p/'state'))
            for key in ['HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_DISPLAY','DISPLAY','DBUS_SESSION_BUS_ADDRESS']:env.pop(key,None)
            r=subprocess.run(['/usr/bin/dbus-run-session','--','/usr/bin/qs','--path',str(shell/'input-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=12);log=r.stdout+r.stderr
            self.assertEqual(r.returncode,0,log);self.assertIn('PASS production input page',log)
            self.assertNotRegex(log,r'FAIL |TypeError|ReferenceError|Binding loop|Cannot assign|Error loading configuration')
            print(next(line for line in log.splitlines() if 'PASS production input page' in line))
if __name__=='__main__':unittest.main(verbosity=2)
