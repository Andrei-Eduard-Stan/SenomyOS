.pragma library
function ageLabel(at, now) {
    const seconds=Math.max(0,Math.floor((now-at)/1000));
    if(seconds<60)return seconds+"s ago";
    if(seconds<3600)return Math.floor(seconds/60)+"m ago";
    if(seconds<86400)return Math.floor(seconds/3600)+"h ago";
    return Math.floor(seconds/86400)+"d ago";
}
function describe(at,now,threshold,cached) {
    if(!Number.isFinite(Number(at)) || Number(at)<=0)return "UNAVAILABLE · observation time unknown";
    if(Number(at)>now+60000)return "UNKNOWN · source timestamp is in the future";
    return (now-at>threshold?"STALE":cached?"CACHED":"LIVE")+" · "+ageLabel(at,now);
}
function segments(values,times,now,span) {
    const result=[];let part=[];
    for(let i=0;i<values.length;i++){
        const at=times.length===values.length?Number(times[i]):now-(values.length-1-i)*1000;
        if(at<now-span || at>now || values[i]===null || !Number.isFinite(Number(values[i]))){if(part.length)result.push(part);part=[];continue;}
        if(part.length && at-part[part.length-1].at>2500){result.push(part);part=[];}
        part.push({at:at,value:Number(values[i])});
    }
    if(part.length)result.push(part);return result;
}
