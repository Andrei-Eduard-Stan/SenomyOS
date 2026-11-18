"""Private worker adapter. The only dispatcher available here is dry-run."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

source=Path(__file__).resolve().parents[2]/'scripts/session-scheduler.py'
spec=importlib.util.spec_from_file_location('session_scheduler',source)
engine=importlib.util.module_from_spec(spec);spec.loader.exec_module(engine)

class InertRuntime(engine.Runtime):
    def __init__(self,directory):
        self.root=Path(directory)/'runtime';self.persistent_root=Path(directory)/'state'
        self.tool=Path(__file__).resolve().parents[4]/'scripts/senomy-session-action'
    def identity(self,expected=None):
        identity={'session':'qa','boot':'qa','signature':'qa'}
        if expected and expected!=identity:raise engine.Problem('Private login changed.')
        return identity
    def available(self,action,identity):
        if action not in engine.ACTIONS:raise engine.Problem('Invalid private action.')
        return False
    def timer_available(self):return True
    def timer_active(self,record):return True
    def arm(self,record):pass  # The harness supervises the real worker separately.
    def stop(self,record):pass  # Terminal/obsolete receipts make the worker exit.
    def execute(self,action,identity):
        self.identity(identity)
        result=subprocess.run([str(self.tool),'dry-run',action],env=dict(os.environ,XDG_SESSION_ID='qa'),capture_output=True,text=True,check=True)
        command=json.loads(result.stdout)
        with (self.root/'dry-run-executions.jsonl').open('a') as stream:stream.write(json.dumps(command)+'\n')
    def notify_failure(self,label,message):pass

if __name__=='__main__':
    print(json.dumps(engine.Scheduler(InertRuntime(sys.argv[1])).watch(sys.argv[2])))
