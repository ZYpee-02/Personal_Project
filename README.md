# Riftbound Live — five-script offline playtest v0.2.2

A fantasy sky-island Roblox game with username joining, local viewer avatars,
cooperative storm rounds, live leaderboards, money-per-second earnings, and
simulated gifts/follows. All game data is in memory; `PersistenceEnabled = false`.
There are no save-service, HTTP, account-lookup or external-asset calls in the game.

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
7. Open Keeper Tools, enter `Alice_01`, then Open the Star Gate. Repeat with `Bobby_02`.
   Click Awaken a Storm, vote, and watch balances/leaderboards. Test targeted gifts
   and follows using the username field. See `docs/PLAYTEST.md` for the full checklist.
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

## Rules and economy

- Up to 18 named crew members per session. The arrival queue is bounded at 30.
- Gathering: 55 seconds. Voting: 35 seconds. Storm: 12 seconds. Results: 12 seconds.
  Hosts can end gathering early. All Studio players are hosts; published places
  use the owner or `Config.HostUserIds` for host authorization.
- Every viewer identity gets one vote per round; changing sides moves that vote.
  A tie chooses Ward. The goal is `max(1, ceil(crew / 3))` participating voices.
  Ward creates a shield; Sail produces wind trails.
- Crew earn **$5/s during voting and storms**, plus **$3/s** if they voted that round.
  Every successful team round adds **$2/s** to everyone for subsequent rounds.
  Rates are capped at $100/s and session balances at $1 billion.
- Gathering/results do not pay. No retroactive joining or voting rewards are added.
  Earnings use elapsed seconds, not an assumed heartbeat rate. Money is fictional
  test currency; there are no Robux purchases, cashouts, or paid entitlements.
- Round earnings reset at the next vote. Session balances remain until Stop/server
  shutdown. The HUD ranks five session earners; the world board ranks the top three
  current-round earners, or the completed round during results. Ties use arrival order.
- Successful rounds add a shard and a crystal to the sky garden, capped at 24
  visible crystals. No votes means no shard; the next round still starts normally.
- Gifts are simulated and cosmetic: Bloom creates motes, Aurora creates colored
  lighting/aura, and Giant enlarges the targeted stand-in and shows titan stars.
  Effects expire after 18 seconds. They do not buy income, votes, or round wins.
- Follows are deduplicated by viewer ID within the session, capped at 10,000.

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
expire after two minutes. Use in-game Keeper Tools for the complete offline test.

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
source-code identity in the manual guide and ZIP, and offline API exclusions. The
native Luau compiler validates all five actual game files and all five sources in
the optional XML place. They cannot validate Roblox rendering, physics, or Studio
UI behavior. Run the manual checklist on Windows/macOS.

The prepared compiler is `.local/tools/luau-compile`. To use another official
compiler, set `LUAU_COMPILE` to its path. Source revision and reproduction details
are in `docs/SOURCE_VALIDATION.md`. An optional `default.project.json` is available
for Rojo users, but no plugin is needed for manual setup.
