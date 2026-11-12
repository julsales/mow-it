#!/usr/bin/env python3
"""Assemble generated raster art and editable labels in a local OpenPencil doc.

Commands are bounded and resumable: prepare, import BOARD, fill BOARD --limit 8,
export BOARD, save. The local MCP token is read internally, never logged/saved.
This creates design mockups, not evidence of Roblox Play behavior.
"""
import argparse
import base64
from html import escape
import json
import os
from pathlib import Path
import urllib.request
import urllib.error
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/art/generated-v3'
STATE = Path('/tmp/mowit-pencil-assembly-v3.json')
INK, WHITE, TEAL = '#102D43', '#FFFFFF', '#073746'
SKINS = ROOT / 'assets/UI/generated-v3'

def rpc(command, args):
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'))
    discovery = runtime / 'openpencil/mcp.json'
    info = json.loads(discovery.read_text())
    request = urllib.request.Request(
        f"http://127.0.0.1:{info['httpPort']}/rpc",
        data=json.dumps({'command': command, 'args': args}).encode(),
        headers={'Authorization': 'Bearer ' + info['authToken'], 'Content-Type': 'application/json'},
        method='POST')
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            result = json.loads(response.read())
    except urllib.error.HTTPError as error:
        detail = json.loads(error.read()).get('error', 'Local RPC rejected request')
        raise RuntimeError(str(detail)) from None
    value = result.get('result', {})
    if not result.get('ok') or (isinstance(value, dict) and value.get('error')):
        raise RuntimeError(str(value.get('error', result.get('error', 'RPC failed'))))
    return value

def read_state():
    return json.loads(STATE.read_text())

def write_state(state):
    STATE.write_text(json.dumps(state, indent=2))

def tool(state, name, args):
    return rpc('tool', {'document_id': state['document'], 'page_id': state['page'], 'name': name, 'args': args})

class Board:
    def __init__(self, name, width, height, x, y):
        self.name, self.width, self.height, self.x, self.y = name, width, height, x, y
        self.parts, self.images, self.blends, self.surfaces = [], {}, [], {}
        self.sequence = 0
    def begin_surface(self, x, y, w, h, color, radius=14, stroke='none', weight=0):
        key = self.key('container')
        self.parts.append(f'<g id="{key}">')
        self.surfaces[key] = {'color':color,'radius':radius}
        self.rect(x,y,w,h,color,radius,stroke,weight)
    def end_surface(self):
        self.parts.append('</g>')
    def key(self, prefix):
        self.sequence += 1
        return f'{prefix}_{self.sequence}'
    def rect(self, x, y, w, h, color, radius=14, stroke='none', weight=0, opacity=1, key=None):
        key = key or self.key('surface')
        self.parts.append(f'<rect id="{key}" x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{color}" stroke="{stroke}" stroke-width="{weight}" opacity="{opacity}"/>')
        return key
    def text(self, value, x, y, size=20, color=WHITE, anchor='start', weight=800):
        self.parts.append(f'<text id="{escape(value, quote=True)}" x="{x}" y="{y}" font-family="Montserrat" font-weight="{weight}" font-size="{size}" fill="{color}" text-anchor="{anchor}">{escape(value)}</text>')
    def image(self, asset, x, y, w, h, mode='FIT', opacity=1):
        if asset == 'quest-available': mode = 'FILL'
        path = OUT/'background.png' if asset == 'background' else SKINS/(asset+'.png')
        key = self.rect(x, y, w, h, WHITE, 0, opacity=opacity, key=self.key('asset'))
        self.images[key] = {'path': str(path.relative_to(ROOT)), 'mode': mode}
        return path
    def skin(self, asset, x, y, w, h, tint=None, radius=14, mode='FILL'):
        path = self.image(asset, x, y, w, h, mode)
        if tint:
            with Image.open(path) as image:
                box = image.getchannel('A').point(lambda a: 255 if a > 170 else 0).getbbox()
                iw, ih = image.size
            scale = max(w/iw, h/ih) if mode == 'FILL' else min(w/iw, h/ih)
            left = x+(w-iw*scale)/2+box[0]*scale+3
            top = y+(h-ih*scale)/2+box[1]*scale+3
            right = x+(w-iw*scale)/2+box[2]*scale-3
            bottom = y+(h-ih*scale)/2+box[3]*scale-3
            left, top, right, bottom = max(x,left), max(y,top), min(x+w,right), min(y+h,bottom)
            key = self.rect(round(left,2), round(top,2), round(right-left,2), round(bottom-top,2), tint, radius, key=self.key('tint'))
            self.blends.append(key)
    def button(self, x, y, w, value, color='#A62BEE', height=44):
        self.begin_surface(x,y,w,height,color,12,'#1B2452',1.5)
        self.rect(x+4,y+3,w-8,6,'#FFFFFF',4,opacity=.28)
        foreground = WHITE if contrast(WHITE,color)>=4.5 else INK if contrast(INK,color)>=4.5 else '#071A28'
        self.text(value,x+w/2,y+height/2+6,16,foreground,anchor='middle')
        self.end_surface()
    def backdrop(self):
        self.image('background',0,0,self.width,self.height,'FILL')
    def navigation(self):
        for i,(label,asset,tint) in enumerate([('CREW','crew','#238DE8'),('SHOP','passes','#FFB721'),('QUESTS','quests','#9A4DE5'),('REWARDS','rewards','#DC46B6')]):
            x,y=20+(i%2)*112,222+(i//2)*112
            self.skin('button-base',x,y,108,108,tint,12,'FIT')
            self.image(asset,x+12,y+2,84,84)
            self.begin_surface(x+7,y+77,94,27,TEAL,8)
            self.text(label,x+54,y+96,15,anchor='middle')
            self.end_surface()
            if label=='QUESTS': self.image('quest-available',x+79,y-8,26,46)
        for i,(asset,color) in enumerate([('coin-single','#FFDE59'),('clover','#C3FF8C')]):
            y=465+i*75
            self.rect(26,y,222,62,TEAL,16,'#31D7EB',1.5)
            self.image(asset,14,y-8,78,78)
            self.text('0',100,y+43,34,color)
    def indicators(self):
        for i,(asset,value) in enumerate([('weather-clear','4:00'),('fuel','100%')]):
            y=24+i*70
            self.rect(1200,y,216,58,TEAL,15,'#22CDE8',1.5)
            self.image(asset,1202,y-3,64,64)
            self.text(value,1280,y+39,26)
    def tracker(self):
        x,y=1144,296
        self.rect(x,y,272,218,TEAL,16,'#73D852',2)
        self.begin_surface(x+3,y+3,266,55,'#285D24',13)
        self.text('Meet Farmer Joe',x+64,y+35,17)
        self.end_surface()
        self.image('quests',x+1,y-9,66,66)
        self.image('quest-available',x+239,y-12,30,52)
        self.text('Follow the trail to',x+20,y+96,17)
        self.text('your neighbor.',x+20,y+121,17)
        self.button(x+17,y+156,238,'SHOW ROUTE','#168CEB')
    def title(self, x, y, w, value, icon):
        self.begin_surface(x,y,w,68,'#07638F',13,'#35DDF4',1.5)
        self.text(value,x+93,y+47,34)
        self.button(x+w-53,y+11,42,'X','#B51F3D',44)
        self.end_surface()
        self.image(icon,x-6,y-11,90,90)
    def dump(self):
        text=f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{self.height}" viewBox="0 0 {self.width} {self.height}">'+''.join(self.parts)+'</svg>'
        return {'name':self.name,'svg':text,'x':self.x,'y':self.y,'images':self.images,'blends':self.blends,'surfaces':self.surfaces,'background':TEAL}

def contrast(foreground, background):
    def luminance(color):
        rgb=[int(color[i:i+2],16)/255 for i in (1,3,5)]
        linear=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb]
        return sum(c*w for c,w in zip(linear,[.2126,.7152,.0722]))
    values=sorted([luminance(foreground),luminance(background)])
    return (values[1]+.05)/(values[0]+.05)

def passes_window(b, x, y, width, full=False):
    """One catalog, shared between the HUD viewport and long scroll design."""
    height=1006 if full else 664
    if full:
        b.begin_surface(x,y,width,height,TEAL,20,'#20BCD8',2)
    else:
        # The original generated frame already supplies the textured body.
        b.parts.append('<g id="Passes-content">')
    b.title(x,y,width,'PASSES','passes')
    b.text('Make room for a bigger harvest.',x+18,y+96,17,weight=600)
    top=y+112
    gap=12; inset=22; cw=(width-2*inset-2*gap)/3
    ch=348 if full else 264
    offers=[('2x COINS','coin','#EFB52B',['Double your coins','from every sale.']),
            ('+2 CREW SLOTS','crew','#195C96',['Bring two extra','helpers along.']),
            ('AUTO-SELL','grass','#326A1D',['Sell automatically','as you mow.'])]
    for i,(title,icon,color,lines) in enumerate(offers):
        cx=x+inset+i*(cw+gap)
        foreground=INK if i==0 else WHITE
        b.begin_surface(cx,top,cw,ch,color,17,'#F5D66B' if i==0 else '#67B1D3' if i==1 else '#88BE4B',1.5)
        b.skin('offer-banner' if i==0 else 'banner-base',cx,top,cw,ch,None if i==0 else color,0)
        b.image('rays',cx+12,top+40,cw-24,ch-88,opacity=.24 if i==0 else .12)
        b.text(title,cx+cw/2,top+35,21 if full else 19,foreground,anchor='middle')
        art=168 if full else 110
        b.image(icon,cx+(cw-art)/2,top+43,art,art)
        for j,line in enumerate(lines):
            b.text(line,cx+cw/2,top+art+66+j*21,15,foreground,anchor='middle',weight=700)
        b.button(cx+15,top+ch-53,cw-30,'COMING SOON','#9822D5',40)
        b.end_surface()
    lower=top+ch+gap; lw=(width-2*inset-gap)/2; lh=330 if full else 208
    for i,(title,icon,color) in enumerate([('INFINITE FUEL','fuel','#9E3948'),('MORE TO GROW','passes','#174C60')]):
        cx=x+inset+i*(lw+gap)
        b.begin_surface(cx,lower,lw,lh,color,17,'#DA8591' if i==0 else '#387D91',1.5)
        b.skin('banner-base',cx,lower,lw,lh,color,0)
        b.image('rays',cx+7,lower+7,lw-14,lh-14,opacity=.12)
        b.text(title,cx+lw/2,lower+35,22,anchor='middle')
        art=148 if full else 112
        b.image(icon,cx+10,lower+49,art,art)
        dx=cx+art+24
        lines=['Keep motorized','tools running.'] if i==0 else ['New passes','coming later.']
        for j,line in enumerate(lines):b.text(line,dx,lower+86+j*23,15,weight=700)
        if i==0:b.button(cx+lw-202,lower+lh-53,186,'COMING SOON','#9822D5',40)
        else:
            b.begin_surface(cx+lw-202,lower+lh-53,186,40,'#245768',12)
            b.text('STAY TUNED',cx+lw-109,lower+lh-27,15,'#C2E2EB',anchor='middle')
            b.end_surface()
        b.end_surface()
    if full:
        b.text('Permanent upgrades. One purchase per pass.',x+24,lower+lh+50,17,weight=700)
        b.text('Equipment is sold at the world stalls.',x+24,lower+lh+82,16,weight=600)
    else:b.text('Passes will be available soon.',x+width/2,y+height-26,15,anchor='middle',weight=600)
    b.end_surface()

def make_boards():
    boards=[]
    b=Board('01 HUD and passes',1440,900,0,0);b.backdrop();b.navigation();b.indicators();b.tracker()
    b.image('window-frame',286,78,860,800)
    passes_window(b,368,134,696)
    b.rect(20,18,433,30,'#102D43',8,opacity=.8);b.text('DESIGN PREVIEW / SAMPLE VALUES',34,39,13)
    boards.append(b.dump())

    b=Board('02 Passes full scroll content',860,1150,1520,0)
    b.rect(0,0,860,1150,TEAL,20)
    passes_window(b,18,64,824,True)
    b.text('FULL SCROLL CONTENT / DESIGN PREVIEW',430,1118,14,'#C2E2EB',anchor='middle')
    boards.append(b.dump())

    b=Board('03 Daily rewards',1440,900,0,990);b.backdrop();b.navigation();b.indicators()
    b.image('window-frame',286,78,860,800)
    b.parts.append('<g id="Modal-content" transform="translate(44.4537815 0) scale(0.9579831933 1)">')
    b.title(344,134,714,'DAILY REWARDS','rewards')
    b.image('rewards',350,207,148,132);b.text('Your daily harvest',510,249,29)
    b.text('A little thank-you for tending your lawn.',510,282,16)
    for i,amount in enumerate([50,100,200,350,500,750,1000]):
        x=348+i*100;b.begin_surface(x,350,92,142,'#366D20' if i==0 else '#19576A',13,'#C5FF80' if i==0 else '#397E92',1.5)
        b.text('DAY '+str(i+1),x+46,378,13,anchor='middle');b.image('coin-single',x+17,388,58,58);b.text(str(amount),x+46,476,17,anchor='middle')
        b.end_surface()
    b.image('coin-single',354,515,46,46);b.text('50',406,548,24,'#FFDF60')
    b.image('clover',476,515,46,46);b.text('5',530,548,24,'#C8FF92')
    b.button(650,518,384,"COLLECT TODAY'S GIFT",'#67AE22',48)
    b.rect(352,602,696,148,'#0F495B',14,'#2C8097',1.5);b.image('grass',360,614,116,116)
    b.text("Your crew's harvest",488,641,23);b.text('No offline harvest waiting.',488,673,16)
    b.button(488,692,526,'COLLECT GRASS','#28687A',40)
    b.parts.append('</g>')
    boards.append(b.dump())

    b=Board('04 Quest discovery states',1240,680,1520,1250)
    b.rect(0,0,1240,680,'#0A3042',16);b.text('QUESTS / DISCOVER, TALK, MOW',32,48,28)
    states=[('Meet Farmer Joe','Follow the trail to your neighbor.','SHOW ROUTE'),('Farmer Joe',"Neighbor's Yard",'ACCEPT JOB'),("Neighbor's Yard",'Mow 200 grass in Starter Lawn.','IN PROGRESS')]
    for i,(title,detail,action) in enumerate(states):
        x=28+i*408;b.rect(x,92,384,422,TEAL,16,'#2FB6D0',1.5)
        b.image('quests',x+8,98,76,76);b.text(title,x+92,145,21)
        if i<2:b.image('quest-available',x+329,92,38,62)
        b.text(detail,x+22,207,16)
        if i==0:
            b.text('Talk to your neighbor to',x+22,246,16);b.text('discover their local job.',x+22,271,16)
        elif i==1:
            b.text('Mow 200 grass in Starter Lawn.',x+22,246,16);b.text('5 minutes / party job',x+22,278,16)
            b.image('coin-single',x+20,302,50,50);b.text('800',x+80,338,23,'#FFDA58')
            b.image('clover',x+194,302,50,50);b.text('10',x+254,338,23,'#C7FF90')
        else:
            b.rect(x+22,246,340,18,'#1D5460',9);b.rect(x+22,246,102,18,'#8DD737',9)
            b.text('60 / 200 grass',x+22,298,19);b.text('4:12 left',x+22,333,17)
        b.button(x+22,440,340,action,'#1F94E9' if i<2 else '#366D20',48)
    b.image('quest-available',40,555,40,70);b.text('Red ! = a quest is available',104,593,23)
    b.text('Discovery and acceptance remain server-owned.',104,627,16,'#A6CBD7')
    boards.append(b.dump())

    b=Board('05 Generated asset library',1220,1120,2860,0)
    b.rect(0,0,1220,1120,'#103A4B',16);b.text('GENERATED ART / SEPARATE LAYERS',32,48,28)
    names=sorted(p.stem for p in SKINS.glob('*.png'))
    for i,name in enumerate(names):
        x=24+(i%5)*240;y=85+(i//5)*245
        b.image(name,x+14,y,188,188);b.text(name,x+108,y+216,15,anchor='middle')
    b.text('Native image_gen / transparent PNGs / no baked UI text',32,1090,17,'#A6CBD7')
    boards.append(b.dump())
    return boards

def flatten(value):
    if isinstance(value,dict):
        if 'id' in value and 'name' in value:yield value
        for child in value.values():yield from flatten(child)
    elif isinstance(value,list):
        for child in value:yield from flatten(child)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['prepare','import','rebuild','fill','export','lint','save']);parser.add_argument('--board',type=int,default=1);parser.add_argument('--limit',type=int,default=8)
    args=parser.parse_args();OUT.mkdir(exist_ok=True)
    if args.action=='prepare':
        boards=make_boards();(OUT/'assembly.json').write_text(json.dumps(boards,indent=2))
        print('Prepared',len(boards),'editable boards');return
    state=read_state();definitions=json.loads((OUT/'assembly.json').read_text());definition=definitions[args.board-1];key=str(args.board)
    if args.action=='lint':
        failed=False
        for target,scope in [('contrast-audit.json',{'ids':[board['id'] for board in state['boards'].values()]}),
                             ('contrast-page-audit.json',{})]:
            result=tool(state,'lint',dict(scope,rules=['color-contrast'],limit=200))
            (OUT/target).write_text(json.dumps(result,indent=2))
            print(target,json.dumps(result))
            failed=failed or bool(result['errors'] or result['warnings'])
        if failed:raise SystemExit(1)
        return
    if args.action in ('import','rebuild'):
        if args.action=='rebuild' and key in state['boards']:
            old=state['boards'].pop(key)
            tool(state,'set_visible',{'id':old['id'],'value':False})
            if state.get('archive_page'):
                tool(state,'reparent_node',{'id':old['id'],'parent_id':state['archive_page']})
            state.setdefault('previous_boards',[]).append(old['id']);write_state(state)
        if key in state['boards']:print('Already imported:',key);return
        result=tool(state,'import_svg',{'svg':definition['svg'],'name':definition['name'],'x':definition['x'],'y':definition['y']})
        # SVG groups carry visual sibling surfaces but no semantic background.
        # Native frames give text its actual background for the editor's lint.
        tool(state,'lint_fix',{'ids':[result['id']],'rules':['no-groups'],'suggestions':True})
        tree=tool(state,'get_page_tree',{'root_id':result['id'],'depth':12})
        nodes={node['name']:node['id'] for node in flatten(tree)}
        tool(state,'set_fill',{'id':result['id'],'color':definition['background']})
        for name,surface in definition['surfaces'].items():
            tool(state,'set_fill',{'id':nodes[name],'color':surface['color']})
        tool(state,'batch_update',{'operations':json.dumps([
            {'id':nodes[name],'props':{'corner_radius':surface['radius']}}
            for name,surface in definition['surfaces'].items()])})
        missing=set(definition['images'])-set(nodes)
        if missing:raise RuntimeError('Missing imported placeholders: '+str(missing))
        state['boards'][key]={'id':result['id'],'nodes':nodes,'filled':[],'blended':[]};write_state(state)
        print('Imported',definition['name'],'with',len(definition['images']),'raster slots');return
    if args.action=='fill':
        board=state['boards'][key];count=0
        for name,spec in definition['images'].items():
            if name in board['filled']:continue
            encoded=base64.b64encode((ROOT/spec['path']).read_bytes()).decode()
            tool(state,'set_image_fill',{'id':board['nodes'][name],'image_data':encoded,'scale_mode':spec['mode']})
            board['filled'].append(name);write_state(state);count+=1
            print('Filled',key,name,Path(spec['path']).name,flush=True)
            if count>=args.limit:break
        if len(board['filled'])==len(definition['images']):
            for name in definition['blends']:
                if name not in board['blended']:
                    tool(state,'set_blend',{'id':board['nodes'][name],'mode':'MULTIPLY'})
                    board['blended'].append(name);write_state(state)
        print('Progress',key,len(board['filled']),'/',len(definition['images']));return
    if args.action=='export':
        board=state['boards'][key]
        if len(board['filled'])!=len(definition['images']):raise RuntimeError('Board still has unfilled placeholders')
        result=tool(state,'export_image',{'ids':[board['id']],'format':'PNG','scale':1})
        target=OUT/f'board-{key}.png';target.write_bytes(base64.b64decode(result['base64']))
        print('Exported',target.name,result.get('width'),result.get('height'));return
    if args.action=='save':
        tool(state,'switch_page',{'page':state['page']})
        tool(state,'viewport_zoom_to_fit',{'ids':[state['boards']['1']['id']]})
        rpc('save_file',{'document_id':state['document'],'page_id':state['page'],'path':str(OUT/'mow-it-ui-v3.fig')})
        (OUT/'openpencil-nodes.json').write_text(json.dumps(state,indent=2))
        print('Saved mow-it-ui-v3.fig and focused the HUD board')

if __name__=='__main__':main()
