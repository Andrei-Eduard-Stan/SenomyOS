#!/usr/bin/env python3
"""CLI diagnostic availability and allowlisted IPC; never contacts a live shell."""
import json,os,subprocess,sys,tempfile,unittest
from pathlib import Path
SCRIPT=Path(__file__).resolve().parents[3]/'scripts/senomy-render-probe.py'
class RenderProbe(unittest.TestCase):
    def test_actions_and_invalid_response(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);fake=root/'qs';seen=root/'seen.json'
            fake.write_text('#!/usr/bin/env python3\nimport json,os,sys\nopen(os.environ["SEEN"],"w").write(json.dumps(sys.argv[1:]))\nprint(json.dumps({"schema_version":1,"recording":sys.argv[-1]=="start","transitions":[]}))\n');fake.chmod(0o700)
            env=dict(os.environ,SENOMY_QS_BIN=str(fake),SEEN=str(seen))
            for action in ['start','state','stop']:
                result=subprocess.run([sys.executable,str(SCRIPT),action],env=env,capture_output=True,text=True,timeout=5)
                self.assertEqual(result.returncode,0,result.stderr);self.assertTrue(json.loads(result.stdout)['ok'])
                args=json.loads(seen.read_text());self.assertEqual(args[-4:],['call','shell','renderMetrics',action])
            seen.unlink();result=subprocess.run([sys.executable,str(SCRIPT),'$(false)'],env=env,capture_output=True,text=True,timeout=5)
            self.assertEqual(result.returncode,2);self.assertFalse(seen.exists())
            for body in ['print("not ready")','print("{}")','import sys;sys.exit(1)']:
                fake.write_text('#!/usr/bin/env python3\n'+body+'\n')
                result=subprocess.run([sys.executable,str(SCRIPT),'state'],env=env,capture_output=True,text=True,timeout=5)
                self.assertEqual(result.returncode,1);self.assertFalse(json.loads(result.stdout)['ok'])
if __name__=='__main__':unittest.main()
