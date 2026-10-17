# Solo entrance / race preparation validation (v13)

No Roblox Studio renderer, Humanoid solver, animation preview or native FPS profiler
is available in this cloud environment. Studio playtesting has not been performed.

## Completed runs

Validation covers **192 distinct test cases across the full-suite run and targeted
reruns**, plus all **10 Luau compilation targets** (five raw sources and five
matching XML exports). No diagnosed failures remain unresolved.

The initial full run completed 186 cases: 181 passed and five older fixtures failed
because their World stubs lacked the required preparation observer or assumed the
old unscoped four-second entrance. Those fixtures were corrected; both affected
files passed **23/23** on rerun. Five subsequently added real-server batch/identity
cases passed with their file (**8/8**). The new surface check caught the staging
ramp/platform lip, which was corrected and passed its rerun. Counts overlap across
runs and should not be added together.

Final preparation tests cover 2/5/10/20 command-following fields without ordinary
grid warps or recoveries, as well as camera projections, API failures, aliases,
resets and recovery. Final source/export/registration/startup contracts passed
**39/39**. The repeated server/World/client integration was rerun after the approach
change: **690 simulated seconds, at least three autonomous races**, all passing.
Five-script manual identity, offline restrictions, ZIP integrity and the unchanged
v10 course fingerprint pass. Studio was not run.

## Automated coverage

- Twenty accepted entries reserve unique positions, remain registered while queued,
  receive exactly one full 4.5-second individual introduction, then wait for a
  round/sequence-scoped physical arrival acknowledgement before the next solo.
- Registration closes on time, locks the roster, retains accepted pending entries
  and rejects late/stale requests. Advancing the clock alone cannot launch unready
  actors. All-ready preparation enters the launch countdown without an extra delay.
- Canonical account IDs reject aliases/duplicates, including verified/offline alias
  mixing. Ledger earnings/history survive fresh rounds and username changes.
- Actual World pre-grid MoveTo commands are exercised with 2/5/10/20 actors using
  explicit command-following movement. Normal paths complete without grid warps;
  stalled/fallen actors exercise the separate marked recovery path.
- Appearance failure and hung-loading timeout preserve FIFO/registration; stale
  jobs cannot install an old rig into a later round. The actual native-loader code
  is exercised with mocked APIs, not downloaded avatar assets.
- The client shows one subject throughout the solo, NEW CHALLENGER then username,
  distinct entrance angles, walk coverage, ready/pending status and all four batch
  controls. Roam/Stream overrides remain operational.
- Preparation restores the original race speed at GO. Giant gifts cannot change
  preparation/racing collider scale; visuals defer without changing earnings.
- Static surface checks sample all 20 approach centerlines: supporting floor stays
  within 0.2 studs of intended foot height and approach slopes stay below 25 degrees.
  This caught and corrected a flat-stage/ramp overlap that the movement mock missed.
- Existing registration, economy, race-contact, broadcast-camera, offline export
  and startup regressions remain. The course builder fingerprint stays unchanged.

Some existing v11 isolated-domain and snapshot tests explicitly select the older
pure-domain contract to retain their original timing/projection assertions. The
production server requires SoloEntrances=true. New v13 tests and real-server tests
exercise the mandatory preparation gate; legacy fixtures are not evidence that the
production gate can be bypassed.

## Command-following preparation observations

These runs use the production preparation controller with simulated MoveTo motion.
The clock starts at simultaneous registration. Walking is serialized after each
solo; the two-racer case also waits for the 30-second registration deadline.

| Racers | Full solo time | Launch countdown begins | Preparation recoveries |
| ---: | ---: | ---: | ---: |
| 2 | 9.0s | 30.0s | 0 |
| 5 | 22.5s | 58.2s | 0 |
| 10 | 45.0s | 114.5s | 0 |
| 20 | 90.0s | 222.7s | 0 |

The four-second READY/3/2/1 ceremony follows those timestamps. These are mock
observations, not native timing guarantees. A twenty-racer lobby therefore has
90 seconds of introductions plus physical walking time; it does not start after
only 90 seconds. Existing road-contact approximations still measure 102–120-second
finishes from GO, with genuine deadline DNFs rather than invented finish times.
Those comparison fixtures retain their earlier 34-second GO time; they do not
predict the moving-obstacle phase or native outcomes of the later v13 launch.

## Limits and native Studio requirements

The preparation movement mock directly follows production Humanoid MoveTo goals
in three dimensions. It does not reproduce gravity, friction, collider rotation,
Humanoid slope/step handling, grounded-state lag, outfit weights, replication or
native path obstruction. The older race-contact approximation separately exercises
gravity/contact for the unchanged road. Neither is native physics certification.

Projection/GUI checks use arithmetic CFrame/service mocks, not rendered images or
font rasterization. Native account APIs are mocked for failure/timeout/race tests.
Wall times in the interpreter are not Roblox FPS and cannot establish 20-avatar
performance. Real outfit loading, 4–5-second visual timing over replication, portal
poses, camera safety on every angle and native slopes/recovery need Studio testing.

See SOLO_ENTRANCE_REPLACEMENT.md for the complete native checklist. Keep streaming
off, persistence/network integration disabled and normal demo seeding off.
