# Offline Studio acceptance checklist

Requires Roblox Studio on Windows/macOS; not executed on the Linux cloud machine.
Use a new test place, with HTTP Requests and Studio API Services access **disabled**.

- [ ] Create the five instances from MANUAL_STUDIO_SETUP.md in stopped edit mode.
- [ ] Paste each complete raw source into its own Script Editor tab.
- [ ] Verify exact parent/type/name for Config, RealmState, World, server Realm and client Realm.
- [ ] It does not publish, prompt for credentials, or request service access.
- [ ] No duplicate server/client Realm scripts from older attempts are enabled.
- [ ] Play creates the island and player HUD; no save or HTTP errors appear in Output.
- [ ] Walk/jump across both bridges and test respawning after falling.
- [ ] Add `Alice_01`, `Bobby_02`, `Clara_03` using Keeper Tools. Local rigs appear.
- [ ] Invalid and duplicate names are rejected without extra avatars.
- [ ] During gathering, balances remain zero. Start a storm, then vote.
- [ ] Base earnings are $5/s; a joined avatar that votes earns $8/s in its first round.
- [ ] Cast Ward then Sail as the same demo username; only one vote remains.
- [ ] Enough participation creates a shard and garden crystal; no votes does not.
- [ ] Ward creates a shield; a Sail majority creates wind trails.
- [ ] HUD/session leaderboard and world/round board update as money accrues.
- [ ] Results show the last round's winners; money stops accruing in results/gathering.
- [ ] Next vote resets round earnings, preserves session money, and adds $2/s after a win.
- [ ] Targeted Bloom/Aurora/Giant affect the selected avatar/sky for 18 seconds.
- [ ] Giant returns to normal scale, and none of the effects change votes or income.
- [ ] Simulated follows count once per identity and change no money or round result.
- [ ] Stop and Play again: all game state is empty; no saved totals reappear.
- [ ] Two-player test: votes and leaderboards agree across clients.
- [ ] Device emulator: HUD and Keeper Tools fit phone/tablet screens.
- [ ] Published private test, if desired: a non-host cannot perform host actions.
- [ ] Starting the separate Node simulator causes no HTTP polling from the offline game.

Do not enable the online integration as part of this offline acceptance test.
