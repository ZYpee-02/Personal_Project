> Current v11 registration tournament: use [TOURNAMENT_REGISTRATION_REPLACEMENT.md](TOURNAMENT_REGISTRATION_REPLACEMENT.md) and replace all five sources. The v10 course itself is unchanged.

# Riftbound Live v10 — shared fantasy skyway

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

## Road and racing behavior

- A 64-stud-wide road winds through four sections. Real shallow banking and gentle
  climbs use native WedgeParts. Each cell is triangulated from shared boundary
  vertices; neighboring road sections meet edge to edge, without overlapping
  rectangles or an individual track for each avatar.
- Forks at gates 12–18 and 30–36 split the road into a broad main bridge and an
  inside shortcut. The opening and rejoin partition the same road cross-section.
  Both routes pass the same sequence of gates and reconnect before the next section.
  Each shortcut has one intentional three-stud jump; the main road has no gaps.
- The Moving Bridges section has a connected timber deck and moving slalom gates.
  Stone ruins, partial-width hurdles, sweeping gates and marble final turns offer
  routes around obstacles as well as jumps. No part of the running deck teleports
  or disappears under a racer. Fantasy islands, meadows, waterfalls, crystals,
  open portals and clouds remain outside the running surface.
- A five-column/four-row grid supports 20 starters together. The default cohort is
  **16** and the demo seeds 20 viewers. Up to 40 session members can rotate through
  cohorts, with new eligible viewers taking priority. Grid order rotates by round;
  grid slots are starting positions, not private routes or finishing positions.
- All racing roots move through server-owned Humanoid physics and MoveTo/Jump,
  with the same 12.5-stud/second walk speed and JumpPower 50.
  Steering considers nearby runners and gates; route choice uses current position,
  congestion and prior recovery risk. There is no name-based speed or winner timer.
  NPC body collisions with other NPCs are disabled through a dedicated collision
  group to avoid pileups; ground/hazard collisions remain active. Steering reduces
  crowd overlap, but native pushing/body-contact races are not being simulated.
- Each physical gate requires the selected route's corridor, grounded arrival,
  height and sequential progress. Cutting across a fork's empty median, leaving
  the road or skipping gates triggers recovery or rejects progress. Recoveries
  return to the last verified gate on the selected route and retain the clock.
  The finish time is interpolated at the shared finish plane. Late racers DNF.
- The 120-second deadline, fictional economy, gifts, measured leaderboard,
  automatic rounds, winner celebrations and queued avatar entrances remain.
  Native account verification/appearance loading is still optional; OFFLINE JOIN
  and procedural demo avatars work without account requests. For fully local
  testing set ResolveViewerUsernames=false and LoadAvatarAppearances=false.
  DataStoreService and real TikTok networking remain disabled.

## Spectator presentation

The director tracks the current leader and up to two nearby competitors, changes
subject when a real overtake changes the lead, periodically spotlights another
racer, identifies shortcut battles and switches to a dedicated finish shot.
It follows real roots instead of fitting the entire long course. The starting
shot samples the front grid so 20 entrants do not force a distant zoom-out.
The top five positions remain readable; the HUD includes the total racing field.
Entrance montages still queue/group without pausing physics, scoring or the deadline.

Stream/Roam toggles, elevated lens bounds, safe close shots, late camera ownership,
reversible atmosphere/effect isolation, local enclosure/scenery masking and named
Studio Baseplate hiding remain. Native visual checks are still required; cloud
projection tests cannot prove that Roblox renders a frame without occlusion.

## Available validation

See [SHARED_SKYWAY_TEST_RESULTS.md](SHARED_SKYWAY_TEST_RESULTS.md) for the completed
5/10/15/20 contact-model runs, timing and limitations. The route plan below is
procedurally generated documentation, not a gameplay screenshot.

![Shared road with two forks](SKYBRIDGE_ROUTE.svg)

## Required Studio playtests

1. Use a fresh Play for each SprintCompetitors setting: **5, 10, 15, 20**. Keep at
   least that many DemoNames. Leave entrances enabled and allow their initial queue
   to drain: the first race can have a smaller field; the next eligible cohort
   fills automatically. For equal comparisons disable optional appearance calls
   and simulated gifts first, then repeat with them enabled.
2. Watch at least three rounds per setting. Record measured finish spread, DNFs,
   falls by gate/route and stuck runners. Inspect actual wedge seams, banked-turn
   traction, Humanoid step-up/jump latency, shortcut takeoff/landing, moving-gate
   contacts and recoveries. Walk both branches manually in Roam if useful.
3. In Studio MicroProfiler and Stats record client/server frame time, physics
   time, memory, instance count and replication traffic for each field size.
   Repeat on the intended streaming PC and a published private server. The cloud
   interpreter's wall times are **not** Roblox FPS or a production capacity promise.
   Reduce SprintCompetitors if the native frame/physics budget is exceeded; do not
   compensate by assigning winners or moving roots along a timer.
4. Check pack overtakes, fork separation/rejoins, finish battles and newcomer
   montages at 390×844, 1080×1920 and landscape. Ensure the watched competitors stay
   large and in the clear HUD area, scenery masks restore in Roam, and every shot
   stays above the track. Test 20 simultaneous arrival requests and Stop/Play reset.
5. Repeat with loaded Roblox outfits, oversized accessories, gifts, a falling or
   dead leader, all DNFs and a camera replacement. Keep streaming disabled. Cloud
   tests cover state/command/projection behavior; native solver, animation,
   appearance loading, anti-occlusion, visual polish and live performance require Studio.
