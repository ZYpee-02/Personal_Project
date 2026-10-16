# Readable Stream View v3 — replace only Realm.client.lua

The latest screenshots show some geometry, but a small dark start platform and
mostly empty space remain. The earlier all-parts-present/on-screen checks did not
establish readability or visibility of the full course. **This update still needs
Roblox Studio visual confirmation.** It changes only the client Luau file.

## Exact replacement

1. Back up the place and **Stop Play**.
2. Open **StarterPlayer → StarterPlayerScripts → Realm** (LocalScript).
3. Replace its **entire source** with
   [`roblox/StarterPlayerScripts/Realm.client.lua`](../roblox/StarterPlayerScripts/Realm.client.lua).
   Use the file's Raw/copy button. Copy Luau only, without Markdown fences. Keep one
   client script; do not append source or use the Command Bar.
4. Leave Config, RealmState, World and the **server** Realm unchanged. Physics,
   checkpoint/finish timing, rounds, money and leaderboards are not modified.
5. Press **Play**, keep Stream View active (the button says ROAM VIEW), and use a
   portrait phone emulator. Fit the phone preview to the Studio window so its
   bottom is visible. Watch a race, results and reset; switch Roam/Stream as well.
6. Confirm Client Output includes **presentation=course-overview-v3**, clock=14.00,
   brightness=3.00, exposure=0.25 and the new Focus **(0,68,45)**. Old version logs
   with only Focus (0,70,60) indicate the prior client is still running.

No new scripts, remotes, modules, plugins or integrations are required. Persistence,
custom HTTP and TikTok remain disabled. The complete five-source manual remains
available for fresh installs; this working physical Sprint place needs only the
one replacement above.

## Changes and hypotheses

**Foreshortened course:** The previous camera's 25-degree elevation looked along a
nearly flat route, compressing its length into a small screen area. The new fixed
view aligns with the long course axis: heading **0**, elevation **55 degrees**,
vertical FOV **55**, aim **(0,68,45)**. It never follows a racer or zooms for results.
There is no local translation after lookAt; actual Focus and direction agree.
The position changes only for viewport/bounds fitting.

Fitting uses three conservative display regions: start, race track/jumping space,
and finish/podium. These enclose all authored course vertices and the racing
jump envelopes in tests. The broad server box includes empty low corners below
the start; forcing those into the clear HUD area shrank the useful course. The
server box remains unchanged and validated. Padded bounds still use the full box
for conservative fitting; invalid/missing bounds use the known course regions.

At 1080×1920 the mathematical camera distance to its aim is about **321 studs**,
position **(0,331,229)**. At 390×844 it is about **403**, position **(0,398,276)**.
This is a higher view, not a claim that a smaller distance alone fixes framing.
The actual route spans over **210 logical vertical pixels**, about twice the
previous view. These are computed projection values, not observed Studio results.
The established portrait HUD layout/labels remain unchanged. Distance is bounded
at 170–850; unusable viewports use the 390×844 fallback.

**Dark lighting:** Stream View now applies a local daylight profile: ClockTime 14,
Brightness 3, ExposureCompensation +0.25, EnvironmentDiffuseScale 1,
EnvironmentSpecularScale 0.5, brighter OutdoorAmbient and GlobalShadows false.
Roam restores those properties to their saved values. The server and other clients
are unaffected. Ambient itself is not overridden, preserving animated gift colors.
Existing post-processing effects are not deleted or disabled.

**Large decorative occluders:** The ward sphere encloses the old course-center
focus. More significantly, the Storm rift is centered near (0,90,-50), directly
above the finish. A segment/sphere calculation using actual World geometry shows
it crosses the new lens-to-finish-arch sightline. A ray to the start did not check
that route. Both shells are now locally hidden in Stream View; Roam restores their
previous LocalTransparencyModifier values. Server Transparency, votes and storm
state remain unchanged. Avatars, auras, particles, ribbons, crowns, clouds and
other decorations are retained. Intersecting a transparent sphere is not by itself
proof of black-screen causation, so the native visual comparison remains required.

## Diagnostics and controlled comparisons

Output retains actual CFrame position/look/up, actual Focus, aimDot, focus error,
pre-apply camera drift, local part/opaque counts, sphere masks and lens containment.
New fields identify the presentation revision and actual lighting values.

Each of six key anchors also reports world/screen coordinates and a raycast
sightline. Rays exclude the two locally hidden shells. Other hits report the full
instance hierarchy, so a generic Handle can be traced to its avatar/accessory.
The start ray can be clear while an outfit or another decoration blocks the
finish; a projected anchor is not a visibility test. A target hit or a gate/podium
edge can be normal, and even transparent objects can register ray hits. These logs
provide inspection evidence rather than automatic proof that an object obscures
all pixels. No arbitrary outfit or user geometry is removed automatically.

If the new view is still obscured, capture the **entire v3 diagnostic block**, in
particular Finish arch / FINISH island / podium sightlines and their actual
coordinates. Keep the portrait screenshot. It can identify a custom object or
appearance that the source-only checks do not contain.

Optional isolation, changing one flag at a time with **Play stopped**:

- STREAM_DAYLIGHT=false compares the same camera with the original local lighting.
- STREAM_HIDE_RIFT=false compares finish visibility with the large storm sphere.
- STREAM_HIDE_WARD=false compares the ward shell, including a ward-active round.

Restore true for the default readable stream presentation after comparison.
CAMERA_DIAGNOSTICS=false silences temporary logs after verification. Camera control,
local daylight and shell masking remain active.

Geometry streaming recovery is unchanged: requests occur only with native streaming
enabled and missing local course geometry, with the existing bounded three attempts.
The reported 155-part state does not trigger requests. Persistent remains a server
replication policy, not a visibility guarantee.

## Validation boundary

Automated checks exercise actual source with mocked services, project real course
vertices at multiple sizes, and cover jump space, stable rounds, Roam restoration,
lighting, masks, camera replacement, bad bounds, viewports, drift and per-anchor
obstructions. Existing automatic-race/economy/standings tests remain active. Native
Luau compilation covers five raw sources and five XML-exported equivalents.

**No Roblox Studio rendering, real physics, native raycasting, streaming or outfit
asset loading was performed here.** Confirm legibility and visibility on your
actual capture view through at least one race, podium and reset. Test multiple
outfits and gifts. The black-screen/presentation issue is not claimed resolved
without that Studio evidence.
