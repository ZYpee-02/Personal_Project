"""Draw the authored route as an SVG plan, not a Roblox gameplay screenshot."""
from pathlib import Path
from math import sin, cos, pi, atan2, degrees, hypot
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "roblox/ServerScriptService/World.lua").read_text()
amplitude, stride = map(float, re.search(r"local TRAIL_AMPLITUDE, TRAIL_STRIDE = ([\d.]+), ([\d.]+)", source).groups())
palette = ["#6affd5", "#53aaff", "#ff8971", "#ad82ff"]
names = ["STARTING DASH", "MOVING BRIDGES", "HAZARD ZONE", "FINAL SPRINT"]
details = ["Curved stepping stones / raised landings", "Narrow moving spans / hurdle rows", "Sweeping gates / timed crossings", "Last bends / crown finish arch"]
def point(cp, lane=3):
    return 70 + cp * stride * .92, 226 - (sin(cp*pi/12)*amplitude + (lane-3)*8)*1.1

svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="480" viewBox="0 0 1200 480">',
       '<rect width="1200" height="480" rx="24" fill="#111c31"/>',
       '<g font-family="Arial,sans-serif" fill="#f4f7ff">',
       '<text x="34" y="45" font-size="26" font-weight="bold">SKYBRIDGE / WINDING SKY TRAIL</text>',
       '<text x="34" y="73" font-size="15" fill="#b4c4df">Route plan • 48 gates • 5 physical racers • 120-second deadline • not a Studio screenshot</text>']
for section, color in enumerate(palette):
    x = 54 + section * 12 * stride * .92
    svg.append(f'<rect x="{x:.1f}" y="101" width="{12*stride*.92-5:.1f}" height="239" rx="12" fill="{color}" opacity=".055"/>')
    svg.append(f'<text x="{x+10:.1f}" y="123" font-size="12" fill="{color}" font-weight="bold">{section+1} / {names[section]}</text>')
for lane in range(1,6):
    points = " ".join(f"{x:.2f},{y:.2f}" for x,y in (point(cp,lane) for cp in range(49)))
    svg.append(f'<polyline points="{points}" fill="none" stroke="#7388a8" stroke-width="1" opacity=".3"/>')
    for cp in range(1,49):
        x,y = point(cp,lane)
        a,b = point(max(0,cp-1),lane),point(min(48,cp+1),lane)
        angle = degrees(atan2(b[1]-a[1], b[0]-a[0]))
        section = (cp-1)//12
        width = 6 if section==1 else (10 if cp%6==0 else 7)
        color = palette[section]
        svg.append(f'<rect x="-9" y="{-width/2}" width="18" height="{width}" rx="2" fill="{color}" stroke="#111c31" stroke-width=".7" transform="translate({x:.2f} {y:.2f}) rotate({angle:.2f})"/>')
for cp in [4,8,16,20,28,32,36,40,44]:
    x,y=point(cp-.5)
    svg.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="5" fill="#ffd080" stroke="#111c31" stroke-width="2"/>')
for cp in [26,30,34]:
    x,y=point(cp-.5)
    svg.append(f'<path d="M{x-7:.2f},{y+6:.2f} L{x:.2f},{y-8:.2f} L{x+7:.2f},{y+6:.2f} Z" fill="#ff8971" stroke="#fff" stroke-width="1"/>')
svg += ['<rect x="49" y="201" width="28" height="50" rx="5" fill="#ffd080"/>',
        '<text x="39" y="279" font-size="12" fill="#ffd080">START</text>',
        '<circle cx="45" cy="310" r="13" fill="none" stroke="#ad82ff" stroke-width="4"/>',
        '<text x="68" y="315" font-size="12" fill="#d6bcff">STAR GATE / ENTRANCES</text>']
x,y=point(48)
svg += [f'<rect x="{x-5:.1f}" y="{y-28:.1f}" width="10" height="56" rx="2" fill="#ffd080"/>',
        f'<text x="{x-24:.1f}" y="{y+53:.1f}" font-size="12" fill="#ffd080">FINISH</text>']
for i,(name,detail,color) in enumerate(zip(names,details,palette)):
    x=34+i*290
    svg += [f'<rect x="{x}" y="370" width="278" height="76" rx="10" fill="#1c2c46"/>',
            f'<text x="{x+13}" y="396" font-size="14" fill="{color}" font-weight="bold">{i+1}. {name}</text>',
            f'<text x="{x+13}" y="421" font-size="11" fill="#c6d2e7">{detail}</text>']
svg += ['</g></svg>']
target=ROOT / "docs/SKYBRIDGE_ROUTE.svg"
target.write_text("\n".join(svg)+"\n")
ET.parse(target)
length=sum(hypot(amplitude*(sin(cp*pi/12)-sin((cp-1)*pi/12)),stride) for cp in range(1,49))
print(f"Built {target.relative_to(ROOT)}; centerline {length:.1f} studs.")
