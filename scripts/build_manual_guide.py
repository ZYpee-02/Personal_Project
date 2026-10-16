"""Documentation only: show the complete raw source of each manually installed script."""
from pathlib import Path
from offline_sources import sources

ROOT = Path(__file__).resolve().parents[1]
order = ["Config", "RealmState", "World", "Realm"]
scripts = sorted(sources(), key=lambda row: (row[0] == "StarterPlayerScripts", order.index(row[2])))
intro = '''# Riftbound Live: Skybridge Sprint complete raw scripts and manual replacement

Use the Script Editor and Explorer. Do not paste this document or any script into
the Command Bar. There is no generated installer or serialized source wrapper.

**Round-transition update v5.1 (Studio confirmation required):** If cinematic-v5
already runs, replace ONLY **Realm.client.lua**, the Realm LocalScript under
StarterPlayer → StarterPlayerScripts. It fixes per-frame overview diagnostics/scans
and adds TEST TOOLS → HOLD CAMERA to keep the view fixed across automatic rounds.
Follow `docs/CAMERA_FIX.md` for the next-round comparison. The gray cause is unconfirmed.

Older physical Skybridge Sprint installations need the v5 baseline too: **World.lua** in the
ServerScriptService World ModuleScript, **Realm.server.lua** in the normal
ServerScriptService Realm Script, and **Realm.client.lua** in the Realm LocalScript
under StarterPlayer → StarterPlayerScripts. Keep Config and RealmState unchanged.
Follow `docs/CAMERA_FIX.md` for exact replacement and restart/visual checks.
Stop Play before editing and save the place before starting the test.
Edit the saved StarterPlayer → StarterPlayerScripts template, not the temporary
Players → your name → PlayerScripts copy created during Play.

For a fresh install or an upgrade from BEFORE physical Sprint, install all five
complete sources below together; follow `docs/SPRINT_REPLACEMENT.md` for the
gameplay upgrade. Keep names/types/parents and avoid duplicate scripts. The steps
below describe a fresh install, not a requirement to reset your working server.

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
9. Five Demo_ travelers seed in Studio. After 12 seconds gathering and 8 seconds
   optional voting, up to five race the raised obstacle course using Humanoids.
   The race lasts at most 80 seconds, or ends when every entrant finishes/DNFs.
   Ten seconds of results follow, then the next round starts automatically.
10. Watch at least three Sprint rounds. Gates/times require actual root movement;
    timeouts do not manufacture winners. Demo gifts/follows remain automatic.
    Default Roblox appearance loading is optional; LoadAvatarAppearances=false
    keeps the exact same physical gameplay with local fallback rigs only.
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
four names/two earnings rows. Roam view restores nearby world boards. The fixed
camera validates every bounds snapshot, stays above/outside the course, limits
Sprint distance to 850 studs, and restores vertical FOV and Focus every render frame.
The v3 Sprint overview aims at (0,68,45), with FOV 55, heading 0 and elevation 55
degrees, using actual course regions to fit the frame and zero local translation.
Stream View applies local daylight and hides the ward/rift spheres that cover
the course. Roam restores the previous light properties and local shell opacity;
server effects and game state are unchanged.
Temporary `[Riftbound camera]` diagnostics check actual local geometry as well as
the streaming policy, actual CFrame/Focus, all six anchor sightlines and lens enclosures.
See docs/CAMERA_FIX.md for current evidence and the held-camera round-transition test.
Missing geometry with engine streaming enabled can trigger
at most three native Roblox stream requests per Stream View session; none run
when streaming is disabled or the course is present. No external bridge is used.

All game data is in memory, with `PersistenceEnabled = false`. There are no
save-service, custom HTTP or TikTok calls. LoadAvatarAppearances=true permits two
native Roblox appearance APIs; false makes zero account/appearance requests.
Fallback rigs spawn immediately, and late/failing appearances never block rounds.
Roblox physics, asset loading and rendering still need a Windows/macOS playtest.

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
