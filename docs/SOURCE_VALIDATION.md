# Raw Luau source validation

Current release: physical Skybridge Sprint. All five files changed; follow
[SPRINT_REPLACEMENT.md](SPRINT_REPLACEMENT.md). Native Roblox appearance loading is
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
