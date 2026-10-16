"""Documentation only: show the complete raw source of each manually installed script."""
from pathlib import Path
from offline_sources import sources

ROOT = Path(__file__).resolve().parents[1]
order = ["Config", "RealmState", "World", "Realm"]
scripts = sorted(sources(), key=lambda row: (row[0] == "StarterPlayerScripts", order.index(row[2])))
intro = '''# Riftbound Live v10 — shared fantasy skyway

This replaces v9's five isolated lanes with **one broad connected road**. Replace
all five complete sources together: Config, navigation, route validation, cohort
limits and the client contract all change. No new game module is added.

## Exact Studio replacements

Stop Play and back up your place. Open each GitHub file and choose **Raw**, then
replace the entire matching source (do not append code or paste Markdown fences):

| Complete source | Studio location and instance type |
| --- | --- |
| [Config.lua](../roblox/ServerScriptService/Config.lua) | ServerScriptService → Config, ModuleScript |
| [RealmState.lua](../roblox/ServerScriptService/RealmState.lua) | ServerScriptService → RealmState, ModuleScript |
| [World.lua](../roblox/ServerScriptService/World.lua) | ServerScriptService → World, ModuleScript |
| [Realm.server.lua](../roblox/ServerScriptService/Realm.server.lua) | ServerScriptService → Realm, Script; Enabled; RunContext Legacy |
| [Realm.client.lua](../roblox/StarterPlayerScripts/Realm.client.lua) | StarterPlayer → StarterPlayerScripts → Realm, LocalScript; Enabled |

Keep your existing HostUserIds and any intentional economy settings in Config.
Keep one instance of each script. Edit the saved StarterPlayerScripts template,
not the runtime Players/PlayerScripts copy. With Play stopped set
**Workspace.StreamingEnabled=false**, save, then start a fresh Play session.
HTTP Requests and Studio API Services access can stay disabled. The server creates
its own remotes. No Command Bar installer, plugin or bridge is needed.

Expect `[Riftbound] Ready`, `presentation=race-show-v10`, and course revision
`show-v10-shared-road`. A GitHub push updates source only; it does not modify an
already open Studio place. MANUAL_STUDIO_SETUP.md also contains all five raw sources.


The sections below contain the complete current raw Luau sources.

'''
intro = intro.replace('(../roblox/', '(roblox/')
filenames = {("ServerScriptService", "Realm"): "Realm.server.lua", ("StarterPlayerScripts", "Realm"): "Realm.client.lua"}
sections = []
for directory, kind, name, source in scripts:
    filename = filenames.get((directory, name), name + ".lua")
    parent = "StarterPlayer → StarterPlayerScripts" if directory == "StarterPlayerScripts" else directory
    sections.append(f"### {filename}\n\nCreate a **{kind}** named **{name}** under **{parent}**.\n\n```luau\n{source}```\n")
output = ROOT / "MANUAL_STUDIO_SETUP.md"
output.write_text(intro + "\n".join(sections), encoding="utf-8")
print(f"Built {output.name} with five complete, unescaped source-code blocks.")
