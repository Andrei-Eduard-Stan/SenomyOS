#!/usr/bin/env python3
"""Install checksum-pinned upstream fallback fonts in the current user's font directory."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,tempfile,urllib.request

def main():
 root=Path(__file__).resolve().parents[1]
 records=json.loads((root/'appearance/shared/fonts/unicode-sources.json').read_text())['fonts']
 target=Path(os.environ.get('XDG_DATA_HOME',str(Path.home()/'.local/share')))/'fonts/senomy-unicode'
 target.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='senomy-unicode-') as tmp:
  for row in records:
   name=row['file'];assert Path(name).name==name and row['url'].startswith('https://raw.githubusercontent.com/')
   destination=target/name
   if destination.is_symlink():raise RuntimeError('Font destination is a symlink: '+name)
   if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest()==row['sha256']:continue
   with urllib.request.urlopen(urllib.request.Request(row['url'],headers={'User-Agent':'SenomyOS-unicode-fonts'}),timeout=60) as response:blob=response.read(40000001)
   if len(blob)>40000000 or hashlib.sha256(blob).hexdigest()!=row['sha256']:raise RuntimeError('Font checksum mismatch: '+name)
   path=Path(tmp)/name;path.write_bytes(blob)
   if destination.exists():raise RuntimeError('A different file already exists: '+str(destination))
   shutil.copyfile(path,destination);destination.chmod(0o644)
 config=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'fontconfig/conf.d/60-senomy-unicode.conf'
 expected=(root/'appearance/fontconfig/60-senomy-unicode.conf').read_bytes()
 if config.is_symlink() or config.exists() and config.read_bytes()!=expected:raise RuntimeError('An existing fallback configuration differs; it was preserved.')
 config.parent.mkdir(parents=True,exist_ok=True);config.write_bytes(expected)
 subprocess.run(['fc-cache','-f',str(target)],check=True,timeout=60)
 print(json.dumps({'ok':True,'font_directory':str(target),'config':str(config),'files':len(records)}))
if __name__=='__main__':main()
