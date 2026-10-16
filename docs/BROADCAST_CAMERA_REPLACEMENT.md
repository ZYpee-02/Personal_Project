# Riftbound Live v12 — cinematic racing broadcast

This update changes **only Realm.client.lua** among the five game scripts. The
shared v10 course, server, registration rules, physical navigation and economy
are unchanged. It uses original Roblox presentation, with no imported show assets.

## Exact Studio replacement

If you already installed the v11 registration tournament:

1. Stop Play and save your place.
2. Open the complete [Realm.client.lua](../roblox/StarterPlayerScripts/Realm.client.lua)
   on GitHub and select **Raw**. Copy the entire source.
3. Replace the entire source of the **LocalScript named Realm** under
   **StarterPlayer → StarterPlayerScripts**. Keep exactly one client Realm.
   Edit the saved template, not Players → your player → PlayerScripts.
4. Leave Config, RealmState, World and the server Realm unchanged. Keep
   **Workspace.StreamingEnabled=false**, save, then start a fresh **Play**.
5. Client Output should report **presentation=broadcast-v12**. The unchanged
   course still reports **show-v10-shared-road**. ROAM VIEW is the manual override;
   STREAM VIEW resumes the director. HOLD CAMERA remains available in Test Tools.

For an older installation without fresh round registration, first install the
[five tournament sources](../docs/TOURNAMENT_REGISTRATION_REPLACEMENT.md), using
the current client above. MANUAL_STUDIO_SETUP.md contains all five complete raw
sources. No new ModuleScript, plugin or installer is needed. Preserve intentional
HostUserIds/economy settings. DataStore access and HTTP/TikTok integration remain
disabled. A GitHub push does not update an open Roblox Studio place automatically.

## Broadcast rules

- Empty registration stays in WAITING FOR CHALLENGERS with a slow, animated
  arena/Star Gate view. The instruction to submit a Roblox username stays visible.
- Registered avatars rotate through front, side, close-up and group introductions.
  Six or more registered racers use two-second groups of up to three, with
  one solo close-up in each four-shot cycle;
  smaller rosters use 2.5-second introductions, periodically grouping them.
  Unseen/least-recently-framed racers take priority. Coverage survives new arrivals
  and clears only for a new round. Names appear in the announcement strip and
  existing avatar labels. The announcement rotates one complete username at a
  time within group introductions. Existing wave/stretch/cheer/look/celebrate
  poses continue.
- Star Gate arrival shots alternate with coverage of the registered field. A
  continuous arrival queue cannot monopolize the camera. A last-second entrant
  may get a group/start-grid appearance rather than a solo introduction before
  the server locks registration; the camera never extends registration to finish
  an introduction.
- The four-second READY/3/2/1 sequence uses front, side and rear shots of the whole
  locked grid. Existing harmless fire/sparks/gate effects and GO timing continue.
- Normal racing views last 4, 6 or 8 seconds: FRONT, REAR, SIDE, WIDE, LOW ANGLE,
  LEADER, MID-PACK and FINISH. FINISH is used for competitors actually in the final
  section; earlier in the course that slot becomes SIDE. Views use observed root
  positions and horizontal facing, never invented motion or a full-course fit.
- Subject selection rotates by least-recent coverage, with dedicated leading and
  lower-half selections. Nearby competitors join the shot for overtakes and pack
  racing. Impossible group framing reduces to the same primary competitor.
- Highlights last 1.5–2.5 seconds. Rank gains need another still-racing competitor
  physically nearby; shortcuts need a route transition; jump highlights need
  upward root velocity and an airborne Humanoid; close battles require movement
  and nearby bodies. Power-ups use the server's round-scoped cosmetic event.
  Crossings need a real finished status and timestamp. None creates race results.
- A priority queue holds at most eight highlights, expires stale events after five
  seconds and suppresses repeated events. Finishes outrank overtakes, then
  power-ups/routes/jumps/duels. Four seconds of normal coverage separate ordinary
  highlights; finish events can interrupt lower-priority moments. Excess events
  are intentionally skipped. GO and the locked start always take precedence.
- Nearby views orbit/ease around the observed pack with lens interpolation.
  Long-distance subject transfers use the existing brief translucent gold
  broadcast transition to avoid flying through empty course sections.
- Every new view fits avatar/jump margins inside the HUD's clear action rectangle.
  Native lens-overlap, near-plane rays, subject sightlines and Blockcast queries
  check track, scenery and Terrain. Avatars and already locally hidden visual
  shells are excluded, not the road. Blocked angles try elevated alternatives
  around the same racer. If all candidates fail, the last validated view holds
  while the next frame retries; an unrelated distant starting-grid shot is not
  substituted. A safe shot takes precedence over the requested angle.

## Offline playtest

Use Test Tools → OFFLINE JOIN to submit names in the current window. Start with
an empty lobby, add one racer, then add a second to start the 30-second timer.
Add 15–20 during that window to inspect group coverage. Existing DEMO TESTING is
an explicit opt-in that submits fresh entries every round; normal mode stays empty.
Use the existing trail/shield/starburst controls during a race for highlights.
Overtake/shortcut/jump/finish highlights follow actual race events.

Read-only attributes on PlayerGui → RiftboundHUD expose **BroadcastShot**,
**BroadcastSubjects** (comma-separated currently framed usernames) and
**BroadcastQueue**. They are local inspection aids, not registration APIs.

Verify at 390×844 or 1080×1920 and landscape: complete names, readable avatars,
all grid participants, idle poses, harmless synchronized fire, varied views,
mid-pack coverage, fork/jump highlights, unobstructed finish and podium shots,
and repeated ROAM/STREAM overrides. Inspect bends, arches, trees and moving
obstacles while the camera changes sides. Monitor 5/10/15/20 loaded avatars with
Studio's native profiler; adjust capacity only after measuring.

[Automated results and native testing limits](../docs/BROADCAST_TEST_RESULTS.md)
separate arithmetic/service mocks from actual Roblox rendering and physics.
