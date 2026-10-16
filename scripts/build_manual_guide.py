"""Documentation only: show the complete raw source of each manually installed script."""
from pathlib import Path
from offline_sources import sources

ROOT = Path(__file__).resolve().parents[1]
order = ["Config", "RealmState", "World", "Realm"]
scripts = sorted(sources(), key=lambda row: (row[0] == "StarterPlayerScripts", order.index(row[2])))
intro = '''# Riftbound Live Phase 2: complete raw scripts and manual replacement

Use the Script Editor and Explorer. Do not paste this document or any script into
the Command Bar. There is no generated installer or serialized source wrapper.

**Updating the working Phase 1 game?** Save a backup of your Studio place, stop
Play, and replace the ENTIRE source of each of the five existing instances below.
Keep their names, types and parents. Replace all five together; do not mix versions
or add duplicates. Restore any custom HostUserIds into the new Config afterward.
**Updating the working Phase 2 game to the presentation fix?** Replace the ENTIRE
source of **World.lua and Realm.client.lua** together. Config, RealmState and the
server Realm are unchanged from the working startup repair. All five complete
files are provided below in case your copies are mixed. Follow
`docs/PRESENTATION_REPLACEMENT.md` for exact replacement and resolution checks.
`docs/STARTUP_FIX.md` documents the earlier startup repair;
`docs/PHASE2_REPLACEMENT.md` covers the first-three-round checklist.

## Step-by-step

1. Open a new Roblox Studio place and stop Play mode. Keep HTTP Requests and Studio
   API Services access disabled. No publication, Node process or plugin is needed.
2. Open Explorer and Properties from Studio's View/Window menu.
3. Under **ServerScriptService**, insert three **ModuleScript** instances. Name
   them exactly **Config**, **RealmState**, and **World** (without `.lua`).
4. Under **ServerScriptService**, insert one normal **Script** named **Realm**.
   Its source is the file `Realm.server.lua`. Leave RunContext at Legacy/default.
5. Expand **StarterPlayer → StarterPlayerScripts**. Insert one **LocalScript**
   named **Realm** there. Its source is `Realm.client.lua`. This client script
   belongs in StarterPlayerScripts, not StarterCharacterScripts or the server.
6. Double-click each instance to open its Script Editor. Select **all** of its
   default/template text and replace it with its matching complete source below.
   Copy only the code inside that file's code block, without Markdown fences.
   In a raw file preview, copy the source itself. Do not combine the five files.
7. Make sure the server Script and LocalScript are enabled. Finish all five files
   before pressing Play. Do not keep duplicate Realm server/client scripts active.
8. Press **Play**, not Run. The server creates the islands, stand-in avatars, event
   objects and money/round state; the LocalScript builds the player HUD.
9. Wait: six clearly named Demo_ travelers arrive automatically in Studio. After
   12 seconds gathering and 8 seconds optional voting, they compete for 30 seconds.
   A 10-second result/celebration phase follows, then the next round starts itself.
10. Watch three rounds: Starfall Scramble, Skybridge Sprint, then Heartseed Relay.
    No votes, clicks or Keeper Tools are needed. Demo gifts/follows also run in Studio.
    Usernames label local procedural avatars; no real account/outfit is downloaded.
11. Optional **TEST TOOLS** can add a username, start gathering early, simulate votes,
    gifts or a follow. **ROAM VIEW** restores normal character camera controls;
    **STREAM VIEW** returns to the fitted 9:16 arena view. Keep tools closed for capture.
    Base income is $5/s in voting/competition, plus $2/s for automatic activity,
    a $3/s voting bonus, checkpoint bounties and podium prizes. Gifts stay cosmetic.
12. Stop and Play again to confirm all money, crew, gifts, follows and shards reset.

Expected Explorer tree:

```text
ServerScriptService
├── Config       (ModuleScript)
├── RealmState   (ModuleScript)
├── World        (ModuleScript)
└── Realm        (Script; source: Realm.server.lua)
StarterPlayer
└── StarterPlayerScripts
    └── Realm    (LocalScript; source: Realm.client.lua)
```

The server's three `require(script.Parent.NAME)` calls refer to the three sibling
ModuleScripts above. Config, RealmState and World each return their module table.
The client requires no modules; it waits for `ReplicatedStorage.Riftbound` and its
Snapshot, Action and Notice RemoteEvents, which the server creates automatically.
Do not create those remotes or install anything from `integrations/` manually.
The corrected server creates them BEFORE loading modules and publishes Ready only
after a successful world build and first render. The client shows loading progress
and a bounded error panel. Success in SERVER Output starts with `[Riftbound] Ready`.
Check the server Realm is enabled with RunContext Legacy, and has no duplicates.

The presentation update keeps a clear central arena area, puts both leaderboards
in separate bottom panels, and reuses the bottom round dock for results. Stream
view hides duplicate world/scenery boards and limits projected avatar labels to
four names/two earnings rows. Roam view restores nearby world boards. Camera
distance adapts to the viewport; no result zoom or central winner banner is used.

All game data is in memory, with `PersistenceEnabled = false`. These sources have
no save-service access, HTTP calls, external asset fetches, or TikTok connection.
Roblox Studio/engine behavior still requires a local Windows/macOS playtest.

## Complete source files

'''
filenames = {("ServerScriptService", "Realm"): "Realm.server.lua", ("StarterPlayerScripts", "Realm"): "Realm.client.lua"}
sections = []
for directory, kind, name, source in scripts:
    filename = filenames.get((directory, name), name + ".lua")
    parent = "StarterPlayer → StarterPlayerScripts" if directory == "StarterPlayerScripts" else directory
    sections.append(f"### {filename}\n\nCreate a **{kind}** named **{name}** under **{parent}**.\n\n```luau\n{source}```\n")
output = ROOT / "MANUAL_STUDIO_SETUP.md"
output.write_text(intro + "\n".join(sections), encoding="utf-8")
print(f"Built {output.name} with five complete, unescaped source-code blocks.")
