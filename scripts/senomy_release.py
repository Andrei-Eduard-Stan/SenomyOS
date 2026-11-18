"""User release transactions. No service, package or compositor operations."""
import contextlib
import fcntl
import hashlib
import json
import os
import re
import shutil
import stat
import tarfile
import tempfile
import time
from pathlib import Path, PurePosixPath


def digest(data):
    return hashlib.sha256(data).hexdigest()


def relative(value):
    if not isinstance(value,str): raise ValueError('Unsafe relative path')
    p = PurePosixPath(value)
    if not value or p.is_absolute() or '..' in p.parts or str(p) != value:
        raise ValueError('Unsafe relative path')
    return p


def safe(path):
    """Refuse linked ancestors, including dangling links; never resolve before checking."""
    path = Path(os.path.abspath(path))
    for item in (*reversed(path.parents), path):
        if item.is_symlink():
            raise ValueError('Symlink refused: ' + str(item))
    return path


def atomic(path, data, mode=0o600):
    safe(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.transaction-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as out:
            out.write(data); out.flush(); os.fsync(out.fileno())
        os.chmod(name, mode)
        os.replace(name, path)
        sync_dir(path.parent)
    finally:
        if os.path.exists(name): os.unlink(name)


def sync_dir(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try: os.fsync(fd)
    finally: os.close(fd)


def write_json(path, value):
    atomic(path, (json.dumps(value, indent=2) + '\n').encode())


def read_json(path):
    safe(path)
    return json.loads(path.read_text())


def candidate(path):
    path = safe(path)
    manifest_data = (safe(path/'release.json')).read_bytes()
    archive = safe(path/'source.tar.gz')
    manifest = json.loads(manifest_data)
    installer=manifest.get('installer_files',[])
    if installer and installer!=['senomy-release-snapshot.py','senomy_release.py']: raise ValueError('Invalid installer inventory')
    for name in installer:
        entry=next((e for e in manifest['files'] if e['path']=='scripts/'+name),None)
        if not entry or digest(safe(path/name).read_bytes())!=entry['sha256']: raise ValueError('Installer/source integrity mismatch')
    expected = ''.join(digest(safe(path/n).read_bytes())+'  '+n+'\n' for n in ('source.tar.gz','release.json',*installer))
    if safe(path/'SHA256SUMS').read_text() != expected:
        raise ValueError('Candidate checksum mismatch')
    manifest = json.loads(manifest_data)
    files = manifest.get('files', [])
    if manifest.get('schema_version') != 2 or not files:
        raise ValueError('Prepare a schema-2 release with the maintained snapshot tool')
    seen = set()
    for entry in files:
        name = str(relative(entry['path']))
        if name in seen or entry['mode'] not in ('0644','0755') or not re.fullmatch('[a-f0-9]{64}', entry['sha256']):
            raise ValueError('Invalid manifest entry')
        seen.add(name)
    return digest(manifest_data), manifest, archive


def verify_tree(payload, manifest, sealed=True):
    safe(payload)
    expected = {e['path']: e for e in manifest['files']}
    actual = set()
    for path in payload.rglob('*'):
        safe(path)
        if path.stat().st_uid != os.getuid(): raise ValueError('Payload ownership drift')
        if path.is_file():
            name = str(path.relative_to(payload)); actual.add(name)
            entry = expected.get(name)
            if not entry or digest(path.read_bytes()) != entry['sha256']:
                raise ValueError('Payload content drift: '+name)
            mode = (0o555 if entry['mode']=='0755' else 0o444) if sealed else int(entry['mode'],8)
            if stat.S_IMODE(path.stat().st_mode) != mode or path.stat().st_uid != os.getuid():
                raise ValueError('Payload mode/owner drift: '+name)
        elif not path.is_dir(): raise ValueError('Unsupported payload entry')
    if actual != set(expected): raise ValueError('Payload inventory mismatch')
    required={'shell/quickshell/shell.qml','scripts/senomy-quickshell-run','scripts/senomy_app_launch.py','deploy/release.json','deploy/packages.json','appearance/tokens.json'}
    if not required<=actual: raise ValueError('Required runtime payload files missing')
    spec=read_json(payload/'deploy/release.json')
    if spec.get('schema_version')!=1 or not spec.get('bindings'): raise ValueError('Invalid release deployment manifest')
    for binding in spec['bindings']:
        if str(relative(binding['source'])) not in actual: raise ValueError('Missing runtime binding source')
        relative(binding['path'])
        if 'entrypoint' in binding:
            entry=str(relative(binding['entrypoint']))
            if binding['root']!='bin' or entry!='libexec/entries/'+binding['path'] or entry not in actual or expected[entry]['mode']!='0755':
                raise ValueError('Invalid generated release entry point')
        if binding['root'] not in ('bin','units','data'): raise ValueError('Unsupported runtime binding root')


class Releases:
    def __init__(self, store=None):
        self.store = safe(store or Path(os.environ.get('XDG_DATA_HOME', str(Path.home()/'.local/share')))/'senomyos/runtime')
        self.roots = {'bin': Path(os.environ.get('XDG_BIN_HOME', str(Path.home()/'.local/bin'))),
                      'units': Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config')))/'systemd/user',
                      'data': Path(os.environ.get('XDG_DATA_HOME', str(Path.home()/'.local/share')))}
        self.selector = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config')))/'senomyos/shell.json'

    @contextlib.contextmanager
    def locked(self):
        safe(self.store); self.store.mkdir(parents=True, exist_ok=True, mode=0o700)
        st = self.store.stat()
        if st.st_uid != os.getuid() or st.st_mode & 0o022:
            raise ValueError('Release store must be owned by this user and not group/world writable')
        lock = safe(self.store/'.lock')
        with lock.open('a') as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            yield

    def installed(self, release_id):
        if not re.fullmatch('[a-f0-9]{64}', release_id): raise ValueError('Invalid release ID')
        base = safe(self.store/'versions'/release_id)
        manifest_data = safe(base/'release.json').read_bytes()
        if digest(manifest_data) != release_id: raise ValueError('Installed manifest drift')
        manifest = json.loads(manifest_data)
        verify_tree(base/'payload', manifest)
        return base/'payload', manifest

    def install(self, source):
        release_id, manifest, archive = candidate(source)
        with self.locked():
            versions = safe(self.store/'versions'); versions.mkdir(exist_ok=True)
            target = versions/release_id
            if target.exists():
                self.installed(release_id)
                return {'release':release_id,'state':'already-installed'}
            with tempfile.TemporaryDirectory(prefix='.install-', dir=versions) as name:
                temp = Path(name); payload = temp/'payload'; payload.mkdir()
                indexed = {e['path']:e for e in manifest['files']}; seen=set()
                with tarfile.open(archive, 'r:gz') as tar:
                    for member in tar:
                        name = str(relative(member.name))
                        if not name.startswith('senomyos/') or not member.isfile(): raise ValueError('Unsafe archive entry')
                        name = name[len('senomyos/'):]; entry=indexed.get(name)
                        if not entry or name in seen or member.size != entry['bytes'] or member.mode != int(entry['mode'],8):
                            raise ValueError('Archive inventory mismatch')
                        seen.add(name)
                        data = tar.extractfile(member).read()
                        if digest(data) != entry['sha256']: raise ValueError('Archive content mismatch')
                        destination = payload/name; destination.parent.mkdir(parents=True,exist_ok=True)
                        atomic(destination, data, 0o555 if entry['mode']=='0755' else 0o444)
                if seen != set(indexed): raise ValueError('Incomplete archive')
                verify_tree(payload,manifest)
                manifest_bytes=safe(Path(source)/'release.json').read_bytes()
                if digest(manifest_bytes)!=release_id: raise ValueError('Candidate changed during installation')
                atomic(temp/'release.json',manifest_bytes,0o444)
                for folder in sorted((p for p in payload.rglob('*') if p.is_dir()), key=lambda p:len(p.parts), reverse=True): folder.chmod(0o555)
                payload.chmod(0o555)
                os.rename(temp,target); sync_dir(versions)
        return {'release':release_id,'state':'installed-inactive'}

    def current(self):
        link=self.store/'current'
        if not link.is_symlink():
            if link.exists(): raise ValueError('Current is not a managed link')
            return None
        target=os.readlink(link)
        if not re.fullmatch('versions/[a-f0-9]{64}/payload', target): raise ValueError('Unmanaged current target')
        self.installed(target.split('/')[1])
        return target

    def dependencies(self, payload):
        spec=read_json(payload/'deploy/release.json')
        packages=read_json(payload/'deploy/packages.json')
        available={name:shutil.which(name) is not None for name in spec['required_commands']+spec['optional_commands']}
        # pacman remains the package authority; this never synchronises a database.
        import subprocess
        installed=None
        if shutil.which('pacman'):
            r=subprocess.run(['pacman','-Qq'],capture_output=True,text=True,timeout=15)
            if r.returncode==0: installed=set(r.stdout.splitlines())
        missing=[p['package'] for p in packages['official'] if p['required'] and (installed is None or p['package'] not in installed)]
        return {'missing_required_commands':[n for n in spec['required_commands'] if not available[n]],
                'missing_optional_commands':[n for n in spec['optional_commands'] if not available[n]],
                'missing_required_packages':missing,'package_inventory_available':installed is not None}

    def legacy_preferences(self, payload, legacy):
        if legacy is None or not (legacy/'appearance/tokens.json').exists(): return {'migration_required':False}
        def skin(root):
            tokens=read_json(root/'appearance/tokens.json')
            manifest=root/'appearance'/str(relative(tokens.get('skin',{}).get('manifest','skins/default.json')))
            value=read_json(manifest)
            return {k:value.get(k,{}) for k in ('persona','backgrounds')}
        old=skin(legacy);new=skin(payload)
        path=self.selector.parent/'appearance.json';safe(path)
        override=read_json(path) if path.exists() else {'schemaVersion':1}
        if override.get('schemaVersion')!=1: raise ValueError('Unknown appearance preference schema')
        def effective(base,overlay):
            result=dict(base)
            for k,v in overlay.items():
                result[k]=effective(result.get(k,{}),v) if isinstance(v,dict) and isinstance(result.get(k,{}),dict) else v
            return result
        before=effective(old,override);after=effective(new,override)
        return {'migration_required':before!=after,'note':'Explicitly migrate legacy persona/background values before changing their defaults; no migration is performed by activation.'}

    def plan(self, release_id, legacy=None, legacy_receipts=(), legacy_release=None):
        payload, manifest=self.installed(release_id)
        spec=read_json(payload/'deploy/release.json'); items=[]; previous=self.current()
        previous_bindings={}
        if previous:
            previous_payload,_=self.installed(previous.split('/')[1])
            for binding in read_json(previous_payload/'deploy/release.json')['bindings']:
                previous_bindings[(binding['root'],binding['path'])]=binding
        if legacy: legacy=safe(legacy)
        owned={}
        for receipt in legacy_receipts:
            record=read_json(Path(receipt))
            if not legacy or record.get('status')!='applied': raise ValueError('Legacy receipt requires approved source and applied status')
            for item in record.get('entries',[]):
                if item.get('strategy')!='replace': continue
                scope={'user_bin':'bin','xdg_config':'config','xdg_data':'data'}.get(item['target']['root'])
                owned[(scope,str(relative(item['target']['path'])),str(relative(item['source'])))]=(item['source_hash'],int(item['mode'],8))
        if legacy_release:
            if not legacy: raise ValueError('A legacy release proof requires the reviewed legacy source root')
            reference,_=self.installed(legacy_release)
            for component in read_json(reference/'deploy/manifest.json')['components']:
                for item in component.get('entries',[]):
                    target=item.get('target',{})
                    if target.get('root')!='user_bin' or item.get('strategy')!='replace': continue
                    path=str(relative(target['path']));source=str(relative(item['source']))
                    mode=int(item['mode'],8)
                    if mode not in (0o644,0o755): continue
                    # Exact old published component source/mode, never a guessed
                    # target or arbitrary hash. Explicit applied receipts win.
                    owned.setdefault(('bin',path,source),(digest((reference/source).read_bytes()),mode))
        destinations=set()
        for entry in spec['bindings']:
            if entry['root'] not in self.roots: raise ValueError('Unknown binding root')
            source=str(relative(entry['source'])); target=self.roots[entry['root']]/str(relative(entry['path']))
            safe(target.parent)
            if target in destinations or target.is_relative_to(self.store) or target==self.selector:
                raise ValueError('Duplicate or reserved binding target')
            destinations.add(target)
            if not (payload/source).is_file(): raise ValueError('Missing binding source')
            expected=str(self.store/'current'/str(relative(entry.get('entrypoint',source))))
            before=self.image(target)
            if entry.get('existing_only') and before is None: continue
            allowed=before is None or before=={'kind':'link','target':expected}
            old_binding=previous_bindings.get((entry['root'],entry['path']))
            if old_binding and old_binding['source']==source:
                old_target=str(self.store/'current'/str(relative(old_binding.get('entrypoint',source))))
                allowed=allowed or before=={'kind':'link','target':old_target}
            if legacy and before:
                old=legacy/source
                allowed=allowed or before=={'kind':'link','target':str(old)}
                allowed=allowed or (before['kind']=='file' and old.is_file() and before['sha256']==digest(old.read_bytes()) and before['mode']==stat.S_IMODE(old.stat().st_mode))
            recorded=owned.get((entry['root'],entry['path'],source))
            if before and before['kind']=='file' and recorded:
                allowed=allowed or (before['sha256'],before['mode'])==recorded
            if not allowed: raise ValueError('Unmanaged or drifted target: '+str(target))
            items.append({'target':str(target),'before':before,'after':{'kind':'link','target':expected}})
        safe(self.selector)
        before=self.image(self.selector)
        if before:
            if before['kind']!='file': raise ValueError('Selector must be a regular file')
            value=json.loads(bytes.fromhex(before['data']))
            if value.get('schema_version')!=1: raise ValueError('Unknown selector schema')
        else: value={'schema_version':1,'selected_backend':'quickshell','login_default':'quickshell'}
        value['source_root']=str(self.store/'current')
        data=(json.dumps(value,indent=2)+'\n').encode()
        items.append({'target':str(self.selector),'before':before,'after':{'kind':'file','data':data.hex(),'sha256':digest(data),'mode':0o600}})
        return {'schema_version':1,'release':release_id,'previous':previous,'items':items,'dependencies':self.dependencies(payload),'legacy_reference_release':legacy_release,'preferences':self.legacy_preferences(payload,legacy) if previous is None else {'migration_required':False},
                'note':'No services are reloaded or started. Activate only at a separately authorised saved-work checkpoint.'}

    @staticmethod
    def image(path):
        if path.is_symlink(): return {'kind':'link','target':os.readlink(path)}
        if not path.exists(): return None
        if not path.is_file() or path.stat().st_uid!=os.getuid() or path.stat().st_mode & 0o022:
            raise ValueError('Unsafe managed target: '+str(path))
        data=path.read_bytes()
        return {'kind':'file','data':data.hex(),'sha256':digest(data),'mode':stat.S_IMODE(path.stat().st_mode)}

    @staticmethod
    def put(path, image):
        safe(path.parent); path.parent.mkdir(parents=True,exist_ok=True)
        if image is None:
            if path.exists() or path.is_symlink(): path.unlink()
        elif image['kind']=='file':
            if path.is_symlink(): path.unlink()
            atomic(path,bytes.fromhex(image['data']),image['mode'])
        else:
            temporary=path.parent/('.link-'+str(os.getpid()))
            if temporary.exists() or temporary.is_symlink(): raise ValueError('Link staging collision')
            temporary.symlink_to(image['target'])
            os.replace(temporary,path)
        sync_dir(path.parent)

    def activate(self, release_id, legacy=None, legacy_receipts=(), legacy_release=None):
        with self.locked():
            if self.pending(): raise ValueError('Unfinished transaction; inspect and recover before activation')
            plan=self.plan(release_id,legacy,legacy_receipts,legacy_release)
            if plan['preferences']['migration_required']: raise ValueError('Legacy appearance defaults differ; review explicit preference migration before activation')
            deps=plan['dependencies']
            if deps['missing_required_commands'] or deps['missing_required_packages']: raise ValueError('Required dependencies missing: '+json.dumps(deps))
            receipt=self.store/'transactions'/(str(time.time_ns())+'.json')
            plan.update(state='prepared',store=str(self.store)); write_json(receipt,plan)
            try:
                for entry in plan['items']:
                    path=Path(entry['target'])
                    if self.image(path)!=entry['before']: raise ValueError('Target drift during activation')
                    self.put(path,entry['after'])
                # The selected payload changes last, in one atomic rename.
                self.put(self.store/'current',{'kind':'link','target':'versions/'+release_id+'/payload'})
                plan['state']='activated';write_json(receipt,plan)
            except Exception:
                self.restore(receipt); raise
        return {'state':'activated-not-runtime-accepted','receipt':str(receipt),'release':release_id}

    def pending(self):
        return [str(p) for p in (self.store/'transactions').glob('*.json') if read_json(p).get('state')=='prepared']

    def restore(self, receipt):
        # Receipts must belong to this store; content is revalidated before each write.
        receipt=safe(receipt)
        if receipt.parent != self.store/'transactions': raise ValueError('Receipt outside release store')
        value=read_json(receipt)
        if value['store']!=str(self.store) or value['state'] not in ('prepared','activated'): raise ValueError('Receipt is not restorable')
        payload,_=self.installed(value['release'])
        bindings=read_json(payload/'deploy/release.json')['bindings']
        allowed={str(self.roots[e['root']]/str(relative(e['path']))):str(self.store/'current'/str(relative(e.get('entrypoint',e['source'])))) for e in bindings}
        seen=set()
        for entry in value['items']:
            path=Path(entry['target']);safe(path.parent)
            if str(path) in seen: raise ValueError('Duplicate receipt target')
            seen.add(str(path))
            if path==self.selector:
                if entry['after']['kind']!='file': raise ValueError('Invalid selector receipt')
            elif allowed.get(str(path)) != entry['after'].get('target') or entry['after']['kind']!='link': raise ValueError('Invalid receipt target')
            now=self.image(path)
            if now not in (entry['before'],entry['after']): raise ValueError('Rollback refused: target drift '+str(path))
        required={str(self.roots[e['root']]/str(relative(e['path']))) for e in bindings if not e.get('existing_only')}|{str(self.selector)}
        if not required<=seen or not seen<=set(allowed)|{str(self.selector)}: raise ValueError('Incomplete receipt')
        previous=value['previous']
        if previous is not None:
            if not re.fullmatch('versions/[a-f0-9]{64}/payload',previous): raise ValueError('Invalid previous release')
            self.installed(previous.split('/')[1])
        current=self.current()
        selected='versions/'+value['release']+'/payload'
        if current not in (selected,value['previous']): raise ValueError('Rollback refused: newer release selected')
        for entry in reversed(value['items']): self.put(Path(entry['target']),entry['before'])
        self.put(self.store/'current',None if value['previous'] is None else {'kind':'link','target':value['previous']})
        value['state']='rolled-back';write_json(receipt,value)
        return {'state':'rolled-back','receipt':str(receipt),'runtime':'unchanged; no restart performed'}

    def status(self):
        current=self.current()
        result={'state':'development-or-not-installed','current':current,'pending':self.pending()}
        if current:
            release_id=current.split('/')[1]
            plan=self.plan(release_id)
            if any(self.image(Path(e['target'])) != e['after'] for e in plan['items']):
                raise ValueError('Selected release bindings or selector drifted')
            result.update(state='selected-integrity-verified',release=release_id)
        return result
