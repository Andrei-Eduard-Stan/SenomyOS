/** Editable current-source atlas. PptxGenJS, real PNG captures, native text/shapes. */
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const HERE=path.dirname(fileURLToPath(import.meta.url));
const OUT=path.dirname(HERE), ROOT=path.resolve(OUT,'../../..');
const require=createRequire(path.join(process.env.ATLAS_DEPS||'/tmp/senomy-atlas-deps','package.json'));
const pptxgen=require('pptxgenjs');
const JSZip=require('jszip');
let sharp;try{sharp=require('sharp');}catch{sharp=createRequire('/usr/lib/chatgpt/resources/cua_node/lib/node_modules/package.json')('sharp');}
const pptx=new pptxgen();
pptx.defineLayout({name:'ATLAS',width:16,height:9});pptx.layout='ATLAS';
pptx.author='SenomyOS';pptx.subject='Current-source visual inventory and editable redesign workbook';
pptx.title='SenomyOS UI/UX Design Atlas';pptx.company='SenomyOS';pptx.lang='en-GB';
pptx.theme={headFontFace:'Bruno Ace SC',bodyFontFace:'Adwaita Sans',lang:'en-GB'};
const C={bg:'08090B',surface:'0F1115',ink:'F1F1F4',muted:'92959F',dim:'666A74',line:'343842',violet:'9892E8',warning:'C8A367',danger:'C46F7D',success:'7FA98A'};
const FONT={heading:'Bruno Ace SC',body:'Adwaita Sans',data:'Audiowide',meta:'JetBrainsMono Nerd Font'};
const W=16,H=9,M=.5;
pptx.defineSlideMaster({title:'ATLAS_COMPARISON',background:{color:C.bg},objects:[
 {placeholder:{options:{name:'beforeArea',type:'body',x:.75,y:2.15,w:6.75,h:3.8,fontFace:FONT.body,fontSize:20,color:C.dim,margin:0,align:'center',valign:'mid'},text:'Insert current screenshot'}},
 {placeholder:{options:{name:'afterArea',type:'body',x:8.5,y:2.15,w:6.75,h:3.8,fontFace:FONT.body,fontSize:20,color:C.dim,margin:0,align:'center',valign:'mid'},text:'Insert proposed design'}}
]});
const all=[], byId=new Map(), slides=[], assetMeta=new Map(), geometry=[], imageSlides=new Map();
await fs.mkdir(path.join(OUT,'screenshots/crops'),{recursive:true});
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const rel=p=>path.relative(OUT,p).replaceAll('\\','/');
const qml=n=>'shell/quickshell/components/'+n+'.qml';
const cap=p=>path.join(OUT,'screenshots/full',p+'.png');
const exists=async p=>!!(await fs.stat(p).catch(()=>false));

async function asset(p,state='',method='NATIVE PREVIEW',notes=''){
 if(!await exists(p))return null;
 if(!assetMeta.has(p)){const b=await fs.readFile(p),m=await sharp(b).metadata();assetMeta.set(p,{path:rel(p),width:m.width,height:m.height,sha256:sha(b),state,capture_method:method,notes});}
 return {...assetMeta.get(p),state:state||assetMeta.get(p).state,capture_method:method,notes};
}
async function add(id,name,category,source,images=[],extra={}){
 const item={id,name,category,kind:'surface',owner:category,route:null,source_files:Array.isArray(source)?source:[source],captures:[],slide_refs:[],review_status:'Unreviewed',redesign_status:'Pending',implementation_status:'Not started',priority:'P2 · proposal',notes:[],...extra};
 for(const im of images){const a=await asset(typeof im==='string'?cap(im):im.path,typeof im==='string'?path.basename(im):im.state,typeof im==='string'?'NATIVE PREVIEW':im.method||'NATIVE PREVIEW',typeof im==='string'?'':im.notes||'');if(a)item.captures.push(a);}
 item.capture_status=item.captures.length?'captured':'unavailable';
 if(item.captures[0]?.capture_method==='UNAVAILABLE')item.capture_status='projection_only';
 all.push(item);byId.set(id,item);return item;
}
const items=id=>byId.get(id);
const main=item=>item?.captures[0];
function ref(item,slide){if(item&&!item.slide_refs.includes(slide._atlasNo))item.slide_refs.push(slide._atlasNo);}
function rect(slide,x,y,w,h,fill=null,line=C.line,dash=null){slide.addShape(pptx.ShapeType.rect,{x,y,w,h,fill:fill?{color:fill}:{color:C.bg,transparency:100},line:line?{color:line,width:.7,...(dash?{dashType:dash}:{})}:{transparency:100}});geometry.push({slide:slide._atlasNo,x,y,w,h,type:'shape'});}
function text(slide,str,x,y,w,h,size=16,color=C.ink,font=FONT.body,opts={}){
 slide.addText(String(str),{x,y,w,h,fontFace:font,fontSize:size,color,margin:0,breakLine:false,paraSpaceAfterPt:0,vertAnchor:'top',valign:'top',...opts});
 geometry.push({slide:slide._atlasNo,x,y,w,h,type:'text',text:String(str),size});
}
function line(slide,x,y,w,color=C.line){slide.addShape(pptx.ShapeType.line,{x,y,w,h:0,line:{color,width:.6}});}
function base(section,title,subtitle='',masterName=null){
 const s=pptx.addSlide(masterName?{masterName}:{});s.background={color:C.bg};s._atlasNo=slides.length+1;s._atlasSection=section;
 slides.push({number:s._atlasNo,section,title});
 text(s,section.toUpperCase(),M,.27,13,.22,9,C.violet,FONT.meta,{charSpacing:1.5});
 text(s,title,M,.65,15,.5,26,C.ink,FONT.heading);
 if(subtitle)text(s,subtitle,M,1.16,15,.38,12,C.muted);
 line(s,M,8.62,15);text(s,'SENOMYOS  /  UIUX ATLAS  /  CURRENT SOURCE',M,8.74,12,.18,8,C.dim,FONT.meta);
 text(s,String(s._atlasNo).padStart(3,'0'),14.65,8.71,.85,.25,10,C.muted,FONT.meta,{align:'right'});
 return s;
}
function pic(s,a,x,y,w,h,{align='center',back=false}={}){
 if(!a)return;
 const ratio=a.width/a.height,box=w/h;let iw=w,ih=h;
 if(ratio>box)ih=w/ratio;else iw=h*ratio;
 const px=align==='left'?x:x+(w-iw)/2,py=y+(h-ih)/2;
 if(back)rect(s,x,y,w,h,C.bg,null);
 s.addImage({path:path.join(OUT,a.path),x:px,y:py,w:iw,h:ih,altText:a.path});
 if(!imageSlides.has(a.path))imageSlides.set(a.path,new Set());imageSlides.get(a.path).add(s._atlasNo);
 geometry.push({slide:s._atlasNo,x:px,y:py,w:iw,h:ih,type:'image',path:a.path,pixel_width:a.width,pixel_height:a.height});
}
function sourceNote(s,related,notes=''){
 const lines=related.filter(Boolean).map(i=>`${i.id}: ${i.source_files.join(', ')}\n${i.captures.map(c=>`${c.capture_method}: ${c.path} (${c.state})`).join('\n')}`);
 s.addNotes([...lines,notes||'Current authored source. Controlled synthetic data and an offscreen Qt host. No live device or account action.'].join('\n\n'));
 related.forEach(i=>ref(i,s));
}
async function crop(parent,name,r,state='detail'){
 const p=path.join(OUT,parent.path), m=await sharp(p).metadata();
 const left=Math.max(0,Math.round(r[0])),top=Math.max(0,Math.round(r[1]));
 const width=Math.min(m.width-left,Math.round(r[2])),height=Math.min(m.height-top,Math.round(r[3]));
 if(width<1||height<1)throw Error('Invalid crop '+name);
 const target=path.join(OUT,'screenshots/crops',name+'.png');
 await sharp(p).extract({left,top,width,height}).png().toFile(target);
 const a=await asset(target,state,parent.capture_method,parent.notes);a.crop_of=parent.path;a.crop_rect={x:left,y:top,width,height};return a;
}
function label(s,item,x,y,w=4.5,detail=''){
 text(s,item.id,x,y,w,.2,9,C.violet,FONT.meta);
 text(s,item.name,x,y+.28,w,.6,15,C.ink,FONT.body);
 if(detail)text(s,detail,x,y+.91,w,.75,11,C.muted);
}
function board(title,group,section='A · Master interface overview',subtitle='Actual current components. Controlled native previews, unless individually labelled.'){
 const s=base(section,title,subtitle),n=group.length,cols=n<=2?2:3,rows=Math.ceil(n/cols);
 const top=1.77,bottom=8.35,gap=.3,cw=(15-gap*(cols-1))/cols,ch=(bottom-top-gap*(rows-1))/rows;
 group.forEach((g,i)=>{const item=g.item||g,a=g.asset||main(item),x=M+(i%cols)*(cw+gap),y=top+Math.floor(i/cols)*(ch+gap);text(s,item.id,x,y,cw,.2,9,C.violet,FONT.meta);text(s,g.label||item.name,x,y+.25,cw,.32,13,C.ink);pic(s,a,x,y+.74,cw,ch-1.0);if(a?.capture_method==='UNAVAILABLE')text(s,'OFFLINE PROJECTION ONLY',x,y+ch-.2,cw,.2,9,C.warning,FONT.meta);ref(item,s);});
 sourceNote(s,group.map(g=>g.item||g));return s;
}
async function gallery(item,a=main(item),title=null){
 const s=base('B · Current-state gallery',title||item.name,`${item.id}    ${item.route||item.owner}    ${a?.capture_method||'UNAVAILABLE'}`);
 if(!a){text(s,'UNAVAILABLE',M,2,10,.6,28,C.warning,FONT.heading);text(s,item.notes.join('\n'),M,3,13,2,18,C.muted);sourceNote(s,[item]);return s;}
 if(item.id==='SHELL-RAIL'){
   item.captures.forEach((capture,i)=>{const y=1.8+i*1.55;text(s,capture.state+' logical pixels',.5,y,10,.25,12,C.violet,FONT.meta);pic(s,capture,.5,y+.37,capture.width*15/1920,.625,{align:'left'});});
   text(s,'Consistent scale across responsive variants',8.6,5.2,6.8,.4,16,C.ink);text(s,'Actual Rail content and breakpoint equations. Synthetic workspaces and system values. Individual modules appear on the next page.',8.6,5.83,6.8,1.0,14,C.muted);sourceNote(s,[item]);return s;
 }
 if(item.id==='POWER-CARE'&&item._packCrops){
   item._packCrops.forEach((c,n)=>{text(s,'PACK '+n,.5,1.8+n*3.2,10.3,.25,11,C.violet,FONT.meta);pic(s,c,.5,2.17+n*3.2,10.3,2.65);});
   text(s,'SOURCE',11.3,1.85,4.2,.25,10,C.violet,FONT.meta);text(s,item.source_files.join('\n').replace('shell/quickshell/',''),11.3,2.25,4.2,.9,11,C.muted,FONT.meta);text(s,'Native crops of each complete capacity card',11.3,3.5,4.2,1.1,17,C.ink);pic(s,item._detail,11.3,5.7,4.2,1.35);text(s,'Threshold controls / synthetic values',11.3,7.22,4.2,.5,11,C.muted);sourceNote(s,[item]);return s;
 }
 pic(s,a,.5,1.8,10.4,6.5);
 text(s,'SOURCE',11.3,1.85,4.2,.25,10,C.violet,FONT.meta);
 text(s,item.source_files.map(f=>f.replace('shell/quickshell/','')).join('\n'),11.3,2.2,4.2,.85,11,C.muted,FONT.meta,{breakLine:false});
 text(s,'CAPTURED STATE',11.3,3.19,4.2,.25,10,C.violet,FONT.meta);
 text(s,a.state,11.3,3.55,4.2,.65,16,C.ink);
 if(item.notes.length)text(s,item.notes.join(' '),11.3,4.28,4.2,1.18,12,C.muted);
 if(item._detail){pic(s,item._detail,11.3,5.68,4.2,2.25);text(s,'Enlarged component crop',11.3,8.03,4.2,.23,10,C.muted,FONT.meta);}
 sourceNote(s,[item]);return s;
}
function comparison(item,blank=false,title=null){
 const s=base('C · Current versus redesign intention',title||(blank?'Reusable comparison template':item.name),blank?'Duplicate this editable slide for another surface.':`${item.id}    Current source baseline    Proposed design remains blank`,blank?'ATLAS_COMPARISON':null);
 const bw=7.25,by=2,bh=4.1;
 text(s,'CURRENT / BEFORE',.5,1.7,bw,.25,12,C.muted,FONT.meta);text(s,'PROPOSED / AFTER',8.25,1.7,bw,.25,12,C.violet,FONT.meta);
 rect(s,.5,by,bw,bh,null,C.line);rect(s,8.25,by,bw,bh,null,C.violet,'dash');
 if(!blank)pic(s,main(item),.65,by+.1,bw-.3,bh-.2);
 if(!blank){text(s,'Insert a proposed design here',9.0,3.35,5.7,.4,20,C.dim);text(s,'Design intention, mockup or later implemented screenshot',8.85,4.0,6.0,.5,12,C.muted);}
 const fields=['What works','Inconsistencies','Changes needed','Desired hierarchy','Layout / alignment','Interaction','Reusable assets','Priority','Implementation status'];
 fields.forEach((v,i)=>{const col=i%3,row=Math.floor(i/3),x=.5+col*5.16,y=6.37+row*.59;line(s,x,y+.45,4.85);text(s,v,x,y,4.85,.23,10,C.muted);text(s,'[ Add notes ]',x+2.05,y,2.8,.23,10,C.dim);});
 text(s,blank?'Component ID: [ Add ID ]':'Review: Unreviewed   /   Redesign: Pending   /   Implementation: Not started',.5,8.21,14.8,.23,9,C.violet,FONT.meta);
 if(item)sourceNote(s,[item]);else s.addNotes('Reusable editable template. Replace both image areas and update the native text fields. No proposed design is approved.');
 return s;
}

// Stable source and capture inventory.
const routes=JSON.parse(await fs.readFile(path.join(OUT,'routes.json'),'utf8'));
const areaSource={overview:qml('ControlCentre'),network:qml('control/ControlNetworkPage'),audio:qml('audio/AudioPanel'),power:qml('control/ControlPowerPage'),calendar:qml('control/ControlCalendarPage'),input:qml('control/ControlInputPage'),devices:qml('control/ControlDevicesPage'),apps:qml('control/ControlApplicationsPage'),appearance:qml('AppearanceSettings'),accounts:qml('control/ControlAccountsPage'),settings:qml('control/ControlSettingsPage')};
// Source name differs between revisions. Use the actual existing audio owner.
if(!await exists(path.join(ROOT,areaSource.audio)))areaSource.audio=qml('audio/AudioSettings');
if(!await exists(path.join(ROOT,areaSource.audio)))areaSource.audio=qml('ControlCentre');
for(const r of routes){
 const id='SETTINGS-'+r.id.toUpperCase().replaceAll('/','-');
 await add(id,r.path,'Settings',areaSource[r.route],['control/settings-'+r.id.replaceAll('/','-')],{kind:r.target?'focus_target':'subpage',route:r.id,owner:'Control Centre / full Settings',notes:r.target?[`Focus destination inside an existing page: ${r.target}. Shared page, not an independent window.`]:['Controlled fixture data. Provider-unavailable views describe the fixture, not current hardware.']});
}
await add('CTRL-OVERVIEW','Compact Control Centre','Control Centre',qml('ControlCentre'),['control/control-overview'],{priority:'P1 · proposal'});
await add('SHELL-RAIL','Obsidian Rail','Shell',[qml('RailWindow'),qml('WorkspaceRail'),qml('MachineStateIsland')],['rail/rail-1920','rail/rail-1366','rail/rail-800','rail/rail-390'],{notes:['Production Rail content and breakpoint equations in an offscreen Qt host. Synthetic workspace and system objects.']});
for(const [slug,name,src] of [['workspaces','Workspace module','WorkspaceRail'],['machine-state','Machine state island','MachineStateIsland'],['system-controls','System controls island','SystemControlsIsland'],['clock','Clock and notification trigger','ClockIsland'],['session-trigger','Session trigger','PowerIsland']])await add('RAIL-'+slug.toUpperCase(),name,'Rail modules',qml(src),['rail/'+slug],{kind:'component'});
await add('SHELL-EXPANDED','Expanded machine briefing','Shell',qml('ExpandedSenomyPanel'),['expanded/wide','expanded/narrow']);
await add('SHELL-LENS','Command Lens','Launcher',[qml('lens/CommandLensPopup'),qml('lens/CommandLensContent')],['lens/all','lens/apps','lens/files','lens/windows','lens/actions','lens/no-results','lens/search-focus','lens/narrow','lens/touch','lens/provider-error']);
await add('QUICK-AUDIO','Audio quick panel','Quick controls',qml('VolumePopup'),['audio/01-standard','audio/02-muted-focus','audio/03-devices','audio/04-device-review','audio/05-narrow-short','audio/06-touch','audio/07-unavailable','audio/08-empty','audio/09-large-type-contrast']);
await add('QUICK-NETWORK','Network quick panel','Quick controls',[qml('NetworkPopup'),qml('control/ControlNetworkPage')],['network/network','network/network-review','network/network-unavailable']);
await add('QUICK-BATTERY','Battery and power quick panel','Quick controls',[qml('BatteryPopup'),qml('control/ControlPowerPage')],['network/battery']);
await add('QUICK-BLUETOOTH','Bluetooth quick panel','Quick controls',qml('BluetoothPopup'),['bluetooth-quick/quick']);
await add('QUICK-CALENDAR','Calendar quick panel','Quick controls',qml('CalendarPopup'),['calendar-quick/01-today-empty','calendar-quick/02-other-day','calendar-quick/03-date-picker','calendar-quick/04-agenda','calendar-quick/05-event-details','calendar-quick/06-touch','calendar-quick/07-narrow','calendar-quick/08-short','calendar-quick/09-large-type','calendar-quick/10-unavailable']);
// Add any differently named native calendar captures without inventing a label.
const calendarQuick=items('QUICK-CALENDAR');for(const p of (await fs.readdir(path.join(OUT,'screenshots/full/calendar-quick'))).filter(x=>x.endsWith('.png'))){const a=await asset(cap('calendar-quick/'+p.slice(0,-4)),p.slice(0,-4));if(!calendarQuick.captures.some(c=>c.path===a.path))calendarQuick.captures.push(a);}
await add('QUICK-TRAY','Application tray and native menus','Quick controls',[qml('TrayPopup'),qml('TrayContents')],(await fs.readdir(path.join(OUT,'screenshots/full/tray'))).filter(p=>p.endsWith('.png')).map(p=>'tray/'+p.slice(0,-4)));
await add('NOTIFY-CENTRE','Notification history and DND','Notifications',[qml('NotificationCenter'),qml('notifications/NotificationArchive')],['popups/notifications-470','popups/notifications-dnd','popups/archive-review']);
await add('NOTIFY-TOAST','Notification toast','Notifications',qml('NotificationToast'),['popups/toast-470'],{notes:['Synthetic notification content. No real notification history was read.']});
await add('SESSION-MAIN','Session actions and scheduling','Session',[qml('PowerPopup'),qml('PowerContents')],['session-popup/popup-idle-640','session/idle-640','session/selected-now-640','session/countdown-640','session/review-now-640','session/review-schedule-640','session/scheduled-640','session/review-replace-640','session/error-640','session/date-time-640','session/missed-390','session/failed-390','session/unavailable-680','session/touch-680','session/large-text-reduced-motion-390']);
for(const p of (await fs.readdir(path.join(OUT,'screenshots/full/session-popup'))).filter(x=>x.endsWith('.png'))){const a=await asset(cap('session-popup/'+p.slice(0,-4)),p.slice(0,-4));if(!items('SESSION-MAIN').captures.some(c=>c.path===a.path))items('SESSION-MAIN').captures.push(a);}
await add('SESSION-COMMITMENT','Pinned schedule and safety notifications','Session',[qml('ScheduleCommitment'),qml('SessionScheduleMonitor'),qml('NotificationToast')],(await fs.readdir(path.join(OUT,'screenshots/full/session-surfaces'))).filter(p=>p.endsWith('.png')).map(p=>'session-surfaces/'+p.slice(0,-4)));
await add('DISPLAY-RECOVERY','Keep, Revert and recovery failure','Display management',qml('DisplayRecovery'),['safety/keep-revert','safety/recovery-failed'],{priority:'P1 · proposal'});
for(const view of ['projection','arrangement','settings','workspaces','profiles','diagnostics'])await add('DISPLAY-'+view.toUpperCase(),'Displays / '+view,'Display management',qml('DisplaySettings'),['display/display-'+view+'-1000','display/display-'+view+'-380'],{route:'devices/displays#'+view,notes:['Real display editor, synthetic inventory. No display draft or compositor setting was touched.']});
await add('DISPLAY-DRAFT-REVIEW','Display draft review','Display management',qml('DisplaySettings'),['display/display-review-ready']);
await add('BLUETOOTH-INSPECTOR','Bluetooth device inspector','Device management',[qml('bluetooth/BluetoothPage'),qml('bluetooth/BluetoothInspector')],(await fs.readdir(path.join(OUT,'screenshots/full/bluetooth'))).filter(p=>p.endsWith('.png')).map(p=>'bluetooth/'+p.slice(0,-4)),{priority:'P1 · proposal',notes:['Transport disabled. Native layout with synthetic adapter, devices and audio nodes.']});
for(const name of ['inspector-crop','inspector-error-crop']){const a=await asset(cap('bluetooth-quick/'+name),name);if(a)items('BLUETOOTH-INSPECTOR').captures.push(a);}
await add('POWER-ENERGY','Power and battery profiles','Power',qml('control/ControlPowerPage'),['energy/overview','energy/profiles','energy/batteries','energy/profile-review','energy/narrow']);
await add('POWER-CARE','Dual-pack battery care','Power',qml('control/BatteryCareEditor'),['care/dual-packs'],{notes:['Actual care controller reads a private synthetic transport. No hardware writes.']});
await add('ACCOUNTS-PROFILE','Users and accounts','Accounts',qml('control/ControlAccountsPage'),['accounts/profile','accounts/administration','accounts/administration-lower','accounts/provider','accounts/narrow','accounts/review','accounts/failed'],{priority:'P1 · proposal'});
for(const p of (await fs.readdir(path.join(OUT,'screenshots/full/directories/directory-performance'))).filter(x=>/^performance-.*\.png$/.test(x)&&!x.includes('narrow'))){const n=p.slice(12,-4);await add('PERF-'+n.toUpperCase(),'Performance / '+n,'Performance',qml('PerformanceDashboard'),['directories/directory-performance/'+p.slice(0,-4)],{route:n});}
await add('PERF-PROCESS-REVIEW','Process termination review','Performance',[qml('PerformanceDashboard'),qml('ProcessManagerPage')],['directories/directory-performance/process-review'],{priority:'P1 · proposal'});
for(const p of (await fs.readdir(path.join(OUT,'screenshots/full/directories/directory-insights'))).filter(x=>/^insights-.*\.png$/.test(x)&&!x.includes('narrow'))){const n=p.slice(9,-4);await add('INSIGHTS-'+n.toUpperCase(),'Senomy Insights / '+n,'Insights',qml('InsightsPanel'),['directories/directory-insights/'+p.slice(0,-4)],{route:n});}
for(const name of ['briefing','agenda','month','week','day','calendars','reminders','transfer','accounts','preferences','editor','editor-errors','details','note-editor','note-details','bulk-import','bulk-review','date-actions']){const owned={agenda:'CalendarAgenda',month:'CalendarBrowser',week:'CalendarTimetable',day:'CalendarTimetable',transfer:'CalendarImport',editor:'EventEditor','editor-errors':'EventEditor','note-editor':'EventEditor','bulk-import':'CalendarImport','bulk-review':'CalendarImport'}[name];await add('CAL-'+name.toUpperCase(),'Calendar / '+name,'Calendar',[qml('control/ControlCalendarPage'),...(owned?[qml('calendar/'+owned)]:[])],['calendar/'+name+'-794','calendar/'+name+'-320'],{route:'calendar/'+name,notes:['Private calendar daemon and temporary synthetic database. No personal events or connected accounts.']});}
await add('LOGIN-MAIN','SDDM login','Authentication',['appearance/login/sddm/senomyos/Main.qml','appearance/login/sddm/senomyos/CompactLogin.qml'],['auth/login-1920x1080','auth/login-1366x768','auth/login-800x1000','auth/login-360x640','auth/login-640x360','auth/login-account-picker'],{priority:'P1 · proposal',notes:['Current source theme with fake SDDM identity/session models and inert authentication/power callbacks. Installed greeter may differ. No real credentials were used.']});
await add('LOCK-MAIN','Hyprlock composition','Authentication','appearance/lock/hyprlock.conf', ['1920x1080','1366x768','800x1000','360x640'].map(v=>({path:cap('auth/lock-'+v),state:v+' offline config projection',method:'UNAVAILABLE',notes:'Not native Hyprlock rendering. Offline geometry/type/asset projection with a static substitute background. Native lock was not activated.'})),{priority:'P1 · proposal',notes:['Native capture unavailable under the no-lock constraint. Projection is a limited source reference, not proof of actual lock rendering, authentication or native failure states.']});

// Real component crops, with their exact pixel provenance.
const controls=await asset(cap('controls/native-controls'),'default');
const controlsTouch=await asset(cap('controls/native-controls-touch'),'touch');
const specs=[['COMBO','Dropdown selector','ShellComboBox',[18,18,444,53]],['SPIN','Numeric stepper','ShellSpinBox',[18,83,444,48]],['TEXT','Text field','ShellTextField',[18,147,444,49]],['CHECK','Checkbox','ShellCheckBox',[18,208,444,45]],['DISABLED','Disabled action','DashboardButton',[18,329,444,51]]];
for(const [id,name,source,r] of specs){const a=await crop(controls,'component-'+id.toLowerCase(),r);const item=await add('COMPONENT-'+id,name,'Controls',qml(source),[],{kind:'component'});item.captures=[a];item.capture_status='captured';if(id==='COMBO'){const d=await asset(cap('controls/native-dropdown'),'open');item.captures.push(d);}if(id==='TEXT'||id==='CHECK')item.captures.push(controlsTouch);}
const overview=main(items('SETTINGS-OVERVIEW'));
for(const [id,name,source,r] of [['NAV','Settings navigation','ControlNavigation',[27,100,245,645]],['HEADER','Shared Settings header','DashboardWindow',[27,20,1065,70]],['METRIC','Metric card','DashboardCard',[299,178,260,112]],['ROUTES','Quick destination tiles','control/ControlRouteTiles',[299,529,770,111]],['PAGE-HEADING','Directory page heading','ControlCentre',[298,106,785,61]]]){const a=await crop(overview,'component-'+id.toLowerCase(),r);const i=await add('COMPONENT-'+id,name,'Structure',qml(source),[],{kind:'component'});i.captures=[a];i.capture_status='captured';}
items('SETTINGS-OVERVIEW')._detail=main(items('COMPONENT-METRIC'));
const audioA=main(items('QUICK-AUDIO'));
for(const [id,name,source,r] of [['OUTPUT','Output level and mute','VolumePopup',[22,55,390,115]],['MIC','Microphone level and mute','VolumePopup',[22,196,390,112]]]){const a=await crop(audioA,'component-'+id.toLowerCase(),r);const i=await add('COMPONENT-'+id,name,'Controls',qml(source),[],{kind:'component'});i.captures=[a];i.capture_status='captured';}
const care=items('POWER-CARE');care._packCrops=[await crop(main(care),'care-pack-0',[0,55,800,270]),await crop(main(care),'care-pack-1',[0,485,800,270])];care._detail=await crop(main(care),'care-threshold-controls',[0,380,365,98]);care.captures.push(...care._packCrops,care._detail);
const unavailable=[
 ['LOCK-NATIVE','Native Hyprlock and unlock/error states','Authentication','appearance/lock/hyprlock.conf','Capturing native output requires activating Hyprlock. The task explicitly prohibits locking this session.'],
 ['DISPLAY-IDENTIFY','Physical monitor identification overlay','Display management',qml('DisplayIdentifyOverlay'),'No live identification action. The current editor and recovery overlays have isolated captures. Physical per-output placement remains uncaptured.'],
 ['AUTH-SYSTEM','System password and authorization handoffs','Accounts',qml('control/ControlAccountsPage'),'External secure system dialogs and terminals are outside the authored QML. No credentials or authorization workflow was opened.'],
 ['FILE-NATIVE','Native avatar file chooser','Accounts',qml('control/ControlAccountsPage'),'The native FileDialog requires a platform dialog backend. Profile controls are captured without opening a real file chooser.'],
 ['BOOT-PLYMOUTH','Plymouth boot splash','Boot','appearance/boot/plymouth/senomyos/senomyos.script','Boot transition cannot be captured without starting a boot/session transition. No boot component was activated.'],
 ['FILES-GTK','GTK file-manager theme in an application','External applications','appearance/file-manager/gtk3/SenomyOS/gtk-3.0/gtk.css','Theme source exists. No isolated trustworthy application render was obtained. Existing running applications were left alone.']
];
for(const [id,name,category,source,note] of unavailable)await add(id,name,category,source,[],{notes:[note],priority:'P1 · proposal'});

// Validate every recorded source reference and repair only real naming differences.
for(const i of all){for(let k=0;k<i.source_files.length;k++){
 const f=i.source_files[k];if(await exists(path.join(ROOT,f)))continue;
 if(f.includes('/calendar/'))i.source_files[k]=qml('control/ControlCalendarPage');
 else if(f.endsWith('lens/CommandLensContent.qml'))i.source_files[k]=qml('lens/LensContent');
 else if(f.endsWith('notifications/NotificationArchive.qml'))i.source_files[k]=qml('NotificationCenter');
 else throw Error('Unverified source reference '+f);
 }i.source_files=[...new Set(i.source_files)];}
for(const i of all)for(const f of i.source_files)if(!await exists(path.join(ROOT,f)))throw Error('Missing source '+f);

// A. Visual master index.
{
 const s=base('A · Master interface overview','SenomyOS UI/UX Design Atlas','Current-source visual baseline and editable redesign workspace');
 text(s,'03 NOVEMBER 2026',.5,1.85,8,.35,12,C.violet,FONT.meta);
 pic(s,main(items('SHELL-RAIL')),.5,2.45,15,1.1);
 const cover=[items('SETTINGS-OVERVIEW'),items('QUICK-AUDIO'),items('LOGIN-MAIN')];
 cover.forEach((i,n)=>{const x=.5+n*5.15;text(s,i.name,x,3.95,4.7,.3,13,C.muted);pic(s,main(i),x,4.5,4.7,3.15);ref(i,s);});
 text(s,'Actual authored interfaces. Blank After areas. Source and capture references throughout.',.5,8.11,15,.28,13,C.muted);
 sourceNote(s,[items('SHELL-RAIL'),...cover]);
}
board('Desktop and quick controls',[items('CTRL-OVERVIEW'),items('QUICK-AUDIO'),items('QUICK-NETWORK'),items('SHELL-LENS'),items('QUICK-CALENDAR'),items('QUICK-TRAY')]);
board('Core settings pages',['SETTINGS-NETWORK-WIFI','SETTINGS-AUDIO-MIXER','SETTINGS-INPUT-KEYBOARD','SETTINGS-APPEARANCE-MOTION','ACCOUNTS-PROFILE','POWER-ENERGY'].map(items));
board('Devices and display management',['DISPLAY-ARRANGEMENT','BLUETOOTH-INSPECTOR','POWER-CARE','DISPLAY-PROFILES','DISPLAY-RECOVERY','SETTINGS-DEVICES-INPUTS'].map(items));
board('Briefings and productivity',['PERF-CPU','PERF-PROCESSES','INSIGHTS-BRIEFING','INSIGHTS-NOTIFICATIONS','CAL-MONTH','SESSION-MAIN'].map(items));
board('Notifications and session',['NOTIFY-TOAST','NOTIFY-CENTRE','SESSION-COMMITMENT','SHELL-EXPANDED','SHELL-LENS'].map(items));
{
 const s=base('A · Master interface overview','Surface ownership and navigation','One primary shell surface. Full Settings is an entry mode of Control Centre.');
 const rows=[['Entry','Owning surface','Presentation'],['Rail system controls','Control Centre / full Settings','Shared page tree and routing'],['CPU / memory / uptime','Performance Dashboard','Separate primary surface'],['Senomy briefing control','Senomy Insights','Separate primary with eight routes'],['Clock, audio, network, tray','Quick popover','Transient over an existing primary'],['Session trigger','Session actions','Reviewed execution and scheduling'],['Greeter / locked session','SDDM / Hyprlock','Separate authentication runtimes']];
 s.addTable(rows,{x:.5,y:1.9,w:15,h:4.9,colW:[3.9,5.0,6.1],rowH:.55,fontFace:FONT.body,fontSize:15,color:C.ink,fill:C.bg,border:{type:'solid',color:C.line,pt:.6},margin:.12,bold:false,autoPage:false});
 text(s,'Settings categories',.5,7.19,3.9,.35,16,C.violet,FONT.heading);
 text(s,'Overview, Network, Audio, Power, Calendar, Input, Device management, Applications, Appearance, Users & accounts, System',4.4,7.19,11.1,.85,16,C.ink);
 s.addNotes('Source: shell/quickshell/shell.qml, services/ShellState.qml, components/RailWindow.qml, components/ControlDirectory.js and AGENTS.md. Primary ownership is coordinated by ShellState.');
}
{
 const s=base('A · Master interface overview','Capture key and coverage boundaries');
 const rows=[['Label','Meaning'],['NATIVE PREVIEW','Current QML body and assets, offscreen Qt host, controlled/inert providers'],['EXISTING EVIDENCE','Verified previous screenshot, with date and provenance if reused'],['LIVE','Actual running UI capture. No new live captures were taken for this atlas.'],['UNAVAILABLE','No trustworthy native capture. Reason and any limited projection are explicit.']];
 s.addTable(rows,{x:.5,y:1.75,w:15,colW:[3.2,11.8],rowH:.68,fontFace:FONT.body,fontSize:16,color:C.ink,fill:C.bg,border:{type:'solid',color:C.line,pt:.6},margin:.14,autoPage:false});
 text(s,'Source baseline',.5,6.35,3.5,.4,18,C.violet,FONT.heading);text(s,'The dirty worktree is the baseline. Capture status does not assert physical, compositor or authentication acceptance.',4.3,6.35,11.2,.85,17,C.ink);
 text(s,'Hyprlock projections show parsed geometry and assets with a substitute static background. Native lock, unlock and PAM states remain uncaptured.',.5,7.55,15,.65,14,C.warning);
}

// B. Large native screenshots, meaningful route pages only. Focus targets share parent pages.
await gallery(items('SHELL-RAIL'));
board('Rail modules at inspection scale',['RAIL-WORKSPACES','RAIL-MACHINE-STATE','RAIL-SYSTEM-CONTROLS','RAIL-CLOCK','RAIL-SESSION-TRIGGER','SHELL-EXPANDED'].map(items),'B · Current-state gallery');
await gallery(items('CTRL-OVERVIEW'));await gallery(items('SETTINGS-OVERVIEW'));
const routeGallery=['network/overview','network/wifi','network/saved','network/advanced','audio/overview','audio/mixer/playback','audio/mixer/recording','audio/devices','audio/media','audio/diagnostics','power/overview','power/batteries','power/profiles','input/pointer','input/keyboard','input/methods','devices','devices/inputs','devices/audio','devices/network','devices/batteries','apps','apps/defaults','apps/autostart','apps/launcher','appearance/backgrounds','appearance/motion','settings','settings/about','settings/notifications','settings/idle','settings/integration'];
for(const route of routeGallery)await gallery(items('SETTINGS-'+route.toUpperCase().replaceAll('/','-')));
for(const id of ['SHELL-LENS','QUICK-AUDIO','QUICK-NETWORK','QUICK-BATTERY','QUICK-BLUETOOTH','QUICK-CALENDAR','QUICK-TRAY','NOTIFY-CENTRE','NOTIFY-TOAST','SHELL-EXPANDED','ACCOUNTS-PROFILE','POWER-ENERGY','POWER-CARE','DISPLAY-PROJECTION','DISPLAY-ARRANGEMENT','DISPLAY-SETTINGS','DISPLAY-WORKSPACES','DISPLAY-PROFILES','DISPLAY-DIAGNOSTICS','DISPLAY-DRAFT-REVIEW','DISPLAY-RECOVERY'])await gallery(items(id));
for(const i of all.filter(i=>i.id.startsWith('PERF-')||i.id.startsWith('INSIGHTS-')))await gallery(i);
for(const i of all.filter(i=>i.id.startsWith('CAL-')))await gallery(i);
await gallery(items('SESSION-MAIN'));

const states=[
 ['Audio states','QUICK-AUDIO',[0,1,2,3,6,7]],
 ['Launcher scopes and search','SHELL-LENS',[1,2,3,4,5,9]],
 ['Notification history, DND and review','NOTIFY-CENTRE',[0,1,2]],
 ['Tray menus and feedback','QUICK-TRAY',[1,2,3,4,7,8]],
 ['Bluetooth connection and management states','BLUETOOTH-INSPECTOR',[0,1,2,5,12,14]],
 ['Session review and schedule states','SESSION-MAIN',[1,3,4,6,8,9]],
 ['Session feedback states','SESSION-MAIN',[10,11,12,13,14]],
 ['Accounts and administration states','ACCOUNTS-PROFILE',[0,1,2,4,5,6]],
];
for(const [title,id,indexes] of states){const i=items(id);const use=indexes.filter(n=>i.captures[n]);for(let n=0;n<use.length;n+=3)board(title+(use.length>3?' / '+(Math.floor(n/3)+1):''),use.slice(n,n+3).map(k=>({item:i,asset:i.captures[k],label:i.captures[k].state})),'B · State comparisons');}

// C. Editable comparison pages for each major family, plus reusable blanks.
for(const id of ['SHELL-RAIL','CTRL-OVERVIEW','SETTINGS-OVERVIEW','SHELL-LENS','QUICK-AUDIO','QUICK-NETWORK','QUICK-CALENDAR','QUICK-TRAY','NOTIFY-CENTRE','NOTIFY-TOAST','DISPLAY-ARRANGEMENT','DISPLAY-RECOVERY','BLUETOOTH-INSPECTOR','ACCOUNTS-PROFILE','POWER-ENERGY','POWER-CARE','CAL-MONTH','CAL-EDITOR','SESSION-MAIN','PERF-CPU','PERF-PROCESSES','INSIGHTS-BRIEFING'])comparison(items(id));
comparison(null,true,'Blank surface comparison');comparison(null,true,'Blank component comparison');comparison(null,true,'Blank state comparison');

// D. Current component system. All images are real crops or existing authored assets.
board('Form controls',['COMPONENT-COMBO','COMPONENT-SPIN','COMPONENT-TEXT','COMPONENT-CHECK','COMPONENT-DISABLED','COMPONENT-MIC'].map(items),'D · Component system and anatomy');
board('Navigation and hierarchy',['COMPONENT-NAV','COMPONENT-HEADER','COMPONENT-PAGE-HEADING','COMPONENT-ROUTES','COMPONENT-METRIC','RAIL-WORKSPACES'].map(items),'D · Component system and anatomy');
{
 const i=items('SETTINGS-OVERVIEW'),a=main(i),s=base('D · Component system and anatomy','Settings visual anatomy','Editable region annotations over the actual current Settings capture');
 pic(s,a,.5,1.8,10.3,6.5);
 const iw=6.5*a.width/a.height,ox=.5+(10.3-iw)/2,scale=iw/a.width;
 const regions=[['01','Header and mode controls',[20,18,1072,70]],['02','Search and shared navigation',[24,98,248,650]],['03','Route heading and report actions',[294,99,786,66]],['04','Reusable metrics and route tiles',[294,173,786,606]]];
 regions.forEach(([n,name,r],k)=>{rect(s,ox+r[0]*scale,1.8+r[1]*scale,r[2]*scale,r[3]*scale,null,C.violet);text(s,n,11.2,2.0+k*1.35,.65,.35,17,C.violet,FONT.data);text(s,name,12.0,2.0+k*1.35,3.5,.72,16,C.ink);});
 sourceNote(s,[i]);
}
{
 const i=items('NOTIFY-TOAST'),s=base('D · Component system and anatomy','Notification anatomy','Current notification layout with synthetic content');
 pic(s,main(i),.75,1.9,7.0,5.9);
 const rows=[['01','Application and urgency'],['02','Dismiss control'],['03','Summary and plaintext body'],['04','Client action buttons'],['05','Bounded scroll region']];
 rows.forEach(([n,label],k)=>{text(s,n,8.7,2.0+k*1.15,.6,.3,18,C.violet,FONT.data);text(s,label,9.5,2.0+k*1.15,5.5,.55,18,C.ink);line(s,8.7,2.85+k*1.15,6.3);});
 sourceNote(s,[i]);
}
board('Buttons and action groups',['COMPONENT-OUTPUT','COMPONENT-MIC','COMPONENT-DISABLED','DISPLAY-RECOVERY','PERF-PROCESS-REVIEW','DISPLAY-DRAFT-REVIEW'].map(items),'D · Component system and anatomy');
{
 const s=base('D · Component system and anatomy','Current typography roles','Authored roles from appearance/tokens.json and the rendered components');
 const roles=[['HEADING','Bruno Ace SC','Directory and authentication headings'],['VALUE','Audiowide','Metrics, time and prominent values'],['BODY','sans-serif / Adwaita Sans here','Controls and readable content'],['METADATA','JetBrainsMono Nerd Font','Source labels, timestamps and technical detail']];
 roles.forEach((r,n)=>{const y=1.9+n*1.42;line(s,.5,y+1.13,15);text(s,r[0],.5,y,2.3,.3,11,C.violet,FONT.meta);text(s,r[1],3,y,7,.48,n===3?17:23,C.ink,[FONT.heading,FONT.data,FONT.body,FONT.meta][n]);text(s,r[2],10.5,y,5,.62,14,C.muted);});
 sourceNote(s,[items('COMPONENT-PAGE-HEADING'),items('COMPONENT-METRIC')],'Source: appearance/tokens.json, config/DirectoryStyle.qml and appearance/shared/auth/VisualRoles.js. sans-serif resolves to the locally installed font. Font portability requires these families on the editing device.');
}
{
 const s=base('D · Component system and anatomy','Existing colour roles','Exact current token values. The swatches and labels remain editable.');
 const tokens=JSON.parse(await fs.readFile(path.join(ROOT,'appearance/tokens.json'),'utf8'));
 const entries=Object.entries(tokens.colors).filter(([k,v])=>typeof v==='string'&&v.startsWith('#'));
 entries.forEach(([name,value],i)=>{const col=i%4,row=Math.floor(i/4),x=.5+col*3.85,y=1.9+row*1.5;rect(s,x,y,3.5,.7,value.slice(1),C.line);text(s,name,x,y+.83,3.5,.23,12,C.ink);text(s,value,x,y+1.13,3.5,.2,10,C.muted,FONT.meta);});
 s.addNotes('Source: appearance/tokens.json. Colours are token data rendered as editable PowerPoint swatches, not a proposed palette.');
}
{
 const s=base('D · Component system and anatomy','Spacing, frame geometry and control density','Current implementation values. Context-specific rules coexist.');
 const rows=[['Role','Current value','Source'],['Rail height / island height','72 / 64 px','config/Theme.qml'],['Standard frame safe inset','14 / 16 / 14 / 16 px','config/Theme.qml'],['Standard / large corner','32 / 48 px','config/Theme.qml'],['Density compact / standard / touch','32 / 36 / 48 px','appearance/tokens.json'],['Shared touch target','48 px','config/Theme.qml'],['Authentication controls','48 px high, 24 px content inset','appearance/tokens.json'],['Authentication form / breakpoint','480 px max / 720 px wide','appearance/tokens.json'],['Authentication spacing steps','4, 8, 12, 16, 24, 32 px','appearance/tokens.json']];
 s.addTable(rows,{x:.5,y:1.8,w:15,colW:[5.4,4.1,5.5],rowH:.58,fontFace:FONT.body,fontSize:14,color:C.ink,fill:C.bg,border:{type:'solid',color:C.line,pt:.6},margin:.1,autoPage:false});
 pic(s,main(items('COMPONENT-HEADER')),.5,7.45,10.8,.58);text(s,'Actual authored cut-corner header',11.6,7.45,3.9,.6,12,C.muted);
 sourceNote(s,[items('COMPONENT-HEADER')]);
}
board('Responsive layouts and readability',[
 {item:items('SHELL-LENS'),asset:items('SHELL-LENS').captures.find(c=>c.state==='narrow'),label:'Command Lens / narrow'},
 {item:items('QUICK-AUDIO'),asset:items('QUICK-AUDIO').captures.find(c=>c.state.includes('large-type')),label:'Audio / large text and contrast'},
 {item:items('CAL-EDITOR'),asset:items('CAL-EDITOR').captures[1],label:'Calendar editor / narrow'},
 {item:items('SHELL-RAIL'),asset:items('SHELL-RAIL').captures[3],label:'Rail / micro width'},
 {item:items('SESSION-MAIN'),asset:items('SESSION-MAIN').captures.find(c=>c.state.includes('touch')),label:'Session / touch'},
 {item:items('COMPONENT-TEXT'),asset:controlsTouch,label:'Shared controls / touch'}
 ],'D · Component system and anatomy');
board('Feedback, empty and disabled states',[
 {item:items('SHELL-LENS'),asset:items('SHELL-LENS').captures.find(c=>c.state==='no-results'),label:'No search results'},
 {item:items('QUICK-AUDIO'),asset:items('QUICK-AUDIO').captures.find(c=>c.state.includes('unavailable')),label:'Audio provider unavailable'},
 {item:items('QUICK-TRAY'),asset:items('QUICK-TRAY').captures.find(c=>c.state.includes('no-items')),label:'No tray items'},
 {item:items('CAL-EDITOR-ERRORS'),label:'Calendar validation'},
 {item:items('DISPLAY-RECOVERY'),asset:items('DISPLAY-RECOVERY').captures[1],label:'Recovery failure'},
 {item:items('COMPONENT-DISABLED'),label:'Disabled action'}
 ],'D · Component system and anatomy');
board('Dialogs, reviews and destructive actions',['DISPLAY-DRAFT-REVIEW','DISPLAY-RECOVERY','PERF-PROCESS-REVIEW','CAL-BULK-REVIEW','SESSION-MAIN','NOTIFY-CENTRE'].map(items),'D · Component system and anatomy');
for(const id of ['COMPONENT-COMBO','COMPONENT-TEXT','COMPONENT-CHECK','COMPONENT-METRIC'])comparison(items(id),false,items(id).name+' / component worksheet');

// E. Login and lock, including the explicit native-lock boundary.
{
 const i=items('LOGIN-MAIN');
 for(const a of i.captures.slice(0,2)){const s=base('E · SDDM and Hyprlock','SDDM / '+a.state,'NATIVE PREVIEW    Current source, fake identity and inert authentication');pic(s,a,.5,1.8,15,6.5);sourceNote(s,[i]);}
 board('SDDM / portrait and narrow layouts',i.captures.slice(2).map(a=>({item:i,asset:a,label:a.state})),'E · SDDM and Hyprlock');
 comparison(i,false,'SDDM login / redesign worksheet');
 const lock=items('LOCK-MAIN'),s=base('E · SDDM and Hyprlock','Hyprlock / limited source projection','UNAVAILABLE: native capture    Offline geometry/type/asset reference only');
 pic(s,lock.captures[1],.5,1.8,10.3,6.1);pic(s,lock.captures[3],11.35,1.8,3.8,6.1);
 text(s,'Static substitute background. Native lock rasterisation, PAM and failure feedback remain unverified.',.5,8.05,15,.3,12,C.warning);sourceNote(s,[lock]);
 comparison(lock,false,'Hyprlock / redesign worksheet');
}
{
 const s=base('E · SDDM and Hyprlock','Desktop and authentication comparison','Observed source treatments, with no proposed replacement design');
 const points=[['Perimeters','Desktop panels and revised SDDM reuse authored cut corners. Hyprlock uses a generated raster perimeter.'],['Type hierarchy','Heading, value, body and metadata roles exist in tokens. Native lock fields retain their own font and rendering rules.'],['Information density','Rail compresses at four widths. Login changes portrait/form composition and supports scrolling.'],['Interaction ownership','Desktop controls use shared route/review services. SDDM relies on its greeter proxy. Hyprlock owns secure lock interaction.']];
 points.forEach((p,i)=>{const y=1.8+i*1.5;text(s,p[0],.5,y,3.6,.45,19,C.violet,FONT.heading);text(s,p[1],4.25,y,11.25,.9,18,C.ink);line(s,.5,y+1.15,15);});
 sourceNote(s,[items('SHELL-RAIL'),items('LOGIN-MAIN'),items('LOCK-MAIN')],'These are implementation distinctions, not automatic defects. Redesign decisions remain pending.');
}

// F. Planning boards and an editable tracker, split into readable groups.
// Group aliases and focus anchors with their real owning page before writing
// tracker references. They do not need duplicate screenshots in the gallery.
for(const i of all.filter(i=>i.capture_status==='captured'&&!i.slide_refs.length&&i.route)){
 const matches=all.filter(j=>j!==i&&j.route&&j.slide_refs.some(n=>slides[n-1].section.startsWith('B'))&&(i.route===j.route||i.route.startsWith(j.route+'/')||j.route.startsWith(i.route+'/'))).sort((a,b)=>{
  const exactA=a.route===i.route?2:i.route.startsWith(a.route+'/')?1:0,exactB=b.route===i.route?2:i.route.startsWith(b.route+'/')?1:0;
  return exactB-exactA||(exactA===1?b.route.length-a.route.length:a.route.length-b.route.length);
 });
 if(matches[0]){const owner=matches[0];i.slide_refs=owner.slide_refs.filter(n=>slides[n-1].section.startsWith('B'));i.related_component_variants=[owner.id];i.notes.push('Gallery groups this route or focus anchor with '+owner.id+'. Its exact additional capture remains in screenshots.');}
}
{
 const s=base('F · Redesign planning','Current patterns to review','Evidence-backed comparison prompts. Classification is a proposal only.');
 const rows=[['Evidence','Current distinction','Planning question'],['ShellButton / DashboardButton / DirectoryButton','Several button families coexist','Which roles can share one primitive?'],['Audio QuickPanelStyle vs other popovers','Audio has a dedicated opaque quick-panel composition','Should other quick panels adopt the same hierarchy?'],['tokens.json typography vs individual controls','Shared roles coexist with local pixel sizes','Which local sizes should become named roles?'],['Rail, Settings, auth responsive rules','Different density and layout thresholds serve different tasks','Which spacing and focus rules can be shared?'],['Native lock vs source projection','Different secure renderer and field constraints','Which visual changes fit native Hyprlock capabilities?']];
 s.addTable(rows,{x:.5,y:1.85,w:15,colW:[4.7,5.1,5.2],rowH:.83,fontFace:FONT.body,fontSize:14,color:C.ink,fill:C.bg,border:{type:'solid',color:C.line,pt:.6},margin:.12,autoPage:false});
 text(s,'No automatic spacing or alignment defect is inferred from fixture-only content. Evaluate the enlarged crops and real interaction states before deciding.',.5,7.5,15,.65,15,C.muted);
 s.addNotes('Sources: components/ShellButton.qml, DashboardButton.qml, DirectoryButton.qml, config/QuickPanelStyle.qml, config/DirectoryStyle.qml, docs/DESIGN_SYSTEM.md and appearance/tokens.json.');
}
{
 const s=base('F · Redesign planning','Redesign classification matrix','Initial working proposals. No application changes are authorised by this atlas.');
 const rows=[['Classification','Suggested scope','Decision'],['Reuse as-is','Approved authored logo, portrait and frame artwork','Pending review'],['Refine','Spacing, hierarchy and state readability within each family','Pending review'],['Redesign','Major surface worksheets after evaluating current captures','Pending review'],['Consolidate','Equivalent button, selector and review primitives','Pending review'],['Remove / retire','Only proven redundant surfaces or components','No retirement proposed']];
 s.addTable(rows,{x:.5,y:1.9,w:15,colW:[3.6,8.0,3.4],rowH:.83,fontFace:FONT.body,fontSize:16,color:C.ink,fill:C.bg,border:{type:'solid',color:C.line,pt:.6},margin:.14,autoPage:false});
 text(s,'Workflow',.5,7.4,3,.4,19,C.violet,FONT.heading);text(s,'Before capture   /   Design intention   /   Reviewed mockup   /   Implemented After',3.5,7.4,12,.6,16,C.ink);
}
const tracked=all.filter(i=>i.kind!=='focus_target');
for(let start=0;start<tracked.length;start+=8){
 const batch=tracked.slice(start,start+8),s=base('F · Redesign planning',`Surface tracker ${Math.floor(start/8)+1}`,'Review, redesign and implementation cells are native editable PowerPoint text.');
 const rows=[['ID / name','Owner / source','Image / current slide','Priority','Review','Redesign','Implementation']];
 batch.forEach(i=>{const page=i.slide_refs.find(n=>slides[n-1].section.startsWith('B'))||i.slide_refs[0];rows.push([i.id+'\n'+i.name.split(' / ').at(-1),i.category+'\n'+path.basename(i.source_files[0]),(i.captures[0]?path.basename(i.captures[0].path):'Uncaptured')+'\n'+(page?'Slide '+page:i.captures.length?'Additional asset':'No capture'),i.priority.split(' ·')[0],'Unreviewed','Pending','Not started']);});
 s.addTable(rows,{x:.5,y:1.8,w:15,colW:[3.15,3.7,3.25,1.0,1.25,1.25,1.4],rowH:.67,fontFace:FONT.body,fontSize:10.5,color:C.ink,fill:C.bg,border:{type:'solid',color:C.line,pt:.5},margin:.07,autoPage:false});
 batch.forEach(i=>ref(i,s));sourceNote(s,batch);
}
{
 const s=base('F · Redesign planning','Uncaptured and conditional interfaces','The inventory retains these gaps. The atlas does not claim complete native visual coverage.');
 const gaps=all.filter(i=>i.capture_status!=='captured');
 const rows=[['ID','Interface','Precise limitation'],...gaps.map(i=>[i.id,i.name,i.notes.join(' ')])];
 s.addTable(rows,{x:.5,y:1.75,w:15,colW:[2.4,3.5,9.1],rowH:.75,fontFace:FONT.body,fontSize:12,color:C.ink,fill:C.bg,border:{type:'solid',color:C.line,pt:.5},margin:.1,autoPage:false});
 text(s,'Additional state gaps: live OSK occlusion, real authentication success/failure, physical multi-output placement and production-provider mutations remain outside this safe capture run. GRUB is deferred.',.5,8.0,15,.44,11,C.warning);
 gaps.forEach(i=>ref(i,s));
}

// Attach focus targets and alias routes to their actual parent-gallery pages.
for(const i of all.filter(i=>!i.slide_refs.length)){
 const candidates=all.filter(j=>j!==i&&j.slide_refs.length&&j.route&&(i.route===j.route||i.route?.startsWith(j.route+'/'))).sort((a,b)=>(b.route?.length||0)-(a.route?.length||0));
 const parent=candidates[0]||items('SETTINGS-OVERVIEW');i.slide_refs=[...parent.slide_refs];i.notes.push('Grouped with the existing owning page rather than duplicated as a separate window.');
}
// Source catalogue includes smaller definitions, even when their view is conditional.
async function files(dir){let out=[];for(const e of await fs.readdir(dir,{withFileTypes:true})){const p=path.join(dir,e.name);if(e.isDirectory())out.push(...await files(p));else out.push(p);}return out;}
const sourceFiles=[...(await files(path.join(ROOT,'shell/quickshell/components'))).filter(p=>p.endsWith('.qml')||p.endsWith('.js')),...(await files(path.join(ROOT,'shell/quickshell/config'))).filter(p=>p.endsWith('.qml')),...(await files(path.join(ROOT,'appearance/login/sddm/senomyos'))).filter(p=>p.endsWith('.qml')||p.endsWith('.js')),path.join(ROOT,'appearance/tokens.json'),path.join(ROOT,'appearance/lock/hyprlock.conf')];
const sourceCatalog=[];
for(const p of sourceFiles){const rp=path.relative(ROOT,p),content=await fs.readFile(p);sourceCatalog.push({path:rp,sha256:sha(content),inventory_ids:all.filter(i=>i.source_files.includes(rp)).map(i=>i.id)});}
const countSurfaces=all.filter(i=>i.kind!=='component'&&i.kind!=='focus_target');
const capturePaths=new Set(all.flatMap(i=>i.captures.map(c=>c.path)));
for(const i of all)for(const a of i.captures){a.slide_refs=[...(imageSlides.get(a.path)||[])];a.deck_representation=a.slide_refs.length?'embedded':'additional_asset';}
const inventory={schema_version:1,title:'SenomyOS UI/UX Design Atlas',date:'2026-11-03',baseline:'Current dirty source worktree. No runtime publication.',source_root:ROOT,slide_size:{width_inches:16,height_inches:9,aspect:'16:9'},capture_policy:'Offscreen native QML with controlled providers. No live source, device, account or display mutations. Lock images are limited offline projections only.',summary:{inventoried_surfaces:countSurfaces.length,visually_captured_surfaces:countSurfaces.filter(i=>i.capture_status==='captured').length,projection_only_surfaces:countSurfaces.filter(i=>i.capture_status==='projection_only').length,unavailable_surfaces:countSurfaces.filter(i=>i.capture_status==='unavailable').length,reusable_components:all.filter(i=>i.kind==='component').length,focus_destinations:all.filter(i=>i.kind==='focus_target').length,unique_images_and_crops:capturePaths.size,slides:slides.length},items:all.map(({_detail,_packCrops,...i})=>i),source_catalog:sourceCatalog,slides,limitations:['Physical compositor placement and input acceptance are separate from offscreen captures.','Live display draft and running applications were never changed.','Native Hyprlock unavailable. Offline projection uses substitute background and does not prove rasterisation, PAM or failure feedback.','Current-source SDDM may differ from the installed greeter.','Dynamic hardware routes use representative synthetic device identities.','GRUB deferred. No speculative After design.']};
await fs.writeFile(path.join(OUT,'inventory.json'),JSON.stringify(inventory,null,2)+'\n');
await fs.writeFile(path.join(OUT,'tools/geometry.json'),JSON.stringify(geometry,null,2)+'\n');
await fs.writeFile(path.join(OUT,'tools/slide-index.json'),JSON.stringify(slides,null,2)+'\n');
const bad=geometry.filter(g=>g.x<-.01||g.y<-.01||g.x+g.w>W+.01||g.y+g.h>H+.01);if(bad.length)throw Error('Out-of-slide objects: '+JSON.stringify(bad));
await pptx.writeFile({fileName:path.join(OUT,'SenomyOS-UIUX-Design-Atlas.pptx')});
// PptxGenJS 4.0.1 can declare non-existent extra default masters. Remove only
// orphan content-type overrides, leaving all actual slide objects untouched.
const finalPath=path.join(OUT,'SenomyOS-UIUX-Design-Atlas.pptx');
const zip=await JSZip.loadAsync(await fs.readFile(finalPath));
let types=await zip.file('[Content_Types].xml').async('string');
types=types.replace(/<Override\b[^>]*\bPartName="([^"]+)"[^>]*\/>/g,(tag,name)=>zip.file(name.replace(/^\//,''))?tag:'');
zip.file('[Content_Types].xml',types);
await fs.writeFile(finalPath,await zip.generateAsync({type:'nodebuffer',compression:'DEFLATE'}));
console.log(JSON.stringify(inventory.summary));
