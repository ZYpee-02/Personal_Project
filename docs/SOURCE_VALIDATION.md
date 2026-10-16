> **Current v10 shared skyway:** replace all five sources using
> [SHARED_SKYWAY_REPLACEMENT.md](SHARED_SKYWAY_REPLACEMENT.md). The older
> release notes below are historical; do not mix their scripts with v10.

> Current v7 race-show upgrade: replace all five sources using
> [RACE_SHOW_REPLACEMENT.md](RACE_SHOW_REPLACEMENT.md). The older notes below describe
> previous builds; their short-course dimensions and camera settings are historical.

# Raw Luau source validation

Current update: cinematic/restart safeguards for physical Skybridge Sprint. World,
server Realm and client Realm changed; follow [CAMERA_FIX.md](CAMERA_FIX.md). Fresh installs still use all
five files and [SPRINT_REPLACEMENT.md](SPRINT_REPLACEMENT.md). Native appearance loading is
optional and guarded; no persistence/custom HTTP/TikTok code is enabled.

The manual game consists of exactly:

| File | Type | Parent | Instance name |
| --- | --- | --- | --- |
| Config.lua | ModuleScript | ServerScriptService | Config |
| RealmState.lua | ModuleScript | ServerScriptService | RealmState |
| World.lua | ModuleScript | ServerScriptService | World |
| Realm.server.lua | Script | ServerScriptService | Realm |
| Realm.client.lua | LocalScript | StarterPlayer/StarterPlayerScripts | Realm |

All are actual source under `roblox/`, without an enclosing source string or JSON.
Their complete source also appears in `MANUAL_STUDIO_SETUP.md` as five independent
Luau code blocks, identical to the files. There is no Command Bar installation path.

## Dependency checks

The server uses `require(script.Parent.Config)`, `require(script.Parent.RealmState)`
and `require(script.Parent.World)`. The three names must be extension-free sibling
ModuleScripts. Config returns its configuration table; RealmState and World return
their module tables. The client has no requires: it waits for the Riftbound folder
and Snapshot, Action and Notice events that the server creates in ReplicatedStorage.
The server now publishes channels before any require and advertises readiness after
building/rendering the world. Client startup waits have explicit timeouts; see
[STARTUP_FIX.md](STARTUP_FIX.md) for diagnostic attributes and failure behavior.

Tests verify these dependencies, the final return in each module, matching remote
names, raw code-block identity, offline restrictions and the absence of the retired
generator from the active build. The optional starter ZIP contains those exact
raw files, under their proper service folders, without an installer.

## Native Luau compiler

The official `luau-lang/luau` revision used for native syntax/bytecode compilation is
`8387cfb461b38ce09e37c1e4c2811538ef1bf5cb`. It was obtained over HTTPS and built with
`make config=release luau-compile -j2`. The prepared binary is retained in ignored
`.local/tools/luau-compile` for repeated checks.

`npm run check:luau` builds the manual deliverables, then invokes `luau-compile --null`
on the five raw files and five script sources extracted from the optional XML place:
10 compilation targets. The normal tests also parse all five as plain Lua and
exercise the real RealmState module using Fengari. Neither executes Roblox services.

For a fresh development machine, set LUAU_COMPILE to a trusted official binary, or:

```sh
git clone https://github.com/luau-lang/luau.git /tmp/riftbound-luau
git -C /tmp/riftbound-luau checkout 8387cfb461b38ce09e37c1e4c2811538ef1bf5cb
make -C /tmp/riftbound-luau config=release luau-compile -j2
LUAU_COMPILE=/tmp/riftbound-luau/build/release/luau-compile npm run check:luau
```

Studio users need none of these development tools. Use the Script Editor to paste
one complete file per instance. Rendering, physics, GUI layout, character scaling
and the actual Studio session still require the Windows/macOS manual playtest.

## Phase 2 automated behavior checks

The Phase 1 rule/economy/bridge tests remain active. Additional tests cover the
three no-vote activities, progress/coins across heartbeat frequencies, sprint finish
time ordering, gifts having no effect on winners, late arrivals, one-time prizes,
balance caps, immutable snapshots, invalid durations and safe empty rounds.

A coroutine-based scheduler executes the **actual Realm.server.lua** with actual
Config/RealmState and mocked World/Roblox services for 185 simulated seconds. It
checks that demo arrivals, gifts, follows, winners, scene callbacks and several
rounds occur with no players or Keeper events. It also checks DemoStudioOnly and
OfflineDemoEnabled gates. It cannot exercise World rendering, TweenService, camera
or GUI layout; those are explicitly covered by the manual Studio checklist instead.

Startup regression tests execute the actual server bootstrap with mocked engine
services, including missing/wrong/duplicate modules, module exceptions, invalid
settings, missing Phase 2 exports, failed World construction/render, and animation
failure shutdown. Client-bootstrap tests check its loading/error GUI contract with
mocked Instances, including no server, original module errors, readiness timeout
and wrong remote classes. Neither test suite executes Roblox's actual UI/engine.

## Presentation checks

`tests/presentation.test.js` exercises the actual layout/camera math at 320×568,
390×844, 720×1280, 1080×1920, 1920×1080, 844×390 and 1200×1920. It checks panel
separation, reserved regions and projected main-arena bounds. It also runs the
entire client and World source with mocked Instances, vector/CFrame arithmetic,
GUI rectangles and services, using actual Config/RealmState and 18 long-name
travelers. Those tests cover phase UI, text row sizes/truncation settings, camera
stability, label budgets/intersections, tools actions, late label attributes,
nearby roam boards, native nameplates and money/gift effects.

These mocks do not rasterize fonts, render Roblox geometry, implement true model
scaling/occlusion, tween over time or measure performance. Numeric font sizes and
rectangle fitting are not visual readability approval. Use
[PRESENTATION_REPLACEMENT.md](PRESENTATION_REPLACEMENT.md) and the Studio checklist
to verify those remaining behaviors on the intended capture/device.

## Physical Sprint checks

Sprint tests exercise actual Config/RealmState/World: no timer-only finishes,
sequential gates and replay/stale/time rejection, observed standings for all five
racers, ties, one-time rewards, cohort/reset/DNF behavior, unanchored server-owned
rigs, MoveTo/jump commands, sampled root positions and recovery, appearance
disabled/failure/success/timeout, and full-course camera bounds at seven resolutions.

An end-to-end scheduler executes the actual server, World and client for several
rounds with a command-following movement stub. Root samples and stubbed movement
are **not actual Roblox physics**. No native appearance requests were made by these
tests. Real R6 avatar assets, collision/jump traversal, streaming, rendering,
occlusion, model scaling and performance require Windows/macOS Studio playtesting.

## Fixed spectator camera regression checks

`tests/camera.test.js` executes the actual camera math and full client with the
documented engine mocks. Ten viewport sizes include 1080×1920, 2160×3840, portrait,
landscape and 1:4/4:1 edges. Tests project display-region corners and actual authored part vertices into
the unobstructed gameplay rectangle and check finite positions, height, distance,
heading and center. Corrupt/missing/undersized/inverted/NaN/infinite/oversized bounds
fall back safely. Unusable viewports get bounded fallback positions.

Actual RealmState/World code verifies identical server bounds through all round
phases, all 155 built course BaseParts inside the bounds, and racing jump envelopes.
Full-client tests cover same-activity bounds corrections, phase stability, conflicting
camera CFrames/FOV modes, Focus, zero-size viewport recovery, replacement cameras and
Roam toggles. Partial/missing/transparent geometry is distinguished from a Persistent
policy. Streaming request success/failure, cooldown, attempt limits and disabled/
already-loaded cases use mocks only. A mocked foreground hit checks ray diagnostics.
The existing multi-round server/World/client test continues exercising the race.

The follow-up direct-camera/ward tests check zero Sprint translation, actual
look-at alignment/Focus, a closer position relative to both the aim point and the
geometric course center, and all eight course corners inside the unchanged clear
HUD rectangle. The authored large geometry does not enclose the new lens position
in these arithmetic tests. Ward masking/restoration is checked across phases,
server opacity changes, Roam switches, disabled HUDs and late/replaced geometry.
Further tests exercise the ward-mask A/B flag, raw versus excluded-shell mock
raycasts, large lens enclosures and camera drift reporting. These mocks do not
establish whether the ward actually caused the user's rendered black screen.

These are mathematical/logic checks. No real streaming request, raycast, rendering,
camera controller conflict or Studio visual/physics playtest was performed here.

## Readable overview v3

The v3 checks verify all 155 course parts and all five lane/jump envelopes fit the
three display regions. The existing Sprint camera test now projects every authored
part's eight vertices at seven resolutions rather than only the broad server box.
Camera tests retain ten viewport sizes and assert that the route spans more than
210 logical pixels at 9:16, against the previous heavily foreshortened framing.

A segment/sphere calculation using actual World geometry verifies that Storm rift
crosses the new camera's sightline to the finish arch. Tests exercise its local
mask/restoration across phases while server Transparency remains unchanged. Further
tests cover daylight restoration, preserving gift Ambient colors, the daylight
A/B flag, and a mock accessory blocking a finish anchor while the start ray stays
clear. Full instance paths make that previously unobserved obstruction identifiable.
These calculations/mocks do not prove native rendering, lighting or occlusion.

## Render check v4

The render-check tests verify opt-in, client-only near/far neon parts, screen
projection, following the current camera, cleanup in Roam/disabled HUD and no
gameplay actions or economy changes. The mock exercises GetRenderCFrame offsets,
composed part opacity (including 0.9/0.9 = 1% opacity) and maximum drift retention
between log intervals. The existing camera fitting is unchanged. These checks
do not establish that native Roblox draws either cube or the course. User Studio
reports remain required; the issue is not claimed fixed.

## Cinematic/restart safeguards v5

Tests cover actual-root racing pack/leader tracking, actual arrived podium winners,
winner close-up, safe overview fallback and reset/Roam transitions. Camera fitting
projects the avatar/jump envelopes at four viewport sizes. Additional tests cover
existing-character rescue and later respawns on the separate spectator deck, Roam
subject/position, exact restoration of late Lighting/Camera effects and Atmospheres,
and local masking/restoration of geometry outside the generated realm. Physics and
race/economy code are unchanged; existing multi-round tests still exercise them.
These mock/geometry tests do not prove restart reliability, rendering or movement
in the actual Roblox engine. Two fresh Studio Play runs remain required.
