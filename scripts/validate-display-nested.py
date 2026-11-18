#!/usr/bin/env python3
"""Real Lua IPC integration in a disposable, render-only nested compositor.

Physical DRM card nodes are hidden by bubblewrap. All hyprctl requests target
an instance discovered only beneath this test's private runtime directory.
"""
raise SystemExit("DISABLED: nested compositor QA requires isolation review after the 2026-10-16 session incident. Use mocked display tests.")

from pathlib import Path
import importlib.util
import json
import os
import re
import shutil
import signal
import subprocess
import tempfile
import time

root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('nested_display_core',root/'shell/quickshell/scripts/display_core.py')
core=importlib.util.module_from_spec(spec);spec.loader.exec_module(core)

with tempfile.TemporaryDirectory(prefix='sd-') as directory:
    temp=Path(directory);runtime=temp/'r';runtime.mkdir(mode=0o700)
    config=temp/'hyprland.lua'
    config.write_text('hl.monitor({output="",mode="1280x720@60",position="auto",scale=1})\n')
    current_runtime=os.environ.get('XDG_RUNTIME_DIR',f'/run/user/{os.getuid()}')
    display=os.environ.get('WAYLAND_DISPLAY','wayland-1')
    socket=display if display.startswith('/') else current_runtime+'/'+display
    env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(temp/'config'),
             WAYLAND_DISPLAY=socket,AQ_DRM_DEVICES='/dev/null',HYPRLAND_INSTANCE_SIGNATURE='',
             LIBSEAT_BACKEND='noop',SENOMY_NESTED_QA='1',DBUS_SESSION_BUS_ADDRESS='unix:path='+current_runtime+'/bus')
    env.pop('DISPLAY',None)
    nodes=sorted(Path('/dev/dri').glob('renderD*'))
    if not nodes:raise SystemExit('BLOCKED: no render-only GPU device for nested integration')
    cmd=['bwrap','--ro-bind','/','/','--bind',str(temp),str(temp),'--dev-bind','/dev','/dev',
         '--tmpfs','/dev/dri','--dev-bind',str(nodes[0]),str(nodes[0]),'--unshare-pid','--die-with-parent',
         '--','/usr/bin/Hyprland','--config',str(config)]
    with (temp/'nested.log').open('w') as log:
        proc=subprocess.Popen(cmd,env=env,stdout=log,stderr=log)
        try:
            end=time.monotonic()+15
            signature=None
            while time.monotonic()<end and proc.poll() is None:
                found=list((runtime/'hypr').glob('*/.socket.sock'))
                if found:signature=found[0].parent.name;break
                time.sleep(.1)
            if not signature:
                print((temp/'nested.log').read_text()[-1200:])
                for file in runtime.glob('hypr/*/hyprland.log'):print(file.read_text()[-4000:])
                raise SystemExit('BLOCKED: isolated nested compositor did not become ready')
            env['HYPRLAND_INSTANCE_SIGNATURE']=signature
            # Only this private nested instance is visible to the adapter.
            os.environ.update({k:env[k] for k in ('XDG_RUNTIME_DIR','XDG_CONFIG_HOME','HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_DISPLAY','DBUS_SESSION_BUS_ADDRESS')})
            deadline=time.monotonic()+8
            while not core.query('monitors'):
                if time.monotonic()>deadline:raise RuntimeError('Nested output unavailable')
                time.sleep(.1)
            assert core.query('status')['configProvider']=='lua'
            for name in ('SENOMY-TEST-A','SENOMY-TEST-B'):
                core.command('output','create','headless',name)
            time.sleep(.4)
            inventory=core.query('monitors','all')
            names=[m['name'] for m in inventory]
            assert len(names)>=3,names
            auto_before=[core.configuration(m) for m in inventory]
            core.apply_output(auto_before[-1])
            auto_after=core.normalize_monitors(core.query('monitors','all'))
            drift=[m['name'] for m in auto_after if (m['x'],m['y'])!=next((o['x'],o['y']) for o in auto_before if o['name']==m['name'])]
            print(json.dumps({'autoPositionRegression':{'driftedOutputs':drift}}),flush=True)
            core.command('reload')
            time.sleep(.2)
            pinned_before=[core.configuration(m) for m in core.query('monitors','all')]
            core.pin_layout(pinned_before);core.verify(pinned_before)
            pinned_after=[dict(o) for o in pinned_before]
            pinned_after[-1]['x']+=320
            core.apply_output(pinned_after[-1]);core.verify(pinned_after)
            print(json.dumps({'autoPositionPinnedFix':True}),flush=True)
            native_before=core.query('workspaces')
            core.workspace_operation({'action':'default-home','monitor':names[0]})
            core.restore_policy(startup=True)
            assert {w['id'] for w in core.query('workspaces')}=={w['id'] for w in native_before}
            assert not any(w.get('ispersistent') for w in core.query('workspaces'))
            initial=core.snapshot(False)
            assert sum(w['indicatorVisible'] for w in initial['workspaces'])==1
            core.workspace_operation({'action':'create','monitor':names[1]})
            created=next(m['activeWorkspace']['id'] for m in core.query('monitors') if m['name']==names[1])
            assert created!=1
            observed=core.snapshot(False)
            assert next(w['displayLabel'] for w in observed['workspaces'] if w['id']==created)=='1'
            assert next(m['activeWorkspace']['id'] for m in core.query('monitors') if m['name']==names[0])==native_before[0]['id']
            # Migrate a real legacy generated pin without creating replacements.
            core.install_binding(41,names[0],True)
            assert any(w['id']==41 for w in core.query('workspaces'))
            data=core.store();data.pop('workspaceLifecycleVersion',None)
            data['workspaceDefaultHome']=observed['displays'][0]['key']
            data['workspaces']['41']=dict(home=data['workspaceDefaultHome'],homeNumber=1,slot=41,label='',persistent=True,order=41)
            core.atomic_json(core.store_path(),data)
            # Explicit pins outside the old generated range must survive.
            core.workspace_operation({'action':'dynamic-defaults'})
            assert any(w['id']==41 and w.get('ispersistent') for w in core.query('workspaces'))
            core.install_binding(9,names[0],True)
            data=core.store();data.pop('workspaceLifecycleVersion',None)
            data['workspaces']['9']=dict(home=data['workspaceDefaultHome'],homeNumber=1,slot=9,label='',persistent=True,order=9)
            core.atomic_json(core.store_path(),data)
            core.workspace_operation({'action':'dynamic-defaults'})
            time.sleep(.3)
            assert not any(w['id']==9 for w in core.query('workspaces'))
            core.remove_binding(41)
            print(json.dumps({'nativeDynamicStartup':True,'nativeIndependentLocalOne':True,'noEagerPins':True}),flush=True)
            outputs=[core.configuration(m) for m in inventory]
            for index,out in enumerate(outputs[:3]):
                out.update(enabled=True,mirrorOf='',mode='1280x720@60',scale=1,transform=0,
                           x=index*1280 if index<2 else 640,y=0 if index<2 else 720)
                core.apply_output(out)
            core.verify(outputs[:3])
            # Exact installed API: create bindings, activate distinct workspaces,
            # move a whole workspace and verify actual compositor readback.
            core.install_binding(901,names[0],True)
            time.sleep(.3)
            print(json.dumps({"persistentRuleCreatesEmptyWorkspace":any(w["id"]==901 for w in core.query("workspaces"))}),flush=True)
            core.install_binding(101,names[0],True)
            core.install_binding(201,names[1],True)
            core.dispatch('focus',{'monitor':names[0]});core.dispatch('focus',{'workspace':101})
            core.wait_workspace(101,names[0],active=True)
            core.dispatch('focus',{'monitor':names[1]});core.dispatch('focus',{'workspace':201})
            core.wait_workspace(201,names[1],active=True)
            assert next(m for m in core.query('monitors') if m['name']==names[0])['activeWorkspace']['id']==101
            core.snapshot(False)
            assert created not in {w['id'] for w in core.query('workspaces')}
            assert str(created) not in core.store()['workspaces']
            core.move_workspace(101,names[2]);core.wait_workspace(101,names[2])
            # Real monitor mode/position changes are confined to virtual outputs.
            previous=dict(outputs[2]);mirror=dict(previous,mirrorOf=names[0])
            core.apply_output(mirror)
            try:core.verify([mirror])
            except Exception:
                print(json.dumps({'expected':mirror,'actual':core.query('monitors','all')}))
                raise
            core.apply_output(previous);core.verify([previous])
            core.install_shortcuts({'workspaceMode':'global'})
            copied=temp/'shell/quickshell';shutil.copytree(root/'shell/quickshell',copied,symlinks=True)
            for name in ('appearance','assets'):(temp/name).symlink_to(root/name,target_is_directory=True)
            fixture=copied/'overlay-native-test.qml'
            fixture.write_text('//@ pragma UseQApplication\nimport QtQuick\nimport Quickshell\nimport "components"\nShellRoot {\n QtObject {\n  id:fakeInventory\n  property bool identifying:true\n  property var displays:Quickshell.screens.map((s,i)=>({name:s.name,number:i+1,friendlyName:"Fixture "+s.name,mirrorOf:"none"}))\n  property QtObject displayActions:QtObject {property string token:"fixture";property string actionState:"revert-pending";property string message:"Isolated overlay fixture";property int secondsRemaining:15;function revert(){throw new Error("No mutations in overlay test");}function keep(){throw new Error("No mutations in overlay test");}}\n  function numberFor(name){const d=displays.find(d=>d.name===name);return d?d.number:0;}\n  function dismissIdentify(){identifying=false;}\n }\n Variants {model:Quickshell.screens;Scope {required property var modelData;DisplayIdentifyOverlay {targetScreen:modelData;inventory:fakeInventory}DisplayRecovery {targetScreen:modelData;inventory:fakeInventory}}}\n Timer {interval:1800;running:true;onTriggered:Qt.quit()}\n}\n')
            nested_socket=next(p for p in runtime.glob('wayland-*') if p.is_socket())
            overlay_env=dict(env,WAYLAND_DISPLAY=str(nested_socket),QT_QPA_PLATFORM='wayland',QT_QUICK_BACKEND='software')
            applications=copied/'workspace-window-test.qml'
            applications.write_text('import QtQuick\nimport QtQuick.Window\nimport Quickshell\nShellRoot {Window {width:320;height:240;visible:true;title:"Senomy fixture A"}Window {width:320;height:240;visible:true;title:"Senomy fixture B"}Timer {interval:18000;running:true;onTriggered:Qt.quit()}}\n')
            windows=subprocess.Popen(['qs','--path',str(applications),'--no-color'],env=overlay_env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
            try:
                end=time.monotonic()+3
                clients=[]
                while len(clients)<2 and time.monotonic()<end:
                    clients=[c for c in core.query('clients') if c.get('title','').startswith('Senomy fixture ')]
                    time.sleep(.08)
                assert len(clients)==2,'Two disposable nested application windows required'
                for client,wid in zip(clients,(101,201)):
                    core.dispatch('window.move',{'window':'address:'+client['address'],'workspace':wid,'follow':False})
                core.move_workspace(101,names[0]);core.wait_workspace(101,names[0])
                core.move_workspace(101,names[2]);core.wait_workspace(101,names[2])
                target_id=next(m['id'] for m in core.query('monitors') if m['name']==names[2])
                assert any(c['address']==clients[0]['address'] and c['workspace']['id']==101 and c['monitor']==target_id for c in core.query('clients'))
                core.dispatch('window.move',{'window':'address:'+clients[0]['address'],'workspace':201,'follow':False})
                assert any(c['address']==clients[0]['address'] and c['workspace']['id']==201 for c in core.query('clients'))
                # Guard checks use explicit virtual-fixture capabilities. Every IPC
                # still targets this private compositor; physical DRM cards are hidden.
                enumerate_native=core.enumerate_displays
                def fixture_inventory(raw,data):
                    items=enumerate_native(raw,data)
                    for item in items:item.update(physicalWidth=500,physicalHeight=300,availableModes=['1280x720@60.00Hz','1920x1080@60.00Hz'])
                    return items
                core.enumerate_displays=fixture_inventory
                native_run=core.subprocess.run
                def guarded_run(args,**kwargs):
                    if args and args[0]=='systemd-run':
                        # The launcher connects to the real user manager; explicit
                        # --setenv flags still give the worker the private runtime.
                        kwargs['env']=dict(os.environ,XDG_RUNTIME_DIR=current_runtime)
                    result=native_run(args,**kwargs)
                    if args and args[0]=='systemd-run' and result.returncode:print(result.stderr[:500],flush=True)
                    return result
                core.subprocess.run=guarded_run
                core.internal_display=lambda m:m['name']==names[0]
                for mode in ('pc-only','duplicate','external-only'):
                    plan=core.projection_plan({'mode':mode})
                    result=core.begin(plan);core.confirm(result['token'])
                    assert len(core.query('clients'))>=2
                    assert all(not next(m for m in core.query('monitors','all') if m['name']==w['monitor'])['disabled'] for w in core.query('workspaces') if w.get('windows'))
                    plan=core.projection_plan({'mode':'extend'})
                    result=core.begin(plan);core.confirm(result['token'])
                assert any(c['address']==clients[0]['address'] and c['workspace']['id']==201 for c in core.query('clients'))
                # Real virtual-output hotplug with a populated native workspace.
                core.dispatch('window.move',{'window':'address:'+clients[0]['address'],'workspace':101,'follow':False})
                core.workspace_operation({'action':'move','id':101,'monitor':names[2]})
                core.command('output','remove',names[2]);time.sleep(.2)
                surviving={m['id'] for m in core.query('monitors')}
                assert any(c['address']==clients[0]['address'] and c['monitor'] in surviving for c in core.query('clients'))
                core.snapshot(False)
                core.command('output','create','headless',names[2]);time.sleep(.3)
                core.workspace_operation({'action':'restore-home'})
                core.wait_workspace(101,names[2])
                assert len(core.query('monitors'))==3
                print(json.dumps({'nativePopulatedHotplug':True,'nativeDynamicDestroyNoGhost':True}),flush=True)
                print(json.dumps({'nativeGuardedProjectionModes':True,'nativeProjectionWindowsAccessible':True}),flush=True)
            finally:
                window_text,_=windows.communicate(timeout=22)
                assert windows.returncode==0 and not re.search(r'ERROR|TypeError|ReferenceError',window_text),window_text
            rotated=dict(outputs[2],transform=1,scale=2,x=-360,y=-640)
            core.apply_output(rotated);core.verify([rotated]);core.apply_output(outputs[2]);core.verify([outputs[2]])
            before_focus={m['name']:m['activeWorkspace']['id'] for m in core.query('monitors')}
            overlay=subprocess.Popen(['qs','--path',str(fixture),'--no-color'],env=overlay_env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
            time.sleep(.8)
            layers=core.query('layers')
            identifiers=sum(1 for m in layers.values() for group in m['levels'].values() for layer in group if layer['namespace']=='senomy-display-identify')
            recovery=sum(1 for m in layers.values() for group in m['levels'].values() for layer in group if layer['namespace']=='senomy-display-recovery')
            text,_=overlay.communicate(timeout=8)
            assert overlay.returncode==0 and not re.search(r'ERROR|TypeError|ReferenceError|Binding loop',text),text
            assert identifiers==len(names) and recovery==len(names),(identifiers,recovery,text)
            assert all(m['reserved']==[0,0,0,0] and m['activeWorkspace']['id']==before_focus[m['name']] for m in core.query('monitors'))
            smoke_env=dict(overlay_env,SENOMY_NOTIFICATION_OWNER='none',PIPEWIRE_REMOTE='unix:'+current_runtime+'/pipewire-0')
            smoke=subprocess.Popen(['dbus-run-session','--','qs','--path',str(copied/'shell.qml'),'--no-color'],env=smoke_env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,start_new_session=True)
            try:
                time.sleep(4)
                assert smoke.poll() is None,smoke.stdout.read()
                smoke_layers=core.query('layers')
                rails=sum(1 for m in smoke_layers.values() for group in m['levels'].values() for layer in group if layer['namespace']=='senomy-v2-rail')
            finally:
                if smoke.poll() is None:os.killpg(smoke.pid,signal.SIGTERM)
                smoke_text,_=smoke.communicate(timeout=8)
            filtered='\n'.join(line for line in smoke_text.splitlines() if 'quickshell.service.pipewire.loop' not in line)
            assert 'Configuration Loaded' in smoke_text and not re.search(r'ERROR|TypeError|ReferenceError|Binding loop',filtered),smoke_text
            assert rails==len(names),(rails,smoke_text)
            fresh=core.snapshot()
            core.workspace_operation({'action':'default-home','monitor':names[0]})
            native_groups=core.query('workspaces')
            assert not any(w.get('ispersistent') and w['id'] in range(1,11) for w in native_groups)
            print(json.dumps({'nativeDynamicPolicyRestore':True}),flush=True)
            print(json.dumps({'ok':True,'nestedOnly':True,'outputs':len(names),'centredLayout':True,
                              'workspaceIndependence':True,'workspaceMove':True,'nativeWindowMovement':True,'rotationScaleNegativePosition':True,'mirrorAndRevert':True,'shortcutApi':True,'identifyOverlays':identifiers,'recoveryOverlays':recovery,'focusAndWorkAreaUnchanged':True,'fullShellRails':rails}))
        finally:
            if proc.poll() is None:
                # Signal only the process created here. Never dispatch a session exit.
                proc.terminate()
                proc.wait(timeout=5)
