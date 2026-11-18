.pragma library
function validate(registry) {
    if(registry.schemaVersion!==1 || !registry.frames || typeof registry.frames!=="object") throw new Error("Unsupported skin manifest");
    if(["native","art"].indexOf(registry.defaultMode)<0) throw new Error("defaultMode must be native or art");
    function finite(n) { return typeof n==="number" && Number.isFinite(n); }
    for(const key of Object.keys(registry.frames)) {
        const f=registry.frames[key];
        if(!f || ["native","art","inherit"].indexOf(f.mode || "inherit")<0) throw new Error(key+": invalid mode");
        if(["nine-slice","protected-bands","fit"].indexOf(f.scaling)<0) throw new Error(key+": invalid scaling");
        if(!Array.isArray(f.logicalSize) || f.logicalSize.length!==2 || !f.logicalSize.every(n=>finite(n)&&n>0&&n<=8192)) throw new Error(key+": invalid logicalSize");
        if(typeof f.source!=="string") throw new Error(key+": missing source");
        if(f.opacity!==undefined && (!finite(f.opacity)||f.opacity<0||f.opacity>1)) throw new Error(key+": opacity must be 0–1");
        if(f.offset!==undefined && (!Array.isArray(f.offset)||f.offset.length!==2||!f.offset.every(finite))) throw new Error(key+": invalid offset");
        if(f.background!==undefined && ["art","native"].indexOf(f.background)<0) throw new Error(key+": invalid background");
        for(const group of ["insets","contentPadding"]) {
            if(f[group]!==undefined && (typeof f[group]!=="object" || !["left","right","top","bottom"].every(k=>finite(f[group][k])&&f[group][k]>=0))) throw new Error(key+": invalid "+group);
        }
        if(f.scaling!=="fit") {
            const i=f.insets;
            if(!i || i.left+i.right+(f.fixedCenterWidth||0)>=f.logicalSize[0] || i.top+i.bottom+(f.fixedCenterHeight||0)>=f.logicalSize[1]) throw new Error(key+": caps leave no stretchable centre");
        }
        for(const field of ["fixedCenterWidth","fixedCenterHeight"]) if(f[field]!==undefined && (!finite(f[field])||f[field]<0)) throw new Error(key+": invalid fixed band");
        const p=f.contentPadding;
        if(p && (p.left+p.right>=f.logicalSize[0] || p.top+p.bottom>=f.logicalSize[1])) throw new Error(key+": content padding consumes artboard");
        if(f.variants && !Object.keys(f.variants).every(k=>["normal","hover","active","warning","critical","disabled"].indexOf(k)>=0 && typeof f.variants[k]==="string")) throw new Error(key+": invalid state variants");
    }
    if (registry.backgrounds !== undefined && (!registry.backgrounds || typeof registry.backgrounds !== "object" || Array.isArray(registry.backgrounds)))
        throw new Error("backgrounds must be an object");
    const backgrounds=Object.assign({}, registry.persona && registry.persona.backgrounds || {}, registry.backgrounds || {});
    for(const key of Object.keys(backgrounds)) {
        const bg=backgrounds[key];
        if(!bg || typeof bg !== "object") throw new Error("Unknown persona background: "+key);
        if(bg.source!==undefined && typeof bg.source!=="string") throw new Error(key+": invalid background source");
        if(bg.scaling!==undefined && ["crop","fit"].indexOf(bg.scaling)<0) throw new Error(key+": invalid background scaling");
        if(bg.color!==undefined && (typeof bg.color!=="string" || !/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(bg.color))) throw new Error(key+": background color must be hex");
        for(const k of ["opacity","imageOpacity","scrimOpacity"]) if(bg[k]!==undefined && (!finite(bg[k])||bg[k]<0||bg[k]>1)) throw new Error(key+": invalid "+k);
    }
    const persona=registry.persona || {};
    for(const key of ["reducedMotion","hoverExpansionEnabled","highContrast"])
        if(persona[key]!==undefined && typeof persona[key]!=="boolean") throw new Error("Invalid "+key);
    if(persona.railTextPx!==undefined && (!finite(persona.railTextPx)||persona.railTextPx<10||persona.railTextPx>16))
        throw new Error("Rail text must be 10–16 px");
    if(persona.uiTextScale!==undefined && (!finite(persona.uiTextScale)||persona.uiTextScale<1||persona.uiTextScale>1.5))
        throw new Error("Interface text scale must be 1–1.5");
    return registry;
}
