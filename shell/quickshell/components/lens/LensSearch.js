.pragma library

function focusRequest(address, usingLua) {
    address=String(address || "");
    if (!/^0x[0-9a-f]+$/i.test(address)) return "";
    return usingLua ? 'hl.dsp.focus({window="address:'+address+'"})' : "focuswindow address:"+address;
}

// A provider row has kind/id/label/detail/keywords/icon and an opaque activation
// identity. Provider text is always plain text; it is never executable markup.
function plain(value) {
    return String(value || "").replace(/<[^>]*>/g, "")
        .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'").replace(/&amp;/g, "&");
}
function message(text) {
    const line = text.split("\n").find(l => l.startsWith("\0message\x1f"));
    return line ? plain(line.slice(9)) : "";
}
function parse(text, kind, home) {
    const rows = [], seen = {};
    for (const line of text.split("\n")) {
        if (!line || line[0] === "\0") continue;
        const parts = line.split("\0"), fields = (parts[1] || "").split("\x1f"), meta = {};
        for (let i = 0; i + 1 < fields.length; i += 2) meta[fields[i]] = fields[i + 1];
        if (!meta.info || meta.nonselectable === "true" || seen[meta.info]) continue;
        seen[meta.info] = true;
        let label = plain(parts[0]), detail = "";
        if (kind === "files") {
            label = meta.info.split("/").pop() || meta.info;
            const parent = meta.info.slice(0, meta.info.lastIndexOf("/")) || "/";
            detail = home && (parent === home || parent.startsWith(home + "/")) ? "~" + parent.slice(home.length) : parent;
            if (meta.info === "__senomy_refresh__") { label = "Refresh file index"; detail = "Rescan configured local folders"; }
        } else if (meta.display) {
            const spans = [], pattern = /<span\b[^>]*>(.*?)<\/span>/g;
            let match;
            while ((match = pattern.exec(meta.display)) !== null) spans.push(match);
            if (spans.length) { label = plain(spans[0][1]); detail = spans.length > 1 ? plain(spans[1][1]) : ""; }
        }
        rows.push({kind:kind, id:kind + ":" + meta.info, label:label, detail:detail,
            keywords:meta.meta || "", icon:meta.icon || "", info:meta.info});
    }
    return rows;
}
function normalized(value) { return String(value || "").toLocaleLowerCase().trim(); }
function score(row, query) {
    const label = normalized(row.label), q = normalized(query);
    if (!q) return 0;
    if (label === q) return 1000;
    if (label.startsWith(q)) return 900 - Math.min(80, label.length - q.length);
    const words = label.split(/[^\p{L}\p{N}]+/u);
    if (words.includes(q)) return 800;
    if (words.some(w => w.startsWith(q))) return 750;
    if (label.includes(q)) return 700;
    const tokens = q.split(/\s+/), context = normalized((row.detail || "") + " " + (row.keywords || ""));
    if (tokens.every(t => label.includes(t))) return 650;
    if (tokens.every(t => (label + " " + context).includes(t))) return 500;
    // Tight label-only subsequences are a last resort; context cannot create
    // arbitrary weak matches that displace a literal title or keyword match.
    if (q.length < 2 || /\s/.test(q)) return -1;
    let first = -1, at = 0, last = -1;
    for (let i = 0; i < label.length && at < q.length; ++i) {
        if (label[i] === q[at]) { if (first < 0) first = i; last = i; ++at; }
    }
    const gaps = last - first + 1 - q.length;
    return at === q.length && gaps <= Math.max(3, q.length * 2) ? 200 - gaps * 8 - first : -1;
}
function search(rows, query, scope, browsing, usage, appSort) {
    const q = normalized(query), unique = {}, ranked = [];
    for (const row of rows) {
        if (scope !== "all" && row.kind !== scope || unique[row.id]) continue;
        unique[row.id] = true;
        // Empty All offers observed windows and real, useful actions. No
        // pretend recent history and no alphabetic dump of installed apps.
        if (!q && scope === "all" && row.kind !== "windows" &&
            !(row.kind === "actions" && ["settings", "files", "control"].includes(row.info))) continue;
        const value = score(row, q);
        if (value >= 0) ranked.push({row:row, score:value});
    }
    function popularity(row) {return usage && usage[String(row.id).replace(/^apps:/,"")] || {count:0,lastOpened:0};}
    ranked.sort((a,b) => b.score - a.score || (scope==="apps" && !q && appSort!=="alphabetical" ? popularity(b.row).count-popularity(a.row).count || popularity(b.row).lastOpened-popularity(a.row).lastOpened : 0) || (a.row.kind === "windows" && b.row.kind !== "windows" ? -1 : b.row.kind === "windows" && a.row.kind !== "windows" ? 1 : 0) || a.row.label.localeCompare(b.row.label));
    if (!q && scope === "all") {
        const windows = ranked.filter(r => r.row.kind === "windows").sort((a,b) => Number(!!b.row.focused)-Number(!!a.row.focused));
        const actions = ["settings", "files", "control"].map(id => ranked.find(r => r.row.kind === "actions" && r.row.info === id)).filter(Boolean);
        return windows.slice(0,2).concat(actions).slice(0,5).map(r => r.row);
    }
    return ranked.slice(0, browsing ? 200 : 120).map(r => r.row);
}
function effect(row) {
    if (!row) return "";
    if (row.kind === "windows") return "Focus window";
    if (row.kind === "apps") return "Launch app";
    if (row.kind === "files") return row.info === "__senomy_refresh__" ? "Refresh index" : row.icon === "folder" ? "Open folder" : "Open file";
    return row.info === "screenshot" ? "Start capture" : (row.info || "").startsWith("settings-task:") ? "Open settings" : "Open " + row.label;
}

// Display metadata is distinct from searchable provider context.
function secondary(row) {
    const label=normalized(row.label), detail=String(row.detail || "").trim();
    if (!detail || normalized(detail)===label) return "";
    if (row.kind === "actions" && (/^open\b/i.test(detail) || /^launch\b/i.test(detail))) return "";
    if (row.kind === "windows") {
        const parts=detail.split(" · ");
        const app=normalized(parts[0]);
        if (app && (label===app || label.endsWith(" — "+app) || label.endsWith(" - "+app))) parts.shift();
        return parts.join(" · ");
    }
    return detail;
}
