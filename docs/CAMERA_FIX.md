# Cinematic/restart update v5 — replace THREE scripts

The gray screen returned after a fresh Play run. The previous visible screenshot
was not a permanent fix. User confirmation: only the server Realm was replaced;
no Workspace object was hidden/deleted. **The exact gray-screen cause is still
unconfirmed. This update requires actual Roblox Studio rendering tests.**

## Exact replacements — Stop Play first

Back up the place. Stop Play, then replace each entire source using its matching
raw file. Do not append source, create duplicate Realm scripts, paste Markdown or
use the Command Bar. Keep Config and RealmState unchanged.

| Raw file | Studio instance to replace | Type |
| --- | --- | --- |
| [World.lua](../roblox/ServerScriptService/World.lua) | ServerScriptService → World | ModuleScript |
| [Realm.server.lua](../roblox/ServerScriptService/Realm.server.lua) | ServerScriptService → Realm | Script, Enabled=true, RunContext=Legacy |
| [Realm.client.lua](../roblox/StarterPlayerScripts/Realm.client.lua) | StarterPlayer → StarterPlayerScripts → Realm | LocalScript, Enabled=true |

The server Realm starts with `-- Startup status is created BEFORE requiring any game modules.`
The client Realm starts with `-- Show startup progress BEFORE looking for the server's remotes.`
They are different files despite sharing the Studio instance name Realm.

**Save the place with Play stopped before testing.** The five-script architecture,
existing Config settings and in-memory gameplay remain. Persistence/custom HTTP/
TikTok remain disabled; no Node bridge is needed. Optional Roblox-native appearance
loading retains the existing Config setting.

Do not edit **Players → your name → PlayerScripts → Realm** for installation.
That is a temporary runtime copy. Edit **StarterPlayer → StarterPlayerScripts →
Realm** with Play stopped; its saved source is copied into PlayerScripts on the
next run. If a change disappears after Stop/Play, verify this distinction first.

## What changes

**Roam spawn:** The old Arrival at (0,35,22) is below the raised course. A separate
22×26 deck at (48,82,58) is outside the race lanes. Arrival moves to (48,83.2,58).
The server sets each player's RespawnLocation and places both an existing first
character and later respawns at (48,87,58), clearing falling velocity. This targets
real player characters only; racing NPC movement and scoring are unchanged. Roam
sets CameraSubject to the real Humanoid and starts the camera above/outside the deck.

**Automatic racing montage:** Every nine seconds repeats three three-second beats:
full-course overview, racing pack, then leader close-up. The director reads actual
replicated root positions. It locks a selected racer for that beat to avoid rapid
rank-change cuts and tracks movement smoothly. Wide packs that cannot fit safely
use the overview. There is no replay recording or invented racer movement.

**Podium montage:** Results first frame the winners who have actually reached the
finish/podium, then show the winner alone during the middle of the result period,
then return to the group. If winner models have not arrived or are missing, the
camera keeps the overview. Existing server celebration animation and particles
continue. No finish times, rewards, winners or NPC physics are changed.

**Safe framing:** Cinematic shots fit body/jump/giant space into the existing clear
portrait rectangle, using a 55-degree vertical FOV and 65–220-stud bounded distance.
Lens height must be at least 94 studs. Every shot uses an explicit lookAt CFrame
and optical-axis Focus. Changes between shots cut directly rather than flying
through scenery; tracking within a shot is smoothed. Viewport changes refit directly.
The original 170–850-stud full-course overview remains the fallback. Close-ups
intentionally frame the racers/podium rather than showing every course corner.
STREAM_CINEMATIC=false retains the fixed overview if a comparison is needed.

**Fresh-run render safeguards:** Stream View applies daylight and far FogStart/End
on every run. With STREAM_CLEAR_EFFECTS=true, it temporarily unparents Atmospheres
and disables all PostEffects beneath Lighting/current Camera, including late effects
and Bloom. Unlike a runtime Properties edit, these instructions run again on each
Play. Roam restores the original Atmosphere parents, effect Enabled values and
lighting/fog settings. Nothing is permanently deleted. Ambient gift colors, neon
geometry, auras, ribbons, crowns and particles remain active; screen-space bloom
is intentionally disabled during this isolation. STREAM_CLEAR_EFFECTS=false is an
optional comparison after the default is tested.

**Enclosing geometry:** The earlier lens check searched only RiftboundRealm, and a
ray beginning inside a solid object can miss its enclosing shell. The new scan
includes all Workspace BaseParts. Large scenery containing the lens is logged and
locally masked only while Stream View needs it. Original local opacity is restored
in Roam or when the lens leaves. Course parts and Humanoid models are protected;
server opacity, collisions and user geometry are not deleted/edited. This is a
bounded BasePart containment safeguard, not proof of the gray-screen cause. It does
not read or remove Terrain voxels or guarantee visibility against arbitrary meshes.

## Studio verification — do TWO fresh Play runs

1. Keep native streaming disabled for the first comparison. Press Play and confirm
   Output shows **[Riftbound render] revision=cinematic-v5**. If it still references
   only older revisions, the saved StarterPlayerScripts client was not replaced.
2. Confirm Stream View displays the course from gathering/countdown. During racing,
   watch the first nine seconds to see overview, pack and racer close-up beats. A race
   shorter than six seconds can finish before the first close-up beat.
3. Watch results: group podium, winner close-up, group again, then next overview.
   With no finishers, the overview and existing DNF UI should remain.
4. Toggle Roam/Stream. The actual player should stand on the raised side deck;
   normal camera controls should work. Reset the character once to check respawning.
5. Test portrait 390×844 and 1080×1920 plus desktop. Fit the phone emulator to the
   Studio window; the screenshot showed its top/bottom clipped by the tool panes.
6. Stop Play and start again without changing any runtime Properties. Repeat the
   Stream/Roam and race/results checks. Do not rely on edits made while Play runs.
7. If gray returns, capture the **complete [Riftbound render] and [Riftbound camera]**
   block plus the selected view. The new block includes effect-isolation counts,
   masked-enclosure count, current shot, optical-axis Focus, actual/rendered camera
   coordinates and effective course opacity. No candidate cause is yet confirmed.
8. Optional TEST TOOLS → RENDER CHECK creates the existing near-pink/far-green
   native cubes without changing the camera, race or score. Report which are drawn.

## Automated checks and limits

The full test suite uses mocks and geometry calculations, including race/economy
regressions, spawn rescue/respawns, Roam camera position, racer/podium shot selection,
actual-root following, bounds/framing, restoration of effects and exterior scenery
masks. Native Luau compilation covers five raw sources and five exported equivalents.
Exported/manual/bundle sources are checked against the raw files.

**Roblox Studio visual rendering, engine physics, actual restart behavior and native
streaming were not performed in the cloud.** The spawn correction and montage are
implemented; the gray-screen safeguard remains unverified until the tests above.
