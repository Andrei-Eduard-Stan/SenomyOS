#!/usr/bin/env python3
"""Exercise persistence/receipts with mocked launch transport and isolated state."""
from pathlib import Path
import importlib.util,json,os,sys,tempfile
from types import SimpleNamespace
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parent))
import senomy_app_usage as usage
import senomy_app_launch as launch
with tempfile.TemporaryDirectory(prefix='senomy-app-usage-') as directory,patch.dict(os.environ,{'XDG_STATE_HOME':directory}):
    history=usage.directory()/'history.json'
    assert usage.read(history)['apps']=={}
    def accepted(*args,**kwargs):return SimpleNamespace(returncode=0,stdout=json.dumps({'ok':True,'state':'handed-off','message':'Accepted fixture'}))
    def rejected(*args,**kwargs):return SimpleNamespace(returncode=1,stdout=json.dumps({'ok':False,'state':'failed','message':'Rejected fixture'}))
    request={'kind':'desktop','target':'org.example.App.desktop','args':[]}
    with patch.object(launch,'executable',return_value='/fixture/systemd-run'),patch.object(launch.os,'getuid',return_value=1000),patch.object(launch.os,'geteuid',return_value=1000):
        with patch.object(launch.subprocess,'run',side_effect=accepted):
            assert launch.launch(request)['ok'];assert launch.launch(request)['ok']
        assert usage.read(history)['apps']['org.example.App']['count']==2
        with patch.object(launch.subprocess,'run',side_effect=rejected):assert not launch.launch(request)['ok']
        assert usage.read(history)['apps']['org.example.App']['count']==2
        assert history.stat().st_mode & 0o077==0
        before=history.read_bytes();assert not usage.record('../invalid.desktop');assert history.read_bytes()==before
        history.write_text('{broken')
        with patch.object(launch.subprocess,'run',side_effect=accepted):assert launch.launch(request)['ok']
        assert history.read_text()=='{broken', 'Do not overwrite unreadable history silently'
    assert not list(usage.directory().glob('.history-*'))
print('PASS: successful desktop handoffs persist across requests; failed launches do not count; private atomic file; invalid/malformed data isolated without changing launch success')
