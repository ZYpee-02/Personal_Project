> **Current v10 shared skyway:** replace all five sources using
> [SHARED_SKYWAY_REPLACEMENT.md](SHARED_SKYWAY_REPLACEMENT.md). The older
> release notes below are historical; do not mix their scripts with v10.

# v9 — fantasy skyblock world and separated race lanes

## Exact Studio update

For an existing v7/v8 installation, replace **only these two Luau sources together**:

| Complete raw source | Saved Studio location | Type |
| --- | --- | --- |
| [World.lua](../roblox/ServerScriptService/World.lua) | ServerScriptService → World | ModuleScript |
| [Realm.client.lua](../roblox/StarterPlayerScripts/Realm.client.lua) | StarterPlayer → StarterPlayerScripts → Realm | LocalScript |

Stop Play, back up the place, open GitHub's Raw view, and replace each entire source.
Do not paste Markdown fences, append code, add duplicates, or edit the temporary
Players → PlayerScripts copy. The server Script also named Realm stays as it is.
Config and RealmState stay as they are; preserve configured host IDs and economy
settings. An installation older than v7 needs the [complete five-file install](RACE_SHOW_REPLACEMENT.md).

With Play stopped, keep **Workspace.StreamingEnabled=false**, save, then start a
fresh Play session. No Studio API Services access, custom HTTP, persistence,
publication, plugin or TikTok connection is needed.

Expected markers: `SkybridgeSprint.CourseRevision=show-v9-skyblock` and client
Output `presentation=race-show-v9`. The complete manual and ZIP also contain all
five sources for a fresh installation; no new Roblox modules were added.

## World and track changes

The route keeps 48 sequential checkpoints, four named sections, equal WalkSpeed=12,
the 120-second limit, and about 1,281 studs of horizontal route per lane. Translated
copies of the route preserve equal authored lane distance.

The old eight-stud spacing was smaller than the nine-stud landing blocks and got
effectively narrower on bends. Lanes now use **16-stud spacing**, positive support
gaps, and individually aligned hurdles. Automated footprint checks cover all 240
supports, including conservative envelopes for the full moving-span sweep; they
check neighboring gates and neighboring lanes, not just same-gate centers. Shared
starting ground is an intentional staging junction. The celebration stage is now
beyond the racing supports, with podiums on its surface.

| Section | Natural materials and features |
| --- | --- |
| Starting Dash | Moss-capped slate stepping stones, grassy starting island and hanging bedrock |
| Moving Bridges | Timber decks, wood girders and bounded sideways/vertical platform movement |
| Hazard Zone | Stone-ruin surfaces, lane hurdles and three sweeping magical gates |
| Final Sprint | Marble trail, moss inlays, wider crown arch and separate winner garden |

Floating meadows, elderwood trees, magical crystals, open glowing portals,
waterfall curtains, moving water bands and cloud clusters flank the route.
They use native Roblox materials and procedural parts; no custom asset download
code was added. Decorative parts have collision/touch disabled. Grass caps and
bridge girders remain inside their own support footprint. Trees and island
landmarks sit outside the race lanes; open trail arches sit above jump height.
Scenery is bounded and stays below the camera's minimum lens height.

Waterfalls animate a fixed pool of parts. There are no new per-frame scenery
instances, terrain water floods, physics forces or artificial checkpoint awards.
The server-owned physical race, recovery, measured finish plane, DNFs, rewards,
leaderboards, automatic rounds, gifts and queued avatar entrances retain their rules.

## Spectator presentation

Race shots use a lower elevated angle and fit the lead plus up to two nearby rivals
within an 85–150-stud fitting range. The lens-height constraint is part of fitting,
so a close shot cannot accidentally be rejected into the starting-grid fallback.
Other competitors still receive periodic spotlights and all five remain on the HUD.
Finish and entrance shots keep their dedicated behavior. Full-roster staging may
fall back to a real avatar close-up if it cannot fit at medium distance.

Stream uses softer exposure, natural ambient light and directional shadows.
The existing reversible atmosphere/post-effect isolation, far fog, ward/rift masks,
late camera enforcement and safe fallbacks remain. Roam/Stream still work.

At most about seven times per second, the client asks Roblox which parts obscure
the current target roots/heads. It locally masks only tagged parts inside
FantasyScenery, preserving their previous local opacity. It never masks a racing
support or avatar through this feature. Scenery opacity restores when the view is
clear, in Roam, or when the HUD is disabled. Native foliage occlusion and shadows
still need visual playtesting.

## Available verification and native limits

**146 tests passed, zero failed; all 10 Luau compilation targets passed.**
The automated suite checks support separation including motion envelopes, all
lanes/four sections under simplified gravity/contact, grounded sequential gates,
fall/stall recovery, actual measured model finishes, rewards/DNFs, entrance queues,
portrait/landscape framing, scenery mask restoration and offline safeguards.
Native Luau compilation covers all five raw files and five exported equivalents.
The build verifies raw/manual/XML/ZIP source identity and streaming disabled in
the exported place. All five racers complete the gravity/contact model within
90–120 seconds without recovery; those are simulated results, not Studio timings.

The contact model uses point support/obstruction checks in rotated rectangles,
gravity 196.2 and a 50ms jump response. It does not implement the native Humanoid
state machine, swept bodies, racer-to-racer contact, platform friction, avatar
asset collisions, replication, rendering, shadows or font rasterization. Passing
it does not guarantee zero native falls or a native 90–120-second finish rate.

Required Studio checks:

1. Watch three automatic rounds. Verify all five start, clear all four sections,
   and record finish times, DNFs and any repeated recovery gate.
2. Watch moving bridges at both swing extremes, jumps on outer lanes, all sweeping
   gates and the finish approach. Inspect lane clearance from Roam.
3. Check grass/stone/wood appearance, portal transparency, waterfalls and shadows.
   Check actual FPS with loaded outfits and StreamingEnabled=false.
4. Check portrait 9:16 and landscape: recognizable avatars, readable labels/HUD,
   smooth section changes, no hidden racers behind trees or black/gray shots.
5. Test Roam/Stream, character reset, an offline entrance, seven queued entrances,
   and a fresh Stop/Play. Confirm entrances do not stop scoring or physics.

No native Studio physics, graphics or FPS result is claimed by the cloud tests.
