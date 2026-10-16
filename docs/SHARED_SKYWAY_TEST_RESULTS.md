# Shared skyway validation (v10)

These are cloud checks against the complete five-source v10 implementation.
**No Roblox Studio renderer, native Humanoid solver, MicroProfiler or live Roblox
server is available in this workspace.** A passing cloud check is not a native
physics, visual or frame-rate certification.

## 5 / 10 / 15 / 20 physical-command contact approximations

Actual World.sprintStep and RealmState run with procedural R6 rigs, equal
WalkSpeed=12.5, JumpPower=50, 20Hz controller/contact samples, gravity 196.2 and
50ms jump response. Ground contacts use barycentric tests against the authored
WedgePart collision-face vertices; obstacle faces block movement. Bodies lose
FloorMaterial when they leave support. Route selection, congestion steering,
jumps, gate validation, finish-plane timing and deadline DNFs use production code.

| NPCs | Measured finishers | DNFs | Finisher elapsed seconds | Fall/stall recoveries | Changes of lead | Cloud interpreter wall seconds |
| ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 5 | 5 | 0 | 106.26–112.72 | 0 | 19 | 19.28 |
| 10 | 10 | 0 | 104.93–113.44 | 0 | 22 | 38.72 |
| 15 | 13 | 2 | 105.58–119.55 | 0 | 20 | 59.22 |
| 20 | 18 | 2 | 105.50–119.22 | 0 | 20 | 80.99 |

Both branches were selected in every field size. Every racer reached at least
gate 44 in Final Sprint; the two unfinished racers in the 20-NPC run reached gate
47. Those racers remain DNFs, with no manufactured crossing, finish time or podium
placement. The 120-second deadline is preserved. The 15/20 fields do not promise
that everybody finishes, even in this approximation.

The harness requires at least 85% measured finishers inside 90–120 seconds, all
remaining racers in Final Sprint with valid DNFs, both route choices, observed
changes of lead and zero fall/stall recoveries. Separate fault-injection tests
exercise actual fall/stall recovery, rejected airborne gates and dead rigs.

Wall times are Node/Fengari interpreter costs for up to 120 simulated seconds,
including mocks and test work. They are **not Roblox FPS**, native server frame
costs, replication measurements or comparable hardware benchmarks. They cannot
establish a production capacity limit. Default SprintCompetitors=16 targets the
requested 15–20 range; set 5/10/15/20 explicitly for native comparisons.

## Geometry and logic evidence

- Real WedgePart transforms contain their declared triangular collision faces.
  Road faces have no interior overlaps; cells occupy separate monotonic Z bands.
  Main/shortcut junctions partition the shared road and reconnect fairly.
- Dense route sampling checks continuous shared/main support and exactly the two
  intentional shortcut jump openings. All 48 gates, 20 grid positions, four
  material sections, shallow banking and bounded moving gates are present.
- Physical controller tests cover grounded sequential gates, airborne rejection,
  fall/stall recovery, finish-plane interpolation, frozen finishers, death and
  cosmetic-gift fairness. Domain tests reject skips, replays, stale rounds, late
  crossings, invalid route labels and branch labels outside branch gates.
- The 20-entry cohort and waiting queue, arrivals, grouped montages, account API
  failures/timeouts, measured rewards, DNFs, leaderboards and automatic rounds
  retain their contracts. An integrated server/World/client command-following
  test runs repeated rounds with 20Hz movement; it is a separate, simpler mock.
- Portrait/landscape projection checks cover close packs, both bends, a 20-racer
  fork, a real change of leader within one camera beat, spotlights, entrances,
  finish/podium shots, camera replacement and Stream/Roam restoration. Lighting,
  opacity, enclosure/scenery masks and safe fallbacks retain regression checks.
- The native Luau compiler passes all **10 targets**: five raw files and their
  five XML-exported equivalents. The exported place has exactly five scripts and
  Workspace.StreamingEnabled=false. Manual blocks equal their raw sources;
  bundles pass the offline source audit and ZIP integrity checks.

Final checks: **149 tests passed; 0 failed, skipped, cancelled or TODO** in
244.38 cloud wall seconds. This includes the repeated server/World/client
integration test (three automatic races, command-following movement at 20Hz,
with separate snapshot/client presentation work). `npm run check:luau` passed
all 10 native compilation targets. A further documentation-link fix was checked
with the three manual-source tests and a fresh complete build/compile.

## What still needs Studio

The approximation does not reproduce Humanoid step-up/grounding, real collider
volume, slope traction/friction, moving-contact impulses, ragdoll/death, root
rotation, solver jitter, network ownership/replication latency or loaded outfit
complexity. Verify default Workspace.Gravity=196.2 when comparing jump behavior.
NPC-to-NPC collisions are deliberately disabled; the approximation does not model
native pushing. Crowd steering and route choice still need visual inspection.

Rendering is not exercised: native materials, triangle seams, island scenery,
waterfalls, asset loading, lighting, camera occlusion, text rasterization and a
black/gray-frame regression must be checked in fresh Studio Play sessions.
The SVG is an authored route plan, not a reviewed gameplay screenshot.

Run the [Studio checklist](SHARED_SKYWAY_REPLACEMENT.md#required-studio-playtests)
with 5, 10, 15 and 20 racers for at least three rounds each, on the actual streaming
PC and a private published server. Measure native client/server frame time,
physics, memory and replication traffic before selecting a production field size.
Keep DataStoreService, real TikTok networking and streaming disabled for this test.
