# v7.1 — Starting Dash fall loop

**Historical v7.1 patch.** The current v8 winding trail requires both World and
the client Realm replaced: use [the current instructions](WINDING_TRAIL_REPLACEMENT.md).
The one-file procedure below applies only to the earlier straight v7 course.

For an existing **v7 two-minute course installation**, stop Play and replace only
**ServerScriptService → World (ModuleScript)** with the complete raw source in
[World.lua](../roblox/ServerScriptService/World.lua). Save and start a fresh Play
session. Do not replace either Realm script for this patch. Keep
Workspace.StreamingEnabled=false.

For an older short-course installation, install all five files using
[the full upgrade guide](RACE_SHOW_REPLACEMENT.md) instead.

The course model now has `CourseRevision=show-v7.1-contact`. The client camera marker
remains `race-show-v7`, because the client source has not changed.

## What was wrong

The original starting platform ended at z=52; the first pad began at z=48. The old
jump window started only 14.5 studs from the next pad center (about z=50.5 on the first
transition). That put the takeoff trigger beyond the starting edge. The grounded
check could therefore prevent the jump after the racer had already walked off.
Shorter pads elsewhere could suffer the same late trigger.

The start now overlaps the first pads by two studs. Later jumps use the actual
support edge, current landing height and hurdle position. Each takeoff is requested
once per gate while grounded; continuous flat spans do not request jumps. Recovery
clears velocity and places the collider just above the current position of the last
verified support, including moving bridges. It never awards progress or stops time.
Scoring, rewards, deadlines, cameras, entrances and the economy retain their v7 rules.

## Evidence and remaining native check

Validation: **141 tests passed, zero failed**, and **10 Luau compilation targets
passed** (five raw sources plus five exported equivalents). The manual, XML place
and ZIP contain the complete updated sources.

A new contact approximation reproduced the old 0/48 loop. With the patch, all five
lanes clear Starting Dash and finish all four sections without recovery in the model,
with observed model finish times inside 90–120 seconds. It follows actual MoveTo
commands with gravity 196.2, jump velocity 50, a 50ms jump response, pad bounds,
hurdle/step faces, moving support heights and Air when ground support is lost.

This is still an axis-aligned approximation, not Roblox's Humanoid/contact engine.
It uses point support/obstruction checks rather than a full swept collider. It does
not validate native state transitions, rotating assemblies, racer collisions,
accessory physics, platform friction or replication. The earlier command-only mock
kept FloorMaterial grounded and did not catch this defect.

In Studio, watch a fresh round through Starting Dash: all five progress counters
should pass 0/48 and the first 12 gates. Then watch Moving Bridges, Hazard Zone and
the finish for three rounds. Record any repeated failing gate, recovery count and
actual finish times. Native success is not claimed until that playtest passes.
