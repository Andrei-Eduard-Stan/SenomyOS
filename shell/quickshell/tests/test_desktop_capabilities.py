#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import json
import subprocess
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('capabilities',Path(__file__).resolve().parents[1]/'scripts/desktop-capabilities.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Capabilities(unittest.TestCase):
    def setUp(self):
        p=patch.object(m.shutil,'which',side_effect=lambda name:'/usr/bin/'+name);p.start();self.addCleanup(p.stop)
    def test_no_activation_or_permission_request(self):
        xml='<node><interface name="org.freedesktop.portal.FileChooser"/><interface name="org.freedesktop.portal.ScreenCast"/></node>'
        result=subprocess.CompletedProcess([],0,json.dumps({'data':[xml]}),'')
        with patch.object(m,'run',return_value=result) as run:
            data=m.portal_interfaces();self.assertEqual(data['state'],'advertised');self.assertTrue(next(x for x in data['features'] if x['name']=='FileChooser')['advertised'])
            self.assertFalse(next(x for x in data['features'] if x['name']=='Camera')['advertised']);self.assertIn('--auto-start=no',run.call_args.args[0]);self.assertEqual(run.call_args.args[0][-1],'Introspect')
    def test_malformed_missing_oversized_timeout_and_absence(self):
        for text in ['bad','{}',json.dumps({'data':['invalid']}),'x'*270000]:
            with patch.object(m,'run',return_value=subprocess.CompletedProcess([],0,text,'')):self.assertEqual(m.portal_interfaces()['state'],'unknown')
        with patch.object(m,'run',side_effect=subprocess.TimeoutExpired([],3)):self.assertEqual(m.portal_interfaces()['state'],'unknown')
        with patch.object(m.shutil,'which',return_value=None):self.assertEqual(m.portal_interfaces()['state'],'unknown')
    def test_services_independent_loaded_and_active(self):
        result=subprocess.CompletedProcess([],0,'Id=xdg-desktop-portal.service\nLoadState=loaded\nActiveState=inactive\nSubState=dead\n','')
        with patch.object(m,'run',return_value=result):
            data=m.unit_status('xdg-desktop-portal.service');self.assertTrue(data['available']);self.assertEqual(data['state'],'inactive')
            self.assertFalse(m.unit_status('xdg-desktop-portal-gtk.service')['available'])
    def test_missing_optional_tool_and_unknown_cli(self):
        with patch.object(m.shutil,'which',return_value=None):
            data=m.catalog();self.assertFalse(data['flatpakAvailable']);self.assertFalse(data['fileManagerAvailable'])
        with patch('builtins.print'):self.assertEqual(m.main(['approve-permission']),1)
if __name__=='__main__':unittest.main()
