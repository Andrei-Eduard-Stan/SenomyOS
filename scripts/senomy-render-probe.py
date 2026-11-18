#!/usr/bin/env python3
"""Start/read/stop a bounded passive queued-frame capture in the running shell."""
import argparse,json,os,subprocess,sys
from pathlib import Path

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['start','state','stop'])
    parser.add_argument('--config',type=Path,default=Path(__file__).resolve().parents[1]/'shell/quickshell')
    args=parser.parse_args()
    try:
        result=subprocess.run([os.environ.get('SENOMY_QS_BIN','qs'),'ipc','--path',str(args.config.resolve()),'call','shell','renderMetrics',args.action],capture_output=True,text=True,timeout=4)
        data=json.loads(result.stdout)
        if result.returncode or not isinstance(data,dict) or data.get('schema_version')!=1 or not isinstance(data.get('transitions'),list):raise ValueError('Invalid render-metrics response')
        print(json.dumps({'ok':True,'data':data},separators=(',',':')))
        return 0
    except (OSError,subprocess.SubprocessError,ValueError) as error:
        print(json.dumps({'ok':False,'data':None,'error':'Render metrics unavailable: '+str(error)}))
        return 1
if __name__=='__main__':sys.exit(main())
