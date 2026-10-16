"""Authored road plan; an explanatory SVG, not a Roblox rendering."""
from pathlib import Path
from math import sin,pi
import re
import xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'roblox/ServerScriptService/World.lua').read_text()
amplitude,stride=map(float,re.search(r'local TRAIL_AMPLITUDE, TRAIL_STRIDE = ([\d.]+), ([\d.]+)',source).groups())
width=float(re.search(r'local ROAD_HALF_WIDTH = ([\d.]+)',source).group(1))
def section(cp,route):
    center=sin(cp*pi/12)*amplitude;half=width
    for first,last,side in [(12,18,-1),(30,36,1)]:
        if first<=cp<=last and route!='shared':
            wave=sin(pi*(cp-first)/(last-first))
            center+=(side if route=='main' else -side)*(16+16*wave)
            half=16-(5*wave if route=='shortcut' else 0)
    return center,half

def xy(cp,x):return 65+cp*22,300-x*1.6
colors=['#91b56f','#b08b5b','#8996ac','#bdb29b']
names=['STARTING DASH','MOVING BRIDGES','HAZARD ZONE','FINAL SPRINT']
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="620" viewBox="0 0 1200 620">','<rect width="1200" height="620" rx="24" fill="#111c31"/>','<g font-family="Arial,sans-serif" fill="#f4f7ff">','<text x="30" y="42" font-size="26" font-weight="bold">RIFTBOUND / SHARED FANTASY SKYWAY</text>','<text x="30" y="72" font-size="15">64-stud road • split and rejoin routes • 20-position grid • 48 gates • 120s deadline</text>','<text x="30" y="96" font-size="13" fill="#b4c4df">Authored layout plan, not a Studio screenshot. Gold openings are intentional shortcut jumps.</text>']
for cp in range(1,49):
    fork=12<cp<=18 or 30<cp<=36
    for route in (['main','shortcut'] if fork else ['shared']):
        spans=[(cp-1,cp-.55),(cp-.425,cp)] if route=='shortcut' and cp in [15,33] else [(cp-1,cp)]
        for lo,hi in spans:
            a,wa=section(lo,route);b,wb=section(hi,route)
            points=' '.join(f'{x:.2f},{y:.2f}' for x,y in [xy(lo,a-wa),xy(lo,a+wa),xy(hi,b+wb),xy(hi,b-wb)])
            color='#daab54' if route=='shortcut' else colors[(cp-1)//12]
            svg.append(f'<polygon points="{points}" fill="{color}" stroke="{color}" stroke-width=".4"/>')
for cp,label in [(12,'FORK / 2 ROUTES'),(18,'REJOIN'),(30,'FORK / 2 ROUTES'),(36,'REJOIN')]:
    x,y=xy(cp,section(cp,'shared')[0]);svg.append(f'<text x="{x-25:.1f}" y="{y+76:.1f}" font-size="10" fill="#ffd080">{label}</text>')
for i,name in enumerate(names):
    x=35+i*290
    svg.extend([f'<rect x="{x}" y="525" width="275" height="65" rx="12" fill="#203047"/>',f'<text x="{x+12}" y="553" font-size="15" fill="{colors[i]}">{i+1}. {name}</text>',f'<text x="{x+12}" y="574" font-size="12">Shared gates {i*12+1}–{i*12+12}</text>'])
for cp,label in [(0,'WIDE START'),(48,'CROWN FINISH')]:
    x,y=xy(cp,0);svg.append(f'<text x="{x-30:.1f}" y="{y+95:.1f}" font-size="12" fill="#ffd080">{label}</text>')
svg.extend(['</g></svg>'])
p=ROOT/'docs/SKYBRIDGE_ROUTE.svg';p.write_text('\n'.join(svg)+'\n');ET.parse(p)
print('Built docs/SKYBRIDGE_ROUTE.svg (shared road plan)')
