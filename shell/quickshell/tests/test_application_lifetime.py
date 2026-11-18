#!/usr/bin/env python3
"""No application, real bus, manager mutation or shell restart in these tests."""
from pathlib import Path
import importlib.util,json,os,subprocess,sys,tempfile,unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('app_launch',Path(__file__).resolve().parents[3]/'scripts/senomy_app_launch.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class LaunchTests(unittest.TestCase):
 def test_rejects_untyped_requests(self):
  for request in ({},[],{'kind':'exec','target':'sh'},{'kind':'desktop','target':'../a.desktop'},{'kind':'desktop','target':'a'},{'kind':'desktop','target':'-a.desktop'},{'kind':'open','target':'javascript:alert(1)'},{'kind':'open','target':'https://user:secret@example.com'},{'kind':'open','target':'file://remote/tmp'},{'kind':'open','target':'https://example.com','args':['extra']},{'kind':'open','target':'https://example.com\n'},{'kind':'desktop','target':'a.desktop','args':['https://example.com']*33},{'kind':'tool','target':'sh','args':['-c','true']},{'kind':'tool','target':'wifi-auth','args':['--help']},{'kind':'tool','target':'password','args':['root;true']},{'kind':'tool','target':'network-editor','args':['edit','invalid']},{'kind':'tool','target':'calendar-credential','args':['../private']},{'kind':'tool','target':'console-shell','args':['bash -c true']},{'kind':'open','target':'https://example.com','unknown':True}):
   with self.subTest(request=request),self.assertRaises(m.LaunchError):m.validate(request)
 def test_literal_paths_and_uris(self):
  with tempfile.TemporaryDirectory() as work:
   file=Path(work)/'a $HOME ; λ.txt';file.touch()
   for value in (str(file),file.as_uri(),'https://example.com/a?q=$HOME','mailto:user@example.com'):
    self.assertEqual(m.validate({'kind':'open','target':value})['target'],value)
 def test_missing_file(self):
  with self.assertRaises(m.LaunchError):m.local_path('/definitely-unavailable-wp01')
 def test_fixed_native_arguments(self):
  with patch.object(m,'executable',side_effect=lambda name:'/usr/bin/'+name):
   self.assertEqual(m.tool_argv('wifi-auth',['Wi-Fi $HOME ; λ'])[-1],'Wi-Fi $HOME ; λ')
   self.assertEqual(m.tool_argv('console-shell',['bash'])[-2:],['/usr/bin/bash','-l'])
   self.assertEqual(m.tool_argv('network-editor',['vpn']),['/usr/bin/nm-connection-editor','--show','vpn'])
 def test_network_authentication_is_fixed_argv_and_interface_bound(self):
  uuid='12345678-1234-1234-1234-123456789abc'
  with patch.object(m,'executable',side_effect=lambda name:'/usr/bin/'+name):
   args=m.tool_argv('wifi-auth-interface',['Office $HOME ; λ','wlp-test-1'])
   self.assertEqual(args[-3:],['Office $HOME ; λ','ifname','wlp-test-1'])
   self.assertEqual(m.tool_argv('network-profile-auth',[uuid])[-5:],['--ask','connection','up','uuid',uuid])
   for tool,args in [('wifi-auth-interface',['--help','wlan0']),('wifi-auth-interface',['Office','wlan0;id']),('network-profile-auth',['../../private'])]:
    with self.assertRaises(m.LaunchError):m.tool_argv(tool,args)
 def test_installed_tool_fallback(self):
  with tempfile.TemporaryDirectory() as work,patch.object(m,'ROOT',Path(work)),patch.object(m,'executable',return_value='/usr/bin/senomy-file-workspace'):
   self.assertEqual(m.project_tool('missing','senomy-file-workspace'),'/usr/bin/senomy-file-workspace')
 def receipt(self,returncode=0,stdout=None):return subprocess.CompletedProcess([],returncode,stdout or json.dumps({'ok':True,'state':'handed-off','message':'Accepted.'}),'')
 def test_scope_before_launch_and_private_request(self):
  with patch.object(m.subprocess,'run',return_value=self.receipt()) as run,patch.object(m,'executable',return_value='/usr/bin/systemd-run'),patch.dict(os.environ,{'NOTIFY_SOCKET':'private','WATCHDOG_USEC':'100','INVOCATION_ID':'old','WP01_LITERAL':'$HOME; λ'}):
   result=m.launch({'kind':'open','target':'https://example.com/private'})
   self.assertTrue(result['ok']);command=run.call_args.args[0];options=run.call_args.kwargs
   self.assertIn('--scope',command);self.assertIn('--user',command);self.assertIn('--expand-environment=no',command)
   self.assertNotIn('https://example.com/private',' '.join(command));self.assertIn('https://example.com/private',options['input'])
   self.assertNotIn('cwd',options);self.assertNotIn('shell',options);self.assertNotIn('NOTIFY_SOCKET',options['env']);self.assertNotIn('INVOCATION_ID',options['env']);self.assertEqual(options['env']['WP01_LITERAL'],'$HOME; λ')
 def test_refuses_root_or_changed_uid(self):
  for uid,euid in ((0,0),(1000,0)):
   with patch.object(m.os,'getuid',return_value=uid),patch.object(m.os,'geteuid',return_value=euid),patch.object(m.subprocess,'run') as run:
    self.assertFalse(m.launch({'kind':'desktop','target':'a.desktop'})['ok']);run.assert_not_called()
 def test_no_direct_fallback_on_manager_failure(self):
  with patch.object(m.subprocess,'run',return_value=self.receipt(1,'manager unavailable')) as run,patch.object(m.subprocess,'Popen') as popen:
   result=m.launch({'kind':'desktop','target':'a.desktop'});self.assertFalse(result['ok']);self.assertIn('no direct launch fallback',result['message']);self.assertEqual(run.call_count,1);popen.assert_not_called()
 def test_timeout_is_unverified_without_retry_or_kill(self):
  with patch.object(m.subprocess,'run',side_effect=subprocess.TimeoutExpired('systemd-run',15)) as run:
   result=m.launch({'kind':'desktop','target':'a.desktop'});self.assertEqual(result['state'],'unverified');self.assertIn('unit',result);self.assertEqual(run.call_count,1)
 def test_bad_receipt_and_nonzero_exit(self):
  for completed in (self.receipt(1),self.receipt(0,'{}'),self.receipt(0,'[]'),self.receipt(0,json.dumps({'ok':True,'state':'success','message':'x'}))):
   with patch.object(m.subprocess,'run',return_value=completed):
    result=m.launch({'kind':'desktop','target':'a.desktop'});self.assertFalse(result['ok'])
    if completed.returncode and json.loads(completed.stdout).get('ok'):self.assertEqual(result['state'],'unverified');self.assertIn('may already be running',result['message'])
 def test_worker_rejects_unscoped_invocation(self):
  result=subprocess.run([sys.executable,'-B',str(Path(m.__file__)),'--worker'],input=json.dumps({'kind':'desktop','target':'a.desktop'}),text=True,capture_output=True)
  self.assertNotEqual(result.returncode,0);self.assertFalse(json.loads(result.stdout)['ok'])
 def test_restart_guard_is_conservative_and_read_only(self):
  with tempfile.TemporaryDirectory() as work:
   root=Path(work);group=root/'sys/fs/cgroup/user.slice/fixture.service';group.mkdir(parents=True);(group/'cgroup.procs').write_text('8888\n7777\n')
   proc=root/'proc/7777';proc.mkdir(parents=True);(proc/'cmdline').write_bytes(b'/usr/bin/firefox\0');(proc/'comm').write_text('firefox\n');(proc/'exe').symlink_to(sys.executable)
   original=Path
   def paths(*args):
    p=original(*args)
    return root/str(p).lstrip('/') if str(p) in ('/proc','/sys/fs/cgroup') else p
   result=subprocess.CompletedProcess([],0,'MainPID=8888\nControlGroup=/user.slice/fixture.service\n','')
   with patch.object(m,'Path',side_effect=paths),patch.object(m.subprocess,'run',return_value=result) as run:
    status=m.migration_status();self.assertEqual(status['state'],'migration-required');self.assertEqual(status['processes'],[{'pid':7777,'name':'firefox'}]);self.assertEqual(run.call_count,1);self.assertIn('show',run.call_args.args[0])
 def test_selector_refuses_before_service_or_notification_mutations(self):
  import shutil
  with tempfile.TemporaryDirectory() as work:
   root=Path(work);(root/'scripts').mkdir();(root/'bin').mkdir();record=root/'unexpected'
   selector=root/'scripts/senomy-shell';shutil.copy2(Path(m.__file__).parent/'senomy-shell',selector)
   guard=root/'scripts/senomy-app-launch';guard.write_text('#!/usr/bin/env bash\nexit 1\n');guard.chmod(0o755)
   for name in ('systemctl','hyprctl','busctl','qs'):
    stub=root/'bin'/name;stub.write_text('#!/usr/bin/env bash\ntouch "'+str(record)+'"\nexit 1\n');stub.chmod(0o755)
   env=dict(os.environ,SENOMY_SOURCE_ROOT=str(root),XDG_RUNTIME_DIR=str(root/'runtime'),XDG_CONFIG_HOME=str(root/'config'),PATH=str(root/'bin')+':/usr/bin:/bin')
   result=subprocess.run([str(selector),'restart'],env=env,text=True,capture_output=True)
   self.assertNotEqual(result.returncode,0);self.assertIn('was not restarted',result.stderr);self.assertFalse(record.exists());self.assertFalse((root/'config').exists())
 def test_unavailable_ownership_refuses_restart(self):
  with patch.object(m.subprocess,'run',side_effect=OSError()):self.assertFalse(m.migration_status()['ok'])
if __name__=='__main__':unittest.main()
