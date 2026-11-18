#!/usr/bin/env python3
"""Local Wiki utilities. Never execute a binding or interpolate library text in a shell."""
from __future__ import annotations
import bisect,fcntl,hashlib,json,os,re,shutil,subprocess,sys,tempfile,time,uuid
from pathlib import Path
MAX_BYTES=262144;MAX_ENTRIES=300
SEEDS=[
 ('smile','Smile','Faces','(ᵔᴥᵔ)'),('happy','Happy','Faces','(＾▽＾)'),('joy','Joy','Faces','٩(◕‿◕｡)۶'),('wave','Hello','Faces','(｡･ω･)ﾉﾞ'),('wink','Wink','Faces','(^_~)'),('shrug','Shrug','Faces','¯\\_(ツ)_/¯'),('tableflip','Table flip','Faces','(╯°□°）╯︵ ┻━┻'),('tableback','Put it back','Faces','┬─┬ノ( º _ ºノ)'),('bear','Bear','Animals','ʕ•ᴥ•ʔ'),('cat','Cat','Animals','(=^･ω･^=)'),('bunny','Bunny','Animals','(\\_/ )\n( •_•)\n/ >♡'),('bird','Bird','Animals','(•ө•)'),('hug','Hug','Affection','(つ≧▽≦)つ'),('love','Love','Affection','♡(˃͈ દ ˂͈ ༶ )'),('heart','Heart','Affection','♡'),('hearts','Hearts','Affection','♥ ♡ ღ ❥'),('blush','Blush','Affection','(⁄ ⁄•⁄ω⁄•⁄ ⁄)'),('sparkle','Sparkles','Decorations','✦ ✧ ⋆ ˚｡⋆'),('wings','Little wings','Decorations','𓆩♡𓆪'),('bow','Bow','Decorations','୨୧'),('divider','Divider','Decorations','─── ⋆⋅☆⋅⋆ ───'),('stars','Star border','Decorations','⋆｡°✩ ⋆｡°✩'),('flower','Flowers','Decorations','❀ ✿ ❁'),('moon','Moon and stars','Decorations','☾ ⋆⁺₊⋆'),('happy-emoji','Happy emoji','Emoji','😊 ✨ 🥰'),('celebrate','Celebrate','Emoji','🎉 🎊 🥳'),('nature','Nature','Emoji','🌿 🌸 🦋'),('tools','Tools','Emoji','🛠️ 💻 ⚙️'),('arrows','Arrows','Symbols','← ↑ → ↓ ↔ ↕'),('check','Checks','Symbols','✓ ✔ ☑'),('math','Math','Symbols','∞ ≈ ≠ ± × ÷ √'),('music','Music','Symbols','♪ ♫ ♬'),('ascii-smile','ASCII smile','ASCII',':-)'),('ascii-wave','ASCII wave','ASCII','o/'),('ascii-heart','ASCII heart','ASCII','<3'),('ascii-shrug','ASCII shrug','ASCII','¯\\_(o_o)_/¯')]

def seeds():return [dict(id='builtin-'+i,name=n,category=c,text=t,custom=False) for i,n,c,t in SEEDS]
def data_root():return Path(os.environ.get('XDG_DATA_HOME',str(Path.home()/'.local/share')))/'senomyos/wiki'
def read_store():
 p=data_root()/'emoticons.json'
 if not p.exists():return {'version':1,'entries':[],'favorites':[]}
 if p.is_symlink() or not p.is_file() or p.stat().st_size>MAX_BYTES:raise ValueError('Library file is unsafe or too large; your saved file was not changed.')
 v=json.loads(p.read_text(encoding='utf-8'))
 if not isinstance(v,dict) or v.get('version')!=1 or not isinstance(v.get('entries'),list) or len(v['entries'])>MAX_ENTRIES:raise ValueError('Saved library format is invalid; your file was not changed.')
 v['entries']=[validate_entry(e,existing=True) for e in v['entries']]
 if len({e['id'] for e in v['entries']})!=len(v['entries']):raise ValueError('Saved library contains duplicate IDs.')
 if not isinstance(v.get('favorites',[]),list) or len(v.get('favorites',[]))>MAX_ENTRIES+len(SEEDS):raise ValueError('Saved favorites format is invalid.')
 v['favorites']=[x for x in v.get('favorites',[]) if isinstance(x,str) and len(x)<90]
 return v

def clean(value,limit,label):
 if not isinstance(value,str) or not value.strip() or len(value)>limit or any(ord(c)<32 and c not in '\n\t' for c in value) or any(0xd800<=ord(c)<=0xdfff for c in value):raise ValueError(f'{label} is empty, too long or contains invalid control characters.')
 return value

def validate_entry(e,existing=False):
 if not isinstance(e,dict):raise ValueError('Invalid library entry.')
 key=e.get('id') or ('user-'+uuid.uuid4().hex)
 if not re.fullmatch(r'user-[a-f0-9]{32}',key):raise ValueError('Invalid personal entry ID.')
 return dict(id=key,name=clean(e.get('name'),80,'Name').strip(),category=clean(e.get('category') or 'Personal',40,'Category').strip(),text=clean(e.get('text'),2000,'Emoticon'),custom=True)

def mutate(operation,request):
 root=data_root();root.mkdir(parents=True,exist_ok=True,mode=0o700)
 if root.is_symlink():raise ValueError('Library directory must not be a symlink.')
 lock=root/'.library.lock'
 fd=os.open(lock,os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
 with os.fdopen(fd,'w') as held:
  fcntl.flock(held,fcntl.LOCK_EX);v=read_store();entries=v['entries']
  if operation=='save':
   entry=validate_entry(request);found=next((i for i,e in enumerate(entries) if e['id']==entry['id']),None)
   if found is None:
    if len(entries)>=MAX_ENTRIES:raise ValueError('Personal library is full (300 entries).')
    entries.append(entry)
   else:entries[found]=entry
  elif operation=='remove':
   key=request.get('id');entries[:]=[e for e in entries if e['id']!=key];v['favorites']=[k for k in v['favorites'] if k!=key]
  elif operation=='favorite':
   key=request.get('id')
   if key not in {e['id'] for e in seeds()+entries}:raise ValueError('This entry is no longer available.')
   if key in v['favorites']:v['favorites'].remove(key)
   else:v['favorites'].append(key)
  else:raise ValueError('Unsupported library action.')
  blob=(json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
  if len(blob)>MAX_BYTES:raise ValueError('Library exceeds its storage limit.')
  temp_fd,temp_path=tempfile.mkstemp(prefix='.emoticons-',dir=root)
  try:
   with os.fdopen(temp_fd,'wb') as f:f.write(blob);f.flush();os.fsync(f.fileno())
   os.replace(temp_path,root/'emoticons.json')
  finally:
   if os.path.exists(temp_path):os.unlink(temp_path)
 return library()

def coverage():
 if not shutil.which('fc-list'):return None
 result=subprocess.run(['fc-list','-f','%{charset}\n'],capture_output=True,text=True,timeout=5,check=True)
 intervals=[]
 for token in result.stdout.split():
  try:
   lo,_,hi=token.partition('-');intervals.append((int(lo,16),int(hi or lo,16)))
  except ValueError:continue
 merged=[]
 for lo,hi in sorted(intervals):
  if merged and lo<=merged[-1][1]+1:merged[-1]=(merged[-1][0],max(hi,merged[-1][1]))
  else:merged.append((lo,hi))
 starts=[a for a,b in merged]
 def supports(c):
  code=ord(c)
  if c.isspace() or code in [0x200d,0xfe0e,0xfe0f]:return True
  i=bisect.bisect_right(starts,code)-1
  return i>=0 and code<=merged[i][1]
 return supports

def library():
 v=read_store();support=coverage();entries=seeds()+v['entries']
 for e in entries:
  e['favorite']=e['id'] in v['favorites'];e['missing']=sorted({f'U+{ord(c):04X}' for c in e['text'] if support is not None and not support(c)})
 font_dir=Path(os.environ.get('XDG_DATA_HOME',str(Path.home()/'.local/share')))/'fonts/senomy-unicode'
 return {'entries':entries,'personalCount':len(v['entries']),'coverageAvailable':support is not None,'fontFiles':[p.as_uri() for p in sorted(font_dir.glob('*')) if p.suffix.lower() in ['.ttf','.otf']],'clipboardAvailable':bool(shutil.which('wl-copy'))}

# A deliberately limited static reader for label enrichment, never a Lua evaluator.
def split_top(text,delimiter=','):
 out=[];start=0;depth=0;quote='';escaped=False;i=0
 while i<len(text):
  c=text[i]
  if quote:
   if escaped:escaped=False
   elif c=='\\':escaped=True
   elif c==quote:quote=''
  elif c in "\"'":quote=c
  elif c in '({[':depth+=1
  elif c in ')}]':depth-=1
  elif depth==0 and text.startswith(delimiter,i):out.append(text[start:i].strip());i+=len(delimiter);start=i;continue
  i+=1
 out.append(text[start:].strip());return out

def literal(expr,variables):
 pieces=[]
 for token in split_top(expr,'..'):
  if token in variables:pieces.append(str(variables[token]));continue
  if re.fullmatch(r'\d+',token):pieces.append(token);continue
  if len(token)>1 and token[0] in "\"'" and token[-1]==token[0]:
   # Decode only the trivial quoted constants used in key expressions.
   pieces.append(re.sub(r'\\([\\\"\'])',r'\1',token[1:-1]));continue
  return None
 return ''.join(pieces)
MODS={'SHIFT':1,'CAPS':2,'CTRL':4,'CONTROL':4,'ALT':8,'MOD2':16,'MOD3':32,'SUPER':64,'WIN':64,'MOD4':64,'MOD5':128}
def chord(ch):
 bits=[x.strip() for x in ch.split('+')];mask=0
 for part in bits[:-1]:mask|=MODS.get(part.upper(),0)
 return mask,bits[-1].upper()

def label(action,args):
 ops={'window.close':('Close focused window','Windows'),'exit':('End Hyprland session','System'),'window.float':('Toggle floating','Windows'),'window.pseudo':('Toggle pseudo tiling','Windows'),'window.drag':('Drag window with pointer','Windows'),'window.resize':('Resize window with pointer','Windows'),'workspace.toggle_special':('Toggle special workspace','Workspaces')}
 if action in ops:return ops[action]
 if action=='layout':return ('Toggle split direction' if 'togglesplit' in args else 'Layout action','Windows')
 if action in ['focus','window.swap','window.move']:
  target=re.search(r'(direction|workspace)\s*=\s*([^,}]+)',args)
  if target:
   kind,value=target.groups();value=value.strip(' \"\'');prefix='Focus' if action=='focus' else 'Swap window' if action=='window.swap' else 'Move window'
   return (prefix+(' workspace ' if kind=='workspace' else ' ')+value,'Workspaces' if kind=='workspace' else 'Windows')
 if action=='exec_cmd':
  known=[('senomy-lock','Lock screen','System'),('switchxkblayout','Next keyboard layout','System'),('senomy-fullscreen immersive','Toggle immersive fullscreen','Windows'),('senomy-fullscreen','Toggle fullscreen','Windows'),('show-settings','Open Settings','SenomyOS'),('show-control','Open Control Centre','SenomyOS'),('senomy-osk','Toggle on-screen keyboard','SenomyOS'),('senomy-screenshot','Take a screenshot','System'),('senomy-surface dismiss','Dismiss Senomy surface','SenomyOS'),('set-volume','Adjust output volume','Media'),('set-mute @DEFAULT_AUDIO_SOURCE@','Toggle microphone mute','Media'),('set-mute','Toggle output mute','Media'),('brightnessctl','Adjust display brightness','Media'),('playerctl next','Next track','Media'),('playerctl previous','Previous track','Media'),('playerctl play-pause','Play / pause','Media'),('terminal','Open terminal','Applications'),('fileManager','Open file manager','Applications'),('menu','Open app launcher','Applications'),('kitty','Open terminal','Applications'),('thunar','Open file manager','Applications')]
  for token,title,group in known:
   if token in args:
    if token=='set-volume':title='Volume up' if '5%+' in args else 'Volume down' if '5%-' in args else title
    if token=='brightnessctl':title='Brightness up' if '5%+' in args else 'Brightness down' if '5%-' in args else title
    return title,group
  return 'Custom command','Applications'
 return action.replace('_',' ').replace('.',' / '),'Other'

def source_labels(path):
 if not path.is_file() or path.stat().st_size>1048576:return {}
 text=path.read_text(encoding='utf-8');variables={};labels={}
 for name,expr in re.findall(r'^\s*local\s+(\w+)\s*=\s*(.+)$',text,re.M):
  value=literal(expr,variables)
  if value is not None:variables[name]=value
 def bind(line,context):
  start=line.find('hl.bind(')
  if start<0:return
  body=line[start+8:].strip()
  if not body.endswith(')'):return
  fields=split_top(body[:-1])
  if len(fields)<2:return
  keys=literal(fields[0],context);m=re.fullmatch(r'hl\.dsp\.([\w.]+)\((.*)\)',fields[1])
  if keys is None or not m:return
  action,args=m.groups()
  for key,value in context.items():
   if key in ['direction','workspace']:args=re.sub(r'\b'+key+r'\b(?=\s*[,}])',str(value),args)
  title,group=label(action,args);labels[(chord(keys),action.split('.')[-1])]=(title,group)
 lines=text.splitlines();i=0
 while i<len(lines):
  line=lines[i];count=re.search(r'for\s+(\w+)\s*=\s*(\d+)\s*,\s*(\d+)\s+do',line);pairs=re.search(r'for\s+(\w+)\s*,\s*(\w+)\s+in\s+pairs\(\{(.*)\}\)\s+do',line)
  if count or pairs:
   end=i+1
   while end<len(lines) and lines[end].strip()!='end':end+=1
   contexts=[]
   if count:
    variable,start,stop=count.groups()
    if 0<=int(start)<=int(stop)<=100:
     for n in range(int(start),int(stop)+1):
      ctx=dict(variables);ctx[variable]=n
      for k,base,mod in re.findall(r'local\s+(\w+)\s*=\s*(\w+)\s*%\s*(\d+)', '\n'.join(lines[i+1:end])):
       if base in ctx and int(mod)>0:ctx[k]=int(ctx[base])%int(mod)
      contexts.append(ctx)
   else:
    a,b,content=pairs.groups()
    for key,expr in re.findall(r'(\w+)\s*=\s*("[^"]*"|\x27[^\x27]*\x27)',content):
     contexts.append(dict(variables,**{a:key,b:literal(expr,{})}))
   for ctx in contexts:
    for row in lines[i+1:end]:bind(row,ctx)
   i=end
  else:bind(line,variables)
  i+=1
 return labels

def shortcuts():
 if not shutil.which('hyprctl'):return dict(available=False,bindings=[],message='Hyprland is unavailable in this session.')
 try:
  result=subprocess.run(['hyprctl','-j','binds'],capture_output=True,text=True,timeout=4,check=True)
  if len(result.stdout)>2097152:raise ValueError('Binding list exceeds its read limit.')
  raw=json.loads(result.stdout)
  if not isinstance(raw,list) or len(raw)>3000:raise ValueError('Invalid binding list.')
 except (subprocess.SubprocessError,ValueError) as e:return dict(available=False,bindings=[],message='Could not read active Hyprland bindings. Refresh to retry.')
 cfg=Path(os.environ.get('SENOMY_HYPR_CONFIG',str(Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'hypr/hyprland.lua')))
 try:labels=source_labels(cfg)
 except (OSError,ValueError):labels={}
 policy={}
 try:
  policy_path=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'senomyos/display-manager.json'
  if policy_path.is_file() and policy_path.stat().st_size<=1048576:policy=json.loads(policy_path.read_text())
  if not isinstance(policy,dict):policy={}
 except (OSError,ValueError):pass
 rows=[]
 for i,b in enumerate(raw):
  mask=int(b.get('modmask') or 0);key=str(b.get('key') or ('code:'+str(b.get('keycode',0))))[:100];dispatcher=str(b.get('dispatcher',''))[:120]
  match=re.fullmatch(r'HL\.Dispatcher\(([^)]+)\)',dispatcher);action=match.group(1) if match else dispatcher
  enriched=labels.get(((mask,key.upper()),action))
  label_source='Config label'
  if action=='exec_cmd' and policy.get('managedShortcuts') is True and mask in (64,65) and re.fullmatch('[0-9]',key):
   enriched=(('Move window to' if mask==65 else 'Focus')+' local workspace slot '+str(int(key) or 10),'Workspaces');label_source='Senomy workspace policy'
  if action=='exec_cmd' and policy and policy.get('managedProjectionShortcut',True) and mask==68 and key.upper()=='P':
   enriched=('Open projection options','SenomyOS');label_source='Senomy workspace policy'
  title,group=enriched or label(action,str(b.get('arg') or '') if not match else '')
  if b.get('description'):title=str(b['description'])[:240]
  mods=[name for bit,name in [(64,'Super'),(4,'Ctrl'),(8,'Alt'),(1,'Shift'),(2,'Caps'),(16,'Mod2'),(32,'Mod3'),(128,'Mod5')] if mask&bit]
  friendly={'MOUSE:272':'Left click','MOUSE:273':'Right click','MOUSE_DOWN':'Scroll down','MOUSE_UP':'Scroll up','SPACE':'Space','ESCAPE':'Esc','PRINT':'Print Screen'}
  shown=friendly.get(key.upper(),key)
  flags=[name for field,name in [('locked','Works when locked'),('repeat','Repeats'),('release','On release'),('mouse','Pointer'),('non_consuming','Non-consuming'),('longPress','Long press'),('catch_all','Catch all'),('auto_consuming','Auto-consuming')] if b.get(field)]
  rows.append(dict(id=str(i),chord=' + '.join(mods+[shown]),key=key,action=title,group=group,dispatcher=action,submap=str(b.get('submap') or 'Default')[:100],flags=flags,labelSource=label_source if enriched else 'Runtime description' if b.get('description') else 'Runtime dispatcher'))
 rows.sort(key=lambda row:(row['group'],row['action'],row['chord']))
 return dict(available=True,bindings=rows,count=len(rows),observedAt=int(time.time()),message='Active bindings from Hyprland. Lua labels are read from the current config; unrecognized actions keep their runtime dispatcher name.')

def main():
 try:
  action=sys.argv[1] if len(sys.argv)==2 else ''
  if action=='catalog':data=library();data['shortcuts']=shortcuts()
  elif action=='shortcuts':data={'shortcuts':shortcuts()}
  elif action in ['save','remove','favorite','copy']:
   raw=sys.stdin.buffer.readline(16385)
   if len(raw)>16384:raise ValueError('Request is too large.')
   request=json.loads(raw.decode('utf-8'))
   if not isinstance(request,dict):raise ValueError('Invalid request.')
   if action=='copy':
    text=clean(request.get('text'),4000,'Clipboard text')
    if not shutil.which('wl-copy'):raise ValueError('Clipboard unavailable: wl-copy is not installed.')
    subprocess.run(['wl-copy','--type','text/plain;charset=utf-8'],input=text.encode('utf-8'),stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=5,check=True);data={'copied':True}
   else:data=mutate(action,request)
  else:raise ValueError('Unsupported Wiki utility action.')
  print(json.dumps({'ok':True,'data':data},ensure_ascii=False));return 0
 except (OSError,ValueError,TypeError,KeyError,subprocess.SubprocessError) as exc:
  print(json.dumps({'ok':False,'error':str(exc)[:240]},ensure_ascii=False));return 1
if __name__=='__main__':raise SystemExit(main())
