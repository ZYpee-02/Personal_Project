# Future online integration — deliberately separate

Nothing in this directory is bundled by the five manual game scripts, XML place, or
default Rojo project. No TikTok connection is active. The offline playtest requires
none of these settings or modules. Real LIVE connector/account authorization and
Roblox online behavior have not been validated.

The intended later flow is:

`authorized TikTok LIVE connector → Node event queue → optional Roblox HTTP adapter`

The local browser control desk sends simulated events only. A real connector must
be a separate process/module, explicitly installed and authorized later. It must
map stable viewer IDs to joined usernames, deduplicate provider event IDs and gift
streak updates, and send only finalized gift events. It must not fabricate identities
or use a user-supplied display name as proof of ownership. Gift IDs/prices and a
TikTok login mechanism are intentionally not hardcoded.

Node accepts these normalized event envelopes at `POST /api/events`:

```json
{"type":"join","username":"Alice_01"}
```
```json
{"type":"vote","viewer":"tiktok:stable-id","username":"Alice_01","choice":"ward"}
```
```json
{"type":"gift","username":"Alice_01","kind":"giant","count":1}
```
```json
{"type":"follow","viewer":"tiktok:stable-id"}
```

Existing global cosmetic events remain supported:
`{"type":"blessing","kind":"aurora"}`. Choices are `ward` / `sail`; effects
are `bloom` / `aurora` / `giant`; finalized gift counts must be integers 1–20.
For larger provider streaks, the adapter should map them to a bounded spectacle,
rather than blindly enqueueing many duplicate effects. Ordinary chat should be
ignored; map explicit commands such as `!join Alice_01`, `!ward`, and `!sail`.

## Transport retained for a later explicit opt-in

`roblox/LiveBridge.lua` is the former game's HTTPS polling adapter, now moved out
of the offline build. It requires a `BridgeUrl` (HTTPS, no trailing slash), private
`BridgeToken`, and `BridgePollSeconds` (e.g. 3). Its `start(config, enqueue)` function
takes an enqueue callback `(event, done) -> accepted`, where `done(applied, message)`
reports completion. It must be installed and started explicitly; there is no auto-load.

To connect it later, a separately installed server bootstrap can wrap the offline
game's server-only `ServerScriptService.RiftboundEvent:Invoke(event)` in a task and
call `done` with its result. The game never gives a client this hook. The offline
HUD intentionally reports offline mode; online status wiring is separate future work.

`roblox/LiveAvatars.lua` preserves the official username/real-avatar lookup helper
for a future online appearance provider. It is not wired into offline arrival;
enabling it would require an explicit server-side appearance integration. Offline
username labels are not verified accounts.

Later deployment needs user-controlled HTTPS hosting and Allow HTTP Requests in
Roblox, with one Roblox game server per bridge. Bind `HOST=0.0.0.0` only with a
strong `ADMIN_TOKEN` of at least 24 characters. The optional `GAME_TOKEN` must be
different; otherwise the Node service generates and retains one privately under
ignored `.local/game-config.json`. Do not publish credentials or place them in
ReplicatedStorage, client scripts, browser code, or saved instructions.

The operator/connector uses the admin bearer token; the Roblox adapter uses the
game bearer token for `/api/game/events` and `/api/game/ack`. Queues and receipts
remain in memory: events expire after two minutes and all pending events clear
on restart. Delivery is at least once, with a bounded in-server receipt cache.
Multiple Roblox consumers and durable billing/entitlements are not supported.
No save service is needed or used by either optional Roblox module.
