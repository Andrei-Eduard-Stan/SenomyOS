#!/usr/bin/env python3
"""Local structural/traceability checks, with no desktop or service access."""
from pathlib import Path
import hashlib,json,posixpath,re,struct,zipfile
import xml.etree.ElementTree as ET

ATLAS=Path(__file__).resolve().parents[1]
ROOT=ATLAS.parents[2]
NS={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main','r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
REL='{http://schemas.openxmlformats.org/package/2006/relationships}'

def main():
    inv=json.loads((ATLAS/'inventory.json').read_text());problems=[]
    native_texts=0;native_tables=0;pictures=0;aspects=0;worksheets=0
    with zipfile.ZipFile(ATLAS/'SenomyOS-UIUX-Design-Atlas.pptx') as z:
        names=set(z.namelist());slide_names=sorted((n for n in names if re.fullmatch(r'ppt/slides/slide\d+\.xml',n)),key=lambda s:int(re.search(r'(\d+)\.xml',s)[1]))
        if len(slide_names)!=inv['summary']['slides']:problems.append('Slide count mismatch')
        for name in names:
            if name.endswith('.xml') or name.endswith('.rels'):
                try:ET.fromstring(z.read(name))
                except ET.ParseError:problems.append('Malformed XML '+name)
            if not name.endswith('.rels'):continue
            folder=posixpath.dirname(posixpath.dirname(name))
            for rel in ET.fromstring(z.read(name)):
                if rel.get('TargetMode')=='External':
                    if rel.get('Type','').endswith('/image'):problems.append('External image '+name)
                    continue
                target=posixpath.normpath(posixpath.join(folder,rel.get('Target','')))
                if target not in names:problems.append('Missing relationship '+target)
        types=ET.fromstring(z.read('[Content_Types].xml'))
        for child in types:
            if child.tag.endswith('Override') and child.get('PartName','').lstrip('/') not in names:problems.append('Orphan content type '+child.get('PartName',''))
        for name in slide_names:
            xml=ET.fromstring(z.read(name));texts=[''.join(n.itertext())for n in xml.findall('.//a:t',NS)]
            native_texts+=len(xml.findall('.//p:sp',NS));native_tables+=len(xml.findall('.//a:tbl',NS))
            if 'PROPOSED / AFTER'in texts:worksheets+=1
            rels_name=posixpath.dirname(name)+'/_rels/'+posixpath.basename(name)+'.rels'
            relationships={r.get('Id'):posixpath.normpath(posixpath.join(posixpath.dirname(name),r.get('Target'))) for r in ET.fromstring(z.read(rels_name))}
            for pic in xml.findall('.//p:pic',NS):
                pictures+=1;blip=pic.find('.//a:blip',NS);extent=pic.find('./p:spPr/a:xfrm/a:ext',NS)
                data=z.read(relationships[blip.get('{'+NS['r']+'}embed')])
                if data.startswith(b'\x89PNG') and extent is not None:
                    pw,ph=struct.unpack('>II',data[16:24]);actual=int(extent.get('cx'))/int(extent.get('cy'));expected=pw/ph
                    if abs(actual/expected-1)>.006:problems.append('Stretched picture '+name)
                    aspects+=1
            for xfrm in xml.findall('.//a:xfrm',NS)+xml.findall('.//p:xfrm',NS):
                off=xfrm.find('a:off',NS);ext=xfrm.find('a:ext',NS)
                if off is None:off=xfrm.find('p:off',NS)
                if ext is None:ext=xfrm.find('p:ext',NS)
                if off is None or ext is None:continue
                x,y=int(off.get('x')),int(off.get('y'));w,h=int(ext.get('cx')),int(ext.get('cy'))
                if x<0 or y<0 or x+w>16*914400+100 or y+h>9*914400+100:problems.append('Out of page '+name)
        if worksheets<25:problems.append('Missing comparison worksheets')
        if native_tables<10:problems.append('Missing native tracker tables')
        if not any('slideMasters/'in n for n in names):problems.append('Missing reusable master')
    for item in inv['items']:
        for source in item['source_files']:
            if not (ROOT/source).is_file():problems.append('Missing source '+source)
        for capture in item['captures']:
            p=ATLAS/capture['path']
            if not p.is_file():problems.append('Missing asset '+str(p));continue
            if hashlib.sha256(p.read_bytes()).hexdigest()!=capture['sha256']:problems.append('Changed asset '+capture['path'])
            if any(s<1 or s>inv['summary']['slides']for s in capture.get('slide_refs',[])):problems.append('Bad slide reference '+capture['path'])
    drift=[]
    for entry in inv['source_catalog']:
        p=ROOT/entry['path']
        if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=entry['sha256']:drift.append(entry['path'])
    if drift:problems.append('Source drift: '+', '.join(drift))
    report={'status':'pass'if not problems else'fail','slides':len(slide_names),'native_shapes_and_text':native_texts,'native_tables':native_tables,'pictures':pictures,'image_aspects_checked':aspects,'comparison_worksheets':worksheets,'source_drift':drift,'problems':sorted(set(problems)),'limits':'Structural/source checks. Visual review and office rendering are recorded separately. No Microsoft PowerPoint claim.'}
    (ATLAS/'preview/validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
    if problems:raise SystemExit(1)

if __name__=='__main__':main()
