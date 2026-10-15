# Phase 2 — exact replacement guide

Use this with your already-working Riftbound Live place. These are complete raw
Luau files, not patches, JSON, escaped source strings, or a Command Bar installer.
The five-script architecture and all three require paths stay unchanged.

## Replace all five files

1. Save a backup of your working Studio place with **File → Save to File As**.
   Stop Play before editing. Copy any custom HostUserIds/settings to your notes.
2. Open the five instances below in Studio's **Script Editor**. For each, select
   **all** old source and replace it with the matching complete source from the
   repository, or its individual code block in `MANUAL_STUDIO_SETUP.md`.

| Raw source in this repository | Existing Studio instance to replace |
| --- | --- |
| `roblox/ServerScriptService/Config.lua` | ServerScriptService → Config (ModuleScript) |
| `roblox/ServerScriptService/RealmState.lua` | ServerScriptService → RealmState (ModuleScript) |
| `roblox/ServerScriptService/World.lua` | ServerScriptService → World (ModuleScript) |
| `roblox/ServerScriptService/Realm.server.lua` | ServerScriptService → Realm (Script) |
| `roblox/StarterPlayerScripts/Realm.client.lua` | StarterPlayer → StarterPlayerScripts → Realm (LocalScript) |

3. Keep Explorer names extension-free and keep the three ModuleScripts as siblings
   of the server Realm Script. Do not move the client into StarterCharacterScripts.
4. Replace **all five** before pressing Play; the new server and client expect the
   new Config and snapshot fields. Do not leave older Realm copies enabled.
   Restore HostUserIds if needed, leaving the new Config fields present.
5. Keep `PersistenceEnabled = false`. HTTP Requests and Studio API Services access
   can remain disabled. Install no online helper, plugin or Node process.
6. Press **Play**, not Run. Runtime geometry, remotes and HUD are created by the
   scripts; do not manually add any of them in the saved place.

## Unattended first three rounds

With default Config in Studio:

- About 2–6 seconds: six labeled `Demo_` travelers enter through the gate; your
  player also has a local crew stand-in. The stream camera and HUD appear.
- About 12 seconds: optional Ward/Sail vote opens for 8 seconds. Do nothing for
  this test; no vote or Keeper action is required to compete or complete the loop.
- About 20–50 seconds: Starfall Scramble. Avatars walk the star ring, collect
  deterministic checkpoints, earn points/bounties and show floating income pops.
- About 50–60 seconds: results. The top three move to podiums, the champion gets
  a crown, the scene celebrates, prizes are credited, and the HUD names the winner.
- The next minute runs Skybridge Sprint; the third runs Heartseed Relay. Watch
  at least three full rounds (about three minutes) without using TEST TOOLS.
- Studio-only demo gifts cycle Bloom → Aurora → Giant every 18 seconds after
  the crew seed finishes. Follows deduplicate across targets. The UI labels all of
  these as simulated; no TikTok account, gift payment or external event is involved.

Round durations are nominal; rendering/network/server load can delay transitions.
The server intentionally does not grant time while paused or catch up many rounds
at once after a stall. It bounds income to each current phase deadline.

## What to verify visually in Studio

- Rigs visibly arrive and walk, with moving arms/legs and smooth positional updates.
- Starfall follows the inner collection ring; Sprint uses the raised checkpoint
  course; Relay carries a glowing orb between shrines and heartseed.
- Avatar labels show session money and current income. Green `+$` pops reflect
  actual credited deltas. Idle/result phases show $0/s and pay no passive income.
- Two world billboards show session and round money leaders. The portrait HUD
  shows session earners and competition point leaders. Result prizes/points freeze.
- Podium order agrees with competition results; giants return to normal size;
  auras, aurora ribbons, star showers, drifting clouds, runes and celebration motes
  are visible, readable and do not obscure every avatar.
- Confirm smoothness and performance at 6, 12 and 18 crew. Scene animation is
  capped at 12 server updates/s by default. Procedural particles are pooled Parts,
  not downloaded textures. This is not a benchmark or proven device performance.

## Stream framing and controls

The LocalScript fits a centered **480×854 (approximately 9:16)** safe canvas to the
viewport. In a landscape Roblox window, center-crop the game capture to 9:16 in
your stream software. The custom camera aims at the main arena, with closer podium
framing during results. Camera framing is fixed; the character can still exist and
move while watching the show. Test clipping in Studio's phone/device emulator.

The header starts below the upper safe margin; the bottom 136 logical pixels
(y=718–854) are left free for a stream application's lower controls. Actual TikTok
chat/UI placement varies: check a real capture later before going LIVE. No OBS or
TikTok stream connection has been configured or tested here.

**ROAM VIEW** restores the normal Roblox camera and character controls for walking
around the islands. **STREAM VIEW** returns to the arena view. **TEST TOOLS** keeps
all earlier join/vote/gift/follow functions and a Start Early button, but is not
needed for autoplay. Close that panel before recording the stream view.

## Useful Config switches

- `OfflineDemoEnabled = false`: no seeded Demo_ avatars or automated demo events.
  Your actual player's stand-in still enters, and rounds still run automatically.
- `AutoSimulateGifts = false`: keep seeded crew/rounds, but use tools for gift tests.
- `DemoStudioOnly = true`: keep the fake audience/events confined to Studio.
  They do not appear by default in a published server.
- `StreamCameraDefault = false`: start in normal roam camera instead.
- `SceneUpdatesPerSecond`: 4–30, default 12. Lower it on slow test machines.
- `AutoActivities = false`: keeps the earlier cooperative Ward/Sail loop available.
  Phase 2's default is true and should remain true for the autonomous competitions.

All avatar movement is scripted/kinematic, not Humanoid pathfinding or physics
combat. Real player outfits and TikTok integration remain separate future work.
No source file uses DataStoreService or external requests. Stop and Play again
resets money, crew, results, points, gifts, follows and shards.

## Validation limits

Run `npm run check` and `npm run check:luau` for source/dependency/API audits,
state/economy tests and native Luau compilation. A scheduler test drives the actual
server source through 185 simulated seconds with no players/host inputs, but its
World and Roblox services are mocks. It is **not** a Roblox Studio playtest.
Rendering, collisions, camera framing, UI readability, scale restoration, physical
player traversal and real device performance still need the Studio checklist.
