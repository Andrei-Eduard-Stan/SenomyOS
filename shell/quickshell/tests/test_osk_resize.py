#!/usr/bin/env python3
"""Resize limits and fixed shortcut argv; never targets the live compositor."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest
repo=Path(__file__).resolve().parents[3]
class ResizeTests(unittest.TestCase):
    def test_geometry_limits_corners_and_small_outputs(self):
        with tempfile.TemporaryDirectory(prefix='senomy-resize-') as directory:
            root=Path(directory);source=root/'test.c';source.write_text('''#include <assert.h>
#include "senomy-resize.h"
int main(void) {
 assert(senomy_edge(-1,1,800,250)==0);assert(senomy_edge(1,1,800,250)==3);
 assert(senomy_edge(799,1,800,250)==5);assert(senomy_edge(400,100,800,250)==0);
 struct senomy_drag d={5,-1,800,700,800,250};uint32_t w,h;
 senomy_size(&d,700,600,1000,1000,&w,&h);assert(w==600&&h==350);
 senomy_size(&d,9999,-9999,1000,1000,&w,&h);assert(w==1000&&h==600);
 senomy_size(&d,-9999,9999,1000,1000,&w,&h);assert(w==320&&h==128);
 d.edge=2;senomy_size(&d,900,700,1000,1000,&w,&h);assert(w==600&&h==250);
 senomy_size(&d,-9999,9999,240,200,&w,&h);assert(w==240&&h==120);
 return 0;
}''')
            subprocess.run(['cc','-Wall','-Wextra','-Werror','-I',str(repo/'components/input/osk'),str(source),'-o',str(root/'test')],check=True)
            subprocess.run([str(root/'test')],check=True)
    def test_shortcut_fixed_argv_and_rejects_arguments(self):
        with tempfile.TemporaryDirectory(prefix='senomy-shortcut-') as directory:
            root=Path(directory);tool=root/'qs';tool.write_text('#!/usr/bin/env python3\nimport sys,json\nprint(json.dumps(sys.argv[1:]))\n');tool.chmod(0o755)
            env=dict(os.environ,SENOMY_QS_BIN=str(tool),SENOMY_SOURCE_ROOT=str(root/'source'))
            result=subprocess.run([str(repo/'scripts/senomy-osk')],env=env,capture_output=True,text=True,check=True)
            import json
            self.assertEqual(json.loads(result.stdout),['ipc','--path',str(root/'source/shell/quickshell'),'call','shell','oskToggle'])
            result=subprocess.run([str(repo/'scripts/senomy-osk'),'arbitrary'],env=env,capture_output=True,text=True)
            self.assertEqual(result.returncode,2)
if __name__=='__main__':unittest.main()
