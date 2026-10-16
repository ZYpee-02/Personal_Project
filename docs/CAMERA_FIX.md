# Close overview update v6 — replace ONE client script

The latest Studio screenshots isolate the recurring wide shot: the course is
visible at 77 seconds remaining, gray at 71, then visible again at 68. This happens
within the same race as well as at round changes. During gray, the HUD, small side
deck and some nearby effects still draw. Earlier native diagnostics confirmed all
155 course parts opaque, streaming disabled, Atmospheres/PostEffects isolated,
and actual/rendered camera frames matching. Those properties do not prove that
course pixels are drawn. The underlying renderer/culling cause remains unconfirmed.

## Install on the existing v5/v5.1 place

1. **Stop Play.** Open **StarterPlayer → StarterPlayerScripts → Realm**.
   This must be a **LocalScript**.
2. Replace its ENTIRE source with [Realm.client.lua](../roblox/StarterPlayerScripts/Realm.client.lua)
   and save the place. Keep all four ServerScriptService files unchanged.
3. Start Play. Output identifies **presentation=near-course-v6**.
4. Leave HOLD CAMERA off. Watch gathering, the repeating overview/pack/close-up
   montage, results, then the next round. Confirm that the new overview displays
   the course each time it appears. Stop and Play once more to check the saved source.

Do not replace the server Realm Script, append the client source, create duplicate
Realm instances, use the Command Bar, or edit the temporary Players → your name →
PlayerScripts copy. Edit the saved StarterPlayerScripts template with Play stopped.

## What v6 changes

The old overview was 321 studs from Focus and nearly 400 studs from the finish in
the supplied native capture. v6 replaces that pose in gathering, voting, every
wide racing beat and fallback shots. The new view aims around the actual course
center (0,71,-3), with 35-degree elevation and a wider lens. It fits the full course,
jump space and podium envelopes into the existing clear portrait HUD rectangle.

The fitter prefers a lens distance of at most 180 studs and every course corner
within 260 studs. Across supported viewport aspect ratios (1:4 through 4:1), hard
limits are 100–210 studs from Focus and 290 studs to the farthest display-volume
corner. Vertical FOV adapts from 85 to 120 degrees; very narrow layouts need the
widest lens. Normal portrait/desktop views stay around 175–180 studs. Optional
server bounds padding does not move the fixed authored course or cause another
zoom-out. Invalid bounds and transient invalid viewports use the bounded fallback.

Lens and optical-axis Focus move together to align the course with the clear HUD
rectangle, followed by a direct lookAt. There is no post-lookAt local translation.
This replaces the distant pose; it does not certify an engine draw-distance limit.

The closer racing-pack, racer and podium shots keep their existing 55-degree
lens and actual-root tracking. Snapshot refits retain the current tracking lens
until the director changes shots, preventing an overview lens from flashing on a
close-up between frames. STREAM_CINEMATIC=false uses the new close overview too.

The v5.1 throttle fix remains: overview refits do not reset scene-scan/diagnostic
timers every frame. Phase/shot changes can log immediately; otherwise diagnostics
are limited to ten seconds and enclosing-geometry scans to a quarter second.

All server scripts are unchanged. Automatic physical races, verified checkpoints,
finish times, earnings, gifts, leaderboards and celebration animation continue.
The five-script architecture and in-memory/offline boundaries remain unchanged.
Existing local daylight, effect isolation and scenery masks still restore in Roam.

## Optional diagnostic controls

**TEST TOOLS → HOLD CAMERA** captures position, aim, Focus and FOV across rounds,
viewport changes and camera replacement while gameplay continues. Toggle again or
enter Roam to release it. It starts off. Hold an overview if comparing a round
transition; a held close-up can naturally leave moving racers off screen.

**RENDER CHECK** creates a near pink cube and distant green cube as native 3D
geometry. It starts off and cleans up in Roam or when the HUD is disabled.
Neither test control sends gameplay actions. A short visual result and one Output
block around a remaining failure are sufficient; continuous dumps are unnecessary.

## Older installations only — v5 baseline

If v5/v5.1 is already installed, replace only the client as above. Older physical
Sprint installations also need the spectator deck/player preparation in these
baseline sources. Stop Play and replace each entire matching source:

| Raw file | Studio instance | Type |
| --- | --- | --- |
| [World.lua](../roblox/ServerScriptService/World.lua) | ServerScriptService → World | ModuleScript |
| [Realm.server.lua](../roblox/ServerScriptService/Realm.server.lua) | ServerScriptService → Realm | Script, Enabled=true, RunContext=Legacy |
| [Realm.client.lua](../roblox/StarterPlayerScripts/Realm.client.lua) | StarterPlayer → StarterPlayerScripts → Realm | LocalScript, Enabled=true |

Keep Config and RealmState unchanged. The deck is at (48,82,58), outside the race
lanes; actual player characters spawn/respawn at (48,87,58). Roam restores the actual
Humanoid subject and starts above/outside that deck. Racing NPC physics are unchanged.

Fresh installations or upgrades from before physical Sprint need all five files;
see [SPRINT_REPLACEMENT.md](SPRINT_REPLACEMENT.md) or MANUAL_STUDIO_SETUP.md.

## Validation and limits

Automated geometry checks exercise the new maximum distance to every display-volume
corner, full-course projection in the clear HUD rectangle, corrupted bounds, invalid
viewports, and both desktop screenshot aspect ratios. Integration checks cover
phase/round transitions, camera replacement, Roam, hold/release, the scan/log budgets,
actual racer/podium tracking and preserving the close-up lens during snapshots.
Authored-part corners and racing/jump envelopes are checked independently of the
fit calculation. Existing race/economy and startup regressions still run.

Native Luau compilation covers five raw sources and five exported equivalents.
Manual/export/ZIP sources are checked against the raw files. **Native Roblox Studio
rendering, engine culling and physics cannot be verified in this cloud environment.**
The distant overview has been replaced; a native visual check must establish whether
that resolves the reported gray shot.
