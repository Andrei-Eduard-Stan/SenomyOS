#!/usr/bin/env python3
"""Read-only syntax/projection checks for the scoped Rofi/GTK utility themes."""
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET
import gi

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk

ROOT = Path(__file__).resolve().parent.parent
subprocess.run(['python3', str(ROOT / 'scripts/generate-utility-appearance.py'), '--check'], check=True)
for name in ('SenomyOS', 'SenomyOS-Touch'):
    css = ROOT / 'appearance/file-manager/gtk3' / name / 'gtk-3.0/gtk.css'
    provider = Gtk.CssProvider()
    errors = []
    provider.connect('parsing-error', lambda _, section, error: errors.append(str(error)))
    provider.load_from_path(str(css))
    assert not errors, errors
# Regress the inherited white GtkMessageDialog titlebar without showing a
# window or obtaining the notification/session bus.
    path = Gtk.WidgetPath()
    path.append_type(Gtk.MessageDialog)
    path.iter_set_object_name(-1, 'messagedialog')
    path.iter_add_class(-1, 'background')
    path.append_type(Gtk.Box)
    path.iter_set_object_name(-1, 'box')
    path.iter_add_class(-1, 'titlebar')
    context = Gtk.StyleContext()
    context.set_path(path)
    context.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)
    for state in (Gtk.StateFlags.NORMAL, Gtk.StateFlags.BACKDROP):
        color = context.get_background_color(state)
        assert max(color.red, color.green, color.blue) < .2, color.to_string()
for path in (ROOT / 'appearance/file-manager/gtk3/SenomyOS/gtk-3.0/assets').glob('utility-corner-*.svg'):
    root = ET.parse(path).getroot()
    assert root.attrib['width'] == root.attrib['height'] == '24'
    assert all(x.attrib.get('preserveAspectRatio') == 'xMidYMid meet'
               for x in root if x.tag.endswith('svg'))
for path in [ROOT / 'appearance/launcher/rofi/config.rasi', ROOT / 'appearance/launcher/rofi/themes/command-lens.rasi']:
    # Rofi 2.0's lexer greedily consumes quoted strings on the same line.
    assert all(line.count('"') <= 2 for line in path.read_text().splitlines()), path
print('GTK standard/touch parsing, original corner proportions and Rasi string safety passed.')
