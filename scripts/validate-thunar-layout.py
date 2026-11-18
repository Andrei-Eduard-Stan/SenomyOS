#!/usr/bin/env python3
"""Exercise one-time layout transactions with fake native providers only."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parent.parent
SCRIPT=ROOT/'components/file-manager/thunar/scripts/senomy-thunar-layout'
with tempfile.TemporaryDirectory(prefix='senomy-thunar-layout-test-') as temp:
    work=Path(temp);commands=work/'bin';commands.mkdir();state=work/'preferences.json'
    initial={'/last-side-pane':'THUNAR_SIDEPANE_TYPE_TREE','/last-separator-position':'214',
             '/last-toolbar-items':'open-home:1,search:0,uca-action-user-action:1,undo:1',
             '/last-show-hidden':'true','/misc-single-click':'false','/last-details-view-fixed-columns':'false'}
    def executable(name,body):
        path=commands/name;path.write_text('#!/usr/bin/env python3\n'+body);path.chmod(0o755)
    executable('pgrep','import os,sys\nsys.exit(0 if os.environ.get("FIXTURE_RUNNING")=="1" else 1)\n')
    executable('xfconf-query','''import os,sys,json
from pathlib import Path
p=Path(os.environ['FIXTURE_STATE']);d=json.loads(p.read_text());a=sys.argv[1:]
if '-l' in a: print('\\n'.join(d));sys.exit(0)
k=a[a.index('-p')+1]
if '-s' in a:
    if k==os.environ.get('FIXTURE_FAIL') and a[a.index('-s')+1]!='214':sys.exit(3)
    d[k]=a[a.index('-s')+1]
elif '-r' in a: d.pop(k,None)
else:
    if k not in d:sys.exit(1)
    print(d[k]);sys.exit(0)
p.write_text(json.dumps(d))
''')
    env=dict(os.environ,PATH=str(commands)+':/usr/bin',HOME=str(work/'home'),XDG_STATE_HOME=str(work/'state'),XDG_CONFIG_HOME=str(work/'config'),XDG_DATA_HOME=str(work/'data'),FIXTURE_STATE=str(state))
    def call(*arguments,**extra):
        return subprocess.run([str(SCRIPT),*arguments],env=dict(env,**extra),capture_output=True,text=True,timeout=10)
    (work/'home/Documents').mkdir(parents=True)
    (work/'home/Downloads').mkdir()
    bookmark=work/'config/gtk-3.0/bookmarks';bookmark.parent.mkdir(parents=True)
    original_bookmarks=(work/'home').as_uri()+"\n"+(work/'home').as_uri()+" My alias\nsmb://fixture/shared Shared\n"
    bookmark.write_text(original_bookmarks)
    state.write_text(json.dumps(initial))
    p=call('plan');assert p.returncode==0,p.stderr
    assert json.loads(state.read_text())==initial
    assert not (work/'state').exists()
    p=call('apply','--yes',FIXTURE_RUNNING='1');assert p.returncode!=0
    assert json.loads(state.read_text())==initial
    p=call('apply','--yes',FIXTURE_FAIL='/last-separator-position');assert p.returncode!=0
    assert json.loads(state.read_text())==initial,'Partial apply failed to restore'
    p=call('apply','--yes');assert p.returncode==0,p.stderr
    receipts=list((work/'state/senomyos/thunar-layouts').glob('*.json'))
    receipt=next(p for p in receipts if json.loads(p.read_text())['status']=='applied')
    assert receipt.stat().st_mode & 0o777==0o600
    assert (work/'home/Documents').as_uri() in bookmark.read_text()
    assert (work/'home').as_uri()+' My alias' in bookmark.read_text()
    assert 'smb://fixture/shared Shared' in bookmark.read_text()
    assert (work/'home').as_uri()+'\n' not in bookmark.read_text()
    changed=json.loads(state.read_text());assert changed['/last-side-pane']=='THUNAR_SIDEPANE_TYPE_SHORTCUTS'
    assert 'uca-action-user-action:1' in changed['/last-toolbar-items']
    assert 'undo:1' in changed['/last-toolbar-items']
    for key in ['/last-show-hidden','/misc-single-click']:assert changed[key]==initial[key]
    assert 'toggle-split-view:1' in changed['/last-toolbar-items']
    p=call('apply','--yes');assert p.returncode==0 and 'already matches' in p.stdout
    applied_separator=changed['/last-separator-position']
    changed['/last-separator-position']='260';state.write_text(json.dumps(changed))
    p=call('rollback',str(receipt),'--yes');assert p.returncode!=0 and 'changed since' in p.stderr
    assert json.loads(state.read_text())==changed,'Rollback overwrote owner edits'
    changed['/last-separator-position']=applied_separator;state.write_text(json.dumps(changed))
    applied_bookmarks=bookmark.read_text()
    bookmark.write_text(applied_bookmarks+'file:///owner/new Bookmark\n')
    p=call('rollback',str(receipt),'--yes');assert p.returncode!=0 and 'bookmarks changed' in p.stderr
    assert json.loads(state.read_text())==changed,'Bookmark drift guard changed preferences'
    assert 'file:///owner/new Bookmark' in bookmark.read_text()
    bookmark.write_text(applied_bookmarks)
    p=call('rollback',str(receipt),'--yes');assert p.returncode==0,p.stderr
    assert json.loads(state.read_text())==initial,'Restore did not recover exact values/existence'
    assert bookmark.read_text()==original_bookmarks,'Bookmark rollback was not exact'
    assert json.loads(receipt.read_text())['status']=='rolled_back'
print('PASS: read-only plan, running-app guard, partial failure restoration, custom toolbar/user choices preserved, idempotence, owner-edit rollback guard and exact restoration; fake providers only.')
