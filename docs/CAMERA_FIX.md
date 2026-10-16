# Stream View direct camera and ward test — replace only the client

This is a targeted presentation change for the reported case where Roam View
renders correctly but Stream View is black with 155 opaque course parts present.
**Studio visual success is not confirmed.** The file is ready for the controlled
Studio test below; automated projection/logic checks are distinct from rendering.

## Exact replacement

1. Back up the working place and **Stop Play**.
2. Open **StarterPlayer → StarterPlayerScripts → Realm** (the **LocalScript**).
3. Replace its **entire source** with
   [`roblox/StarterPlayerScripts/Realm.client.lua`](../roblox/StarterPlayerScripts/Realm.client.lua).
   Use GitHub's Raw/copy button; copy actual Luau only, without Markdown fences.
   Do not append code or add a second client script.
4. Leave **Config**, **RealmState**, **World**, and **ServerScriptService → Realm**
   unchanged. There are no new dependencies, scripts, remotes or installers.
   Keep persistence, HTTP/API access and TikTok integration disabled.
5. Press **Play**, open **Client Output**, and test the two camera modes. The button
   labeled **ROAM VIEW** means Stream View is currently active; clicking it enters
   Roam. The **STREAM VIEW** button switches back to the fixed camera.

All four server source files are unchanged. NPC physics, observations/finish times,
automatic rounds, earnings, scores, leaderboards and their HUD positions are intact.

## What the two changes test

**Large ward shell:** World builds Starlight ward as a 110-stud sphere centered at
(0,35,0). Its top reaches Y=90, overlapping the raised course. The previous focus
(0,71,-3) is inside it; the reported camera (223.2,342,125.8) is outside it. A ray
hit at 350.6 studs does not establish visual occlusion: Roblox raycasts can hit
fully transparent parts, and the server normally makes this shell transparent
outside its ward effect. The 155-part count describes the course, not this separate
shell. Its rendering remains a hypothesis to test.

The client now sets **only that shell's LocalTransparencyModifier=1** in Stream
View. It saves and restores the previous modifier in Roam View, on replacement/
detachment, or when the HUD is disabled. Server Transparency/vote/effect state is
untouched. Subsequent server opacity changes cannot expose the shell in Stream
View. Other decorations are not hidden or moved.

**Camera construction/framing:** Sprint now uses a direct CFrame.lookAt(position,
aimPoint) with **no subsequent local CFrame translation**. Its fixed aim point is
**(0,70,60), on the course start area**, not the previous geometric center. Looking
at that on-course point lets the rest of the route recede into the clear upper
area while preserving the existing lower leaderboard panels. Yaw and elevation
are both **25 degrees**, with **vertical FOV 60**. It never tracks NPCs or changes
for results. Viewport/bounds fitting adjusts only distance.

At 1080×1920 the mathematical fit is approximately **272 studs from the aim point**
(position about **104,185,284**), or **326 studs from the geometric course center**.
At 390×844 it is approximately **328 studs from the aim point** (about
**126,209,329**), or **381 studs from the geometric center**. These are computed
reference values, not observed Studio measurements. The changed aim point means
the new fitted-distance number should not alone be compared with the old 372.
The camera is also closer to the unchanged geometric center.

Sprint keeps bounded fitting (160–600 studs), finite input checks and the existing
position safety guard. Invalid snapshots use the known course box. The server's
bounds/yaw remain unchanged; its yaw=60 is the old suggested view, while the new
client uses its own fixed 25-degree heading. A zero/unusable viewport uses the
390×844 fallback and refits when usable. The older non-Sprint island camera is
preserved separately, including its original HUD framing.

## Actual-camera and obstruction diagnostics

Temporary `[Riftbound camera]` logs run every ten seconds and on phase/bounds/mode
changes. They now report:

- **Actual** Camera.CFrame position, LookVector and UpVector, actual Camera.Focus
  position, FOV/mode, fit flag and course part/anchor counts.
- `aimDot` between the actual look direction and actual focus direction. Sprint
  should report about **1.000000**, with `focusError=0.000`.
- `preApplyPositionDrift` and `preApplyAimDrift`: differences before this script
  restores the frame. Nonzero values can identify another camera controller.
- Raw ray hit toward the actual focus, and `filteredRay` with the locally hidden
  ward excluded. A raw ward hit can remain even while its visual is hidden.
  Filtering removes only that shell; it is not a general visibility oracle.
- Ward server/local opacity, camera/focus containment in the ward sphere, and
  `largeGeometryAtLens`. For other large parts this is a conservative bounding-box
  containment check, not exact mesh-volume collision testing. A name here merits
  inspection in Studio; the camera does not dynamically chase around it.

The new pose is outside all authored large-part bounds in the arithmetic tests.
This does not test actual engine rendering, animated occlusion or custom geometry.

The existing geometry/streaming checks remain. Persistent is a replication policy,
not proof of visibility. Native streaming requests run only if streaming is enabled
and local course geometry is missing, with the existing three-attempt limit. Your
reported complete geometry does not trigger that recovery. No external HTTP,
TikTok connection or persistence call is added.

## Controlled Studio verification and hypothesis isolation

1. With defaults (`STREAM_HIDE_WARD=true`), observe gathering, voting, a race,
   podium results and reset. Check all five racers, full course, gate and podium
   at 1080×1920 and 390×844, plus the actual capture window. Confirm normal scores,
   earnings and automatic rounds. Switch Roam/Stream repeatedly.
2. Check Output for actual Focus (0,70,60), FOV 60, aimDot≈1, zero focus error,
   six projected anchors, 155 opaque course parts and no large geometry at the lens.
   If Stream View is still black, the change has **not** been visually validated;
   retain these logs, especially any lens enclosure or camera drift.
3. To isolate the ward hypothesis, **Stop Play** and change only
   `local STREAM_HIDE_WARD = true` near the top of the client to **false**. Play again
   with the same camera/window, compare Stream View, and include a ward-active
   voting/racing phase. A ward ray hit alone is insufficient; compare rendering
   and logged opacity. Restore true after the comparison if hiding helps.
4. If both mask settings render correctly with the new direct camera, that supports
   the framing/distance change as a contributor but does not isolate which camera
   parameter mattered. If hiding is required for visibility, that supports a ward
   rendering contribution. Both defaults change together, so a successful first
   test alone cannot identify the original cause.
5. Keep `CAMERA_DIAGNOSTICS=true` while investigating. Set it false after the Studio
   check to silence temporary prints; camera control and local masking still work.

Automated checks execute the actual client with mocked engine objects, project all
course-envelope corners at ten resolutions, and test direct alignment, closer
positions, bounds, phase stability, Roam/restoration, late wards, masks on/off,
ray exclusions, lens enclosures and drift logs. Existing multi-round physics-command,
economy and standings tests remain. Native Luau compilation covers the five raw
files and their five exported XML equivalents. **No Roblox Studio rendering, real
physics, actual native raycast, streaming or asset-loading test was performed.**
