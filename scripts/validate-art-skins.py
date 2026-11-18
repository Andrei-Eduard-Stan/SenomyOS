#!/usr/bin/env python3
"""Check artist contracts and full SVG/PNG exports without mutating any source."""
import json
import math
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlparse, unquote

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
tokens = json.loads((root / 'appearance/tokens.json').read_text())
manifest_path = root / 'appearance' / tokens['skin']['manifest']
manifest = json.loads(manifest_path.read_text())
assert manifest['schemaVersion'] == 1
assert manifest['defaultMode'] in ('art', 'native')
for key, spec in manifest['frames'].items():
    width, height = spec['logicalSize']
    assert width > 0 and height > 0, key
    assert spec.get('mode', 'inherit') in ('art', 'native', 'inherit'), key
    assert spec['scaling'] in ('fit', 'nine-slice', 'protected-bands'), key
    if spec['scaling'] != 'fit':
        i = spec['insets']
        assert all(math.isfinite(n) and n >= 0 for n in i.values()), key
        assert i['left'] + i['right'] + spec.get('fixedCenterWidth', 0) < width, key
        assert i['top'] + i['bottom'] + spec.get('fixedCenterHeight', 0) < height, key
    for source in [spec['source'], *spec.get('variants', {}).values()]:
        parsed = urlparse(source)
        path = Path(unquote(parsed.path)) if parsed.scheme == 'file' else manifest_path.parent / source
        assert path.is_file(), f'{key}: missing {path}'
        if path.suffix.lower() == '.svg':
            svg = ET.parse(path).getroot()
            _, _, sw, sh = map(float, svg.attrib['viewBox'].replace(',', ' ').split())
            assert math.isclose(sw / sh, width / height, rel_tol=0.0001), f'{key}: aspect ratio mismatch'
            ids = [n.attrib['id'] for n in svg.iter() if 'id' in n.attrib]
            assert len(ids) == len(set(ids)), f'{key}: duplicate SVG ids'
            assert not any(n.tag.endswith('script') for n in svg.iter()), key
print(f'PASS {len(manifest["frames"])} authored frame contracts and complete assets')
