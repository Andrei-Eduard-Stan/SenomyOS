#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
p=Path(os.environ['SENOMY_PRIVATE_CARE_FIXTURE'])/'care.json'
if not p.exists():
 d={'ok':True,'schemaVersion':1,'installed':True,'observedAt':1,'identity':'fixture','token':'a'*64,'persistentAvailable':True,'persistenceReason':'Inert fixture','packs':[{'name':b,'identity':b,'effective':[0,100],'supported':True,'startRange':[0,99],'stopRange':[1,100],'configured':None,'kernel':{'fullWh':20,'designWh':25,'cycles':10},'upower':{'EnergyFull':22,'EnergyFullDesign':25,'ChargeCycles':10,'ChargeThresholdEnabled':False,'ChargeStartThreshold':75,'ChargeEndThreshold':80},'capacityMismatch':True,'healthPercent':80,'healthBasis':'kernel energy_full / energy_full_design','reason':'Fixture only'}for b in ('BAT0','BAT1')],'lastReceipt':None}
else:d=json.loads(p.read_text())
a=sys.argv[1]
if a=='get':print(json.dumps(d));sys.exit(0)
r=json.loads(sys.argv[2]);assert r['token']==d['token']
if a=='apply':
 previous={p['name']:p['effective'][:]for p in d['packs']if p['name']in r['changes']}
 for pack in d['packs']:
  if pack['name']in r['changes']:pack['effective']=r['changes'][pack['name']]
 d['token']='b'*64;d['lastReceipt']={'receipt':'c'*32,'previous':previous,'persistent':r['persistent'],'restorableToken':d['token']}
elif a=='restore':
 for pack in d['packs']:
  if pack['name']in d['lastReceipt']['previous']:pack['effective']=d['lastReceipt']['previous'][pack['name']]
 d['token']='a'*64;d['lastReceipt']=None
else:raise ValueError('Invalid fixture verb')
p.write_text(json.dumps(d));print(json.dumps({'ok':True,'state':'verified','installed':True,'snapshot':d,'lastReceipt':d['lastReceipt'],'message':'Inert fixture readback verified.'}))
