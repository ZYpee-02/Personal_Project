# Fixed cinematic spectator camera — exact replacement

This update changes **only `roblox/StarterPlayerScripts/Realm.client.lua`**.
Your running physical Skybridge Sprint server, Config, RealmState and World are
unchanged. The five-script architecture, observed checkpoint/finish times, fictional
income, gifts, standings, rounds and podium logic remain intact. No installer,
plugin, custom HTTP, TikTok connection or persistence service is added.

## Replace exactly one script

1. Back up your working place and **Stop Play**. Open Explorer and the Script Editor.
2. Expand **StarterPlayer → StarterPlayerScripts** and open the existing **Realm
   LocalScript**. Do not edit the server Script named Realm.
3. Replace its **entire source** with the complete contents of
   [`roblox/StarterPlayerScripts/Realm.client.lua`](../roblox/StarterPlayerScripts/Realm.client.lua).
   On GitHub, use **Raw** or the file's copy button. Copy Luau source only, without
   Markdown fences. Do not append the new code or create a second LocalScript.
4. Keep **Config**, **RealmState**, **World**, and the server **Realm** exactly as
   they are in your working physical Sprint version. Keep the client enabled and
   named Realm. Keep HTTP Requests and Studio API Services access disabled.
5. Press **Play**, not Run. Open **Output**, including **Client** messages, and
   look for `[Riftbound camera]`. Stream View is the default unless your existing
   RiftboundStreamCamera player attribute disables it. The button reads ROAM VIEW
   while Stream View is active; clicking it switches to normal camera controls.
6. For a new install or a version older than physical Sprint, use all five complete
   files in [MANUAL_STUDIO_SETUP.md](../MANUAL_STUDIO_SETUP.md) instead. That document
   contains full, unescaped source blocks identical to the actual files. Your
   working physical Sprint place needs only the one replacement above.

There are no new module dependencies or remotes. The client still waits for the
server-created ReplicatedStorage.Riftbound Snapshot/Action/Notice RemoteEvents.

## What the investigation established

The supplied World.cameraBounds returns the same box whenever physicalSprint is
true: X -26..26, Y 54..88, Z -82..76, yaw 60°. RealmState keeps physicalSprint true
through gathering, voting, storm/race and result for Sprint. Automated execution of
those actual modules verified that behavior across two rounds and checked all 155
course BaseParts plus racer/jump envelopes against that box. No server edit is
needed for this version.

With correct inputs, the previous camera math also placed the camera well above
the map, not underneath it. Code review and executable tests found failure paths:

- No validation for missing/partial/inverted/NaN/infinite/oversized bounds. A finite
  oversized test box drove the old distance loop to approximately 13,150 studs;
  an unsuccessful fit was still returned as a valid camera view.
- Before bounds arrived, the default view targeted the original lower island,
  rather than the raised physical course. Bounds corrections were ignored while
  physicalSprint stayed unchanged.
- The render loop restored neither FieldOfViewMode nor Camera.Focus. Replacement
  cameras, resizing and competing camera scripts could leave inconsistent state.
- Persistent was described as a visibility guarantee. Its presence alone does
  not show whether the course has replicated on the current client or whether
  opaque geometry sits between the lens and the arena.

These are confirmed code paths, **not proof of the exact cause in your Studio
session**. The new diagnostics distinguish framing, absent/transparent geometry
and foreground obstructions. Roblox Studio was not available for this work.

## Fixed camera behavior

The camera keeps the **course center (0, 71, -3)**, **yaw 60°**, **elevation 52°**
and **vertical FOV 50°**. No racer tracking, result zoom, orbit or interpolation
moves it through geometry. Only viewport fitting or validated conservative bounds
padding changes distance. All phases use the same center and heading.

Every snapshot is checked for finite ordered coordinates, course coverage, bounded
padding and the expected heading. Bad/missing data uses the known Skybridge box;
the legacy lower-arena view is selected only when the server explicitly reports
physicalSprint=false. Valid padding is symmetric so it cannot shift the center.

The fit projects all eight envelope corners into the existing clear gameplay
rectangle, separate from the HUD edge panels. The fit is bounded to 120–850 studs;
it cannot grow into an unlimited zoom-out. A second position guard rejects values
below maxY+24, above Y=900, beyond X/Z ±700 or farther than 950 studs from focus.
It reconstructs a known fallback instead of clamping coordinates independently.

The render binding runs at RenderPriority.Last and reapplies Scriptable,
FieldOfViewMode.Vertical, FOV, CFrame and Focus. Viewport changes are also detected
in the render loop, and replacement CurrentCamera instances are rebound. Roam View
restores the saved FOV/mode and character camera subject.

A usable viewport is at least 64×64, at most 32768 per axis, with aspect ratio
between 1:4 and 4:1. Zero/nonfinite/transient/extreme viewports receive the known
390×844 camera fallback; the client refits as soon as a usable viewport returns.
It does not promise to fit the entire course into a one-pixel or extreme-aspect
viewport. Ten supported sizes, including 9:16 and 2160×3840, are checked numerically.

## Streaming is checked separately

The server's RiftboundRealm Model already uses ModelStreamingMode.Persistent.
This update leaves that policy and gameplay geometry alone. The client checks
SkybridgeSprint's actual BaseParts, opacity and six named start/finish/podium
anchors. The diagnostic readiness threshold is the current build's 155 parts.
If you customize the course, review this diagnostic count as well as its bounds.

If Workspace.StreamingEnabled is true and geometry is missing/partial, the client
can request **native Roblox geometry streaming** at the fixed course focus using
Player.RequestStreamAroundAsync. It permits one in-flight call, passes a five-second
timeout, waits at least 15 seconds between attempts, and attempts at most three
requests per Stream View session. Monitoring runs every ten seconds, so actual
retries can be farther apart. Returning successfully is **not** considered proof
that geometry loaded; part/anchor counts are checked again. Engine call completion
is governed by Roblox; the client does not launch additional calls while one waits.

This is an internal Roblox streaming request, not custom HTTP or a TikTok bridge.
No request runs when streaming is disabled or the course is already complete.
For the initial local fallback playtest, set **Workspace.StreamingEnabled=false**
in Studio Properties **before Play** and **Config.LoadAvatarAppearances=false** if
you also want zero authored appearance requests. The optional generated place
already has streaming disabled. Neither change is required for the camera fix.

## Temporary diagnostic logs

Logs appear at most every ten seconds during Stream View, plus the next frame
after phase changes, bounds-validation changes or re-entering Stream View. Typical
390×844 output has camera position near **(263, 402, 149)**, focus **(0, 71, -3)**,
distance about **448**, fit=true and vertical FOV 50. These values were calculated
with mocked geometry; they are reference values, not Studio observations.

The log includes:

- phase, viewport, lens coordinates, focus, fitted distance, fit flag, FOV/mode;
- validated bounds, heading, fallback reason, and a separate received-bounds line;
- StreamingEnabled, realm presence, model streaming policy, course part/opaque
  counts, anchors present/projected, native request count and geometry status;
- the first native raycast hit from the lens toward the focus, including distance.
  A floor hit near the focus is normal. A foreground hit near the lens identifies
  something to inspect; the camera does not dynamically chase or move through it.

Interpret the output as follows:

| Evidence | What it tells you |
| --- | --- |
| fit=true, six anchors projected, 155 opaque parts | Numeric framing and expected local course geometry are present; investigate real render/lighting/occlusion if still black. |
| model policy Persistent, parts=0 or anchors missing | The policy alone did not establish local geometry availability. |
| parts=155, opaque=0 | Geometry exists but is transparent or locally hidden; changing camera persistence cannot fix opacity. |
| fallback reason | Supplied bounds were missing or rejected; the known course view is used instead. |
| native request returned | Only the request completed; the subsequent geometry counts determine readiness. |
| ray hit very near the lens | Inspect that foreground object and its position/size/transparency in Studio. |
| ray=unavailable | The diagnostic raycast could not execute; this does not stop the camera/game. |

After the Studio check, change `local CAMERA_DIAGNOSTICS = true` near the top of the
client to **false** to stop temporary prints. Geometry monitoring and bounded
streaming recovery still function; this flag only disables logs.

## Automated checks and remaining Studio playtest

`npm run check` runs the full existing suite, added camera regressions and builds
all complete raw-source deliverables. `npm run check:luau` compiles all five raw
files and their five XML equivalents with the official native Luau compiler.

Added tests execute the actual camera math/full client with mocked Instances,
CFrames, projections and services. They cover ten supported resolutions, corrupt
bounds, all-phase server bounds, same-activity updates, full-course corners,
viewport recovery, replacement cameras, Roam controls, FOV/Focus overrides,
missing/partial/transparent geometry, mock ray hits and streaming-request limits/
failure behavior. Existing race/economy/leaderboard tests remain active, including
multiple automatic rounds with a command-following movement stub.

**No Studio rendering, physics, actual raycast, native geometry streaming or asset
loading was tested in this Linux environment.** In Windows/macOS Studio:

1. In Stream View, watch gathering → voting → race → podium → reset for at least
   three rounds. The entire course, five racers, gate and podium should stay
   visible; results should not move the camera. Verify times/income/standings.
2. Try 390×844, 720×1280, 1080×1920, 2160×3840, landscape and the actual 9:16 capture.
   Confirm all scenery is visible within the clear gameplay area, and check actual
   fonts/label occlusion visually. The HUD layout and label rules were not changed.
3. Resize/minimize/restore, respawn, switch Roam/Stream repeatedly, and test with
   your other camera scripts enabled. Check Client Output when an issue occurs.
4. Stop Play, test StreamingEnabled off, then on, and move the player body far from
   the arena. The frame should remain fixed; inspect local part/anchor counts and
   request logs to confirm actual replication. Do not rely solely on Persistent.
5. If black returns despite six projected anchors and opaque geometry, keep the
   latest diagnostic block and inspect its near-lens ray hit, actual Lighting/
   Atmosphere settings, and any other scripts modifying transparency or cameras.
   Those external conditions cannot be established by the mocked checks.
