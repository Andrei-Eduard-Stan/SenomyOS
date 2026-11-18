.pragma library
function leaf(id, label, route, view, tags) {
    return {id:id, label:label, route:route, view:view || "", tags:tags || ""};
}
function group(id, label, route, children) { return {id:id,label:label,route:route,children:children}; }
function performance() {
    function views(route, names) { return names.map(name => leaf(route+"/"+name.toLowerCase(),name,route,name.toLowerCase(),name === "THERMALS" || name === "HEALTH" ? "temperature sensor" : "")); }
    const nodes = [leaf("overview","OVERVIEW","overview"),
        group("compute","COMPUTE","",[
            group("cpu","CPU","cpu",views("cpu",["UTILISATION","CORES","FREQUENCY","THERMALS","PROCESSES"])),
            group("gpu","GPU","gpu",views("gpu",["UTILISATION","MEMORY","THERMALS"]))]),
        group("memory","MEMORY","memory",views("memory",["PHYSICAL","SWAP","PRESSURE","PROCESSES"])),
        group("storage","STORAGE","storage",views("storage",["DEVICES","FILESYSTEMS","IO","HEALTH"])),
        group("network","NETWORK","network",views("network",["INTERFACES","TRAFFIC","CONNECTIONS","DNS"])),
        leaf("processes","PROCESSES","processes"), leaf("benchmarks","BENCHMARKS","benchmarks"),
        group("tools","SYSTEM TOOLS","",[leaf("services","SERVICES","services"),leaf("diagnostics","DIAGNOSTICS","diagnostics"),leaf("console","CONSOLE","console"),leaf("reports","REPORTS","reports")])];
    function mark(list){list.forEach(node=>{if(node.id.startsWith("gpu/") || node.id==="storage/health" || node.id==="network/dns")node.availability="unavailable";if(node.children)mark(node.children);});}
    mark(nodes);return nodes;
}
function flatten(nodes, expanded, query) {
    const result=[], q=String(query || "").trim().toLowerCase();
    function matches(node, ancestors) {
        return (ancestors+" "+node.label+" "+(node.tags || "")).toLowerCase().includes(q)
            || (node.children || []).some(child=>matches(child,ancestors+" "+node.label));
    }
    function visit(list, depth, ancestors) {
        list.forEach(node=>{
            if (q && !matches(node, ancestors)) return;
            result.push(Object.assign({},node,{depth:depth,branch:!!node.children,open:!!q || !!expanded[node.id]}));
            if(node.children && (q || expanded[node.id])) visit(node.children,depth+1,ancestors+" "+node.label);
        });
    }
    visit(nodes,0,""); return result;
}

function pathTo(nodes,id) {
    for(const node of nodes){
        if(node.id===id)return [node.id];
        const path=pathTo(node.children || [],id);
        if(path.length)return [node.id].concat(path);
    }
    return [];
}
