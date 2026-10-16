# Riftbound Live — automated registration tournament

The existing wide, shared v10 fantasy skyway is unchanged. Viewers now register
freshly for every round, watch their avatars emote in the lobby, launch through a
fiery READY/3/2/1/GO sequence, race physically for up to 120 seconds, and see measured
podium results before the next empty registration window opens.

**Normal mode starts empty and waits indefinitely.** A second valid entrant starts
a 30-second open registration timer, up to 20 competitors. Dropping below two
cancels it. Closing locks the roster; late entries are rejected rather than queued
for another race. Everyone must submit again next round. Money and historical
statistics remain in the separate session ledger.

[Complete five-source replacement instructions](docs/TOURNAMENT_REGISTRATION_REPLACEMENT.md)
include exact Studio parents/types, offline controls and the future scoped event
contract. MANUAL_STUDIO_SETUP.md contains all five complete raw Luau source blocks.
GitHub pushes do not automatically update an open Studio place.

Use TEST TOOLS → **DEMO TESTING** explicitly for an automated preview: the demo
submits fresh registration events every round and showcases cosmetic power-ups.
It is OFF by default. OFFLINE JOIN, verified Roblox account joins, withdrawal,
stale-round tests and individual visual controls also remain available. Real
TikTok comments are not connected yet. The normal populated cycle needs no
manual start button.

The director covers waiting avatars, the whole starting grid, overtakes, other
competitors, shortcuts, queued 1.5-second power-up highlights, finish battles and
the podium. Roam stays a manual override. Trail/shield/starburst effects are
cosmetic with equal cooldowns; they grant no speed, immunity, score or gift advantage.
Native fires, smoke, sparks and fixed presentation pools do not damage racers.

Physical shared-road navigation, two alternate routes, checkpoints, actual finish
times, DNFs, fictional earnings and session leaderboards are preserved. The course
builder is fingerprinted against v10. Keep Workspace.StreamingEnabled=false;
DataStoreService, custom HTTP and real TikTok networking remain disabled.
Client marker: **race-show-v11**; course marker: **show-v10-shared-road**.

[Available tests and limitations](docs/TOURNAMENT_TEST_RESULTS.md) distinguish cloud
state/geometry/contact/projection checks from required native Studio visual,
Humanoid physics and 15–20-racer performance playtests.

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
