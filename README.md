# Riftbound Live — shared fantasy skyway race show

One broad, banked adventure road with two split-and-rejoin shortcuts, a 20-position
starting grid, 48 measured gates and a 120-second deadline. The default field is
16 NPCs; the offline demo seeds 20 viewers and rotates cohorts automatically.
Racers share the road, steer around traffic and hazards, and choose routes.
Native Humanoid movement and observed finish crossings determine the results.

![Shared skyway plan — not a gameplay screenshot](docs/SKYBRIDGE_ROUTE.svg)

**v10: replace all five complete raw sources together**, including existing v9
installations. [Exact replacement instructions](docs/SHARED_SKYWAY_REPLACEMENT.md)
list every file, Studio parent/type, settings and native playtests.
MANUAL_STUDIO_SETUP.md includes all five complete source blocks. GitHub source
updates do not automatically sync into an open Roblox Studio place.

| Section | Gates | Shared road features |
| --- | --- | --- |
| Starting Dash | 1–12 | Mossy slate, banked curves, broad grid, partial-width hurdles |
| Moving Bridges | 13–24 | Timber main bridge, inside jump shortcut, moving slalom gates |
| Hazard Zone | 25–36 | Stone ruins, sweeping gates, second split/rejoin shortcut |
| Final Sprint | 37–48 | Marble turns, overtakes and crown finish |

Floating meadows, trees, crystals, portals, waterfalls and clouds flank the course.
The director follows the lead pack, real changes of leader, shortcut battles,
other competitors and the finish. Close entrance montages queue without pausing
the race. Stream/Roam controls and reversible camera visibility safeguards remain.

The economy stays fictional and in memory: $2/checkpoint, $40 finish and
$120/$75/$40 podium prizes, plus existing capped earnings and cosmetic gifts.
Grounded sequential gates, route corridors, fall recovery, measured finish times
and DNFs remain authoritative. All racers have equal movement settings; there
are no predetermined winners. NPC-to-NPC body collisions are disabled to avoid
crowd pileups; road and hazard collisions remain active with local steering.

Keep Workspace.StreamingEnabled=false. DataStoreService, custom HTTP and real
TikTok integration remain disabled. OFFLINE JOIN uses procedural avatars;
optional verified joins use bounded native Roblox username/appearance APIs.
To avoid authored account requests set ResolveViewerUsernames=false and
LoadAvatarAppearances=false. Initial arrival montages may make the first race
smaller; subsequent cohorts fill once newcomers complete their entrances.

[Available test results and limits](docs/SHARED_SKYWAY_TEST_RESULTS.md) distinguish
5/10/15/20-racer cloud contact approximations from required native Studio physics,
rendering and performance checks. Client diagnostics identify **race-show-v10**.

## Development checks

```sh
npm ci --ignore-scripts
npm test
npm run check:luau
```

The native compiler is installed by the environment setup. The build regenerates
the five-block manual guide, XML place and ZIP. Tests use Node 22+, Fengari and
limited service/geometry mocks; no external integration is started by the game.

## Node simulator and future TikTok integration are separate

The offline game does not need Node. The optional browser control desk runs with:

```sh
cd /workspace/Personal_Project
npm ci --ignore-scripts
npm run dev
```

Node 22+ is required. The simulator binds to loopback port 8787. In local development,
open that port in your browser; the cloud onboarding UI does not provide localhost
previews. The control desk is an illustration and event simulator, not a live 3D view.
The default offline game does **not** poll it: browser events remain pending and
expire after two minutes. The default Studio demo runs automatically; use TEST TOOLS only for targeted tests.

Node event queues and receipts are also memory-only and clear on restart. Legacy
`.local/queue.json` files, if present from earlier versions, are not read or changed.
The ignored `.local/game-config.json` holds a generated transport credential only;
it contains no gameplay state. Never share or commit it. The Node service has
separate admin/game authentication for the later optional transport.

Real TikTok comments, gifts, and follows are **not connected**. No TikTok connector
is installed, imported, started, or contacted. `integrations/README.md` describes
an explicit future setup, with HTTPS hosting, an authorized LIVE connector, stable
viewer IDs, finalized gift events, and separate admin/game credentials. The optional
Roblox HTTP and avatar modules live under `integrations/roblox/`; neither is included
in the five manual game files, the `.rbxlx`, or the default Rojo project.

## Build and validation

```sh
npm ci --ignore-scripts
npm run check
npm run check:luau    # native compiler required; prepared in this cloud workspace
npm run test:browser  # optional browser simulator check; Chromium required
```

Node 22+ and Python 3 are required for development tools, not for manual Studio
setup. The build generates `MANUAL_STUDIO_SETUP.md`, the optional equivalent
`dist/RiftboundLive.rbxlx`, and `dist/RiftboundLive-Starter.zip` containing the five
raw sources with their correct folder structure. It does not generate an installer
or assign Script.Source at runtime. Edit the five source files directly. Studio
edits do not automatically sync back to the repository.

Automated tests exercise the actual pure-Lua rules, economy, voting, leaderboards,
gifts/follows, the optional Node bridge, local module dependencies, remote names,
source-code identity in the manual guide and ZIP, and offline API exclusions.
Phase 2 tests also drive the actual server scheduler with mocked services for
340 simulated seconds, checking that demo arrivals, gifts and several rounds run
without human/host calls. A separate 440-second command-following stub repeats the
actual physical controller/server/client pipeline; it does not simulate native
collision, jumping, rendering or engine physics. The
native Luau compiler validates all five actual game files and all five sources in
the optional XML place. They cannot validate Roblox rendering, physics, or Studio
UI behavior. Run the manual checklist on Windows/macOS.

The prepared compiler is `.local/tools/luau-compile`. To use another official
compiler, set `LUAU_COMPILE` to its path. Source revision and reproduction details
are in `docs/SOURCE_VALIDATION.md`. An optional `default.project.json` is available
for Rojo users, but no plugin is needed for manual setup.
