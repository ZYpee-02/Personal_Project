# Offline source review — manual five-script setup

The supported distribution is five complete raw Luau files. There is no active
Command Bar generator, Script.Source assignment, serialized Lua blob, code fetch,
or dynamic evaluation. Previously generated installers and their generator were
retired into ignored `.local/retired-command-bar/`; the build/tests never run them.

## Offline boundaries

The five game files contain no DataStoreService, MemoryStoreService, HttpService,
authored external asset URLs, remote module IDs, purchases, periodic saves or
shutdown saves. `Config.PersistenceEnabled` must remain false;
there is no save implementation. Every crew member, avatar, balance, vote,
leaderboard row, gift/follow count and shard resets when the game server stops.

The server requires only sibling ModuleScripts Config, RealmState and World.
All three return a table. Runtime services used by the five files are Players,
ReplicatedStorage, RunService, Lighting and TweenService. The client waits for the
server-created Riftbound folder and Snapshot, Action and Notice RemoteEvents.
These synchronize clients within Roblox; they do not contact external services.

During Play, World builds its own geometry and lighting and creates avatars from
local Parts. `LoadAvatarAppearances=true` additionally allows two guarded native
Roblox calls: GetHumanoidDescriptionFromUserIdAsync and
CreateHumanoidModelFromDescriptionAsync, with normal Roblox outfit asset loads.
This is enabled by default to supply the requested Demo_ appearances. Set it false
for zero authored appearance/account requests and the same physical fallback rigs.
The loader is asynchronous, attempts once per rig, uses a soft deadline, strips
scripts/tools, and installs cosmetics only outside a race. Failed/late results keep
the fallback. No username lookup is used; typed labels are not verified accounts. A
server-only BindableFunction remains available for a future explicitly installed
adapter, but it never starts a connection itself. Online helpers are isolated in
`integrations/` and are not included in the five-file setup or default Rojo project.

Host actions are authorized on the server and throttled. All Studio players can
exercise the offline simulator. In a published place, only its owner or configured
host IDs have those controls. Names, queue size, gift counts, money, rates, crew and
follows are bounded. Gifts are cosmetic and create no income/voting advantage.

## Verification

`scripts/offline_sources.py` uses an explicit five-file manifest and rejects
prohibited services, network/asset APIs, dynamic code execution and nonlocal
requires. Tests check the real raw sources, module returns/dependency names, remote
names, and exact source identity in the manual guide and ZIP. Luau's native compiler
compiles all five source files and the corresponding XML-exported sources.

These are checks for this authored source, not a guarantee for arbitrary untrusted
or obfuscated code. Actual Roblox rendering, physics, UI and avatar scaling must
be playtested in Studio. Keep HTTP Requests and Studio API Services access disabled
and follow `docs/SPRINT_REPLACEMENT.md`. Studio/the Roblox engine may use normal
services. Native appearance requests are the explicitly permitted exception;
custom HTTP and real TikTok networking remain disabled.


## Phase 2 automation and visual bounds

The Studio-only demo explicitly labels its seeded audience and events. Set
OfflineDemoEnabled=false or AutoSimulateGifts=false to stop those simulations;
DemoStudioOnly=true prevents them outside Studio by default. Rounds and automatic
competition do not depend on Keeper input. Sprint uses actual physical observations
and measured finish times, never the legacy deterministic paces. Starfall/Relay
retain those kinematic demos when SprintOnly=false. All currency is fictional,
server-authoritative and in memory. Giant scaling is deferred during Sprint to
keep movement/collider dimensions equal; auras and sky effects remain available.

Scene animation is bounded to 12 updates/s by default (allowed setting 4–30),
crew remains capped at 18, and a 36-Part particle pool and one popup per avatar are
reused. No custom particle texture/sound URLs are loaded. Optional native Roblox
outfits are documented above. At most five physical racers enter each Sprint;
extra viewers wait for rotating cohorts. These are bounds, not a performance
guarantee. Test physics/network/frame costs in Studio.
