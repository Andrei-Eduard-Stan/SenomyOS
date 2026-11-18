#!/usr/bin/env python3
"""Actual account form with fake service; no provider connection or file writes."""
from pathlib import Path
import sys
import os,re,shutil,subprocess,tempfile,struct,zlib
root=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="senomy-account-ui-") as directory:
    temp=Path(directory);shell=temp/"shell/quickshell";shutil.copytree(root/"shell/quickshell",shell,ignore=shutil.ignore_patterns("__pycache__"))
    for n in ["assets","appearance"]:(temp/n).symlink_to(root/n,target_is_directory=True)
    (shell/"account-page-test.qml").write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components/control" as Control
import "config" as Config
Window {
 id:test;visible:true;width:700;height:800
 TestCase {id:input;when:false}
 QtObject {
  id:service;property bool available:true;property bool loading:false;property bool locked:false
  property var snapshot:({currentUid:2001,message:"Fixture account provider",complete:true})
  property var accounts:[{uid:2001,name:"Fixture",username:"fixture",current:true,locked:false,administrator:true,managed:true},{uid:2002,name:"Second",username:"second",current:false,locked:false,administrator:false,managed:true}]
  property string actionState:"idle";property string operation:"";property var target:null;property string proposed:"";property string message:""
  function cancel(){actionState="idle";}
  function refresh(){}
 }
 Control.ControlAccountsPage {id:page;anchors.fill:parent;service:service}
 function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
 Timer {interval:300;running:true;onTriggered:{
  const field=input.findChild(page,"account-display-name");test.check(field && field.text==="Fixture" && !page.dirty,"current account loads without a draft");
  field.forceActiveFocus();input.keyClick(Qt.Key_End);input.keyClick(Qt.Key_A);input.wait(20);const draft=field.text;test.check(page.dirty,"typed display name becomes a guarded draft");
  service.accounts=JSON.parse(JSON.stringify(service.accounts));input.wait(20);test.check(field.text===draft,"periodic equal account readback does not erase typed input");
  service.accounts=[Object.assign({},service.accounts[0],{name:"External name"}),service.accounts[1]];input.wait(20);test.check(field.text===draft,"external name change preserves user proposal until reviewed or reset");
  service.available=false;input.wait(10);test.check(page.dirty && field.text===draft,"provider loss preserves dirty form and its guard");service.available=true;
  page.selectAccount(2002);test.check(page.selectedUid===2001 && page.deferredAccount===2002,"changing account defers behind unsaved form");
  page.load();test.check(!page.dirty && field.text==="External name","explicit reset loads actual provider name");
  page.selectAccount(2002);input.wait(20);test.check(page.selectedUid===2002 && field.text==="Second","clean account selection loads correct identity");
  test.check(!page.chooseAvatar("https://example.invalid/picture.png"),"remote pictures are rejected without a request");
  test.check(page.chooseAvatar(Quickshell.env("SENOMY_AVATAR_TEST_URL")),"native local URL is accepted as a proposal");
  input.wait(600);test.check(page.avatarInfo.path===Quickshell.env("SENOMY_AVATAR_TEST_PATH"),"bounded PNG preview validates local paths with spaces and reserved URL characters");
  test.check(page.dirty,"picture choice stays guarded until confirmation");page.load();test.check(!page.dirty && !page.avatarInfo.path,"discard clears preview without applying it");
  if(Quickshell.env("SENOMY_QA_OUT")){
   for(const width of [700,390]){
    test.width=width;page.showAdministration=true;input.wait(30);page.grabToImage(result=>result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/accounts-"+width+".png"));input.wait(60);
   }
   Config.Skin.registry=Object.assign({},Config.Skin.registry,{persona:Object.assign({},Config.Skin.registry.persona,{uiTextScale:1.5,highContrast:true})});input.wait(30);
   page.grabToImage(result=>result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/accounts-large-contrast.png"));input.wait(60);
  }
  console.log("PASS: actual account form preserves typed drafts across refresh/external updates, defers account selection and resets to actual state");Qt.quit();
 }}
}
''')
    picture=temp/"picture #?.png"
    def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    picture.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b'\x00\xff\xff\xff\xff'))+chunk(b'IEND',b''))
    runtime=temp/"runtime";runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software",XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(temp/"config"),XDG_STATE_HOME=str(temp/"state"))
    env.update(SENOMY_AVATAR_TEST_URL=picture.as_uri(),SENOMY_AVATAR_TEST_PATH=str(picture))
    for key in ["WAYLAND_DISPLAY","HYPRLAND_INSTANCE_SIGNATURE"]:env.pop(key,None)
    r=subprocess.run(["dbus-run-session","--","qs","--path",str(shell/"account-page-test.qml"),"--no-color"],env=env,capture_output=True,text=True,timeout=6)
    log=r.stdout+r.stderr
    if r.returncode or re.search(r"FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign",log):raise SystemExit(log)
    print(next(line for line in log.splitlines() if "PASS:" in line))

    shutil.copy2(root/'shell/quickshell/tests/fixtures/account-service.qml',shell/'account-service-test.qml')
    (temp/'fixture').mkdir();env['SENOMY_PRIVATE_ACCOUNT_FIXTURE']=str(temp/'fixture')
    r=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/'account-service-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=8)
    log=r.stdout+r.stderr
    if r.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign',log) or 'PASS:'not in log:raise SystemExit(log)
    pid=int((temp/'fixture/pid').read_text())
    if Path('/proc',str(pid)).exists():raise SystemExit('Private account watcher leaked after fixture exit')
    print(next(line for line in log.splitlines()if'PASS:'in line))
