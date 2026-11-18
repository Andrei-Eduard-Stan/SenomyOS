#!/usr/bin/env python3
"""Versioned appearance overrides. Never writes release defaults or migrates on read."""
import argparse
import copy
import fcntl
import json
import os
import sys
from pathlib import Path
from senomy_release import atomic, digest, safe

ROOT=Path(__file__).resolve().parents[1]


def object_value(value):
    if not isinstance(value,dict): raise ValueError('Expected a JSON object')
    return value


def validate(value):
    object_value(value)
    if value.get('schemaVersion')!=1: raise ValueError('Unsupported appearance preference schema')
    persona=object_value(value.get('persona',{}))
    for key in ('reducedMotion','hoverExpansionEnabled','highContrast'):
        if key in persona and not isinstance(persona[key],bool): raise ValueError('Invalid '+key)
    for key,lo,hi in (('railTextPx',10,16),('uiTextScale',1,1.5)):
        if key in persona and (type(persona[key]) not in (int,float) or not lo<=persona[key]<=hi): raise ValueError('Invalid '+key)
    backgrounds={**object_value(persona.get('backgrounds',{})),**object_value(value.get('backgrounds',{}))}
    for key,bg in backgrounds.items():
        object_value(bg)
        if 'source' in bg and not isinstance(bg['source'],str): raise ValueError('Invalid background source')
        if 'scaling' in bg and bg['scaling'] not in ('fit','crop'): raise ValueError('Invalid background scaling')
        for field in ('opacity','imageOpacity','scrimOpacity'):
            if field in bg and (type(bg[field]) not in (int,float) or not 0<=bg[field]<=1): raise ValueError('Invalid '+field)
        if 'color' in bg:
            import re
            if not isinstance(bg['color'],str) or not re.fullmatch('#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?',bg['color']): raise ValueError('Invalid background color')
    return value


def read(path):
    safe(path)
    if not path.exists(): return {'schemaVersion':1},'absent'
    st=path.stat()
    if not path.is_file() or st.st_uid!=os.getuid() or st.st_size>1048576 or st.st_mode & 0o022:
        raise ValueError('Unsafe appearance preferences')
    data=path.read_bytes()
    return validate(json.loads(data)),digest(data)


def merge(base,override):
    validate(base);validate(override)
    result=copy.deepcopy(base)
    result['persona']={**base.get('persona',{}),**override.get('persona',{})}
    for key,bg in override.get('backgrounds',{}).items():
        if key not in base.get('backgrounds',{}): raise ValueError('Unknown surface: '+key)
        result.setdefault('backgrounds',{})[key]={**result['backgrounds'][key],**bg}
    return validate(result)


def execute(action,base,path,request):
    validate(base)
    if action=='read':
        overlay,version=read(path)
    else:
        safe(path);path.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
        st=path.parent.stat()
        if st.st_uid!=os.getuid() or st.st_mode & 0o022: raise ValueError('Unsafe preference directory')
        with safe(path.with_suffix('.lock')).open('a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX)
            if action=='reset' and request.get('expected')==('absent' if not path.exists() else digest(path.read_bytes())):
                # Explicit reset can recover malformed JSON. Preserve its exact preimage.
                raw=path.read_bytes() if path.exists() else None
                if raw is not None: atomic(path.with_name('appearance-reset-'+digest(raw)+'.json'),raw)
                try:overlay,version=read(path)
                except (ValueError,json.JSONDecodeError):overlay,version={'schemaVersion':1},request['expected']
            else:overlay,version=read(path)
            if request.get('expected')!=version: raise ValueError('Appearance changed externally; reload before saving')
            if action=='save':
                key=request['key']
                if key not in base.get('backgrounds',{}): raise ValueError('Unknown surface')
                bg=object_value(request['background']);persona=object_value(request['persona'])
                overlay.setdefault('backgrounds',{})[key]={**overlay.get('backgrounds',{}).get(key,{}),**bg}
                overlay['persona']={**overlay.get('persona',{}),**persona}
            elif action=='migrate':
                # Explicit only. Existing user overrides win over legacy defaults.
                legacy=validate(json.loads(safe(Path(request['legacy'])).read_text()))
                legacy_overlay={'schemaVersion':1,'backgrounds':legacy.get('backgrounds',{}),'persona':legacy.get('persona',{})}
                legacy_overlay.update({k:v for k,v in overlay.items() if k not in ('backgrounds','persona')})
                for k,v in overlay.get('backgrounds',{}).items():legacy_overlay['backgrounds'][k]={**legacy_overlay['backgrounds'].get(k,{}),**v}
                legacy_overlay['persona'].update(overlay.get('persona',{}));overlay=legacy_overlay
            elif action=='reset':
                overlay.pop('backgrounds',None);overlay.pop('persona',None)
            else: raise ValueError('Unsupported preference operation')
            validate(overlay);merge(base,overlay)
            data=(json.dumps(overlay,indent=2,allow_nan=False)+'\n').encode()
            current='absent' if not path.exists() else digest(safe(path).read_bytes())
            if current!=version: raise ValueError('Appearance changed during validation; no save performed')
            atomic(path,data);version=digest(data)
            observed,observed_version=read(path)
            if observed_version!=version: raise ValueError('Appearance changed after write; inspect current settings before retrying')
    return {'ok':True,'schemaVersion':1,'version':version,'registry':merge(base,overlay),'path':str(path)}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['read','save','migrate','reset'])
    parser.add_argument('--base',type=Path)
    args=parser.parse_args()
    basepath=args.base
    if basepath is None:
        tokens=json.loads((ROOT/'appearance/tokens.json').read_text())
        basepath=ROOT/'appearance'/tokens.get('skin',{}).get('manifest','skins/default.json')
    base=json.loads(safe(basepath).read_text())
    path=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'senomyos/appearance.json'
    request={} if args.action=='read' else json.loads(sys.stdin.readline(65537))
    print(json.dumps(execute(args.action,base,path,request),allow_nan=False))


if __name__=='__main__':
    try:main()
    except (ValueError,OSError,KeyError) as exc:
        print(json.dumps({'ok':False,'error':str(exc)}));sys.exit(1)
