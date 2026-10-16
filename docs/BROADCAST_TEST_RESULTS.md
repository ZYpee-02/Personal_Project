# Cinematic broadcast validation (v12)

Only the client game source changes from v11. Config, RealmState, World and the
server Realm remain byte-identical, including road geometry, NPC navigation,
registration authority, economy and power-up fairness. The v10 course fingerprint
is also checked independently.

## Completed validation

- `npm test`: **174 passed**, zero failures, skipped, cancelled or TODO tests.
  This includes the 510-second simulated repeated server/World/client run, all
  four registered-field contact tests and 11 broadcast-specific tests.
- Final solo/group introduction, full-name announcement and blocked-camera caption
  refinements were rechecked with the targeted montage/obstruction tests; all pass.
- `npm run check:luau`: **10 targets pass** (five complete raw scripts and the
  matching five sources in the generated XML place).
- Manual/source identity, offline API restrictions, ZIP integrity and unchanged
  course fingerprint pass. A Git diff also confirms all four server sources are
  identical to the previous v11 commit.

## Checks exercised

- Twenty staggered arrivals, active Star Gate queues and continuous registration:
  every racer gets pre-race coverage before closure in the tested window. The
  roster locks on time and rejects late entries regardless of the montage.
- 5/10/15/20 actor fixtures: normal 4–8-second shot cadence, front/rear/side/wide/
  low/leader/mid-pack views, rotation beyond the leaders, bounded lens positions,
  actual subjects on screen and unchanged roots/race counters/deadlines.
- Actual root-facing changes alter the camera. All three start-grid views and
  manual ROAM/STREAM switches work under the service mocks.
- Portrait 390×844 and 1080×1920, plus landscape 1158×536: arithmetic framing of
  full avatar/jump margins across eight headings and three elevations.
- Injected native-query responses reject an obstructed front view, choose another
  angle around the same real subject and keep the road in the query filter.
  Query errors hold the validated view rather than authorizing a blocked one.
- Rank/proximity overtakes, route transitions, airborne upward velocity, moving
  duels, cosmetic power-ups and measured-finish status transitions exercise the
  bounded highlight queue, its spacing, durations and finish preemption.
- New round IDs clear montage coverage/highlights. Registration returns empty;
  session history survives. Existing tournament, camera/gray-screen safeguards,
  scenery restoration, physical navigation and offline source checks remain.

## Rechecked contact approximation

The existing registered-field contact tests were rerun with the unchanged server
and World code. Finish times are measured from GO; the time limit is still 120s.

| Racers | Finished | DNF | Measured finish seconds | Fall/stall recoveries |
| ---: | ---: | ---: | --- | ---: |
| 5 | 5 | 0 | 102.07–109.67 | 0 |
| 10 | 10 | 0 | 102.07–119.73 | 0 |
| 15 | 13 | 2 | 102.07–116.41 | 0 |
| 20 | 19 | 1 | 102.07–117.34 | 0 |

Both forks were used. These are approximate 20Hz contacts/gravity and production
movement commands, not native Humanoid collision or Roblox FPS measurements.
The separate broadcast tests exercise client views with 5/10/15/20 actor fixtures.

## Required native Studio testing

The cloud has no Roblox renderer, Humanoid solver, asset streaming or MicroProfiler.
Projection tests use arithmetic CFrame/viewport mocks, not rendered pixels.
Camera obstruction tests inject query responses; they do not reproduce native
Terrain, WedgePart contact volumes, Blockcast tolerances, moving foliage, loaded
outfits or replicated positions. Mock CFrame interpolation also differs from
Roblox's native rotation interpolation. These checks cannot certify clipping,
readable text, animation quality, smoothness, black-screen absence or FPS.

Run the checklist in BROADCAST_CAMERA_REPLACEMENT.md with real 5/10/15/20 racers,
all four sections, both branches, jumps, arches, finish battles and podium results.
Check avatar sizes, long usernames, group name rotation, camera overlap near trees,
side swaps on bends and repeated ROAM/STREAM changes in portrait and landscape.
The director retries on obstruction and holds its last validated pose if all
candidates fail; native playtesting must confirm this does not hold an off-action
view for a sustained obstruction. Excess highlights and last-second solo
introductions are intentionally skippable so server timing remains authoritative.

Earlier v11 validation details are preserved in TOURNAMENT_TEST_RESULTS.md.
The rechecked contact approximation is not native physics or a performance measurement.
The race still needs native Humanoid/appearance load and FPS validation.
