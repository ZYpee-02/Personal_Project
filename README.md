# Riftbound Live — Skybridge Sprint v0.4.0

A fantasy sky-island spectator game with five automatic physical NPC racers,
verified checkpoints/finish times, fictional earnings, leaderboards, cosmetic gifts
and a portrait spectator camera. All state stays in memory. DataStoreService,
custom HTTP and TikTok networking are disabled.

**Already running physical Sprint? Replace World.lua, Realm.server.lua and
Realm.client.lua** using [the camera/restart guide](docs/CAMERA_FIX.md). Keep Config
and RealmState unchanged. The new client adds racing/podium shots and reversible
rendering safeguards; the reported gray screen still requires Studio confirmation.
For a fresh install or an upgrade from before physical Sprint, install all five
using [the Sprint guide](docs/SPRINT_REPLACEMENT.md). `MANUAL_STUDIO_SETUP.md` contains
all five complete raw sources. No Command Bar installer is used.

Five Demo_ competitors seed in Studio. Fallback R6 rigs spawn immediately. Optional
Roblox appearance loading is enabled by default; set `LoadAvatarAppearances=false`
for a strictly local fallback-only test. No TikTok viewer/gift is connected.
The cloud checks do not establish real Roblox physics or Studio rendering success.

## Manual setup in Roblox Studio

The Command Bar installer is retired and no longer generated or bundled. Use the
five actual source files below. They are complete raw Luau, not serialized strings.
`MANUAL_STUDIO_SETUP.md` includes step-by-step directions and all five full code
blocks if you prefer copying from one document.

1. Open a new place in Roblox Studio on Windows/macOS, with Play stopped.
2. Open Explorer and Properties. Keep HTTP Requests and Studio API Services access
   disabled. No publication, plugin or Node process is needed.
3. Create these exact instances, double-click each to open its Script Editor,
   select all default code, and replace it with the corresponding **entire file**:

| Raw source file | Instance type | Parent | Exact Explorer name |
| --- | --- | --- | --- |
| `roblox/ServerScriptService/Config.lua` | ModuleScript | ServerScriptService | Config |
| `roblox/ServerScriptService/RealmState.lua` | ModuleScript | ServerScriptService | RealmState |
| `roblox/ServerScriptService/World.lua` | ModuleScript | ServerScriptService | World |
| `roblox/ServerScriptService/Realm.server.lua` | Script | ServerScriptService | Realm |
| `roblox/StarterPlayerScripts/Realm.client.lua` | LocalScript | StarterPlayer → StarterPlayerScripts | Realm |

4. Do not append filename suffixes to the instance names. The server's three
   `require(script.Parent.NAME)` calls resolve the sibling ModuleScripts. Each
   ModuleScript returns its table. Leave the server Script's RunContext at its
   Legacy/default setting. Make sure the Script and LocalScript are enabled.
5. Finish all five files before starting. Do not leave duplicate Realm scripts from
   previous attempts active. Do not paste this code into the Command Bar or combine
   files. The client waits for remotes that the server creates automatically.
6. Press **Play**, not Run. The islands appear at runtime, and your player gets a HUD.
7. Watch three automatic Sprint rounds (allow up to six minutes). TEST TOOLS is
   optional. ROAM VIEW restores the normal camera; STREAM VIEW returns to the
   fitted course view. See `docs/SPRINT_REPLACEMENT.md` for physics/appearance checks.
8. Stop and Play again: all gameplay state starts fresh.

If Studio says Config/RealmState/World is not a valid member, check the parent,
instance type, spelling and extension-free Explorer name. If no HUD appears, verify
that the client is a **LocalScript in StarterPlayerScripts**, that you used Play,
and that the server has no errors in Output. Do not manually create the Riftbound
remotes or install anything from `integrations/` for this offline test.

## Physical Sprint and appearances

The 12s gathering → 8s optional vote → up to 80s race → 10s results loop repeats
without host actions. Five crew enter; extra/later joins wait for rotating cohorts.
The Studio host spectates by default (`AutoJoinPlayers=false`); JOIN tools still
accept usernames, and that flag can restore automatic player stand-ins.

Unanchored R6 Humanoids walk/jump along five equal lanes through twelve physical
pads, rises, gaps and moving wind gates. The server owns their assemblies and
samples actual roots. Gates must be reached in order; the finish requires a
physical plane crossing, with an interpolated timestamp. Winners are not selected
by names, money, gifts or theoretical speeds. Falls/stalls reset to verified pads
without stopping the clock. Timeout/dead/missing rigs DNF. No finisher means no
invented champion. Top finishers celebrate on the finish-island podium; the next
round resets automatically. Equal observed times share placements/bonuses.

All movement settings/colliders are identical. Simulated giant scaling waits until
a break during physical racing, while its aura and sky effects still appear.
Starfall/Relay remain available as the original kinematic demonstrations when
`SprintOnly=false`; Sprint always requires observed physical gates.

Appearance loading uses only two native Roblox APIs in a guarded asynchronous
loader. Configured IDs supply Demo_ cosmetics; actual auto-joined player stand-ins
can use their known Roblox ID. Typed usernames remain labels and use fallback rigs;
there is no username lookup. Failures/late responses retain the playable fallback.
Loaded scripts/tools are removed, size settings/colliders normalized, and appearances
install only outside races. The eight-second deadline is soft: in-flight engine
requests cannot be canceled. `LoadAvatarAppearances=false` makes zero authored
account/appearance requests while preserving all gameplay. HTTP/API access settings
can stay disabled. See [offline boundaries](docs/OFFLINE_SAFETY.md).

## Fictional money and presentation

Verified checkpoints pay $2; finishing pays $40; placements 1/2/3 add $120/$75/$40.
Passive income, vote participation, shard/championship bonuses and the existing
$100/s / $1B caps remain. Rewards pay once and all balances reset on Stop. This
currency is fictional game money, not Robux.

The portrait edge HUD retains separate Top Earners/round panels and a lower result
dock. Sprint rows show actual seconds or checkpoints/DNF. Name/earnings labels are
bounded and culled in screen space. The director alternates the full-course
overview, actual racing-pack shots and a leader close-up every three seconds. It uses
observed avatar roots; results cut to arrived podium winners and a winner close-up.
Close views fit avatar/jump envelopes into the clear HUD rectangle at 65–220 studs;
missing/invalid targets or an impossible fit use the bounded overview. Shot changes
cut directly; camera tracking between cuts is smoothed. Set STREAM_CINEMATIC=false
for the original fixed overview.

Stream View applies a reversible local daylight/fog profile and temporarily removes
Atmospheres and disables PostEffects, including Bloom, from Lighting/current Camera.
It scans for late effects and restores exact prior settings in Roam. Ambient gift
colors, avatar auras, ribbons, crowns and particle geometry remain active. The ward
and rift shells remain locally masked. Other scenery enclosing the lens is locally
masked and logged, including geometry outside RiftboundRealm; the racing course
and Humanoid models are protected. None of these masks changes physics.

Player characters now spawn on a separate raised spectator deck outside the race
lanes. Server preparation rescues the already-spawned first character and handles
respawns. Roam restores the Humanoid camera subject and begins above/outside the deck.

Diagnostics identify **cinematic-v5**, the selected shot, effect-isolation counts,
actual CFrame/Focus/rendered frame, opacity, enclosing objects and anchor sightlines.
A count of 155 opaque parts or six projected anchors is not proof of visibility.
See [exact replacement and Studio checks](docs/CAMERA_FIX.md).
The gray-screen cause is not claimed established or resolved by cloud checks.

The realm uses ModelStreamingMode.Persistent, but that policy alone does not prove
the client has its geometry. When engine streaming is enabled and course parts are
missing, at most three native geometry requests run per Stream View session. They
use a five-second timeout argument and a 15-second minimum retry interval; returning
does not count as geometry loaded. No requests run with streaming disabled or a
complete course. The optional place starts with StreamingEnabled=false.
Actual clipping, streaming, fonts, occlusion and performance still require Studio.

## Node simulator and future TikTok integration are separate

The offline game does not need Node. The optional browser control desk runs with:

```sh
cd /workspace/Personal_Project
npm ci --ignore-scripts
npm run dev
```

Node 22+ is required. The simulator binds to loopback port 8787. In local development,
open that port in your browser; the cloud onboarding UI does not provide localhost
previews. The control desk is an illustration and event simulator, not a live 3D view.
The default offline game does **not** poll it: browser events remain pending and
expire after two minutes. The default Studio demo runs automatically; use TEST TOOLS only for targeted tests.

Node event queues and receipts are also memory-only and clear on restart. Legacy
`.local/queue.json` files, if present from earlier versions, are not read or changed.
The ignored `.local/game-config.json` holds a generated transport credential only;
it contains no gameplay state. Never share or commit it. The Node service has
separate admin/game authentication for the later optional transport.

Real TikTok comments, gifts, and follows are **not connected**. No TikTok connector
is installed, imported, started, or contacted. `integrations/README.md` describes
an explicit future setup, with HTTPS hosting, an authorized LIVE connector, stable
viewer IDs, finalized gift events, and separate admin/game credentials. The optional
Roblox HTTP and avatar modules live under `integrations/roblox/`; neither is included
in the five manual game files, the `.rbxlx`, or the default Rojo project.

## Build and validation

```sh
npm ci --ignore-scripts
npm run check
npm run check:luau    # native compiler required; prepared in this cloud workspace
npm run test:browser  # optional browser simulator check; Chromium required
```

Node 22+ and Python 3 are required for development tools, not for manual Studio
setup. The build generates `MANUAL_STUDIO_SETUP.md`, the optional equivalent
`dist/RiftboundLive.rbxlx`, and `dist/RiftboundLive-Starter.zip` containing the five
raw sources with their correct folder structure. It does not generate an installer
or assign Script.Source at runtime. Edit the five source files directly. Studio
edits do not automatically sync back to the repository.

Automated tests exercise the actual pure-Lua rules, economy, voting, leaderboards,
gifts/follows, the optional Node bridge, local module dependencies, remote names,
source-code identity in the manual guide and ZIP, and offline API exclusions.
Phase 2 tests also drive the actual server scheduler with mocked services for
185 simulated seconds, proving that demo arrivals, gifts and several rounds run
without human/host calls; they do not simulate rendering or engine physics. The
native Luau compiler validates all five actual game files and all five sources in
the optional XML place. They cannot validate Roblox rendering, physics, or Studio
UI behavior. Run the manual checklist on Windows/macOS.

The prepared compiler is `.local/tools/luau-compile`. To use another official
compiler, set `LUAU_COMPILE` to its path. Source revision and reproduction details
are in `docs/SOURCE_VALIDATION.md`. An optional `default.project.json` is available
for Rojo users, but no plugin is needed for manual setup.
