.pragma library
.import "SkinSchema.js" as Schema

function merge(registry,key,background,persona) {
    const next=JSON.parse(JSON.stringify(registry));
    Schema.validate(next);
    if(!next.backgrounds || !Object.prototype.hasOwnProperty.call(next.backgrounds,key)) throw new Error("Unknown surface");
    next.backgrounds[key]=Object.assign({},next.backgrounds[key],background);
    next.persona=Object.assign({},next.persona || {},persona);
    return Schema.validate(next);
}
