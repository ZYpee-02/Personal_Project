# Phase 2 Studio acceptance checklist — NOT executed in the cloud

The existing Phase 1 game was reported working by the user. That does not validate
this Phase 2 scene. This checklist requires Roblox Studio on Windows/macOS. Keep
HTTP Requests and Studio API Services access **disabled** throughout the test.

## Replace and boot

- [ ] Back up the working place; stop Play and follow PHASE2_REPLACEMENT.md.
- [ ] Replace all five complete raw sources in the existing instances; no duplicates.
- [ ] Verify Config/RealmState/World are ModuleScripts and the two Realm instances are Script/LocalScript in their documented parents.
- [ ] Press Play; there are no Output errors and no request to publish/enable APIs.
- [ ] Scene has animated clouds/runes/stars, shrines, raised track, podiums and both large boards.
- [ ] Portal visibly delivers six Demo_ rigs and the actual player's crew stand-in.

## Prove autoplay with no tools or votes

- [ ] Leave the game untouched for at least three complete rounds (~3 minutes).
- [ ] Gathering (12s), optional vote (8s), competition (30s), results (10s) repeat.
- [ ] Starfall rigs visit the inner ring and scores increase with checkpoints.
- [ ] Sprint rigs walk the raised course, finish at twelve checkpoints, and the fastest finisher wins.
- [ ] Relay rigs walk between shrine/heartseed and carry a visible energy orb.
- [ ] Round leaders reflect points; money boards reflect money, with clearly different labels.
- [ ] Results show the top three, credit $120/$75/$40 (subject to balance cap), move them to podiums, and show champion crown/cheering/particles.
- [ ] Team success can save shards without a manual vote; unsuccessful goals still advance safely.
- [ ] Round results do not pay twice, and empty rounds also advance with no errors.

## Economy and gifts

- [ ] $5/s base during voting; competition adds $2/s activity income; voting adds $3/s that round.
- [ ] Successful team shards add $2/s and a personal championship adds $1/s to future rates (caps respected).
- [ ] Each checkpoint awards $2; actual credited deltas appear in floating +$ pops.
- [ ] Idle/results show $0/s and accrue no passive money; podium prizes remain visible.
- [ ] Round money resets on the next vote while session totals remain.
- [ ] Demo Bloom/Aurora/Giant/follow events occur automatically and are labeled simulated.
- [ ] Giant visibly enlarges the target, then restores size after ~18s without snapping below the floor.
- [ ] Aurora ribbons/aura and Bloom/star particles are noticeable without obscuring all players.
- [ ] Gifts/follows change no race pace, score, income rate, winner or vote totals.

## Framing, controls, compatibility

- [ ] Observe at 390×844, 720×1280, 1080×1920 and desktop landscape using the device emulator/capture crop.
- [ ] Centered 9:16 HUD, countdown, names, points and earnings are readable; lower reserved strip stays clear.
- [ ] Automatic camera includes the main track, inner ring, shrines and podiums; check top-board clipping.
- [ ] ROAM VIEW restores the normal camera; STREAM VIEW returns smoothly to the arena.
- [ ] Walk/jump across bridges and test player respawn/falling in Roam View.
- [ ] TEST TOOLS starts closed; all earlier username, vote, follow and gift controls still work.
- [ ] Invalid/duplicate usernames are rejected, and switching a vote never adds another voice.
- [ ] Disable OfflineDemoEnabled: no seeded fake audience or automatic gifts, but player crew and rounds still work.
- [ ] Disable AutoSimulateGifts: seeded crew still compete without automatic effects.
- [ ] Two-client Studio test: scores/results agree; each client can independently change camera mode.
- [ ] Published private test: default DemoStudioOnly prevents fake crew/events; non-host cannot use test actions.
- [ ] Stop and Play: all money, crew, gifts, follows, points, results and shards reset.

## Resource check

- [ ] Observe frame rate, network/replication and server time at 6, 12 and 18 crew for several rounds.
- [ ] Verify the bounded particle pool, reused earnings popups and scenery do not accumulate instances over time.
- [ ] Test SceneUpdatesPerSecond=6 if the target machine struggles; no particular FPS/latency is guaranteed.
- [ ] Confirm no custom HTTP/asset requests or DataStore calls occur and no online module is loaded.

Real TikTok events, streaming software capture and production device performance
remain separate future validation. Automated tests use mocked Roblox services and
must never be reported as a Studio rendering/physics playtest.
