# Stream View render diagnostic v4 — replace only Realm.client.lua

**The Stream View disappearance is not yet resolved.** User Studio tests report no
change after disabling Atmosphere density/haze, Blur/DepthOfField/ColorCorrection,
and native streaming. Roam still displays the arena; the player spawns underneath
the terrain. The spawn location is a separate issue and is not changed here.

The latest source keeps the v3 camera coordinates, framing, shell masks, daylight,
HUD and all server gameplay unchanged. It adds an opt-in native 3D render check and
more precise diagnostics instead of another unverified camera adjustment.

## Replace exactly one script

1. Back up the place and **Stop Play**.
2. Open **StarterPlayer → StarterPlayerScripts → Realm** (LocalScript).
3. Replace its entire source with
   [`roblox/StarterPlayerScripts/Realm.client.lua`](../roblox/StarterPlayerScripts/Realm.client.lua).
   Copy the actual raw Luau source, without Markdown fences. Keep one client Realm.
4. Leave **Config, RealmState, World and the server Realm** unchanged. There is no
   Command Bar installer, new ModuleScript or RemoteEvent.
5. Keep StreamingEnabled=false for this comparison. Press **Play**, remain in
   Stream View (the button says ROAM VIEW), and open **TEST TOOLS → RENDER CHECK: OFF**.
   The drawer closes and the check turns on. It creates two client-only neon cubes:
   a small **pink** cube 12 studs in front of the camera, slightly left of center;
   a **green** cube at (0,104,0), above the course. These are actual 3D parts, with no
   BillboardGui/AlwaysOnTop substitute. They cannot collide, touch or affect queries.
6. Capture the phone view and Client Output, including all **[Riftbound render]**
   lines. The revision must say **render-check-v4**. Report whether you see pink,
   green, both, or neither, and whether the course is visible.
7. Toggle **TEST TOOLS → RENDER CHECK: ON** to remove the cubes. Roam View or disabling
   the HUD also removes them. Returning to Stream recreates them only if the check
   remains on. Stopping Play removes all local changes.

The presentation log still says course-overview-v3 because that camera is unchanged;
**render-check-v4** identifies the diagnostic addition. Fit the emulated phone to
Studio's window so the full screen and buttons are visible.

## What this tests

| Observation | Evidence to investigate next |
| --- | --- |
| Pink and green visible, course hidden | Compare actual course opacity/materials with the independent parts. |
| Pink visible, green/course hidden | Distance-dependent rendering/culling or an obstruction along the distant sightline. |
| Neither visible, HUD visible | Active rendered camera, a screen overlay, or broader scene rendering failure. |
| Green visible, pink hidden | Check nearby geometry, camera overrides, and the near-probe position. |

These outcomes narrow the investigation; none alone proves a particular cause.
The near cube moves with the current camera; the green cube stays in world space.
Neither test changes Camera.CFrame, Focus, distance, FOV or the race.

Opacity is now computed as **(1 - Transparency) × (1 - LocalTransparencyModifier)**.
The previous independent thresholds could count a nearly invisible part as opaque:
Transparency=0.9 and local modifier=0.9 leave only 1% opacity. Logs now include both
raw values and their product for each course anchor, plus course min/mean/max.
Opaque counts require at least 95% effective opacity; presence/readiness uses its
own lower visibility threshold. No course transparency is forcibly changed.

GetRenderCFrame reports the native rendered position/direction beside CFrame.
Camera conflict diagnostics retain the maximum drift observed between ten-second
log intervals, including frames when logging was not due. A zero drift still cannot
exclude a different script writing after this callback. Existing anchor projection,
raycasts, bounds, Focus, local geometry and shell diagnostics remain available.
Part counts and successful raycasts do not establish that geometry was drawn.

## Safety and validation boundary

The four server sources are unchanged: NPC movement, checkpoint detection, actual
finish times, rounds, earnings, gifts and leaderboard scoring remain untouched.
Persistence and external TikTok/custom HTTP stay disabled. Optional Roblox-native
appearance loading retains the existing Config setting; the render check makes no
asset or network requests. No rendering effect is deleted or modified by the check.

Automated tests exercise opt-in creation, projection, camera-relative movement,
cleanup, no game actions, effective opacity, native-camera diagnostics via a mock,
and interval drift retention. Existing viewport/physics-model/round checks remain.
Native Luau compilation checks all five raw sources and five exported equivalents.
**No Roblox Studio visual rendering, real physics or native streaming test was run
in the cloud.** This is a diagnostic update, not a confirmed fix.
