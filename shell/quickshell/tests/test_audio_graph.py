import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
def module(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/f'{name}.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
A=module('audio-graph');P=module('audio-preferences')
TOOLS={'wpctl':True,'pw-metadata':True}

def fixture():
    return [
        {'id':0,'type':'PipeWire:Interface:Core','info':{'cookie':17}},
        {'id':1,'type':'PipeWire:Interface:Metadata','props':{'metadata.name':'default'}},
        {'id':2,'type':'PipeWire:Interface:Device','info':{'props':{'object.serial':102,'media.class':'Audio/Device','device.description':'Fixture device'},'params':{'Profile':[{'index':0}],'EnumProfile':[{'index':0,'available':'yes'},{'index':1,'description':'Duplex','available':'yes'},{'index':2,'available':'no'}],'EnumRoute':[{'index':0,'available':'yes','direction':'Output','profiles':[0],'devices':[0]},{'index':1,'available':'unknown','direction':'Output','profiles':[0],'devices':[0]}],'Route':[{'index':0,'device':0,'direction':'Output'}]}}},
        {'id':3,'type':'PipeWire:Interface:Node','info':{'props':{'object.serial':103,'media.class':'Stream/Output/Audio','application.name':'Fixture app','private.secret':'must not appear','node.description':'Stream'}}},
        {'id':4,'type':'PipeWire:Interface:Node','info':{'props':{'object.serial':104,'device.id':2,'card.profile.device':0,'media.class':'Audio/Sink','node.description':'Output'}}},
        {'id':5,'type':'PipeWire:Interface:Node','info':{'props':{'object.serial':105,'media.class':'Audio/Sink','node.description':'Second output'}}},
        {'id':6,'type':'PipeWire:Interface:Link','info':{'output-node-id':3,'input-node-id':4,'state':'active'}}]

def request(kind='move'):
    inv=A.inventory(fixture(),TOOLS);obj=inv['nodes'][0] if kind=='move' else inv['cards'][0]
    return {'kind':kind,'token':obj['token'],'revision':obj['revision'],'target':inv['nodes'][2]['token'] if kind=='move' else 1}

class AudioGraphTests(unittest.TestCase):
    def test_inventory_privacy_and_routes(self):
        v=A.inventory(fixture(),TOOLS);self.assertEqual(v['nodes'][0]['routes'],[4]);self.assertNotIn('private.secret',json.dumps(v));self.assertNotIn('must not appear',json.dumps(v))
    def test_move_argv(self):
        argv,*_=A.prepare(request(),A.inventory(fixture(),TOOLS));self.assertEqual(argv,['pw-metadata','-n','default','3','target.object','Spa:Id','105'])
    def test_profile_and_port(self):
        for kind in ['profile','port']:
            argv,*_=A.prepare(request(kind),A.inventory(fixture(),TOOLS));self.assertEqual(argv,['wpctl','set-'+('route' if kind=='port' else 'profile'),'4' if kind=='port' else '2','1'])
    def test_port_needs_current_node_and_observes_correct_profile_device(self):
        req=request('port');current=A.inventory(fixture(),TOOLS);argv,card,target=A.prepare(req,current);self.assertEqual(argv[2],'4')
        graph=fixture();graph[2]['info']['params']['Route']=[{'index':1,'device':99,'direction':'Output'}]
        self.assertFalse(A.observed(req,card,A.inventory(graph,TOOLS),target))
        graph[2]['info']['params']['Route']=[{'index':1,'device':0,'direction':'Output'}]
        self.assertTrue(A.observed(req,card,A.inventory(graph,TOOLS),target))
        graph=fixture();del graph[4]
        with self.assertRaises(ValueError):A.prepare(req,A.inventory(graph,TOOLS))
    def test_stale_provider_and_node_reuse(self):
        for mutate in [lambda g:g[0]['info'].update(cookie=19),lambda g:g[3]['info']['props'].update({'object.serial':900}),lambda g:g[6]['info'].update({'input-node-id':5})]:
            graph=fixture();mutate(graph)
            with self.assertRaises(ValueError):A.prepare(request(),A.inventory(graph,TOOLS))
    def test_reject_unknown_and_injected_option(self):
        for value in [2,'1;echo secret',True,-1,999]:
            req=request('profile');req['target']=value
            with self.assertRaises(ValueError):A.prepare(req,A.inventory(fixture(),TOOLS))
    def test_wrong_direction_and_nonmovable(self):
        graph=fixture();graph[5]['info']['props']['media.class']='Audio/Source'
        with self.assertRaises(ValueError):A.prepare(request(),A.inventory(graph,TOOLS))
        graph=fixture();graph[3]['info']['props']['node.dont-move']=True;v=A.inventory(graph,TOOLS);req=request();req['revision']=v['nodes'][0]['revision']
        with self.assertRaises(ValueError):A.prepare(req,v)
    def test_confirmation_observed_success(self):
        first=fixture();second=fixture();second[6]['info']['input-node-id']=5;graphs=iter([first,first,second]);writes=[]
        result=A.apply(request(),query=lambda:next(graphs),execute=lambda argv:writes.append(argv),wait=lambda n:None,tools=TOOLS)
        self.assertTrue(result['ok']);self.assertEqual(len(writes),1)
    def test_timeout_is_unverified(self):
        result=A.apply(request(),query=fixture,execute=lambda argv:None,wait=lambda n:None,seconds=0,tools=TOOLS)
        self.assertFalse(result['ok']);self.assertIn('may still finish',result['message'])
    def test_disappearing_target(self):
        graph=fixture();del graph[5];req=request();before=A.inventory(fixture(),TOOLS);_,obj,target=A.prepare(req,before)
        with self.assertRaises(ValueError):A.observed(req,obj,A.inventory(graph,TOOLS),target)
    def test_event_merge_preserves_inventory_and_removes(self):
        cache={};A.merge(cache,fixture());A.merge(cache,[{'id':2,'info':{'params':{'Profile':[{'index':1}]}}}]);self.assertEqual(A.inventory(list(cache.values()),TOOLS)['cards'][0]['profile'],1)
        A.merge(cache,[{'id':3,'info':None}]);self.assertNotIn(3,cache)
    def test_remembered_route_preferences(self):
        rule={'direction':'playback','appKey':'id:fixture.app','endpointName':'fixture-output'}
        prefs=P.validate({'schemaVersion':1,'amplification':False,'routes':[rule]});self.assertEqual(prefs['routes'],[rule])
        with self.assertRaises(ValueError):P.validate(dict(prefs,routes=[rule,rule]))
        with self.assertRaises(ValueError):P.validate(dict(prefs,routes=[dict(rule,endpointName='')]))
        self.assertEqual(P.validate({'schemaVersion':1,'amplification':False})['routes'],[])
    def test_preferences_safe_default_atomic(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'audio.json';self.assertFalse(P.load(path)['amplification']);P.save(path,{'schemaVersion':1,'amplification':True});self.assertTrue(P.load(path)['amplification']);self.assertEqual(path.stat().st_mode & 0o777,0o600)
            with self.assertRaises(ValueError):P.save(path,{'schemaVersion':2,'amplification':True})

if __name__=='__main__':unittest.main()
