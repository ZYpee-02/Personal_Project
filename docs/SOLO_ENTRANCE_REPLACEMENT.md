# Riftbound Live v13 — individual entrances and physical race preparation

This release replaces grouped introductions with **one full 4.5-second introduction
per accepted racer**, followed by an observed physical walk to a reserved grid
position. Registration still closes on its 30-second deadline. A separate locked
preparation phase finishes all accepted entrances and walks before READY/3/2/1/GO.

The shared v10 Skybridge course builder, checkpoint geometry, forks and obstacle
motion remain byte-identical. A separate **ChallengerLobby** adds a waiting terrace,
Star Gate floor and two shallow approach ramps connecting to the existing rear
start apron. No race-road mesh, obstacle or checkpoint was redesigned.

## Exact Roblox Studio replacement

Stop Play, save a backup, and replace **all five complete raw sources together**.
On GitHub select **Raw** for each file and replace its entire source:

| File | Studio parent → instance name | Instance type |
| --- | --- | --- |
| [Config.lua](../roblox/ServerScriptService/Config.lua) | ServerScriptService → Config | ModuleScript |
| [RealmState.lua](../roblox/ServerScriptService/RealmState.lua) | ServerScriptService → RealmState | ModuleScript |
| [World.lua](../roblox/ServerScriptService/World.lua) | ServerScriptService → World | ModuleScript |
| [Realm.server.lua](../roblox/ServerScriptService/Realm.server.lua) | ServerScriptService → Realm | Script, Enabled, RunContext Legacy |
| [Realm.client.lua](../roblox/StarterPlayerScripts/Realm.client.lua) | StarterPlayer → StarterPlayerScripts → Realm | LocalScript, Enabled |

Keep exactly one instance of each. Edit StarterPlayerScripts in the saved place,
not the runtime Players/PlayerScripts copy. Preserve your HostUserIds and deliberate
economy settings. Keep **SoloEntrances=true**, **AutoActivities=true**,
**SprintOnly=true**, **AutoJoinPlayers=false**, **PersistenceEnabled=false** and
**Workspace.StreamingEnabled=false**. Save, then start a fresh **Play**.

Expect server `[Riftbound] Ready` and client **presentation=solo-entrances-v13**.
The course revision deliberately stays **show-v10-shared-road**. The complete
five-source manual is also in MANUAL_STUDIO_SETUP.md. No extra game module or
Command Bar installer is needed. GitHub updates do not modify an open Studio place.
Real TikTok networking and DataStore access remain disabled.

## Automatic cycle and guarantees

1. **Empty lobby:** waiting scenery and the Star Gate remain animated indefinitely.
   WAITING FOR CHALLENGERS and COMMENT YOUR ROBLOX USERNAME TO JOIN are visible.
   Zero or one racer never starts a registration timer or race.
2. **Accept entries:** account verification precedes acceptance for ROBLOX JOIN.
   On acceptance, the racer immediately owns one of 20 configurable slots and is
   appended to the FIFO queue. Native Roblox user IDs deduplicate verified aliases;
   offline testing uses a separate username identity. A known session account
   retains earnings/history across a verified username change. Case duplicates,
   same-window identity re-entry, replayed event IDs and invalid names are rejected.
3. **Open registration:** the second racer starts a 30-second timer. Registration
   stays open during introductions until capacity/deadline. Withdrawing below two
   cancels the timer. Reserved grid positions of remaining racers never shuffle.
4. **Solo Star Gate entrance:** one accepted racer appears at the portal for the
   full configured **4–5 seconds** (default **4.5**). No bursts, groups, shortening
   or queue-expiry rules apply to accepted entrances. NEW CHALLENGER appears first,
   then the complete username. Front/full-body, side and close-up shots, varied
   poses, colored crystals, flames, sparks, smoke and pooled motes provide variety.
5. **Physical grid walk:** only after the solo ends does that racer run along the
   shallow approach and existing start apron using server-owned Humanoid MoveTo
   commands. The next solo waits for observed arrival at the reserved position.
   Ready racers remain on the grid, anchored for warm-up poses. Normal walking
   never warps a racer directly to the grid. Falls/stalls recover first to a safe
   waypoint, then to the grid if recovery fails again; these recoveries are marked
   separately from race recoveries. A timer alone cannot acknowledge readiness.
6. **Close registration:** the roster locks at the registration deadline. Late
   requests and delayed verification are rejected and never carried to another
   round. Pending accepted entrances remain in FIFO order. PREPARING RACERS shows
   ready/total, current racer and pending counts. No new competitors enter here.
7. **Launch:** once every accepted racer has completed their solo and reached the
   grid, the existing front/side/rear lineup, cosmetic fire and READY/3/2/1/GO play.
   All start together at GO. The race clock is **120 seconds from GO**, with the
   original equal race WalkSpeed restored after pre-grid movement.
8. **Race/results:** the v12 racing broadcast, physical navigation, alternate routes,
   measured checkpoints/finish times, DNFs, cosmetic power-ups, earnings and top-three
   celebration continue. Giant gifts are deferred during preparation and racing,
   so they cannot distort colliders; their celebration remains available afterward.
9. **Fresh window:** after results, active participants and pending entrances are
   cleared, a new round ID opens empty registration, and everyone must submit again.
   Session balances, cumulative wins and historical results remain separate.

Twenty solos account for **90 seconds of introductions** at the default duration.
Sequential physical walking adds time to that; 90 seconds is not a promised total
pre-race duration. The next introduction deliberately waits for the previous walk.
Two racers who finish preparation early still wait only for the existing registration
deadline and launch countdown. There is no additional fixed montage delay.

## Appearance handling and recovery

ROBLOX JOIN uses supported native account lookup and HumanoidDescription/R6 avatar
creation. Verification failures reject an unverified entry before it is accepted;
use OFFLINE JOIN for a test without verification. Appearance loading starts after
slot reservation. A failed/hung outfit request uses the existing fallback rig after
a bounded wait (AppearanceTimeoutSeconds=8 by default), preserving registration
and FIFO order. Late appearance models are discarded after the queued loading stage
or when their record/round expires; they cannot replace a walking or racing root.

Grid readiness is a server-only observation, scoped by round ID and entrance
sequence. It checks the actual root against its target and a ground observation.
There is no client action to mark a racer ready or produce a finish. Repeated query
failures or destroyed floor geometry should keep the launch gated, rather than
launch unsafe actors; verify recovery on native Studio physics before going live.

## Offline controls and future bridge

Open **TEST TOOLS**. **JOIN 2 / JOIN 5 / JOIN 10 / JOIN 20** sends a simultaneous
batch of offline requests named Test_Racer1…20 to the current registration window.
Each accepted entry still uses the real solo queue, full duration and walk. A second
batch in the same window deduplicates existing names; closed/full lobbies reject
excess requests. OFFLINE JOIN supports a custom username; ROBLOX JOIN verifies a
real account. WITHDRAW ENTRY and TEST STALE ROUND remain available.

DEMO TESTING is a separate explicit opt-in, OFF by default. It submits fresh events
per round and never bypasses preparation. Turn it off to test empty unattended
waiting. Normal operation never seeds or re-registers previous participants.

The server-only RiftboundEvent BindableFunction still accepts copied envelopes:
`{type="register",username="RobloxName",roundId=currentRound,eventId="unique:id",submittedAt=serverIngressTime,offline=false}`.
Capture round/time at ingress and preserve them on retries. Native verification
rechecks the original window after yielding. Canonical identity comes from lookup,
not a caller-provided appearance ID. This is a future adapter boundary, not an
external TikTok connection. Read-only snapshots add preparation, entrance.stage,
reservedGrid, preparationStatus, introductionCount and preparationRecoveries.

ROAM VIEW remains a manual camera override; STREAM VIEW resumes the current live
shot. Manual Roam/Hold does not stop the server's preparation or racing state.

## Required native playtest

Test both 390×844/1080×1920 portrait and landscape Studio viewports. Inspect loaded
outfits, readable long usernames, portal emergence, all five idle poses, ramps,
physical grid arrival, unique positions, stalled/fallen recovery, queue progress,
closed-window rejection, fire/GO synchronization, restored race speed and the entire
race/podium/fresh-registration cycle. Repeat with 2, 5, 10 and 20 actual avatars;
profile native Humanoid, outfit and particle costs. Verify no camera black screens,
clipping, prolonged obstruction fallback or empty shots, including manual overrides.

[Automated results and limits](../docs/SOLO_ENTRANCE_TEST_RESULTS.md) distinguish
cloud state/command/projection checks from native rendering, animation and physics.
