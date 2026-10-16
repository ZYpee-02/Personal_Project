# Riftbound Live — cinematic two-minute race show (v7)

This upgrade changes the route, state/cohort contract, avatar entrances and client
director together. **Replace all FIVE complete raw files, with Play stopped.**
Do not mix these files with the previous small-course/v6 scripts.

## Exact installation

Save a backup of your working place. Stop Play, then replace each entire source:

| File | Studio parent → name | Instance type |
| --- | --- | --- |
| [Config.lua](../roblox/ServerScriptService/Config.lua) | ServerScriptService → Config | ModuleScript |
| [RealmState.lua](../roblox/ServerScriptService/RealmState.lua) | ServerScriptService → RealmState | ModuleScript |
| [World.lua](../roblox/ServerScriptService/World.lua) | ServerScriptService → World | ModuleScript |
| [Realm.server.lua](../roblox/ServerScriptService/Realm.server.lua) | ServerScriptService → Realm | Script, Enabled, RunContext=Legacy |
| [Realm.client.lua](../roblox/StarterPlayerScripts/Realm.client.lua) | StarterPlayer → StarterPlayerScripts → Realm | LocalScript, Enabled |

Use Raw to copy each whole file, or the five complete Luau blocks in
MANUAL_STUDIO_SETUP.md. Do not paste Markdown fences, append code, use the Command
Bar, add duplicate scripts or edit Players → your name → PlayerScripts (the
runtime copy). Keep any configured HostUserIds when replacing Config.

With Play still stopped, select **Workspace → Properties → StreamingEnabled=false**.
The generated place already has this setting; runtime code cannot change this
Studio setting. The server reports a clear startup error if it is enabled. Leave
HTTP Requests and Studio API Services access disabled. Save, then press **Play**.
No plugin, Node bridge, persistence or real TikTok connection is required.

Expected markers: server `[Riftbound] Ready`; client `presentation=race-show-v7`.
The architecture remains exactly three ModuleScripts, one server Script and one
client LocalScript. No new game modules are required.

**v7.1 contact patch:** if these five v7 scripts are already installed, replace only
World.lua using [the Starting Dash fix instructions](SPRINT_CONTACT_FIX.md). This
removes the opening gap and uses actual support edges for jump timing. The client
marker above stays unchanged; the course attribute becomes `show-v7.1-contact`.

## The larger race

The course runs from z=60 to z=-1092: **1,152 studs, 48 measured gates, five lanes**.
All racers use the same 12-stud/second speed, jump power and collider dimensions.
The physical baseline is about 96 seconds before jumps, waits and recovery; the
race deadline is exactly **120 seconds**, not a minimum finish timer.

| Section | Gates | Course design |
| --- | --- | --- |
| Starting Dash | 1–12 | Broad starting platform, stepped pads, gaps and a hurdle |
| Moving Bridges | 13–24 | Floating spans with bounded lateral/vertical movement and gaps |
| Hazard Zone | 25–36 | Sliding wind gates, jump hurdles, rises and recovery pads |
| Final Sprint | 37–48 | Elevated dash, final jumps, illuminated finish arch and podium |

Section beacons, floating side islands, crystal fans, colored lane pads and neon
checkpoint strips decorate the route. A separate Star Gate stage presents arrivals.
The finish has a large arch, podiums, crowns, celebratory poses and reusable motes.
Stream hides only a top-level Part named Baseplate, locally, to remove the Studio
checkerboard; Roam restores its exact prior local transparency. It does not delete
terrain, geometry or collision surfaces.

Humanoids receive MoveTo and grounded jump commands. The server owns each physical
assembly. Gate checks require an observed root near the next pad and grounding;
the finish requires crossing its plane, with interpolated sample time. A later
gate cannot replace a missed earlier gate. Time alone never increases progress or
manufactures a winner. Falls, excessive displacement and sustained stalls reset
to the last verified pad, clear velocity and retain the clock; recovery never
advances a gate or repays a bounty. Sliding gates are waited out when blocked.

DNFs remain DNFs; active racers rank ahead of DNFs, finishers rank by actual times,
and exact ties share placement. Finish bonus ($40), placement prizes ($120/$75/$40),
$2 per verified checkpoint, passive/vote/activity earnings, caps, gifts and
leaderboards remain. More checkpoints earn more checkpoint bounties. Gifts do not
change racing speed/colliders; giant scaling waits until the race break.

## Director and HUD

The director follows replicated physical roots using a nearby pack window rather
than fitting the entire long course. Section views use elevated medium-distance
shots, a 55-degree vertical lens and 90–180-stud fitted distance. It normally tracks
the lead pack; every fourth eight-second beat spotlights another active competitor.
A dedicated finish shot takes priority over new entrance interruptions near the
last gates. Results show arrived winners and a champion close-up.

Nearby poses blend smoothly when the target stays in the clear HUD rectangle;
distant stage/finish changes cut directly. The lens remains at y=112–220 and within
the authored route corridor. No camera flight crosses the long empty space between
arrival stage and finish. Dispersed groups fall back to one actual competitor;
missing/invalid targets fall back to a close starting-grid view. There is no
whole-course overhead zoom. The previous daylight, effect isolation, shell masks,
optical-axis Focus and late-render camera enforcement remain.

The portrait canvas reserves a clear racing area. Five live competitor rows show
verified gates, finish seconds or DNF; separate earners remain visible. The header
shows the active lead section and countdown; the progress bar follows observed
race progress. Entrances and winners use a large name announcement above the action.
Portrait 390×844 / 1080×1920 and landscape Studio viewports are covered by geometry
checks. Native fonts, safe areas and readability still need visual verification.

ROAM VIEW and STREAM VIEW retain their behavior. The host spawns on the separate
raised spectator deck. TEST TOOLS remains optional; automatic rounds, gifts and
cohorts do not depend on host actions. HOLD CAMERA and RENDER CHECK are optional
diagnostics and should remain off during normal capture.

## Viewer entrances and offline testing

**OFFLINE JOIN** accepts a syntactically valid username label and builds a local
stand-in with no account/appearance request. This is the reliable offline test.

**ROBLOX JOIN / VERIFY ACCOUNT** checks the username with
Players:GetUserIdFromNameAsync. Syntax is 3–20 letters/digits with at most one
internal underscore. An invalid/unverifiable account is rejected with a notice;
it is not silently presented as verified. Verified IDs use the existing optional
GetHumanoidDescriptionFromUserIdAsync and CreateHumanoidModelFromDescriptionAsync
loader for an R6 appearance. Appearance failure keeps a playable fallback.

Lookup has an eight-second soft deadline, a bounded positive cache and at most two
native lookups in flight. Engine requests cannot be forcibly canceled; late results
are ignored. The separate event worker yields while verifying so physics, round
advancement and scoring continue. Native outfit asset loading is Roblox networking,
not custom HTTP or TikTok integration. Set ResolveViewerUsernames=false and
LoadAvatarAppearances=false for entirely local authored join/appearance behavior.

New crew queue for the Star Gate. A normal arrival gets four seconds, a tighter 35-degree
close-up lens (60–150-stud fitting range), a glowing outline and a celebratory pose. With four or more waiting, groups of three receive
2.5 seconds each to reduce interruption. A finish contest defers new montages;
a very late final stretch can preempt an existing entrance shot. The race clock,
physical roots and scoring keep running throughout. When the entrance completes,
the newcomer receives priority in the next available five-person cohort. Previously
unraced viewers precede returning racers; returning racers rotate fairly.

Studio seeds five explicitly labeled Demo_ viewers and cosmetic gifts/follows by
default. They may use configured cosmetic account IDs; they are not real LIVE users.
Set OfflineDemoEnabled=false or AutoSimulateGifts=false to disable simulations.
DemoStudioOnly=true prevents the seeded audience outside Studio.

## Available validation and required Studio checks

Validation run (2026-10-16): **138 tests passed**, plus **10 native Luau compilation
targets passed** (five raw scripts and five exported equivalents). The build also
verified raw/manual/XML/ZIP source identity and StreamingEnabled=false in the place.

Automated tests execute the actual five sources with limited Lua service mocks.
They check every lane pad, all four section bounds, gap/rise and ballistic jump
feasibility, moving-platform limits, actual navigation commands, fall/stall
recovery, grounded gates, interpolated finishes, DNFs, rewards, cohort fairness,
username failure/timeout/cache behavior, entrance grouping, HUD framing, section
tracking, competitor spotlights, finish cameras, Roam restoration and source export
identity. A speed-limited command-following integration completes races within the
90–120-second target and repeats automatic rounds. Native Luau compiles all five
raw files plus five exported equivalents.

**The physics stub integrates MoveTo goals. It does not simulate Roblox gravity,
collision, Humanoid jump execution, moving-platform contact, accessory mass,
replication or path obstruction.** The separate ballistic checks establish geometric
feasibility, not successful native landings. No measured native race-duration result
is claimed. Recovery frequency can make a difficult native race time out.

The v7.1 patch adds a separate gravity/contact approximation that reproduced the
opening fall loop and checks actual takeoff edges, moving supports and hurdle
faces. See [the patch evidence and limits](SPRINT_CONTACT_FIX.md); it supplements
the command-only stub and still requires native Studio verification.

Required Windows/macOS Studio playtest:

1. Watch at least three complete rounds with no controls. Record winner times and
   DNFs; confirm most finishes fall near 90–120s. Check each of the four sections.
2. Inspect jumps/landing on moving bridges and gate waits at normal gravity. Try a
   fall and confirm recovery to the verified pad with no new score/reward. Check
   that falling still costs time. Record the gate numbers of repeated stalls.
3. Test OFFLINE JOIN singly and seven arrivals during a race. Check the large names,
   group shortening, ongoing movement/earnings, return shot and next cohort entry.
4. Test a real Roblox username, a nonexistent username and appearance failure.
   Confirm notices and fallback rigs without blocking the race.
5. Verify all section/finish/podium shots, portrait names and both Studio orientations.
   Confirm no blank view, enclosure or lens below the deck. Test Roam/Stream and
   reset the host once. Start a fresh Play run and verify again.
6. Observe server/client frame and replication costs. The longer scene is larger;
   geometry bounds are not a performance guarantee on every device.

Adjust SprintWalkSpeed only within the supported 10–14 range after collecting
native times; keep SprintRaceSeconds=120. If native jumps stall, tune pad dimensions,
jump trigger or route speed based on the failing gate, not a fabricated finish.
Data persistence and real TikTok connection remain disabled.
