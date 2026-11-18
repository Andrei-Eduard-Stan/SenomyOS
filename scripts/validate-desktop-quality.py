#!/usr/bin/env python3
"""Probe arithmetic, task catalog and literal launcher dispatch with private mocks."""
import importlib.util,json,os,subprocess,tempfile,unittest
from pathlib import Path
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('probe',root/'scripts/senomy-desktop-probe.py');probe=importlib.util.module_from_spec(spec);spec.loader.exec_module(probe)
class DesktopQuality(unittest.TestCase):
    def test_resource_deltas_and_invalid_identity(self):
        a={'pid':2,'startTicks':10,'cpuTicks':100,'contextSwitches':20}
        b=dict(a,cpuTicks=150,contextSwitches=30)
        self.assertEqual(probe.delta(a,b,2,100),{'cpuPercentOneCore':25,'contextSwitchesPerSecond':5})
        for wrong in (dict(b,pid=3),dict(b,startTicks=11),dict(b,cpuTicks=1)):
            self.assertIsNone(probe.delta(a,wrong,2,100))
        self.assertIsNone(probe.delta(a,b,0,100));self.assertIsNone(probe.delta(None,b,2,100))
    def test_battery_absence_and_charging_are_not_zero_drain(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d);self.assertIsNone(probe.battery_energy(base))
            pack=base/'BAT';pack.mkdir()
            for n,v in {'type':'Battery','status':'Discharging','energy_now':'25000000'}.items():(pack/n).write_text(v)
            self.assertEqual(probe.battery_energy(base),25)
            (pack/'status').write_text('Charging');self.assertIsNone(probe.battery_energy(base))
    def test_launcher_routes_only_known_tasks_without_commands(self):
        catalog=json.loads((root/'components/settings/task-intents.json').read_text())['tasks']
        with tempfile.TemporaryDirectory() as d:
            temp=Path(d);router=temp/'surface';out=temp/'args.json'
            router.write_text('#!/usr/bin/env python3\nimport json,os,sys\nopen(os.environ["FIXTURE_ARGS"],"w").write(json.dumps(sys.argv[1:]))\n');router.chmod(0o700)
            env=dict(os.environ,SENOMY_SURFACE_BIN=str(router),FIXTURE_ARGS=str(out),ROFI_RETV='1')
            script=root/'components/launcher/rofi/scripts/senomy-rofi-actions'
            for task in catalog:
                env['ROFI_INFO']='settings-task:'+task['route']
                subprocess.run(['bash',str(script)],env=env,capture_output=True,check=True)
                self.assertEqual(json.loads(out.read_text()),['show-settings',task['route']])
            out.unlink();env['ROFI_INFO']='settings-task:$(touch /tmp/no-command)'
            subprocess.run(['bash',str(script)],env=env,capture_output=True,check=True)
            self.assertFalse(out.exists())
            env['ROFI_RETV']='0';env.pop('ROFI_INFO',None)
            result=subprocess.run(['bash',str(script)],env=env,capture_output=True,check=True).stdout
            self.assertIn(b'microphone too quiet',result);self.assertIn(b'\x1fmeta\x1f',result)
if __name__=='__main__':unittest.main()
