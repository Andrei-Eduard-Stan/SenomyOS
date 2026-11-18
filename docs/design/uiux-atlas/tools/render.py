#!/usr/bin/env python3
"""Render the actual atlas PPTX locally, without an interactive office window."""
from pathlib import Path
import argparse, json, os, shutil, subprocess, tempfile

ATLAS=Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser();p.add_argument('--office-root',type=Path);p.add_argument('--first',type=int,default=1);p.add_argument('--last',type=int);p.add_argument('--montage-only',action='store_true');p.add_argument('--pdf-only',action='store_true');args=p.parse_args()
    out=ATLAS/'preview';out.mkdir(exist_ok=True)
    total=json.loads((ATLAS/'inventory.json').read_text())['summary']['slides']
    if not args.montage_only:
        env={k:v for k,v in os.environ.items() if k not in ['DISPLAY','WAYLAND_DISPLAY','DBUS_SESSION_BUS_ADDRESS']}
        env['SAL_USE_VCLPLUGIN']='svp'
        if args.office_root:
            root=args.office_root.resolve();office=root/'usr/lib/libreoffice/program/soffice.bin';poppler=root/'usr/bin/pdftoppm'
            env['LD_LIBRARY_PATH']=str(root/'usr/lib')+':'+str(office.parent)
        else:
            office=shutil.which('libreoffice') or shutil.which('soffice');poppler=shutil.which('pdftoppm')
        if not office or not poppler:raise SystemExit('LibreOffice and pdftoppm are required. No packages are installed automatically.')
        pdf=out/'SenomyOS-UIUX-Design-Atlas.pdf';pptx=ATLAS/'SenomyOS-UIUX-Design-Atlas.pptx'
        if not pdf.exists() or pdf.stat().st_mtime<pptx.stat().st_mtime:
            with tempfile.TemporaryDirectory(prefix='senomy-atlas-office-profile-') as d:
                argv=[str(office),'-env:UserInstallation='+Path(d).as_uri(),'--headless','--norestore','--nodefault','--nolockcheck','--convert-to','pdf','--outdir',str(out),str(pptx)]
                result=subprocess.run(argv,env=env,capture_output=True,text=True,timeout=90)
                if result.returncode==81:result=subprocess.run(argv,env=env,capture_output=True,text=True,timeout=90)
                (out/'office-render.log').write_text(result.stdout+result.stderr)
                if result.returncode or not pdf.exists():raise SystemExit(result.stdout+result.stderr or 'Office export failed')
        if args.pdf_only:return
        last=min(total,args.last or total)
        for start in range(args.first,last+1,25):
            finish=min(last,start+24)
            subprocess.run([str(poppler),'-f',str(start),'-l',str(finish),'-scale-to','1536','-png',str(pdf),str(out/'slide')],env=env,check=True,timeout=85)
            print(f'Rendered slides {start}–{finish}',flush=True)
    if not args.first==1 or args.last:return
    pngs=sorted(out.glob('slide-*.png'))
    thumbs=out/'.thumbs';thumbs.mkdir(exist_ok=True)
    for image in pngs:
        thumb=thumbs/(image.stem+'.jpg')
        if not thumb.exists()or thumb.stat().st_mtime<image.stat().st_mtime:
            subprocess.run(['magick',str(image),'-thumbnail','384x216','-quality','85',str(thumb)],check=True,timeout=15)
    for start in range(0,len(pngs),24):
        batch=pngs[start:start+24];argv=['magick','montage']
        for image in batch:argv+=['-label',image.stem,str(thumbs/(image.stem+'.jpg'))]
        argv+=['-font','Adwaita-Sans','-pointsize','12','-background','#17191e','-fill','#eeeeee','-geometry','384x216+8+14','-tile','4x',str(out/f'contact-{start//24+1:02}.jpg')]
        subprocess.run(argv,check=True,timeout=45)
    (out/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>SenomyOS atlas previews</title><style>body{background:#08090b;color:#eee;font:16px sans-serif;margin:32px}img{max-width:100%;height:auto}figure{margin:24px 0}</style><h1>SenomyOS UI/UX Design Atlas</h1>'+''.join(f'<figure><figcaption>{image.stem}</figcaption><a href="{image.name}"><img loading="lazy" src="{image.name}"></a></figure>'for image in pngs))
    print(f'{len(pngs)} slide previews and local contact sheets',flush=True)

if __name__=='__main__':main()
