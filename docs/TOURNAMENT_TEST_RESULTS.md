# Tournament registration / presentation validation (v11)

No native Roblox Studio renderer, Humanoid solver or FPS profiler is available in
this workspace. Results below are cloud logic, command, geometry and projection
checks, not native visual or physics certification.

## Registration and event handling

- Zero/one entrant waits indefinitely; the second entrant starts the 30-second open
  timer. Withdrawing below two cancels it; restoring two restarts a full timer.
- Roster capacity 20, case-insensitive duplicates, event replay, invalid/missing
  round IDs/timestamps and closed-window requests are rejected.
- The actual server's BindableFunction is exercised with queued copied envelopes
  and a yielding account resolver. Verification finishing after close is rejected;
  old requests cannot register anyone in the next window.
- Countdown locks the roster; nobody joins during the race. Results clear the
  roster/queues; fresh submissions are required next round. Session money,
  best times, finishes, DNFs and cloned recent-history snapshots are retained.
- Normal server execution remains empty after hundreds of simulated seconds.
  Explicit demo testing sends new registration events each round; disabling it
  returns to empty waiting. There is no automatic normal-mode seed or empty race.

## Presentation and fairness

- 20 staged roots fit the wide start shot at 390×844, 1080×1920 and 1158×536.
  READY/3/2/1/GO timing and no early physical activation are checked.
- All five waiting poses occur. Old models are removed at the next registration;
  the session ledger/history remain. Roam/Stream overrides remain operational.
- Trail/shield/starburst cosmetics have equal cooldowns, queued 1.5-second highlights
  and finish-contest priority. Visual changes leave root position, WalkSpeed,
  JumpPower, race clock, checkpoints and money unchanged.
- Added start/portal/firework props and shield/trail cosmetics have no damaging
  script or collidable road surface. Existing camera/scenery/opacity, HUD,
  entrance, gifts, reward and fault-handling regressions are retained.
- A stored SHA-256 fingerprint proves the v10 road definitions and full course
  builder/obstacle-motion section are byte-identical. Existing independent
  geometry checks still verify surfaces, forks, intentional jumps and materials.

## Physical-command contact approximation

The actual registration flow starts at 30s + a 4s tournament countdown, then uses
production World navigation with 20Hz approximate contacts, gravity 196.2 and 50ms
jump response. Finish times below are measured from GO, not from registration.
Obstacle motion continues through the lobby, so race outcomes differ from v10's
older start time without changing the track or selecting winners.

| NPCs | Finished | DNF | Measured finish seconds | Fall/stall recoveries | Changes of lead |
| ---: | ---: | ---: | --- | ---: | ---: |
| 5 | 5 | 0 | 102.07–109.67 | 0 | 18 |
| 10 | 10 | 0 | 102.07–119.73 | 0 | 18 |
| 15 | 13 | 2 | 102.07–116.41 | 0 | 18 |
| 20 | 19 | 1 | 102.07–117.34 | 0 | 18 |

Both routes were used; all remaining racers reached Final Sprint and become real
DNFs at 120 seconds. The approximation does not model native Humanoid step-up,
collider volume, friction, root rotation, solver/network effects or loaded outfit
costs. Interpreter wall time is not Roblox FPS. Native 15/20-racer performance
and reliable jumps still require the Studio checklist.

Final validation: **164 distinct tests passed** across the 159-test regression
suite, four registered-field contact runs and the repeated server/World/client
race test. No failures, skipped, cancelled or TODO cases remained in those runs.
Final accounting/UI refinements, required tournament configuration and staged
joint enable/disable contracts were also rechecked in targeted test groups. All **10 native Luau compilation targets**
passed: five raw sources and their five XML-exported equivalents. Manual-source
identity, source restrictions, ZIP integrity and the course fingerprint pass.

The repeated integration test advances 510 simulated seconds through at least
three autonomous races with fresh demo registrations, 20Hz command-following
movement, and real server/state/client source. It still mocks contact/replication;
full gravity/triangle contact is exercised separately by the field-size runs.

The server always supplies registration configuration, even for an older Config.
Older low-level variety/economy fixtures without RegistrationSeconds retain their
legacy domain contract; strict registration is covered separately through the
actual server, the new state-machine tests and these physical-command runs.

See [the exact installation and native checklist](TOURNAMENT_REGISTRATION_REPLACEMENT.md).
