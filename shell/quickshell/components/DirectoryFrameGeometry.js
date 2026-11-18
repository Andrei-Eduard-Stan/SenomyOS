.pragma library

// Authored corner allocation plus raised lettering plates, in logical pixels.
// The same polygons feed paint and the native input region; no screen constants.
function chamfer(x, y, width, height, cut) {
    if (width <= 0 || height <= 0) return [];
    const k = Math.max(0, Math.min(cut, width / 2, height / 2));
    return [[x+k,y],[x+width-k,y],[x+width,y+k],[x+width,y+height-k],
        [x+width-k,y+height],[x+k,y+height],[x,y+height-k],[x,y+k]];
}
function polygons(width, height, label, cipher) {
    const top = Math.min(25, height / 4), bottom = height - top;
    const result = [chamfer(0, top, width, bottom-top, 24)];
    for (const rect of [label, cipher]) {
        if (!rect || rect.width <= 0 || rect.height <= 0 || rect.y >= top) continue;
        const left = Math.max(0, rect.x - 8), right = Math.min(width, rect.x + rect.width + 8);
        const y = Math.max(0, rect.y - 2);
        result.push(chamfer(left, y, right-left, Math.max(top+8, rect.y+rect.height+2)-y, 6));
    }
    return result.filter(points => points.length > 0);
}
function contains(polygons, x, y) {
    return polygons.some(points => {
        let inside = false;
        for (let i=0,j=points.length-1; i<points.length; j=i++) {
            const a=points[i], b=points[j];
            if ((a[1]>y)!==(b[1]>y) && x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]) inside=!inside;
        }
        return inside;
    });
}
// Quickshell 0.3.2 Region supports rectangles/ellipses, not polygon paths.
// Merge integer scanlines into bounded rectangles instead of a rectangular mask.
function regions(polygons, width, height) {
    const result=[], active={};
    for (let y=0; y<Math.ceil(height); ++y) {
        const spans=[];
        for (const points of polygons) {
            const hits=[];
            for (let i=0,j=points.length-1; i<points.length; j=i++) {
                const a=points[i],b=points[j],sample=y+0.5;
                if ((a[1]>sample)!==(b[1]>sample)) hits.push(a[0]+(sample-a[1])*(b[0]-a[0])/(b[1]-a[1]));
            }
            hits.sort((a,b)=>a-b);
            for(let i=0;i+1<hits.length;i+=2)spans.push([Math.max(0,Math.floor(hits[i])),Math.min(Math.ceil(width),Math.ceil(hits[i+1]))]);
        }
        spans.sort((a,b)=>a[0]-b[0]);
        const merged=[];
        for(const span of spans){const last=merged[merged.length-1];if(last&&span[0]<=last[1])last[1]=Math.max(last[1],span[1]);else merged.push(span.slice());}
        const used={};
        for(const span of merged){if(span[1]<=span[0])continue;const key=span.join(':');used[key]=true;
            if(active[key]&&active[key].y+active[key].height===y)active[key].height++;
            else {const rect={x:span[0],y:y,width:span[1]-span[0],height:1};result.push(rect);active[key]=rect;}}
        for(const key of Object.keys(active))if(!used[key])delete active[key];
    }
    return result;
}
