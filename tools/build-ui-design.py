#!/usr/bin/env python3
"""Editable OpenPencil source boards and reusable, text-free HUD chrome.

Import each SVG with OpenPencil import_svg, export its PNG there, then save the
document. No screenshot slicing: every icon and label remains a separate layer.
"""
from pathlib import Path
from html import escape
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/art/openpencil'
OUT.mkdir(parents=True, exist_ok=True)
INK, CREAM, GOLD, GREEN, BLUE, CORAL = '#2A2018', '#FBF3DF', '#F2C75C', '#7FA65A', '#63A9D1', '#DF865E'

def rect(x, y, w, h, fill, radius=16, stroke=INK, weight=4, name='surface'):
    return f'<rect id="{name}" x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="{weight}"/>'

def text(value, x, y, size=24, fill=INK, anchor='start', outline=False):
    stroke = f' stroke="{INK}" stroke-width="3" paint-order="stroke"' if outline else ''
    return f'<text id="{escape(value)}" x="{x}" y="{y}" font-family="Montserrat" font-weight="800" font-size="{size}" fill="{fill}" text-anchor="{anchor}"{stroke}>{escape(value)}</text>'

def icon(name, x, y, size):
    source = (ROOT / f'assets/UI/source/{name}.svg').read_text()
    body = source[source.index('>')+1:source.rindex('</svg>')]
    return f'<g id="{name}-icon" transform="translate({x} {y}) scale({size / 128})">{body}</g>'

def svg(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'

def window(x, y, w, h, title, symbol):
    return (rect(x, y+6, w, h, '#61492E', 24) + rect(x, y, w, h, CREAM, 24)
            + rect(x+12, y+12, w-24, 76, GOLD, 16)
            + icon(symbol, x+23, y+16, 68) + text(title, x+105, y+62, 36)
            + rect(x+w-65, y+24, 44, 44, CORAL, 12)
            + text('X', x+w-43, y+56, 28, CREAM, 'middle', True))

def navigation(x, y):
    result = ''
    for i, (label, symbol, color) in enumerate([('CREW', 'crew', GREEN), ('SHOP', 'pack', GOLD), ('QUESTS', 'quests', BLUE), ('REWARDS', 'rewards', CORAL)]):
        xx, yy = x+(i%2)*104, y+(i//2)*104
        result += rect(xx, yy+4, 92, 92, INK, 18) + rect(xx, yy, 92, 92, color, 18)
        result += f'<path d="M{xx+10} {yy+18} Q{xx+46} {yy+3} {xx+82} {yy+18}" fill="none" stroke="#FFFFFF" stroke-opacity=".35" stroke-width="5" stroke-linecap="round"/>'
        result += icon(symbol, xx+16, yy+3, 60) + text(label, xx+46, yy+82, 17, CREAM, 'middle', True)
    result += icon('coin', x-2, y+213, 54) + text('0', x+60, y+251, 35, GOLD, outline=True)
    result += icon('clover', x-2, y+266, 54) + text('0', x+60, y+304, 35, '#B7E08C', outline=True)
    return result

def offer(x, y, w, name, detail, symbol, color, featured=False):
    h = 180 if featured else 146
    result = rect(x, y, w, h, color, 18)
    result += f'<path d="M{x+8} {y+26} Q{x+w*.55} {y+6} {x+w-8} {y+26}" fill="none" stroke="#FFFFFF" stroke-opacity=".25" stroke-width="10"/>'
    result += icon(symbol, x+10, y+12, h-26)
    inset = 180 if featured else 146
    result += text(name, x+inset, y+46, 32 if featured else 26, CREAM, outline=True)
    result += text(detail, x+inset, y+77, 15)
    result += rect(x+w-204, y+h-58, 188, 42, CREAM, 12, INK, 3)
    result += text('COMING SOON', x+w-110, y+h-30, 16, INK, 'middle')
    return result

board = rect(0, 0, 1440, 900, '#8FA66E', 0, 'none', 0)
board += text('MOW IT! / HUD + PASSES', 28, 45, 24, CREAM)
board += text('Editable concept · sample balances shown at 0', 28, 75, 14, CREAM)
board += navigation(28, 240)
board += icon('clear', 1280, 108, 48) + text('4:00', 1335, 141, 25, CREAM, outline=True)
board += icon('fuel', 1280, 162, 48) + text('100%', 1335, 195, 25, CREAM, outline=True)
board += window(310, 106, 800, 710, 'PASSES', 'pack')
board += text('Permanent upgrades for your mowing company', 340, 226, 18)
board += offer(334, 248, 752, '2x COINS', 'Make every harvest go further.', 'coin', GOLD, True)
board += offer(334, 444, 752, '+2 CREW SLOTS', 'Bring two more helpers along.', 'crew', BLUE)
board += offer(334, 606, 752, 'AUTO-SELL', 'Keep mowing when your storage fills.', 'grass', GREEN)
board += rect(1094, 244, 5, 532, '#D9C79A', 2, 'none', 0)
board += rect(1094, 244, 5, 208, '#A9744F', 2, 'none', 0)
board += text('Equipment is sold at the stalls in your world.', 710, 852, 17, CREAM, 'middle')
(OUT/'hud-passes.svg').write_text(svg(1440, 900, board))

# Distinct quest states: contact hint, discovered offer, active progress.
board = rect(0, 0, 1180, 700, '#E4D6AE', 0, 'none', 0)
board += text('LOCAL JOBS / DISCOVER, TALK, MOW', 32, 48, 28)
for i, (heading, sub, action) in enumerate([
    ('Meet Farmer Joe', 'A neighbor needs help in Starter Lawn.', 'SHOW ROUTE TO NPC'),
    ('Farmer Joe', 'Talk nearby to discover and accept a job.', 'TALK TO FARMER JOE'),
    ('A fresh start', 'Mow grass in Starter Lawn.', 'JOB IN PROGRESS'),
]):
    x, y = 32+i*382, 96
    board += rect(x, y, 352, 260, CREAM, 18)
    board += icon('quests', x+12, y+12, 52) + text(heading, x+76, y+47, 21)
    board += text(sub, x+16, y+104, 14)
    if i == 2:
        board += rect(x+16, y+132, 320, 16, '#D9C79A', 8, INK, 2)
        board += rect(x+16, y+132, 120, 16, GREEN, 8, INK, 0)
        board += text('Grass progress + remaining time', x+16, y+182, 14)
    else:
        board += text('Follow the world trail to your neighbor.', x+16, y+150, 14)
    board += rect(x+16, y+198, 320, 44, GOLD if i<2 else '#B7E08C', 12, INK, 2)
    board += text(action, x+176, y+226, 16, INK, 'middle')
board += text('Only contacts on unlocked land are shown. Rewards unlock after discovery.', 32, 410, 18)
board += icon('rewards', 36, 464, 112) + text('Your daily harvest', 170, 499, 28)
board += text('Seven days, real rewards, one clear claim action.', 170, 536, 18)
board += rect(170, 564, 360, 48, GREEN, 12) + text("COLLECT TODAY'S GIFT", 350, 595, 19, CREAM, 'middle', True)
(OUT/'quests-rewards.svg').write_text(svg(1180, 700, board))

components = {'panel-frame': rect(4, 4, 120, 120, CREAM, 20, INK, 4)}
for name, color in [('nav-crew', GREEN), ('nav-shop', GOLD), ('nav-quests', BLUE), ('nav-rewards', CORAL)]:
    components[name] = rect(5, 9, 118, 114, '#61492E', 20, INK, 3) + rect(5, 4, 118, 114, color, 20, INK, 4)
    components[name] += '<path d="M17 24 Q64 8 111 24" fill="none" stroke="#FFFFFF" stroke-opacity=".4" stroke-width="5" stroke-linecap="round"/>'
for name, body in components.items():
    (OUT/f'{name}.svg').write_text(svg(128, 128, body))

manifest = []
for i, name in enumerate(['hud-passes', 'quests-rewards', *components]):
    payload = {'command':'tool','args':{'document_id':'tab-1','page_id':'0:3','name':'import_svg','args':{'name':name,'x':i*1500 if i<2 else (i-2)*180,'y':0 if i<2 else 1100,'svg':(OUT/f'{name}.svg').read_text()}}}
    target = Path(f'/tmp/mowit-pencil-{name}.json')
    target.write_text(json.dumps(payload))
    manifest.append({'name':name,'payload':str(target)})
Path('/tmp/mowit-pencil-imports.json').write_text(json.dumps(manifest))
print('Created two editable boards and five text-free chrome components.')
