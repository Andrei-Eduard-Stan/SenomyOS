.pragma library
.import "TaskIntents.js" as Intent
function node(id,label,tags,target,children,status) {
    return {id:id,label:label,tags:tags||'',target:target||'',children:children,availability:status||'',route:id.split('/')[0]};
}
function build(context) {
    const c=context||{}, result=[
        node('overview','OVERVIEW','quick common controls status'),
        node('network','NETWORK','internet connection',[].join(''),[
            node('network/overview','CONNECTION','status internet'),node('network/wifi','WI-FI','wireless wlan networks'),
            node('network/saved','SAVED CONNECTIONS','profiles ethernet'),node('network/advanced','VPN & ADVANCED','dns proxy editor external')]),
        node('audio','AUDIO','sound volume', '',[
            node('audio/overview','OVERVIEW','sound level', '',[
                node('audio/overview/output','OUTPUT LEVEL','volume speaker headphones','control-output-volume'),
                node('audio/overview/microphone','MICROPHONE','mic mute input level','control-microphone-volume')]),
            node('audio/mixer','MIXER','applications stream', '',[
                node('audio/mixer/playback','PLAYBACK','app sound volume'),node('audio/mixer/recording','RECORDING','mic capture privacy')]),
            node('audio/devices','DEVICES','endpoint profiles ports balance'),node('audio/media','MEDIA','player music seek'),node('audio/diagnostics','DIAGNOSTICS','pipewire sound health')]),
        node('power','POWER','energy', '',[node('power/overview','OVERVIEW','charging remaining'),node('power/batteries','BATTERY PACKS','battery dual'),node('power/profiles','POWER PROFILES','performance balanced saver')]),
        node('calendar','CALENDAR','events notes date month year today', '', [node('calendar/briefing','EVENT BRIEFING','upcoming dates events notes links list'),node('calendar/agenda','AGENDA','upcoming event search'),node('calendar/month','MONTH','date year grid'),node('calendar/week','WEEK','timetable scheduling'),node('calendar/day','DAY','daily schedule'),node('calendar/calendars','CALENDARS','local sources colours visibility'),node('calendar/reminders','REMINDERS','alarms snooze missed'),node('calendar/transfer','IMPORT / BULK ADD','ics csv tsv spreadsheet paste mass batch automate import export'),node('calendar/accounts','ACCOUNTS','caldav offline sync conflicts'),node('calendar/preferences','PREFERENCES','week start numbers work hours timezone')]),
        node('input','INPUT','keyboard mouse touch', '',[node('input/pointer','POINTER & TOUCHPAD','mouse', '',[node('input/pointer/sensitivity','SENSITIVITY','pointer speed','control-pointer-sensitivity'),node('input/pointer/scroll','NATURAL SCROLL','scrolling direction','control-natural-scroll'),node('input/pointer/tap','TAP TO CLICK','touchpad tapping','control-tap-click')]),node('input/keyboard','KEYBOARD LAYOUTS','locale xkb', '',[node('input/keyboard/layout','KEYBOARD LAYOUT','language locale','control-keyboard-layout'),node('input/keyboard/rate','REPEAT RATE','key typing speed','control-repeat-rate'),node('input/keyboard/delay','REPEAT DELAY','key hold timing','control-repeat-delay')]),node('input/methods','INPUT METHODS & OSK','on screen keyboard ime virtual')]),
        node('devices','DEVICE MANAGEMENT','hardware peripherals', '',[node('devices/displays','DISPLAYS & PROJECTION','projection extend duplicate pc screen only arrangement monitor resolution scale rotate'),node('devices/bluetooth','BLUETOOTH','pair connect wireless'),node('devices/inputs','INPUT DEVICES','keyboard mouse touch inventory'),node('devices/audio','AUDIO ENDPOINTS','speaker microphone'),node('devices/network','NETWORK INTERFACES','adapter ethernet wlan'),node('devices/batteries','BATTERIES','battery packs')]),
        node('apps','APPLICATIONS','software', '',[node('apps/defaults','DEFAULT APPLICATIONS','browser mime handlers'),node('apps/autostart','STARTUP APPLICATIONS','login autostart'),node('apps/launcher','COMMAND LENS','launcher files windows actions external')]),
        node('appearance','APPEARANCE','personalise customize', '',[node('appearance/backgrounds','SURFACE BACKGROUNDS','wallpaper', '',[node('appearance/backgrounds/image','BACKGROUND IMAGE','wallpaper path','backgroundSource'),node('appearance/backgrounds/opacity','IMAGE OPACITY','transparency image','control-image-opacity'),node('appearance/backgrounds/scrim','DARK OVERLAY','scrim opacity darkness','control-image-scrim')]),node('appearance/motion','Motion & Readability','animation accessibility text size contrast', '',[node('appearance/motion/text-scale','INTERFACE TEXT SIZE','font size accessibility large','control-ui-text-scale'),node('appearance/motion/contrast','HIGH CONTRAST','visibility readability','control-high-contrast'),node('appearance/motion/reduced','REDUCED MOTION','reduce animations','control-reduced-motion'),node('appearance/motion/hover','HOVER EXPANSION','expand Senomy hover','control-hover-expansion'),node('appearance/motion/text','RAIL TEXT SIZE','font size','control-rail-text')])]),
        node('accounts','Users & Accounts','users login password administrator security'),
        node('settings','System','settings system preferences', '',[node('settings/about','ABOUT & RECOVERY','system os kernel version updates recovery'),node('settings/notifications','NOTIFICATIONS','alerts', '',[node('settings/notifications/dnd','DO NOT DISTURB','dnd silence notifications','control-dnd')]),node('settings/idle','IDLE & LOCK','timeout sleep lid', '',[node('settings/idle/lock','LOCK TIMEOUT','lock after minutes','control-lock-timeout'),node('settings/idle/display','DISPLAY OFF TIMEOUT','screen blank minutes','control-display-timeout')]),node('settings/integration','SHELL & DESKTOP','portals permissions services diagnostics')])
    ];
    function find(id,list) {for(const item of list){if(item.id===id)return item;const hit=find(id,item.children||[]);if(hit)return hit;}return null;}
    function add(parent,items,kind) {const p=find(parent,result);p.children=p.children||[];(items||[]).slice(0,48).forEach(item=>{
        const key=String(item.uuid||item.name||item.id||item.description||'');if(!key)return;
        const label=String(item.description||item.name||item.id), child=node(parent+'/item:'+encodeURIComponent(key),label,kind,'');
        child.deviceKey=key;child.dynamic=true;child.availability=item.available===false?'unavailable':item.ready===false?'not ready':'';p.children.push(child);
    });}
    add('audio/devices',c.outputs,'speaker output');add('audio/devices',c.inputs,'microphone input');
    add('devices/displays',c.displays,'monitor');add('devices/inputs',c.inputDevices,'keyboard mouse peripheral');
    add('network/saved',c.profiles,'saved connection profile');
    add('apps/defaults',(c.defaultRoles||[]).map(n=>({name:n.mime,description:n.label})), 'default application handler');
    function mark(id,available){const n=find(id,result);if(n && available===false)n.availability='unavailable';}
    mark('audio/overview/output',c.outputAvailable);mark('audio/overview/microphone',c.inputAudioAvailable);
    mark('network/wifi',c.networkAvailable);mark('input/pointer',c.inputAvailable);mark('input/keyboard',c.inputAvailable);
    return result;
}
function all(nodes,ancestors) {
    let result=[];for(const item of nodes){const labels=(ancestors||[]).concat(item.label);result.push(Object.assign({},item,{path:labels.join(' / ')}));result=result.concat(all(item.children||[],labels));}return result;
}
function resolve(nodes,id) {return all(nodes).find(n=>n.id===id)||null;}
function parentIds(nodes,id) {const n=resolve(nodes,id);if(!n)return [];const bits=id.split('/');return bits.slice(0,-1).map((_,i)=>bits.slice(0,i+1).join('/'));}
function rows(nodes,expanded,query) {
    const q=String(query||'').trim().toLowerCase();
    if(q){const words=q.split(/\s+/);
        const normalized=q.replace(/[^a-z0-9]+/g,' ').trim().replace(/\s+/g,' ');
        const taskWords=normalized.split(' ').filter(w=>!['i','my','the','a','to','how','do','can','please','is','it'].includes(w));
        const matches=Intent.catalog.filter(task=>task.phrases.some(phrase=>{
            const p=phrase.replace(/[^a-z0-9]+/g,' ').trim();
            return p===normalized || (taskWords.length>=2 && taskWords.every(w=>p.split(' ').includes(w)));
        }));
        const taskRoutes=matches.map(task=>task.route);
        return all(nodes).map(n=>{
        const title=n.label.toLowerCase(),hay=(n.path+' '+n.tags).toLowerCase();
        return Object.assign({},n,{depth:0,branch:!!n.children,open:false,score:taskRoutes.includes(n.id)?-1:title===q?0:title.startsWith(q)?1:title.includes(q)?2:3,matched:taskRoutes.includes(n.id) || words.every(w=>hay.includes(w))});
    }).filter(n=>n.matched).sort((a,b)=>a.score-b.score||a.path.localeCompare(b.path));}
    let result=[];function visit(list,depth){for(const n of list){result.push(Object.assign({},n,{depth:depth,branch:!!n.children,open:!!expanded[n.id]}));if(n.children&&expanded[n.id])visit(n.children,depth+1);}}visit(nodes,0);return result;
}

function validRoute(id) {
    return !!resolve(build({}),id) || /^(audio\/devices|devices\/displays|devices\/inputs|network\/saved|apps\/defaults)\/item:[A-Za-z0-9_%:.~-]+$/.test(id);
}
