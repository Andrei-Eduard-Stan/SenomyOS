#!/usr/bin/env python3
"""Render actual greeter content with fake SDDM models; no authentication bus."""
from pathlib import Path
import os,re,shutil,subprocess,tempfile,sys,signal
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='senomy-login-screens-') as directory:
    temp=Path(directory)
    theme=temp/'theme';shutil.copytree((Path(sys.argv[1]) if len(sys.argv)>1 else root/'appearance/login/sddm/senomyos'),theme)
    main=theme/'Main.qml';text=main.read_text().replace('    id: root','    id: root\n    property var screenModel\n    property var sessionModel\n    property var userModel\n    property var config\n    property var sddm\n    property var keyboard',1)
    main.write_text(text)
    (temp/'test.qml').write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "theme" as Login
Window {
 id:test;visible:true;width:Quickshell.env("SENOMY_LOGIN_START_SHORT")==="1"?640:1920;height:Quickshell.env("SENOMY_LOGIN_START_SHORT")==="1"?360:1080
 property int mutations:0
 property var logins:[]
 TestCase {id:input;when:false}
 ListModel {id:screens;property int primary:-1}
 QtObject {id:viewportGeometry;property real x:0;property real y:0;property real width:test.width;property real height:test.height}
 property var retainedCredential:null
 QtObject {id:sessions;property var entries:[{name:"Hyprland",file:"hyprland.desktop",type:"wayland"},{name:"Plasma",file:"plasma.desktop",type:"wayland"},{name:"Senomy Recovery",file:"senomy-recovery.desktop",type:"x11"}];readonly property int count:entries.length;property int lastIndex:0;function index(i,j){return i;}function data(i,r){const row=entries[i];return !row?null:r===257?"/fixture/"+row.type:r===258?row.file:r===259?row.type:row.name;}}
 ListModel {
  id:users;property string lastUser:"fixture"
  ListElement {name:"fixture";realName:"Fixture Account";icon:"file:///not-present/avatar.png"}
  ListElement {name:"second";realName:"Second Account";icon:""}
  ListElement {name:"senomy-recovery";realName:"Recovery";icon:""}
  function index(i,j){return i;}
  function data(i,role){const row=get(i);return role===257?row.name:role===258?row.realName:role===260?row.icon:"";}
 }
 QtObject {id:configuration;function stringValue(key){return key==="PreviewUser"?"fixture":"";}function boolValue(key){return key==="ShowRecovery";}}
 QtObject {id:proxy;property bool canPowerOff:false;property bool canReboot:false;signal loginFailed();signal loginSucceeded();signal informationMessage(string message);function login(user,password,session){test.logins.push({user:user,password:password,session:session});}function powerOff(){test.mutations++;}function reboot(){test.mutations++;}}
 QtObject {id:keys;property var layouts:[{shortName:"gb"},{shortName:"us"},{shortName:"de"}];property int currentLayout:0;property bool capsLock:false}
 Login.Main {id:login;anchors.fill:parent;screenModel:screens;sessionModel:sessions;userModel:users;config:configuration;sddm:proxy;keyboard:keys}
 function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
 function passwordVisible(item){if(item.echoMode===TextInput.Password && item.visible && item.enabled)return true;for(const child of item.children){if(passwordVisible(child))return true;}return false;}
 function named(item,name){if(item.objectName===name)return item;for(const child of item.children){const found=named(child,name);if(found)return found;}return null;}
 function screen(item){if(item.controlsVisible!==undefined)return item;for(const child of item.children){const found=screen(child);if(found)return found;}return null;}
 function settle(){
  for(let i=0;i<180;i++){
   const backdrop=named(login,"greeter-backdrop"),frame=named(login,"authored-auth-frame");
   if(backdrop && backdrop.renderReady && frame && (!frame.artwork || frame.artworkReady)){input.wait(80);return;}
   input.wait(20);
  }
  const back=named(login,"greeter-backdrop"),art=named(login,"authored-auth-frame");
  check(false,"actual artwork loaded: backdrop="+(back?back.renderReady+" gpu="+back.gpuBlur+" raw="+back.imageReady:"missing")+" frame="+(art?art.artworkReady:"missing"));
 }
 function capture(name){if(!Quickshell.env("SENOMY_QA_OUT"))return;settle();const output=screen(login);check(output && Math.abs(output.width-test.width)<1 && Math.abs(output.height-test.height)<1,"capture screen geometry current");let done=false;test.contentItem.grabToImage(result=>{check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture "+name);done=true;});for(let i=0;i<200&&!done;i++)input.wait(10);check(done,"capture complete");}
 function credentialBounds(label){
  input.wait(100);const field=named(login,"compact-password"),show=named(login,"compact-reveal"),viewport=named(login,"credential-viewport");
  check(!!field && !!viewport && field.activeFocus,label+" password owns focus");
  for(const item of [field,show]){const p=item.mapToItem(viewport,0,0);check(p.x>=-1 && p.x+item.width<=viewport.width+1 && p.y>=7 && p.y+item.height<=viewport.height-7,label+" complete password/Show inside clipped viewport");}
 }
 Timer {interval:150;running:true;onTriggered:{
  if(Quickshell.env("SENOMY_LOGIN_START_SHORT")==="1"){
   screens.append({geometry:viewportGeometry});input.wait(180);test.credentialBounds("initial short display");test.capture("login-short-initial");
  }

  for(const size of [{w:1920,h:1080},{w:1366,h:768},{w:800,h:1000},{w:360,h:640},{w:640,h:360}]){
   test.width=size.w;test.height=size.h;
   if(!screens.count)screens.append({geometry:viewportGeometry});input.wait(100);
   const output=test.screen(login);test.check(output && output.visible,"secondary output exposes login controls");
   test.check(test.passwordVisible(output),"secondary greeter password field is visible and enabled");
   screens.primary=0;input.wait(20);test.check(test.passwordVisible(output),"primary greeter remains available");
   if(size.w===640 && size.h===360)test.credentialBounds("resize into short display");
   test.capture("login-"+size.w+"x"+size.h);

  }
  test.check(login.headingFontReady,"bundled OFL heading font loads from theme data");
  test.check(login.accountDisplayName==="Fixture Account","real SDDM display-name roles feed account identity");
  test.check(login.accountIcon==="file:///not-present/avatar.png","model supplies a local avatar; missing image uses bounded fallback");
  login.userChooserOpen=true;input.wait(50);test.capture("login-account-picker");const choice=test.named(login,"login-user-second");test.check(choice && choice.visible,"normal user available in actual picker");
  choice.clicked();input.wait(50);test.check(login.currentUser()==="second" && !login.userChooserOpen,"picker changes account without authentication");test.credentialBounds("restored short credentials");test.capture("login-short-restored");
  login.selectNextNormalSession();test.check(login.sessionName(login.selectedSessionIndex)==="Plasma","compact session selection changes to real normal session");
  login.selectNextNormalSession();test.check(login.sessionName(login.selectedSessionIndex)==="Hyprland","normal session selection excludes recovery");
  login.selectNextKeyboardLayout();login.selectNextKeyboardLayout();test.check(login.keyboardLayoutLabel()==="DE","keyboard selector includes layouts beyond GB and US");
  const sessionButton=test.named(login,"compact-session");sessionButton.forceActiveFocus();input.keyClick(Qt.Key_Return);input.wait(30);input.wait(80);test.capture("login-session-choices");const plasma=test.named(login,"session-choice-1");test.check(plasma && plasma.visible,"explicit session choice opens");plasma.clicked();test.check(login.sessionName(login.selectedSessionIndex)==="Plasma","explicit choice chooses exact session");login.selectNormalSession(0);
  const layoutButton=test.named(login,"compact-layout");layoutButton.forceActiveFocus();input.keyClick(Qt.Key_Return);input.wait(30);test.capture("login-layout-choices");test.named(login,"layout-choice-1").clicked();test.check(login.keyboardLayoutLabel()==="US","explicit keyboard choice includes all layouts");
  keys.capsLock=true;input.wait(20);test.check(login.capsLock,"real keyboard Caps Lock state reaches password label");
  const password=test.named(login,"compact-password");password.text="disposable-fixture-credential";
  login.attemptLogin(password);test.check(test.logins.length===1 && test.logins[0].user==="second" && test.logins[0].session===0,"only SDDM proxy receives selected identity and session");
  test.check(password.text==="" && login.authenticating,"credential scrubbed immediately after proxy handoff");test.capture("login-authenticating");
  password.text="other-fixture";login.attemptLogin(password);test.check(test.logins.length===1,"pending authentication cannot be resubmitted");
  proxy.loginFailed();input.wait(30);test.check(!login.authenticating && password.text==="","failed authentication scrubs inputs and permits retry");
  test.capture("login-failure");
  const originalSessions=sessions.entries;test.logins=[];login.selectNormalSession(0);sessions.entries=[originalSessions[1],originalSessions[0],originalSessions[2]];password.text="disposable-reorder";login.attemptLogin(password);test.check(test.logins.length===1 && test.logins[0].session===1,"session reorder resolves stable original identity");proxy.loginFailed();sessions.entries=originalSessions;login.selectNormalSession(1);sessions.entries=[originalSessions[0],originalSessions[2]];test.logins=[];password.text="disposable-removed";login.attemptLogin(password);test.check(test.logins.length===0 && password.text==="" && !login.authenticating,"removed selected session refuses handoff and scrubs credential");sessions.entries=originalSessions;login.selectNormalSession(0);
  login.userChooserOpen=true;input.wait(30);const accountSearch=test.named(login,"account-picker-search");accountSearch.text="second";test.capture("login-account-search");accountSearch.forceActiveFocus();input.keyClick(Qt.Key_Return);input.wait(30);test.check(login.currentUser()==="second" && !login.userChooserOpen && test.logins.length===0,"local account search selects without authentication");
  test.logins=[];login.selectAccount("");test.check(login.normalUser==="" && login.currentUser()==="","manual-account fallback remains available");
  login.typedUser="second";password.text="disposable-fixture-credential";login.attemptLogin(password);proxy.loginSucceeded();input.wait(20);
  test.check(login.sessionStarting && login.authenticating && password.text==="","successful authentication locks controls during session handoff");
  proxy.loginFailed();test.logins=[];
  password.text="disposable-fixture";login.beginRecovery(password);
  test.check(login.recoveryMode && login.currentUser()==="senomy-recovery" && login.selectedSessionIndex===2 && password.text==="","recovery remains separately selected and scrubs credentials");
  password.text="disposable-recovery";login.attemptLogin(password);
  test.check(test.logins.length===1 && test.logins[0].user==="senomy-recovery" && test.logins[0].session===2,"recovery uses only the fake authenticated proxy");
  proxy.loginFailed();login.beginRecovery(password);test.check(!login.recoveryMode && login.selectedSessionIndex===0,"return from recovery selects normal session");
  password.text="fixture";login.activateUtility("POWER",password);input.wait(40);
  const cancel=test.named(login,"compact-confirm-cancel"),confirm=test.named(login,"compact-confirm-apply");
  test.check(password.text==="" && cancel.activeFocus,"power review scrubs credentials and focuses Cancel");test.capture("login-power-review");
  input.keyClick(Qt.Key_Tab);input.wait(20);test.check(confirm.activeFocus,"modal Tab stays within review");
  cancel.clicked();input.wait(40);test.check(login.confirmationAction==="" && (password.activeFocus || test.named(login,"compact-username").activeFocus),"cancel restores credential focus without power operation");
  for(const size of [{w:360,h:640},{w:800,h:1000}]){
   test.width=size.w;test.height=size.h;screens.clear();screens.append({geometry:viewportGeometry});
   login.accessibilityMode=true;input.wait(80);const currentPassword=test.named(login,"compact-password");currentPassword.forceActiveFocus();input.wait(50);
   const pos=currentPassword.mapToItem(test.contentItem,0,0);
   test.check(pos.x>=0 && pos.x+currentPassword.width<=test.width && pos.y>=0 && pos.y+currentPassword.height<=test.height,"readability mode keeps focused credential field on output");test.capture("login-readable-"+size.w);
  }
  login.accessibilityMode=false;
  test.check(test.mutations===0,"no real authentication, account or power mutation in fixture");
  test.logins=[];
  console.log("PASS: actual SDDM theme on primary/secondary, desktop/narrow/short layouts, account/session/layout selection and fake-only credential lifecycle");Qt.quit();
 }}
}
''')
    if os.environ.get("SENOMY_QA_OUT"):Path(os.environ["SENOMY_QA_OUT"]).mkdir(parents=True,exist_ok=True)
    runtime=temp/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_DATA_HOME=str(temp/'data'),XDG_CONFIG_HOME=str(temp/'config'),XDG_STATE_HOME=str(temp/'state'))
    for key in ['DISPLAY','WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','DBUS_SESSION_BUS_ADDRESS']:env.pop(key,None)
    process=subprocess.Popen(['dbus-run-session','--','qs','--path',str(temp/'test.qml'),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
    try: stdout,stderr=process.communicate(timeout=40)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid,signal.SIGTERM)
        stdout,stderr=process.communicate(timeout=3)
        raise SystemExit('Private greeter fixture timed out:\n'+(stdout+stderr)[-5000:])
    log=stdout+stderr
    if process.returncode or re.search('FAIL:|ERROR|TypeError|ReferenceError|Binding loop',log):raise SystemExit(log)
    print(next(line for line in log.splitlines() if 'PASS:' in line))
