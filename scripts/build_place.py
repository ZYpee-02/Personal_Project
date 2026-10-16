"""Package the authored Lua files as a Roblox Studio XML place, using only stdlib."""
from pathlib import Path
import xml.etree.ElementTree as ET
from offline_sources import sources as offline_sources

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "dist"


def item(parent, class_name, name):
    node = ET.SubElement(parent, "Item", {"class": class_name, "referent": f"RBX{item.counter}"})
    item.counter += 1
    props = ET.SubElement(node, "Properties")
    ET.SubElement(props, "string", {"name": "Name"}).text = name
    return node, props


item.counter = 1
place = ET.Element("roblox", {"version": "4"})
ET.SubElement(place, "External").text = "null"
ET.SubElement(place, "External").text = "nil"
workspace, props = item(place, "Workspace", "Workspace")
ET.SubElement(props, "float", {"name": "FallenPartsDestroyHeight"}).text = "-100"
ET.SubElement(props, "bool", {"name": "StreamingEnabled"}).text = "false"
item(place, "Lighting", "Lighting")
item(place, "ReplicatedStorage", "ReplicatedStorage")
server, _ = item(place, "ServerScriptService", "ServerScriptService")
starter, _ = item(place, "StarterPlayer", "StarterPlayer")
client, _ = item(starter, "StarterPlayerScripts", "StarterPlayerScripts")

sources = offline_sources()
for directory, class_name, name, source in sources:
    parent = server if directory == "ServerScriptService" else client
    node, props = item(parent, class_name, name)
    ET.SubElement(props, "ProtectedString", {"name": "Source"}).text = source
    if class_name != "ModuleScript":
        ET.SubElement(props, "bool", {"name": "Disabled"}).text = "false"

OUT.mkdir(exist_ok=True)
ET.indent(place, space="  ")
target = OUT / "RiftboundLive.rbxlx"
ET.ElementTree(place).write(target, encoding="utf-8", xml_declaration=True)

# Verify the exact exported sources, not just that an output file exists.
parsed = ET.parse(target).getroot()
exported = [n.text for n in parsed.findall(".//ProtectedString[@name='Source']")]
expected = [source for _, _, _, source in sources]
assert exported == expected, "Place source verification failed"
assert len(exported) == 5, "A required game script is missing"
print(f"Built {target.relative_to(ROOT)} with {len(sources)} verified script sources.")
