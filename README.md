# Riftbound Live — Phase 2 / autonomous offline playtest v0.3.0

A fantasy sky-island Roblox game with username joining, local viewer avatars,
automatic competitions, moving avatars, live leaderboards, money-per-second earnings, and
simulated gifts/follows. All game data is in memory; `PersistenceEnabled = false`.
There are no save-service, HTTP, account-lookup or external-asset calls in the game.

## Upgrade the working Studio game

Replace all five complete sources in their existing instances using
[the exact Phase 2 replacement guide](docs/PHASE2_REPLACEMENT.md). Do not mix versions.
`MANUAL_STUDIO_SETUP.md` contains all five full raw Luau code blocks. With defaults,
Studio seeds six clearly labeled demo travelers and runs rounds/gifts unattended.
No Keeper Tools are needed. Real TikTok integration remains disabled.

## Manual setup in Roblox Studio

The Command Bar installer is retired and no longer generated or bundled. Use the
five actual source files below. They are complete raw Luau, not serialized strings.
`MANUAL_STUDIO_SETUP.md` includes step-by-step directions and all five full code
blocks if you prefer copying from one document.

1. Open a new place in Roblox Studio on Windows/macOS, with Play stopped.
2. Open Explorer and Properties. Keep HTTP Requests and Studio API Services access
   disabled. No publication, plugin or Node process is needed.
3. Create these exact instances, double-click each to open its Script Editor,
   select all default code, and replace it with the corresponding **entire file**:

| Raw source file | Instance type | Parent | Exact Explorer name |
| --- | --- | --- | --- |
| `roblox/ServerScriptService/Config.lua` | ModuleScript | ServerScriptService | Config |
| `roblox/ServerScriptService/RealmState.lua` | ModuleScript | ServerScriptService | RealmState |
| `roblox/ServerScriptService/World.lua` | ModuleScript | ServerScriptService | World |
| `roblox/ServerScriptService/Realm.server.lua` | Script | ServerScriptService | Realm |
| `roblox/StarterPlayerScripts/Realm.client.lua` | LocalScript | StarterPlayer → StarterPlayerScripts | Realm |

4. Do not append filename suffixes to the instance names. The server's three
   `require(script.Parent.NAME)` calls resolve the sibling ModuleScripts. Each
   ModuleScript returns its table. Leave the server Script's RunContext at its
   Legacy/default setting. Make sure the Script and LocalScript are enabled.
5. Finish all five files before starting. Do not leave duplicate Realm scripts from
   previous attempts active. Do not paste this code into the Command Bar or combine
   files. The client waits for remotes that the server creates automatically.
6. Press **Play**, not Run. The islands appear at runtime, and your player gets a HUD.
7. Wait for the six Demo_ travelers and first competition. Observe Starfall Scramble,
   Skybridge Sprint and Heartseed Relay over about three minutes. TEST TOOLS are
   optional. ROAM VIEW restores the normal camera; STREAM VIEW returns to the show.
   See `docs/PLAYTEST.md` for required Studio checks.
8. Stop and Play again: all gameplay state starts fresh.

If Studio says Config/RealmState/World is not a valid member, check the parent,
instance type, spelling and extension-free Explorer name. If no HUD appears, verify
that the client is a **LocalScript in StarterPlayerScripts**, that you used Play,
and that the server has no errors in Output. Do not manually create the Riftbound
remotes or install anything from `integrations/` for this offline test.

## Avatar behavior in offline mode

Username format is checked, and duplicates are rejected case-insensitively. Names
are labels; no account existence or ownership is verified. All crew avatars use
procedural block rigs, not downloaded Roblox outfits. This is necessary for a
playtest with no custom network requests. Actual player characters still behave
normally under Roblox's own engine; this game adds no account/asset fetch calls.

Arrival animations, colored character rigs, name/earnings labels, and gift effects
remain playable. Real avatar lookup is retained separately under `integrations/`
and is deliberately excluded from the manual game files and place.

## Automatic rounds, competition and economy

The 60-second default loop is **12s gathering → 8s optional vote → 30s competition
→ 10s results**. It repeats without any player input. Activities rotate:

| Competition | Visible activity | Ranking |
| --- | --- | --- |
| Starfall Scramble | Collect stars around the inner ring | Most checkpoint points |
| Skybridge Sprint | Race twelve raised checkpoints | Completed checkpoints, then earliest finish |
| Heartseed Relay | Carry energy between shrines and heartseed | Most deliveries/checkpoint points |

Motion is scripted and kinematic. Server-selected paces vary deterministically by
name, round and activity; they are not affected by gifts. Ties use actual finish
progress then arrival order. Arrivals mid-round receive only their time remaining.
The automatic team goal scales with entrants; meeting it saves a shard without
votes. The existing optional Ward/Sail vote can also save a shard and chooses the
shield/wind scenery. It does not decide who wins the automatic competition.

Income is $5/s in voting and competition, plus $2/s for active competition, $3/s
for a vote that round, $2/s per saved team shard, and $1/s per personal championship.
Rates are capped at $100/s; all balances at $1 billion. Each competition checkpoint
adds $2, and the top three get $120/$75/$40. Results/gathering pay no passive money.
Round money resets on the next vote, while session balances last until Stop. Income
uses elapsed time and bounded phase deadlines, not a fixed assumed frame rate.

The HUD shows session money leaders and competition point leaders. Two large world
boards show session and round money leaders. The top three walk to podiums with a
winner banner, crown/cheering motion and pooled procedural celebration particles.
Labels show actual current $/s, with +$ pops for real credited deltas. Team shards
add crystals to the garden (maximum 24 visible). Empty rounds safely keep running.

The centered portrait HUD/camera fits 480×854 logical pixels and reserves the lower
136 pixels for a stream interface. A landscape capture can be center-cropped to
9:16. Actual mobile/capture readability must be checked in Studio. TEST TOOLS starts
closed. All earlier manual joins, votes, sky blessings, targeted gifts and follows
remain available there; every Studio player is a host for testing.

`OfflineDemoEnabled` seeds six Demo_ avatars; `DemoStudioOnly` confines the fake
crew/events to Studio by default. `AutoSimulateGifts` cycles cosmetic Bloom, Aurora
and Giant events every 18 seconds after seeding, with deduplicated demo follows.
Turn these off to test only real player stand-ins/manual inputs. Effects expire
after 18 seconds, restore scale and have no scoring/income advantage. The visuals
use local Parts (including pooled motes), highlights and lighting; no downloaded
textures, particles, sounds or outfits. Follows are bounded at 10,000 per session.

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
185 simulated seconds, proving that demo arrivals, gifts and several rounds run
without human/host calls; they do not simulate rendering or engine physics. The
native Luau compiler validates all five actual game files and all five sources in
the optional XML place. They cannot validate Roblox rendering, physics, or Studio
UI behavior. Run the manual checklist on Windows/macOS.

The prepared compiler is `.local/tools/luau-compile`. To use another official
compiler, set `LUAU_COMPILE` to its path. Source revision and reproduction details
are in `docs/SOURCE_VALIDATION.md`. An optional `default.project.json` is available
for Rojo users, but no plugin is needed for manual setup.
