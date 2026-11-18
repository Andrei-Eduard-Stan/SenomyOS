#!/usr/bin/env python3
"""Project the shared task catalog to QML JS. Does not execute user queries."""
import argparse,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
data=json.loads((root/'components/settings/task-intents.json').read_text())
assert data['schema_version']==1
assert len({t['id'] for t in data['tasks']})==len(data['tasks'])
for task in data['tasks']:
 assert all(isinstance(task[k],str) and task[k] for k in ('id','route','title','detail'))
 assert isinstance(task['phrases'],list) and all(isinstance(p,str) for p in task['phrases'])
out='// Generated from components/settings/task-intents.json.\n.pragma library\nvar catalog = '+json.dumps(data['tasks'],ensure_ascii=False,indent=2)+';\n'
p=root/'shell/quickshell/components/TaskIntents.js'
if args.check:
 if not p.exists() or p.read_text()!=out:raise SystemExit('Task search projection is stale')
 print('PASS: shared task search projection')
else:p.write_text(out)
