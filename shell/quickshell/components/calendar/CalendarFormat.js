.pragma library
// All stored/socket dates remain ISO civil dates; only presentation is regional.
function pattern(format) { return format === "eu" ? "dd/MM/yyyy" : format === "us" ? "MM/dd/yyyy" : "yyyy-MM-dd"; }
function hint(format) { return format === "eu" ? "DD/MM/YYYY" : format === "us" ? "MM/DD/YYYY" : "YYYY-MM-DD"; }
function iso(value, format) {
    const input=String(value).trim();
    let m=/^(\d{4})-(\d{2})-(\d{2})$/.exec(input), y,month,d;
    if(m){y=Number(m[1]);month=Number(m[2]);d=Number(m[3]);}
    else {
        m=/^(\d{2})\/(\d{2})\/(\d{4})$/.exec(input);
        if(!m || !["eu","us"].includes(format)) return "";
        y=Number(m[3]);month=Number(m[format==="us"?1:2]);d=Number(m[format==="us"?2:1]);
    }
    const date=new Date(2000,0,1,12);date.setFullYear(y,month-1,d);
    if(y<1||y>9999||date.getFullYear()!==y||date.getMonth()!==month-1||date.getDate()!==d)return "";
    return String(y).padStart(4,"0")+"-"+String(month).padStart(2,"0")+"-"+String(d).padStart(2,"0");
}
function display(value, format) {
    const key=iso(value,"iso");if(!key)return String(value||"");
    if(format==="eu")return key.slice(8,10)+"/"+key.slice(5,7)+"/"+key.slice(0,4);
    if(format==="us")return key.slice(5,7)+"/"+key.slice(8,10)+"/"+key.slice(0,4);
    return key;
}
function reminder(value) {
    const raw=String(value===undefined?"":value).trim();
    if(raw===""||raw==="NONE")return "";
    if(/^\d+$/.test(raw))return raw;
    const m=/^(\d+)\s*(minutes?|mins?|hours?|hrs?|days?|weeks?)\s*(before)?$/i.exec(raw);
    if(!m)return raw;
    return String(Number(m[1])*(/^w/i.test(m[2])?10080:/^d/i.test(m[2])?1440:/^h/i.test(m[2])?60:1));
}
