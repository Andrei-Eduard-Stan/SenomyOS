.pragma library
function copy(value) { return JSON.parse(JSON.stringify(value)); }
function modeParts(mode) {
    const m=/^(\d+)x(\d+)@(\d+(?:\.\d+)?)(?:Hz)?$/.exec(String(mode));
    return m ? {width:Number(m[1]),height:Number(m[2]),hz:Number(m[3])} : null;
}
function currentMode(display) {
    const modes=display.availableModes || [], hz=Number(display.refreshRate);
    if(!(display.width>0&&display.height>0))return display.restoreMode||modes[0]||"0x0@0";
    const found=modes.find(mode=>{const m=modeParts(mode);return m && m.width===display.width && m.height===display.height && Math.abs(m.hz-hz)<0.06;});
    return found || (display.width+"x"+display.height+"@"+hz.toFixed(5));
}
function fromDisplay(display) {
    return {key:display.key || display.name,name:display.name,mode:currentMode(display),scale:Number(display.scale)||1,
        transform:Number(display.transform)||0,x:Number(display.x)||0,y:Number(display.y)||0,
        enabled:!display.disabled,mirrorOf:display.mirrorOf && display.mirrorOf!=="none" ? display.mirrorOf : ""};
}
function rectangle(output) {
    const mode=modeParts(output.mode) || {width:1,height:1};
    const rotated=output.transform%2===1;
    return {x:output.x,y:output.y,width:(rotated?mode.height:mode.width)/output.scale,height:(rotated?mode.width:mode.height)/output.scale};
}
function bounds(outputs) {
    const visible=outputs.filter(o=>o.enabled&&!o.mirrorOf);
    if(!visible.length)return {x:0,y:0,width:1920,height:1080};
    const r=visible.map(rectangle),x=Math.min.apply(null,r.map(n=>n.x)),y=Math.min.apply(null,r.map(n=>n.y));
    return {x:x,y:y,width:Math.max.apply(null,r.map(n=>n.x+n.width))-x,height:Math.max.apply(null,r.map(n=>n.y+n.height))-y};
}
function fit(outputs,width,height,padding) {
    const b=bounds(outputs),factor=Math.min(Math.max(1,width-padding*2)/b.width,Math.max(1,height-padding*2)/b.height);
    return {factor:factor,panX:(width-b.width*factor)/2-b.x*factor,panY:(height-b.height*factor)/2-b.y*factor};
}
function snap(output,outputs,x,y,tolerance) {
    const r=rectangle(output),others=outputs.filter(o=>o.key!==output.key&&o.enabled&&!o.mirrorOf).map(rectangle);
    let dx=tolerance+1,dy=tolerance+1,gx=null,gy=null;
    // Centre of the combined peer group supports one display below/above two.
    if(others.length){const b=bounds(outputs.filter(o=>o.key!==output.key));others.push(b);}
    others.forEach(peer=>{
        [peer.x,peer.x+peer.width/2,peer.x+peer.width].forEach(edge=>{
            [0,r.width/2,r.width].forEach(own=>{const delta=edge-(x+own);if(Math.abs(delta)<Math.abs(dx)){dx=delta;gx=edge;}});
        });
        [peer.y,peer.y+peer.height/2,peer.y+peer.height].forEach(edge=>{
            [0,r.height/2,r.height].forEach(own=>{const delta=edge-(y+own);if(Math.abs(delta)<Math.abs(dy)){dy=delta;gy=edge;}});
        });
    });
    return {x:Math.round(x+(Math.abs(dx)<=tolerance?dx:0)),y:Math.round(y+(Math.abs(dy)<=tolerance?dy:0)),
        guideX:Math.abs(dx)<=tolerance?gx:null,guideY:Math.abs(dy)<=tolerance?gy:null};
}
function validate(outputs) {
    const enabled=outputs.filter(o=>o.enabled&&!o.mirrorOf);
    if(!enabled.length)return "Keep at least one independent display enabled.";
    for(const out of enabled){
        const mode=modeParts(out.mode),r=rectangle(out);
        if(!mode||mode.width<=0||mode.height<=0||mode.hz<=0)return "No usable advertised mode for "+out.name+". Detect the display or choose an available mode.";
        if(!Number.isFinite(out.scale)||out.scale<0.5||out.scale>4)return "Scale must be between 50% and 400%.";
        if(Math.abs(r.width-Math.round(r.width))>0.02||Math.abs(r.height-Math.round(r.height))>0.02)return "Mode and scale must produce whole logical pixels on "+out.name+".";
    }
    for(let i=0;i<enabled.length;i++)for(let j=i+1;j<enabled.length;j++){
        const a=rectangle(enabled[i]),b=rectangle(enabled[j]);
        if(a.x<b.x+b.width-0.01&&a.x+a.width>b.x+0.01&&a.y<b.y+b.height-0.01&&a.y+a.height>b.y+0.01)
            return "Overlap: "+enabled[i].name+" and "+enabled[j].name+". Move them apart before applying.";
    }
    return "";
}
