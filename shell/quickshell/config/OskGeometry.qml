pragma Singleton
import QtQuick
QtObject {
    property var rectangle: null
    function floatingOn(screen) {
        const k=rectangle;
        return !!screen && !!k && !k.reserved && k.screen===screen.name && k.width>0 && k.height>0;
    }
    function clear() { rectangle=null; }
    function update(data) {
        if (!data || data.ok!==true || data.available!==true || typeof data.screen!=="string"
                || typeof data.reserved!=="boolean" || ![data.x,data.y,data.width,data.height].every(v => typeof v==="number" && isFinite(v) && v>=0 && v<=16384)) {clear();return;}
        rectangle=data;
    }
    // Select free monitor space before positioning a panel, so it can move
    // above a keyboard even when its original bottom-anchored frame overlaps.
    function place(screen,area,desiredWidth,desiredHeight,center) {
        const k=rectangle;
        let choices=[area];
        if(screen && k && k.reserved && k.screen===screen.name && k.width>0 && k.height>0
                && area.x+area.width>k.x && k.x+k.width>area.x && area.y+area.height>k.y && k.y+k.height>area.y) {
            const gap=8;
            choices=[{x:area.x,y:area.y,width:area.width,height:Math.min(area.height,k.y-gap-area.y)},
                {x:area.x,y:Math.max(area.y,k.y+k.height+gap),width:area.width,height:area.y+area.height-Math.max(area.y,k.y+k.height+gap)},
                {x:area.x,y:area.y,width:Math.min(area.width,k.x-gap-area.x),height:area.height},
                {x:Math.max(area.x,k.x+k.width+gap),y:area.y,width:area.x+area.width-Math.max(area.x,k.x+k.width+gap),height:area.height}];
        }
        let best=null,score=-1;
        for(const c of choices) {
            const w=Math.min(desiredWidth,c.width),h=Math.min(desiredHeight,c.height);
            if(w<240 || h<180)continue;
            const areaScore=w*h;
            if(areaScore>score) {score=areaScore;best={x:Math.max(c.x,Math.min(c.x+c.width-w,center-w/2)),y:c.y+c.height-h,width:w,height:h};}
        }
        if(best)return best;
        // Prefer a smaller free viewport over putting a panel under the OSK.
        for(const c of choices) {
            const w=Math.min(desiredWidth,c.width),h=Math.min(desiredHeight,c.height);
            if(w<=0 || h<=0)continue;
            if(w*h>score) {score=w*h;best={x:Math.max(c.x,Math.min(c.x+c.width-w,center-w/2)),y:c.y+c.height-h,width:w,height:h};}
        }
        if(best)return best;
        // No free piece exists: keep a bounded frame and the Rail dismiss path.
        const w=Math.max(1,Math.min(desiredWidth,area.width)),h=Math.max(1,Math.min(desiredHeight,area.height));
        return {x:Math.max(area.x,Math.min(area.x+area.width-w,center-w/2)),y:area.y+area.height-h,width:w,height:h};
    }
}
