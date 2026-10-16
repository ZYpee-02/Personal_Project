"""Documentation only: show the complete raw source of each manually installed script."""
from pathlib import Path
from offline_sources import sources

ROOT = Path(__file__).resolve().parents[1]
order = ["Config", "RealmState", "World", "Realm"]
scripts = sorted(sources(), key=lambda row: (row[0] == "StarterPlayerScripts", order.index(row[2])))
intro = '''# Riftbound Live v7 — complete raw scripts for the two-minute race show

**Replace all FIVE complete sources together.** The long course, state contract,
entrance queue and section director must match. Follow docs/RACE_SHOW_REPLACEMENT.md
for exact behavior, offline/verified join modes and the native Studio checklist.
No Command Bar installer, serialized code wrapper or new game module is used.

## Install with Play stopped

1. Back up the working place. Stop Play. Set Workspace.StreamingEnabled=false in
   Properties and save. The generated place already has streaming disabled. The
   server refuses this playtest configuration if streaming is enabled.
2. Under ServerScriptService, keep one ModuleScript each named Config, RealmState
   and World. Keep one normal Script named Realm, Enabled, RunContext=Legacy.
3. Under StarterPlayer → StarterPlayerScripts, keep one LocalScript named Realm,
   Enabled. This is a different Realm from the server Script.
4. Replace each entire source with its matching raw Luau block below, without
   Markdown fences. Do not append/combine sources or create duplicate scripts.
   Preserve configured HostUserIds in Config. Edit the saved StarterPlayerScripts
   template, not Players → your name → PlayerScripts (the runtime copy).
5. Save, then press Play. Expect server [Riftbound] Ready and client diagnostics
   presentation=race-show-v7. Watch at least three automatic rounds, then Stop/Play
   again to verify the saved source and fresh-start behavior.

```text
ServerScriptService
├── Config       (ModuleScript)
├── RealmState   (ModuleScript)
├── World        (ModuleScript)
└── Realm        (Script; Realm.server.lua)
StarterPlayer
└── StarterPlayerScripts
    └── Realm    (LocalScript; Realm.client.lua)
```

The server creates ReplicatedStorage.Riftbound plus Snapshot/Action/Notice remotes.
Do not create them manually. Missing-module/type/duplicate errors are reported by
bounded startup checks. Keep HTTP Requests and Studio API Services access disabled;
no publication, plugin, Node bridge or external TikTok connection is needed.

## Expected show

The route is 1,152 studs with 48 measured gates across Starting Dash, Moving Bridges,
Hazard Zone and Final Sprint. Five server-owned Humanoids use the same movement
settings. The 120-second deadline does not manufacture winners: actual checkpoint
observations and a finish-plane crossing determine times, DNFs and rewards. The
12-stud/second baseline is about 96 seconds before waits/jumps/recovery. Fall/stall
recovery returns only to the last verified pad and retains the clock.

The director follows nearby real competitors and the active section, periodically
shows another racer, covers the final stretch and celebrates podium winners. It
uses medium shots and a close starting-grid fallback, never a whole-route zoom-out.
ROAM VIEW and STREAM VIEW remain available. The named template Baseplate is hidden
locally in Stream and restored in Roam. Light/effect/shell isolation remains reversible.

TEST TOOLS → OFFLINE JOIN creates a local labeled stand-in with no account request.
ROBLOX JOIN / VERIFY ACCOUNT uses a bounded native Roblox username lookup and optional
appearance APIs. A normal entrance lasts four seconds; bursts group three for 2.5
seconds. New montages defer near a contested finish. Movement, scoring and round
clocks continue; newcomers enter the next eligible cohort after presentation.

Demo_ viewers, gifts/follows and all money are fictional/offline test data. Set
ResolveViewerUsernames=false and LoadAvatarAppearances=false for zero authored
account/appearance requests. Data persistence and real TikTok integration remain
disabled. Optional native avatar loading can fetch normal Roblox outfit assets;
it is separate from custom HTTP. Failed/late appearance loads retain fallback rigs.

Automated checks cover authored geometry, jump feasibility, command following,
measured results, economy, queues, failure handling, camera framing and exports.
**They do not simulate native Roblox collision, Humanoid jumping, moving-platform
contact or rendering.** Real Studio playtests must establish native completion times,
section traversal, avatar loading, portrait readability and absence of blank views.
See docs/RACE_SHOW_REPLACEMENT.md for the precise playtest and tuning checklist.

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
