#!/usr/bin/env python3
"""Project utility frames from original Island polygons and shared tokens.

Independent of the legacy generator: rebuilding these assets must not replace
pre-existing changes in the login, lock or Quickshell projections.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GTK_ASSETS = ROOT / 'appearance/file-manager/gtk3/SenomyOS/gtk-3.0/assets'


def substitute(template, values):
    for key, value in values.items():
        template = template.replace('@' + key + '@', str(value))
    return template


def projections():
    tokens = json.loads((ROOT / 'appearance/tokens.json').read_text())
    template = (ROOT / 'appearance/shared/utility-frame.svg.in').read_text()
    colors = tokens['frame_system']['colors']
    common = dict(IVORY=colors['ivory'], SILVER=colors['cold_silver'],
                  STEEL=colors['steel'], VIOLET=colors['violet_light'])
    # Retain the installed Rofi background's .86 opacity. Dimensions remain
    # placeholders, replaced with bounded numeric values by the launch wrapper.
    rofi = substitute(template, dict(common, FILL=tokens['colors']['background'], ALPHA=.86))
    full = substitute(template, dict(
        common, WIDTH=96, HEIGHT=96, RIGHT=72, BOTTOM=72, CUTRIGHT=84,
        CUTBOTTOM=84, RIGHTRULE=93.92, BOTTOMRULE=93.88,
        FILL=tokens['colors']['surface'],
        ALPHA=tokens['frame_system']['glass']['raised_alpha']))
    files = {ROOT / 'appearance/launcher/rofi/assets/utility-frame.svg.in': rofi}
    # GTK SSD windows paint background layers, rather than a custom widget
    # tree. Fixed cropped corners meet separately sized plain rules/fill planes.
    for corner, x, y in [('tl', 0, 0), ('tr', 72, 0), ('bl', 0, 72), ('br', 72, 72)]:
        files[GTK_ASSETS / f'utility-corner-{corner}.svg'] = full.replace(
            'width="96" height="96" viewBox="0 0 96 96"',
            f'width="24" height="24" viewBox="{x} {y} 24 24"', 1)
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for path, body in projections().items():
        if args.check:
            if not path.exists() or path.read_text() != body:
                raise SystemExit(f'Stale utility asset: {path}')
        else:
            path.write_text(body)
    print('Utility appearance projections are current.')


if __name__ == '__main__':
    main()
