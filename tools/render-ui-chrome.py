#!/usr/bin/env python3
"""Rasterize SVG components exported from OpenPencil, preserving alpha.

The editor's 0.16.0 exporter inserts an opaque root-frame rect even for a
transparent fill. Remove only that full-canvas root rect, never colored art.
Requires CairoSVG and Pillow. Run after exporting .openpencil.svg components.
"""
from pathlib import Path
import xml.etree.ElementTree as ET
import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/art/openpencil'
for path in sorted(SOURCE.glob('*.openpencil.svg')):
    node = ET.fromstring(path.read_text())
    removed = 0
    for group in list(node):
        if group.tag.endswith('g'):
            for child in list(group):
                if child.tag.endswith('rect') and child.get('width') == '128' and child.get('height') == '128':
                    group.remove(child)
                    removed += 1
    assert removed == 1, f'{path}: expected exactly one exporter background'
    target = ROOT / 'assets/UI' / (path.name.removesuffix('.openpencil.svg') + '.png')
    cairosvg.svg2png(bytestring=ET.tostring(node), write_to=str(target), output_width=512, output_height=512)
    with Image.open(target) as image:
        assert image.mode == 'RGBA' and image.getextrema()[3][0] == 0
    print(target.name, '512px RGBA; transparent exterior')
