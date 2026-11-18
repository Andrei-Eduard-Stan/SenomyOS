#!/usr/bin/env python3
"""Prepare verified user releases; explicit activation never starts services."""
import argparse,gzip,hashlib,io,json,os,shlex,subprocess,tarfile,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
FOLDERS=('shell','scripts','components','deploy','systemd','assets','appearance','wiki')
EXCLUDE={'__pycache__','.git','.pytest_cache','.venv','node_modules'}

def inventory(root=ROOT):
    paths=[]
    for name in FOLDERS:
        paths.extend(p for p in (root/name).rglob('*') if p.is_file() and not any(part in EXCLUDE for part in p.relative_to(root).parts))
    for document_root in (root/'docs', root/'docs/reference'):
        paths.extend(document_root.glob('*.md'))
    paths.extend(root/n for n in ('AGENTS.md','README.MD','hyprland.lua','hyprland.conf') if (root/n).is_file())
    paths.extend(p for p in root.glob('LICENSE*') if p.is_file())
    result=[]
    for p in sorted(set(paths)):
        if not p.resolve().is_relative_to(root.resolve()):raise ValueError('Source symlink escapes repository: '+str(p.relative_to(root)))
        payload=p.read_bytes()
        result.append({'path':str(p.relative_to(root)),'sha256':hashlib.sha256(payload).hexdigest(),'bytes':len(payload),'mode':'0755' if p.stat().st_mode & 0o111 else '0644'})
    return result

def prepared_payload(files, root=ROOT):
    """Pin executable release entry points; preserve source and payload provenance."""
    original={entry['path']:entry for entry in files}
    data={}
    for entry in files:
        content=(root/entry['path']).read_bytes()
        if hashlib.sha256(content).hexdigest()!=entry['sha256']:
            raise ValueError('Source changed during preparation: '+entry['path'])
        data[entry['path']]=content
    spec=json.loads(data['deploy/release.json'])
    names=set()
    for binding in spec['bindings']:
        if binding['root']!='bin':continue
        source=binding['source']
        from senomy_release import relative
        relative(source);name=str(relative(binding['path']))
        if '/' in name or name in names:raise ValueError('Invalid or duplicate release entry name')
        names.add(name)
        if original[source]['mode']!='0755' or name.endswith('.py'):continue  # Importable Python modules stay modules.
        entry='libexec/entries/'+name
        if entry in data:raise ValueError('Generated release path collides with source')
        binding['entrypoint']=entry
        data[entry]=('#!/usr/bin/env bash\n# Generated release entry point: never inherit a development checkout root.\nset -euo pipefail\nentry_path="$(readlink -f -- "${BASH_SOURCE[0]}")"\nrelease_root="$(cd -- "$(dirname -- "$entry_path")/../.." && pwd -P)"\nexport SENOMY_SOURCE_ROOT="$release_root"\nexport SENOMY_SESSION_ACTION="$release_root/scripts/senomy-session-action"\nexec "$release_root"/'+shlex.quote(source)+' "$@"\n').encode()
    data['deploy/release.json']=(json.dumps(spec,indent=2)+'\n').encode()
    result=[]
    for name,content in sorted(data.items()):
        previous=original.get(name)
        entry={'path':name,'sha256':hashlib.sha256(content).hexdigest(),'bytes':len(content),'mode':previous['mode'] if previous else '0755'}
        if not previous:entry['generated']=True
        elif entry['sha256']!=previous['sha256']:entry['source_sha256']=previous['sha256']
        result.append(entry)
    return result,data


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('action',choices=['plan','create','install','activate-plan','activate','rollback','recover','status']);parser.add_argument('destination',nargs='?');parser.add_argument('--store',type=Path);parser.add_argument('--legacy-source',type=Path);parser.add_argument('--legacy-release');parser.add_argument('--legacy-receipt',type=Path,action='append',default=[]);parser.add_argument('--confirm',action='store_true',help='Confirm reviewed release binding changes; never restarts a service');args=parser.parse_args()
    if args.action not in ('plan','create'):
        from senomy_release import Releases
        engine=Releases(args.store)
        if args.action=='status':result=engine.status()
        else:
            if not args.destination:parser.error('This action requires a candidate directory, release ID or receipt')
            if args.action=='install':result=engine.install(Path(args.destination))
            elif args.action=='activate-plan':result=engine.plan(args.destination,args.legacy_source,args.legacy_receipt,args.legacy_release)
            else:
                if not args.confirm:parser.error('Review activate-plan/receipt first, then supply --confirm')
                if args.action=='activate':result=engine.activate(args.destination,args.legacy_source,args.legacy_receipt,args.legacy_release)
                else:
                    with engine.locked():result=engine.restore(Path(args.destination))
        print(json.dumps(result,indent=2));return
    source_files=inventory();files,payload=prepared_payload(source_files);plan={'schema_version':2,'fileCount':len(files),'bytes':sum(f['bytes'] for f in files),'scope':'Prepared versioned payload; install and activation are separate reviewed operations','limits':['Dirty source is captured exactly; this is not a clean-release claim.','Hardware/session acceptance and font/artwork redistribution review remain required.','Dependencies are declared but not bundled; this is not an OS image or an installer.']}
    if args.action=='plan':print(json.dumps(plan,indent=2));return
    if args.destination is None:parser.error('create requires a new destination directory')
    target=Path(args.destination).expanduser().absolute()
    from senomy_release import safe
    safe(target)
    if target.exists() or target.is_symlink():parser.error('Destination already exists')
    if target.is_relative_to(ROOT):parser.error('Keep candidates outside the live source tree')
    target.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.senomy-release-',dir=target.parent) as d:
        temp=Path(d);archive=temp/'source.tar.gz'
        manifest={**plan,'files':files,'source_files':source_files,'installer_files':['senomy-release-snapshot.py','senomy_release.py'],'entrypoint_policy':'Pinned payload root; inherited development root is replaced only at release entry points'}
        with archive.open('wb') as stream,gzip.GzipFile(filename='',mode='wb',fileobj=stream,mtime=0) as compressed,tarfile.open(mode='w',fileobj=compressed,format=tarfile.PAX_FORMAT) as tar:
            for entry in files:
                data=payload[entry['path']]
                info=tarfile.TarInfo('senomyos/'+entry['path']);info.size=len(data);info.mode=int(entry['mode'],8);info.mtime=0;info.uid=info.gid=0
                tar.addfile(info,io.BytesIO(data))
        for entry in source_files:
            if hashlib.sha256((ROOT/entry['path']).read_bytes()).hexdigest()!=entry['sha256']:raise ValueError('Source changed during snapshot: '+entry['path'])
        (temp/'release.json').write_text(json.dumps(manifest,indent=2)+'\n')
        for name in manifest['installer_files']:
            (temp/name).write_bytes(payload['scripts/'+name])
            os.chmod(temp/name,0o755 if name=='senomy-release-snapshot.py' else 0o644)
        sums=''.join(hashlib.sha256((temp/name).read_bytes()).hexdigest()+'  '+name+'\n' for name in ('source.tar.gz','release.json',*manifest['installer_files']))
        (temp/'SHA256SUMS').write_text(sums)
        os.mkdir(target,mode=0o700)
        for name in ('source.tar.gz','release.json','SHA256SUMS',*manifest['installer_files']):
            if name not in manifest['installer_files']:os.chmod(temp/name,0o600)
            os.replace(temp/name,target/name)
    print(json.dumps({**plan,'destination':str(target)},indent=2))
if __name__=='__main__':
    try:main()
    except (ValueError,OSError,KeyError) as exc:
        print(json.dumps({'ok':False,'error':str(exc)}));raise SystemExit(1)
