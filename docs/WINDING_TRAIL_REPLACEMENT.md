# v8 — winding Skybridge obstacle trail

**Historical v8 guide.** The current fantasy skyblock layout uses
[the v9 two-file replacement](FANTASY_SKYBLOCK_REPLACEMENT.md).

![Plan of the winding course](SKYBRIDGE_ROUTE.svg)

This is a route plan, not a captured Roblox render. The actual course is generated
by World.lua; native appearance, collision and performance still need Studio testing.

## Replace two sources in an existing v7/v7.1 installation

1. Stop Play and back up the place.
2. Replace the **entire ServerScriptService → World (ModuleScript)** source with
   [World.lua](../roblox/ServerScriptService/World.lua).
3. Replace the **entire StarterPlayer → StarterPlayerScripts → Realm (LocalScript)**
   source with [Realm.client.lua](../roblox/StarterPlayerScripts/Realm.client.lua).
   This is the client Realm, separate from the server Script of the same name.
4. Keep Workspace.StreamingEnabled=false. Save and start a fresh Play session.

Use GitHub's Raw button and copy only the full Luau source. Do not append code or
edit the temporary Players → PlayerScripts runtime copy. Config, RealmState and
the server Realm retain the same runtime contract; your existing host IDs and
economy settings can stay. The Config file in the complete package only updates a
route-length comment. Older pre-v7 installations need all five files from
[the full installation guide](RACE_SHOW_REPLACEMENT.md).

Expected markers: `Workspace.RiftboundRealm.SkybridgeSprint.CourseRevision` is
`show-v8-winding`; client Output starts `presentation=race-show-v8`.

## Course changes

The centerline now bends 64 studs to either side, creating four broad S turns.
Its measured horizontal length is **1,280.9 studs**; start-to-finish Z displacement
is still 1,152 studs. All five lanes are translated copies of the same route, so
they have equal authored distance. The 120-second deadline and equal WalkSpeed=12
stay in place. Centerline distance divided by speed is about 107 seconds, before
waits/recovery; native timings must be measured rather than guaranteed.

| Section | Physical features |
| --- | --- |
| Starting Dash | Curved colorful stepping blocks, height changes, enlarged landings and hurdle rows |
| Moving Bridges | Narrow blue moving spans, bounded sideways/vertical motion and jumps |
| Hazard Zone | Coral trail blocks, three sweeping wind gates and independent lane hurdles |
| Final Sprint | Purple return bends, final hurdle rows, crown arch and finish podiums |

Pads rotate with the route, vary in width/thickness, and use distinct section
colors. Larger landing blocks and open trail arches mark every sixth gate; side
islands, beacons and crystal fans follow the bends. There are nine hurdle rows,
each with five separately aligned physical hurdles. A long diagonal shared bar
would meet outside lanes too far from their takeoff points, so it is not used.

The starting apron overlaps the first pads. Jump timing intersects each rotated
support along the actual travel direction, including current moving-platform
positions. Sliding-gate waits use obstacle-local coordinates. Finish timing uses
the final segment's crossing plane, with sample interpolation. Checkpoint order,
fall recovery, DNFs and rewards remain measured; active racing roots receive no
animation teleportation. Recovery still returns only to the last verified support.

The director accepts competitors on the wider bends and turns its medium shot
with each segment's heading. Pack/spotlight/finish shots, portrait framing, safe
fallbacks, Roam/Stream controls, and the viewer entrance montage remain in place.
The map is not used as a distant full-course camera shot.

## Validation and native limits

**143 tests passed, zero failed. All 10 Luau compilation targets passed** (five raw
scripts plus five exported equivalents). The build verifies complete raw/manual/
XML/ZIP source identity and StreamingEnabled=false in the exported place.

The route/contact tests cover every lane and all four sections, including rotated
support bounds, gravity, Air after loss of support, a 50ms jump response, hurdles,
moving support heights and measured finish times. Separate camera tests frame
all five racers at both outer bends in portrait and landscape. All five contact-model
racers finish in 90–120 seconds without recovery. These are simulated results.

The contact approximation uses point support and obstruction checks inside
yaw-rotated rectangles. It does not implement Roblox Humanoid states, swept body
collisions, friction, inter-racer contact, asset loading, replication or rendering.
It cannot prove successful native landings or a native 90–120-second finish rate.

Required Studio playtest: watch three complete rounds, checking the first 12 gates,
both outside bends, each moving span, all wind gates and the finish. Record finish
times, DNFs and repeated recovery gates. Test portrait and landscape, Roam/Stream,
one offline join and seven simultaneous offline joins. Check frame rate, body
visibility and label readability. Keep StreamingEnabled=false and external TikTok,
HTTP integration and persistence disabled.
