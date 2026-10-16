# Skybridge Sprint — exact five-file replacement

Replace **all five complete sources together**. Config, RealmState, World, server
and client all changed. The earlier two-file presentation replacement is no longer
sufficient. No sixth script, plugin, Command Bar installer or Node process is needed.

| Complete raw file | Exact Studio instance |
| --- | --- |
| `roblox/ServerScriptService/Config.lua` | ServerScriptService → Config (ModuleScript) |
| `roblox/ServerScriptService/RealmState.lua` | ServerScriptService → RealmState (ModuleScript) |
| `roblox/ServerScriptService/World.lua` | ServerScriptService → World (ModuleScript) |
| `roblox/ServerScriptService/Realm.server.lua` | ServerScriptService → Realm (normal Script) |
| `roblox/StarterPlayerScripts/Realm.client.lua` | StarterPlayer → StarterPlayerScripts → Realm (LocalScript) |

1. Back up the working place. **Stop Play** before editing. Keep notes of custom
   host IDs/settings; do not copy your old Config over the new source wholesale.
2. Open each instance in the **Script Editor**, select all source, and replace it
   with its entire matching raw file. `MANUAL_STUDIO_SETUP.md` contains all five
   complete Luau blocks too. Copy source only, without Markdown fences. Do not
   combine files, append code or use the Command Bar.
3. Keep the names extension-free and types/parents exactly as above. Leave server
   Realm enabled with RunContext Legacy. Keep one enabled client LocalScript.
4. Restore HostUserIds if needed. Keep PersistenceEnabled false. HTTP Requests and
   Studio API Services access stay disabled. No TikTok bridge is started.
5. Choose appearance mode: default **LoadAvatarAppearances=true** permits the two
   native Roblox avatar APIs and their normal Roblox asset loads. For a completely
   local fallback-only test, set it **false**. No HTTP setting is needed for either.
6. Press **Play**, not Run. SERVER Output should print `[Riftbound] Ready`. Five
   Demo_ NPCs seed automatically in Studio, with immediate physical fallback rigs.
7. Watch gathering (12s), optional vote/countdown (8s), a physical race (up to 80s),
   then results (10s). The race ends early once every entrant has finished or DNF'd.
   Observe at least three rounds, allowing about six minutes if they all time out.

## What is implemented

The raised course has five equal-width lanes, twelve sequential pads, changes in
height, gaps, moving wind gates, a start platform, finish arch and podiums. All
racers use identical WalkSpeed/JumpPower and server-owned unanchored R6 assemblies.
The invisible collider has uniform dimensions; visible body parts are massless and
non-colliding. Humanoid MoveTo and grounded jump commands drive the racers.
Procedural joint poses animate their limbs without moving racing roots by script.

The server samples physical root positions about 20 times/s. A grounded root must
reach each pad in order. The last gate requires a real forward crossing of the
finish plane within its lane/height envelope. Finish timestamps interpolate between
the two bracketing samples: they are measured observations, not theoretical times.
Standings use verified checkpoints and physical segment progress, then finish time.
Usernames, balances and gifts do not select winners.

Falls, implausible displacements and six-second stalls return a racer to its last
verified pad. The clock continues, and reset teleports grant no checkpoint. Dead or
missing rigs DNF; dead rigs rebuild during a break. Timeouts are DNFs, never invented
finishers. With no finishers there is no champion, prize podium or victory bonus.

Completed gates pay $2, each finish pays $40, and placements 1/2/3 pay an additional
$120/$75/$40. Passive income, voting bonuses, session caps and shard bonuses remain.
All money is fictional session currency, not Robux. Rewards pay once. Exactly equal
observed finish times share placement/bonus; the podium displays at most three rigs.
All five finishers still get tracked placements, including fourth and fifth.

Up to five crew members enter each race. Extra/later usernames wait for a later
cohort; cohorts and lane assignments rotate between rounds. Default AutoJoinPlayers
is false so the Studio host spectates and exactly five Demo_ rigs seed. JOIN tools
still enqueue usernames; AutoJoinPlayers=true restores automatic player stand-ins.
DemoStudioOnly keeps the fake audience/gifts confined to Studio by default.

## Appearance loading and strict offline mode

Five configured Roblox IDs supply cosmetic appearances for the five Demo_ labels;
these are not connected LIVE viewers or claims about who is watching. Current
player stand-ins can use that player's numeric ID when AutoJoinPlayers is enabled.
Manually typed usernames remain labels and use fallback rigs: no username/account
lookup is performed.

World.loadAppearance guards the only two authored account API calls:
Players.GetHumanoidDescriptionFromUserIdAsync and
Players.CreateHumanoidModelFromDescriptionAsync (R6). Loading runs asynchronously
once per crew rig. Scripts/Tools are stripped, movement settings/colliders normalized,
and a successful appearance installs only outside a race. Failures retain the ready
fallback. Results arriving after the 8-second soft deadline are discarded/cleaned
up. Roblox requests already in flight cannot be canceled by this deadline.

Set LoadAvatarAppearances=false for zero authored account/appearance requests. The
same playable physical rigs, rounds and effects remain. DataStoreService, custom
HTTP and TikTok networking are absent in both modes. The optional Node integration
remains outside this five-file game.

## Camera, labels, results and gifts

The existing portrait edge HUD and label budgets remain. Sprint standings show
checkpoint counts or actual finish seconds/DNF. The winner/prize stays in the lower
dock, with the top three on the finish-island podium. NPCs are physically driven
only during racing; staging and celebrations use scripted positioning.

The spectator camera fits a fixed box around the whole raised course, jumping
avatars and podium at a diagonal angle. It does not chase a root or zoom into the
floor. Bounds are recomputed on resize/arena changes, including landscape center
crops. The complete procedural realm uses ModelStreamingMode.Persistent so it
remains loaded even when the player's body is far from the camera. Fog/atmosphere
were reduced for the wider view; geometry is retained between rounds, not destroyed.

Aurora/Bloom/aura effects remain cosmetic. **Giant body scaling waits until a break**
if the gift arrives during a physical race; the aura still appears immediately.
The queued size celebration lasts six seconds at the break even if the original
18-second effect expired during the race.
This prevents size, legs or collider changes from changing race performance.

SprintOnly=true repeats Sprint by default. Setting it false restores the previous
Starfall/Sprint/Relay rotation. Starfall and Relay retain their earlier kinematic
demonstrations; Sprint always requires real checkpoint observations in either mode.
TEST TOOLS remains optional. Stop/Play resets every balance, vote, gift and result.

## Automated evidence and Studio checks still required

`npm run check` runs rule/economy/bridge/startup/presentation tests and builds the
complete sources, equivalent place and ZIP. `npm run check:luau` compiles all five
raw sources and all five XML equivalents with native Luau. Sprint tests cover
gate ordering/replays/stale rounds, no elapsed-time auto-finishes, all five measured
placements/ties, one-time money, five-entry/late cohort behavior, fall/stall resets,
physical ownership/commands, appearance off/failure/success/timeout and camera bounds
at seven resolutions.

An end-to-end test runs the actual server, World and client for several rounds with
a command-following movement stub. Other tests manually feed root positions. These
tests **do not simulate Roblox physics, collisions, jump arcs, actual asset loading,
streaming or GPU rendering**. No Studio playtest was performed for this update.

In Windows/macOS Studio, verify:

- All five rigs load or fall back without delaying rounds. Try appearance mode on
  and off; test service failure/timeout and ensure no mid-race body replacement.
- NPCs actually walk, jump the two-stud gaps/rises, navigate all twelve pads and
  cross the finish. Confirm changing positions produces changing results. A stuck
  bot should retry/reset, then DNF at timeout rather than receive a fake finish.
- Temporarily block a lane or drop a racer: only its last verified pad is restored,
  its clock continues, and it does not gain checkpoints or duplicate rewards.
- At least three rounds reset/repeat; late JOIN participants rotate in; dead rigs
  rebuild; podium order, printed seconds and money agree with the physical race.
- Giant/aura/Bloom/Aurora remain visible, size stays normalized during a race, and
  size restores during breaks. Check animations and collisions with real R6 outfits.
- At 390×844, 720×1280, 1080×1920 and landscape capture, the full course/racers are
  visible, fonts readable, labels controlled, and the camera never enters geometry.
- Test StreamingEnabled on/off in Workspace Properties, player respawn and Roam /
  Stream switching; the procedural world should remain visible and loaded.
- Observe performance with five physical racers and 6/12/18 total crew, plus two
  clients. No FPS or successful physics traversal has been claimed from cloud tests.
