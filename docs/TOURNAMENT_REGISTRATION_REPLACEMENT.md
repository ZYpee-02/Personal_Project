# Riftbound Live v11 — fresh registration and cinematic tournament

The shared v10 track is unchanged. This update changes race entry, presentation
and actor lifecycle around it. **Replace all five complete raw sources together.**

## Exact Studio replacement

Stop Play, save a backup, then use GitHub **Raw** to replace each entire source:

| Complete file | Studio parent → instance name | Type |
| --- | --- | --- |
| [Config.lua](../roblox/ServerScriptService/Config.lua) | ServerScriptService → Config | ModuleScript |
| [RealmState.lua](../roblox/ServerScriptService/RealmState.lua) | ServerScriptService → RealmState | ModuleScript |
| [World.lua](../roblox/ServerScriptService/World.lua) | ServerScriptService → World | ModuleScript |
| [Realm.server.lua](../roblox/ServerScriptService/Realm.server.lua) | ServerScriptService → Realm | Script, Enabled, RunContext Legacy |
| [Realm.client.lua](../roblox/StarterPlayerScripts/Realm.client.lua) | StarterPlayer → StarterPlayerScripts → Realm | LocalScript, Enabled |

Keep your HostUserIds and intentional economy values. Keep AutoActivities=true,
SprintOnly=true and AutoJoinPlayers=false for this tournament. Keep one instance of each
script. Edit StarterPlayerScripts, not a runtime Players/PlayerScripts copy. Keep
**Workspace.StreamingEnabled=false**, save and start a fresh **Play**. HTTP Requests
and Studio API Services access remain unnecessary. MANUAL_STUDIO_SETUP.md contains
the same five complete source blocks. No new game module or installer is required.

Expect server `[Riftbound] Ready` and current client `presentation=broadcast-v12`.
For v11 installs, the [v12 broadcast update](BROADCAST_CAMERA_REPLACEMENT.md)
requires only replacing the client; the registration rules here still apply.
The course revision deliberately remains `show-v10-shared-road`: its road builder,
shared checkpoints, branching geometry and obstacle motion have not changed.
GitHub updates do not automatically modify an open Studio place.

## The automatic cycle

1. **WAITING FOR CHALLENGERS.** Registration is open with an empty roster, animated
   scenery and Star Gate, a slow lobby camera, username instructions and free slots.
   Zero or one registered viewer causes no countdown and no empty race, indefinitely.
2. The second valid registration starts the configurable **30-second registration
   timer**. More entrants can join until it expires, up to **20** by default.
   A withdrawal below two cancels the timer; a new second registration restarts
   the full timer. Names are deduplicated case-insensitively within the window.
3. At closing, the roster locks immediately. Pending entry requests and entrance
   montages are cancelled; all admitted racers are staged on the existing grid.
   A four-second **READY — 3 — 2 — 1** sequence plays with flames, smoke and sparks.
   **GO!** opens the visual gate and starts the physical 120-second race. The initial
   wide shot includes the whole registered field, then returns to recognizable packs.
4. Physical Humanoid navigation, overtaking, route selection, grounded checkpoints,
   measured finish crossings, fictional earnings and DNFs retain the v10 rules.
   Closed-window submissions are rejected, not saved for the next race.
5. Results announce actual finishers and show the top three available podium places,
   usernames, measured times and fictional prizes. Confetti, sparklers/fireworks and
   victory poses play. Fewer than three finishers never creates invented winners.
6. The active roster, entry queue and highlight queue clear. After the podium period,
   the next registration window opens with **zero entrants** and a new round ID.
   Every previous participant must submit again. Session balances, gifts/follows,
   wins, best times, finish/DNF counts and bounded recent history remain in memory.

The session ledger and active actors are separate: only registered/current-result
avatars are retained, up to the 20-racer target. Old actors and pending appearances
are removed on reset. Up to MaxSessionMembers=500 distinct names retain statistics;
recent race history keeps 50 rounds. These are explicit memory limits, not saves.
Inactive ledger members do not accumulate new race income while waiting unregistered.

## Offline controls and demo testing

Normal defaults are **OfflineDemoEnabled=false**, **AutoJoinPlayers=false** and
**AutoSimulateGifts=false**. An empty initial lobby is intentional. Roblox accounts
are not automatically entered just because the host opens Studio.

Open **TEST TOOLS** in Studio (or as an authorized host):

- **OFFLINE JOIN:** enter a username and submit one procedural stand-in during the
  currently displayed registration window. Repeat with another name to start the timer.
- **ROBLOX JOIN / VERIFY ACCOUNT:** validate the native Roblox account and request
  its appearance. Optional API timeout/failure keeps the supported fallback. Outfits
  that finish loading during a race are deferred to a safe presentation phase.
- **WITHDRAW ENTRY:** remove an open-window entry; test cancellation below two.
- **TEST STALE ROUND:** deliberately submit the previous round ID and see rejection.
  Also try JOIN during countdown, racing and results: it must be rejected immediately.
- **DEMO TESTING: ON/OFF:** an explicit Studio-only option by default. When enabled,
  the demo sends fresh scoped registration events for DemoNames in each new window.
  It never bypasses capacity, roster locking or reset. Disable it to stop future
  demo submissions; let any current registered race finish, then expect an empty lobby.
- **TRAIL VISUAL / SHIELD VISUAL / STARBURST:** activate cosmetics on the named active
  racer. All have the same 12-second cooldown, four-second effect and 1.5-second
  queued camera highlight. **They do not change speed, jump, collision, immunity,
  checkpoints, rewards or scoring.** Gift money cannot buy a racing advantage.
- DemoPowerups=true showcases those cosmetics automatically **only while explicit
  demo testing is enabled**. AutoSimulateGifts=true separately enables simulated
  gifts/follows in demo races. Existing cosmetic gifts/sky effects remain available.
- **ROAM VIEW / STREAM VIEW**, hold-camera and render-check controls remain.

No streamer button is required to advance a populated race. Real TikTok comments
are **not connected yet**; use these controls or the server-only interface below
for offline registration. For zero authored account requests also set
ResolveViewerUsernames=false and LoadAvatarAppearances=false.

## Camera and effects

The director covers the full starting grid, nearby packs, changes of position,
periodic other competitors, shortcuts, power-up close-ups and finish battles.
Finish contests take priority over power-up highlights. The highlight queue is
bounded to 12, coalesces a racer's queued visual and expires stale requests after
five seconds, so bursts cannot take over the show. Effects still activate when a
camera request is dropped. Entrance montages queue/group during registration;
unfinished ones end when the roster locks so they cannot delay or interrupt racing.

Waiting actors rotate through waving, stretching, cheering, looking around and
celebrating. Racing animations touch massless limbs/cosmetics, never the race root.
Fire, smoke, sparks, trail attachments and shield bubbles are presentation only;
there is no fire damage or additional collidable course geometry. Shared start
and podium effects use fixed pools instead of a fire emitter for every entrant.

Nearby shots ease smoothly. Widely separated subjects use a safe handoff rather
than flying through empty space, with a brief gold overlay that is always at
least 90% transparent. Elevated lens limits, view fitting, fog/effect isolation,
local occlusion masks and manual Roam override preserve the camera safeguards.

## Future server event contract — no networking installed

A future trusted server adapter can invoke ServerScriptService.RiftboundEvent
(BindableFunction). This hook already exists; it does not poll a service or read
TikTok. A registration envelope is:

```lua
{
    type = "register", -- legacy "join" alias obeys the same strict contract
    username = "RobloxUsername",
    roundId = currentSnapshot.registration.roundId,
    eventId = "adapter:unique-comment-id",
    submittedAt = receivedAtServerClock, -- os.clock() at ingress on this server
    offline = false,
}
```

Capture the round ID and ingress time **once when the comment is received**.
Preserve them and the event ID through queuing/retries. Never assign a new round
or timestamp while replaying an old comment. Never prequeue closed-window comments.
The hook rejects missing IDs, stale/future windows, duplicates and closed/full
registration; the domain rechecks after a yielding account lookup. Queue envelopes
are copied, so callers cannot mutate a request already waiting for processing.

Withdrawal uses type="withdraw" and the same scoped fields. Cosmetics use
 type="powerup", kind="trail"/"shield"/"starburst", the active round ID and a fresh
server-clock timestamp captured during the race. Those cosmetics are not gift
advantages. The client test controls stamp requests on the server and include the
round ID shown when clicked. The trusted adapter must keep any viewer identity or
account-ownership policy separate; username validity is not an ownership claim.

## Required Studio checks

Cloud test results are in [TOURNAMENT_TEST_RESULTS.md](TOURNAMENT_TEST_RESULTS.md).
Native rendering, physics and performance remain unverified here. In fresh Play:

1. Leave the normal lobby empty for several minutes; try one registration. Verify
   no countdown, no race, visible scenery/portal and clear username instructions.
2. Register two, withdraw one, add another, then fill 15/20 slots. Test duplicates,
   full capacity and late requests during all closed phases. Use a slow/failing
   account lookup and prove its old request cannot spill into a later round.
3. Inspect every waiting pose, names, entrance grouping, READY/3/2/1/GO fire timing,
   all-field start shot, pack/overtake/shortcut/power-up shots, manual Roam and
   return transitions at 390×844, 1080×1920 and landscape. Check smoke and outfits
   do not obscure racers or cause gray/black frames.
4. Test simultaneous cosmetic events, cooldown/replay rejection, finish priority,
   trail rendering, shield pulses, fireworks/confetti and actual top-three rewards.
   Check native attachments, limb joints and loaded R6 appearances.
5. Run at least three physical races each with 5, 10, 15 and 20 competitors. Record
   actual finish spreads, DNFs, recovery gates and frame/physics/replication costs
   in Studio Stats/MicroProfiler on the intended streaming PC/private server.
   The cloud contact approximation is not native Humanoid grounding or a Roblox
   FPS measurement. Verify default Workspace.Gravity=196.2 for jump comparisons.
6. After results, verify the roster/queue and old avatars clear, money/history
   persist, and nobody reappears without a fresh registration (unless the explicit
   demo option sends fresh test submissions). Repeat Stop/Play to verify defaults.

Keep streaming, DataStoreService and real TikTok networking disabled for this test.
