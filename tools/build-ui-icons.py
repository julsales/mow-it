#!/usr/bin/env python3
"""Original Mow It! icon geometry; SVG masters and antialiased RGBA exports.

Run with CairoSVG and Pillow installed. No screenshots, upscaling or web art.
"""
from pathlib import Path
import math
import cairosvg
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/UI'
SOURCE = OUT / 'source'
SOURCE.mkdir(parents=True, exist_ok=True)
INK, CREAM, GOLD, GREEN = '#2A2018', '#FBF3DF', '#F2C75C', '#7FA65A'


def path(d, fill, width=5, stroke=INK):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>'


def rect(x, y, w, h, fill, r=4, width=5):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{INK}" stroke-width="{width}"/>'


def circle(x, y, r, fill, width=5):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{INK}" stroke-width="{width}"/>'


def leaf(x=64, y=64, scale=1):
    return f'<g transform="translate({x} {y}) scale({scale})">' + path('M0 14 Q-29 12 -27 -12 Q-3 -17 0 4 Q4 -19 27 -21 Q30 8 0 14Z', GREEN, 4) + path('M0 22 L0 9 M-14 -2 L0 9 L15 -7', 'none', 3) + '</g>'


def cloud(fill=CREAM):
    return path('M30 82 C9 82 8 51 28 48 C29 19 66 17 75 40 C99 26 121 50 111 68 C110 80 100 82 90 82Z', fill)


def sun(golden=False):
    body = ''
    for angle in range(0, 360, 45):
        a = math.radians(angle)
        x, y = 64 + 45*math.cos(a), 64 + 45*math.sin(a)
        xx, yy = 64 + 53*math.cos(a), 64 + 53*math.sin(a)
        body += path(f'M{x} {y} L{xx} {yy}', 'none', 7)
    body += circle(64, 64, 31, GOLD)
    body += path('M46 56 Q49 43 63 42', 'none', 5, '#FFF3B6')
    if golden:
        body += path('M93 77 L97 90 L110 94 L97 98 L93 111 L89 98 L76 94 L89 90Z', '#FFF2A8', 4)
    return body


icons = {}
icons['shop'] = rect(28, 52, 72, 58, '#A9744F') + rect(38, 53, 52, 37, '#523C29', 0)
icons['shop'] += leaf(61, 80, .54) + circle(78, 82, 9, GOLD, 3)
icons['shop'] += rect(22, 91, 84, 15, GOLD) + path('M15 48 L29 23 H99 L113 48 Q112 64 97 61 Q83 68 76 59 Q63 68 51 59 Q38 68 28 60 Q11 65 15 48Z', '#C7623F')
icons['shop'] += path('M40 25 L34 49 Q34 62 47 61 Q59 62 59 49 L61 25 M82 25 L90 49 Q94 62 80 61 Q68 64 68 49 L67 25', CREAM, 0)
icons['shop'] += rect(43, 12, 42, 25, GOLD, 9, 4) + leaf(64, 25, .30)
icons['crew'] = path('M38 74 C41 60 48 48 64 48 C80 48 87 60 90 74 C113 98 93 117 74 106 Q64 100 54 106 C34 117 14 98 38 74Z', '#AEDA75')
for x,y,rx,ry,rot in [(25,49,12,17,-26),(49,28,12,17,-12),(79,28,12,17,12),(103,49,12,17,26)]:
    icons['crew'] += f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" transform="rotate({rot} {x} {y})" fill="{GREEN}" stroke="{INK}" stroke-width="5"/>'
icons['crew'] += path('M48 83 Q51 71 58 69', 'none', 5, '#E2F7BD')
icons['quests'] = rect(28, 17, 76, 96, '#8FBBD0', 10) + path('M28 34 H18 Q12 13 30 13 H88 Q73 15 77 34Z', '#BDE1E9', 4)
icons['quests'] += path('M45 52 H86 M45 69 H83 M45 86 H71', 'none', 6)
icons['quests'] += circle(26, 31, 17, '#E08054', 4) + path('M26 21 V32 M26 40 V41', 'none', 4, CREAM)
icons['rewards'] = rect(23, 56, 82, 56, '#C7623F', 7) + rect(18, 43, 92, 22, '#E48856', 5)
icons['rewards'] += path('M62 44 C28 46 23 12 43 15 Q61 17 64 43 C64 15 87 9 94 24 Q101 44 67 44Z', GOLD, 5)
icons['rewards'] += rect(55, 45, 18, 66, GOLD, 1, 4) + path('M34 74 V99', 'none', 4, '#EF9B69')
icons['coin'] = path('M17 52 V82 C17 109 111 109 111 82 V52Z', '#C99139') + '<ellipse cx="64" cy="53" rx="47" ry="28" fill="#F2C75C" stroke="#2A2018" stroke-width="5"/>'
icons['coin'] += path('M31 79 V88 M48 85 V94 M68 86 V96 M88 82 V92', 'none', 4) + leaf(64, 52, .65)
icons['coin'] += path('M30 46 Q39 32 60 32', 'none', 4, '#FFF3BB')
icons['clover'] = path('M62 70 Q60 98 82 111', 'none', 8)
icons['clover'] += path('M62 61 C16 72 6 35 25 23 C43 9 62 28 63 41 C67 6 106 13 106 35 C105 54 83 62 73 62 C110 65 112 100 91 106 C71 112 62 89 62 76 C50 113 17 104 18 83 C17 68 40 58 62 61Z', '#9ACB65')
icons['clover'] += path('M40 37 L62 61 L86 36 M39 85 L62 61 L87 86', 'none', 3, '#4C8530')
icons['grass'] = leaf(64, 68, 1.65)
icons['fuel'] = rect(25, 39, 75, 71, '#C7623F', 10) + path('M39 39 V21 H74 V39 M45 22 V32 H65 V22', '#E48856', 5)
icons['fuel'] += path('M77 39 L88 18 L105 26 L94 48', GOLD, 5) + path('M45 59 L80 91 M80 59 L45 91', 'none', 6, '#8C432E')
icons['fuel'] += path('M61 53 C59 65 47 72 47 81 A15 15 0 0 0 77 81 C77 72 65 63 61 53Z', GOLD, 4)
icons['pack'] = path('M19 49 L35 24 H93 L110 49 V108 H19Z', '#C99139') + rect(16, 48, 97, 26, GOLD, 5)
icons['pack'] += path('M44 25 L36 49 V108 M83 25 L92 49 V108', 'none', 8) + rect(54, 64, 22, 24, GOLD, 4, 4) + path('M65 72 V80', 'none', 4)
icons['clear'] = sun()
icons['golden_sun'] = sun(True)
icons['rain'] = cloud('#9CCADB') + path('M34 96 L28 108 M62 96 L56 108 M90 96 L84 108', 'none', 7, '#2E7798')
icons['moon_night'] = path('M87 17 C35 -2 4 59 39 95 C64 122 105 105 114 77 C78 91 51 55 87 17Z', '#B9B8E3')
icons['moon_night'] += path('M93 22 L97 35 L110 39 L97 43 L93 56 L89 43 L76 39 L89 35Z', GOLD, 3) + circle(34, 69, 5, '#9293C5', 0)
icons['storm'] = cloud('#818CA6') + path('M63 63 H86 L71 86 H86 L52 118 L60 92 H45Z', GOLD, 4)

for name, body in icons.items():
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">{body}</svg>'
    (SOURCE / f'{name}.svg').write_text(svg)
    cairosvg.svg2png(bytestring=svg.encode(), write_to=str(OUT / f'{name}.png'), output_width=1024, output_height=1024)

sheet = Image.new('RGB', (1000, 4*182), '#f5e8cd')
draw = ImageDraw.Draw(sheet)
for i, name in enumerate(icons):
    x, y = (i % 4)*250, (i//4)*182
    im = Image.open(OUT / f'{name}.png')
    for size, dx in [(112, 8), (48, 132), (24, 195)]:
        thumb = im.resize((size, size), Image.Resampling.LANCZOS)
        sheet.paste(thumb, (x+dx, y+18+(112-size)//2), thumb)
    draw.text((x+12, y+142), name, fill=INK)
sheet.save(ROOT / 'docs/art/icons-v2-preview.png')
print(f'Rendered {len(icons)} original icons at 1024px; preview includes 112/48/24px.')
