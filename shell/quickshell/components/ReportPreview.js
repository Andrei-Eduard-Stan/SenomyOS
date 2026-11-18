.pragma library

// A read-only projection of the existing report grammar. Export retains original lines.
function blocks(preview) {
    const lines=(preview || []).map(row=>String(row.text===undefined?"":row.text));
    const out=[];let metadata=null,inHeader=true,inCode=false;
    const separator=text=>/^={8,}\s*$/.test(text);
    for(let i=0;i<lines.length;i++) {
        const raw=lines[i];
        if(raw.startsWith("```")){inCode=!inCode;out.push({kind:"text",text:raw});continue;}
        if(!inCode && separator(raw) && i+2<lines.length && /^[A-Z][A-Z0-9 /&_.-]{0,60}$/.test(lines[i+1]) && separator(lines[i+2])) {
            out.push({kind:"heading",text:lines[i+1]});i+=2;inHeader=false;metadata=null;continue;
        }
        if(!inCode && /^#{1,6}\s+/.test(raw)){out.push({kind:"heading",text:raw.replace(/^#{1,6}\s+/,"")});inHeader=false;continue;}
        if(i===0 && raw==="SENOMYOS EVIDENCE REPORT"){out.push({kind:"title",text:raw});continue;}
        const match=inHeader && /^(ID|PROFILE|GENERATED|HOST|KERNEL|POLICY):\s*(.*)$/.exec(raw);
        if(match) {
            if(!metadata){metadata={kind:"metadata",fields:[]};out.push(metadata);}
            metadata.fields.push({label:match[1].charAt(0)+match[1].slice(1).toLowerCase(),text:match[2]});continue;
        }
        metadata=null;
        out.push({kind:"text",text:raw});
    }
    return out;
}
