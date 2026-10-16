# Phase 2 presentation update — exact replacement guide

This update changes presentation only. Automatic rounds, scoring, income, viewer
joining, simulated gifts/follows and the startup repair remain intact. All data
remains in memory. No save-service access, external requests or TikTok connection
is used. Keep the existing five-script architecture.

## Replace these two complete files

| Complete raw source | Existing Studio instance | Action |
| --- | --- | --- |
| `roblox/ServerScriptService/World.lua` | ServerScriptService → World (ModuleScript) | Replace entire source |
| `roblox/StarterPlayerScripts/Realm.client.lua` | StarterPlayer → StarterPlayerScripts → Realm (LocalScript) | Replace entire source |
| `roblox/ServerScriptService/Config.lua` | ServerScriptService → Config (ModuleScript) | Unchanged |
| `roblox/ServerScriptService/RealmState.lua` | ServerScriptService → RealmState (ModuleScript) | Unchanged |
| `roblox/ServerScriptService/Realm.server.lua` | ServerScriptService → Realm (normal Script) | Unchanged |

1. Save a backup of the working place, then **Stop Play**. Edit the saved scripts,
   not copies under Players in a running test session.
2. Open World and the client Realm in Studio's **Script Editor**. Select all source
   and paste the entire corresponding raw file. Do not append code or paste into
   the Command Bar. Do not include Markdown fences. Replace both together: the
   client expects the new compact, tagged labels created by World.
3. Keep names extension-free and retain the exact parents/types. Leave the server
   Realm enabled with RunContext Legacy and the client enabled. Do not add a sixth
   script or manually create GUI/remote objects.
4. `MANUAL_STUDIO_SETUP.md` contains all five complete source blocks. If your
   copies are mixed, restore all five from that guide, then restore your custom
   Config values. Config, RealmState and the server Realm are byte-identical to
   the working startup repair (`5e187df`).
5. Keep PersistenceEnabled false, HTTP Requests disabled and Studio API Services
   access disabled. No Node process/plugin/publication is required.
6. Press **Play**. SERVER Output should still print `[Riftbound] Ready`. Observe
   three automatic rounds without opening TEST TOOLS. Compare against the checks
   below at the listed resolutions. Stop/Play clears all game state.

## What changes on screen

The centered 480×854 logical canvas has separate, fixed zones. Uniform scaling
preserves their gaps at every aspect ratio. Text stays on one line, truncates with
an ellipsis and is clipped within each panel instead of spilling into another.

| Zone | Logical bounds (x, y, width, height) | Behavior |
| --- | --- | --- |
| Camera / tools buttons | 216, 18, 240, 30 | Two buttons with a 12px gap |
| Activity/countdown | 24, 56, 432, 64 | Compact top header |
| Gifts/notices | 24, 128, 432, 28 | One replaceable notice, never a stack |
| Clear arena area | 16, 166, 448, 344 | No ordinary HUD panel here |
| Top Earners | 24, 522, 210, 110 | Three session-money rows |
| Round Leaders | 246, 522, 210, 110 | Three competition-point rows |
| Round information | 24, 640, 432, 64 | Voting, income/team progress, or winner/prize |
| Offline status | 24, 708, 432, 10 | Small secondary footer |
| Reserved lower LIVE area | y=718–854 | No ordinary game HUD |

Results reuse the round information panel; no central banner opens. Leaderboards
show compact money/point values. The dock shows the leading earner's current $/s
outside the vote/result phase. Full usernames remain in game state; long strings
may show ellipses in narrow rows.

TEST TOOLS is a deliberate debugging overlay: opening it hides both leaderboards
until it closes. The header and round dock stay separate. No testing controls are
needed for normal gameplay.

## Camera and world labels

- A 50° vertical-FOV camera fits the **entire main island/arena**, its bedrock,
  routes and giant-avatar envelope into the clear area. It recalculates on viewport
  changes and keeps the same wide composition during results. Distant side islands
  remain scenery and may be outside a portrait crop.
- STREAM VIEW applies the fitted camera immediately. ROAM VIEW restores the normal
  character camera and saved FOV/mode. In landscape, crop to the centered 9:16
  canvas; the camera accounts for that narrower crop.
- World money boards moved to opposite side islands. They are hidden in stream
  view and appear nearby in roam (95 studs) if they fit without intersecting another
  accepted label/HUD panel. Scenery captions are hidden in stream and limited to
  70 studs in roam.
- Each traveler has **one** BillboardGui: a name row and a separate rising earnings
  row. Session balances/$/s no longer repeat over all 18 avatars. Pops still reflect
  credited deltas; suppressing a label never suppresses income, movement or scoring.
- The client projects rectangles, checks HUD/label intersections, and selects at
  most **four names in stream**, **six in roam**, **two earnings rows**. Winners,
  gifts and the leader take priority; other names rotate every five seconds. Some
  names will be hidden in a crowd.
- Billboard sizes/fonts follow canvas scale. The offset above each head adapts to
  camera depth, including giant rigs. Labels are not always on top; normal engine
  occlusion applies. Selection refreshes about 8 times per second, so brief crossing
  overlaps between refreshes remain possible.
- Native Humanoid names are hidden locally in stream and restored in roam. The
  client also handles label attributes arriving after the instance.

## Resolution checks and limits

Automated checks use the actual client layout/camera functions and instantiate
the entire client and World with mocked Instances, CFrames and services. They
exercise 18 long-name viewers, all phases, the tools drawer, nearby roam boards,
label budgets/intersections, gift enlargement/expiration and credited pops. They
check text row sizing, no wrapping/truncation settings and uniform scaling.

| Viewport | Canvas scale | 16px logical row font after scale |
| --- | --- | --- |
| 320×568 | 0.665 | 10.6px |
| 390×844 | 0.813 | 13.0px |
| 720×1280 | 1.499 | 24.0px |
| 1080×1920 | 2.248 | 36.0px |
| 1920×1080 | 1.265 | 20.2px |
| 844×390 | 0.457 | 7.3px |
| 1200×1920 | 2.248 | 36.0px |

These establish arithmetic bounds, **not rendered font measurements**. The short
844×390 landscape viewport fits structurally but its portrait crop is only about
219×390 pixels; use a larger/portrait capture for readable stream text. Status and
footer text is smaller than leaderboard rows. Check real glyphs, ellipses and
readability on your intended device/capture.

No Roblox Studio session was run for this update. The user reported the preceding
Phase 2 working, with visual clutter. This version still needs:

- Device Emulator checks at 390×844, 720×1280, 1080×1920 and landscape/cropped capture.
- Fonts/ellipses with 20-character names and large balances/scores.
- Camera clipping, avatar visibility, giant scaling and occlusion while moving.
- Three full rounds, all gifts, tools open/closed, and Roam/Stream switching.
- Performance at 6/12/18 viewers and two-client behavior; no FPS claim is made here.
- Actual TikTok interface/capture placement later; no platform is connected.

Run `npm run check` and `npm run check:luau` for tests, source/API audits, build
identity checks and native compilation. See `docs/PLAYTEST.md` for the complete
Studio checklist and `docs/SOURCE_VALIDATION.md` for compiler details.
