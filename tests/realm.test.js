import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const luaparse = require('luaparse');
const source = readFileSync(new URL('../roblox/ServerScriptService/RealmState.lua', import.meta.url), 'utf8');
const prelude = `
local Realm = (function() ${source} end)()
local config = { GatheringSeconds = 10, VotingSeconds = 5, StormSeconds = 3, ResultSeconds = 2, MaxCrew = 6 }
local function realm() return Realm.new(config, 0) end
`;

function runLua(code) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  try {
    const status = lauxlib.luaL_dostring(L, to_luastring(prelude + code));
    assert.equal(status, lua.LUA_OK, status === lua.LUA_OK ? undefined : to_jsstring(lua.lua_tostring(L, -1)));
  } finally { lua.lua_close(L); }
}

test('all authored Roblox scripts parse as Lua, with no missing source files', () => {
  let count = 0;
  for (const directory of ['ServerScriptService', 'StarterPlayerScripts']) {
    const root = new URL(`../roblox/${directory}/`, import.meta.url);
    for (const file of readdirSync(root).filter(name => name.endsWith('.lua'))) {
      assert.doesNotThrow(() => luaparse.parse(readFileSync(new URL(file, root), 'utf8'), { luaVersion: '5.3' }), file);
      count++;
    }
  }
  assert.equal(count, 5);
});

test('optional online helpers parse independently and remain outside the offline source tree', () => {
  const root = new URL('../integrations/roblox/', import.meta.url);
  for (const file of readdirSync(root).filter(name => name.endsWith('.lua'))) {
    assert.doesNotThrow(() => luaparse.parse(readFileSync(new URL(file, root), 'utf8'), { luaVersion: '5.3' }), file);
  }
});

test('a round completes only after each phase deadline and awards a shard for free participation', () => runLua(`
local r = realm()
assert(not r:advance(9))
assert(r:advance(10) and r.phase == "voting" and r.round == 1)
assert(r:vote("viewer:1", "ward"))
assert(not r:advance(14))
assert(r:advance(15) and r.phase == "storm" and r.success)
assert(r:advance(18) and r.phase == "result" and r.wins == 1 and r.storms == 1)
assert(r:advance(20) and r.phase == "gathering")
assert(r:advance(30) and r.round == 2 and r.totals.ward == 0)
`));

test('one vote per identity; changing sides moves the existing vote', () => runLua(`
local r = realm(); r:advance(10)
assert(r:vote("a", "ward"))
assert(not r:vote("a", "ward"))
assert(r:vote("a", "sail"))
assert(r.totals.ward == 0 and r.totals.sail == 1)
assert(not r:vote("b", "teleport"))
assert(not r:vote("", "ward"))
assert(not r:vote({}, "ward"))
assert(r.totals.ward + r.totals.sail == 1)
`));

test('gathering, storm, and result reject late or early votes', () => runLua(`
local r = realm()
assert(not r:vote("a", "ward"))
r:advance(10); r:advance(15)
assert(not r:vote("a", "ward"))
r:advance(18)
assert(not r:vote("a", "sail"))
`));

test('crew capacity and case-insensitive deduplication keep avatar slots stable', () => runLua(`
local r = realm()
local ok, member = r:addCrew("Traveler", 1)
assert(ok and member.slot == 1)
assert(not r:addCrew("TRAVELER", 1))
for i = 2, 6 do assert(r:addCrew("Traveler" .. i, i)) end
assert(not r:addCrew("Seventh", 7))
assert(#r.crewOrder == 6)
local snapshot = r:snapshot(2)
assert(#snapshot.crew == 6 and snapshot.seconds == 8)
snapshot.crew[1] = "changed"
assert(r.crew.traveler.username == "Traveler")
`));

test('crew scales the participation goal; ties choose a ward', () => runLua(`
local r = realm()
for i = 1, 6 do r:addCrew("Traveler" .. i, i) end
r:advance(10)
assert(r.requiredVotes == 2)
r:vote("a", "ward"); r:vote("b", "sail")
r:advance(15)
assert(r.choice == "ward" and r.success)
`));

test('a sail majority changes the storm path', () => runLua(`
local r = realm(); r:advance(10)
r:vote("a", "sail"); r:advance(15)
assert(r.choice == "sail" and r.success)
`));

test('insufficient participation records a storm without granting a shard', () => runLua(`
local r = realm()
for i = 1, 6 do r:addCrew("Traveler" .. i, i) end
r:advance(10); r:vote("a", "ward"); r:advance(15); r:advance(18)
assert(not r.success and r.storms == 1 and r.wins == 0)
`));

test('all blessings expire and cannot alter votes, success, or milestones', () => runLua(`
for _, kind in ipairs({ "bloom", "aurora", "giant" }) do
  local r = realm()
  assert(r:bless(kind, 1))
  assert(r:snapshot(2).blessing ~= "")
  assert(r:snapshot(19).blessing == "")
  r:advance(10); r:advance(15); r:advance(18)
  assert(not r.success and r.wins == 0 and r.totals.ward == 0 and r.totals.sail == 0)
end
local r = realm()
assert(not r:bless("win", 0))
`));

test('money uses elapsed seconds, voting participation, and the active-round boundary', () => runLua(`
local r = realm()
r:addCrew("Alice", 1); r:addCrew("Bobby", 2)
r:tick(9); assert(r.crew.alice.balance == 0)
r:advance(10); r:tick(12)
assert(r.crew.alice.balance == 10 and r.crew.bobby.balance == 10)
r:vote("a", "ward", "Alice", 12)
r:tick(15)
assert(r.crew.alice.balance == 34 and r.crew.bobby.balance == 25)
r:advance(15); r:tick(18); r:advance(18)
assert(r.crew.alice.balance == 58 and r.crew.bobby.balance == 40)
assert(r.lastRound[1].username == "Alice" and r.lastRound[1].money == 58)
r:tick(19); assert(r.crew.alice.balance == 58)
`));

test('the next round resets round money and voting bonus while keeping session balances', () => runLua(`
local r = realm(); r:addCrew("Alice", 1)
r:advance(10); r:vote("a", "sail", "Alice", 10)
r:advance(15); r:advance(18)
assert(r.crew.alice.balance == 64 and r:rate(r.crew.alice) == 10)
r:advance(20); r:advance(30)
assert(r.crew.alice.roundMoney == 0 and not r.crew.alice.participated)
assert(r.crew.alice.balance == 64 and r:rate(r.crew.alice) == 7)
assert(r.lastRound[1].money == 64)
`));

test('late heartbeats cannot award money for time beyond the phase deadline', () => runLua(`
local r = realm(); r:addCrew("Alice", 1); r:advance(10)
r:tick(100)
assert(r.crew.alice.balance == 25)
r:tick(99); r:tick(100)
assert(r.crew.alice.balance == 25)
`));

test('mid-round arrivals start earning only after joining and ties sort by arrival slot', () => runLua(`
local r = realm(); r:addCrew("Bobby", 1); r:advance(10); r:tick(12)
r:addCrew("Alice", 2); r:addCrew("Clara", 3); r:tick(13)
assert(r.crew.alice.balance == 5 and r.crew.bobby.balance == 15)
local rows = r:leaderboard(false)
assert(rows[1].username == "Bobby" and rows[2].username == "Alice" and rows[3].username == "Clara")
`));

test('money and rate caps are enforced; snapshots do not expose mutable state', () => runLua(`
local r = realm(); r.config = { GatheringSeconds = 10, VotingSeconds = 5, StormSeconds = 3, ResultSeconds = 2, MaxCrew = 6, MaxBalance = 12, MaxMoneyPerSecond = 6 }
r:addCrew("Alice", 1); r:advance(10); r:vote("a", "ward", "Alice", 10); r:tick(15)
assert(r.crew.alice.balance == 12 and r:rate(r.crew.alice) == 6)
local snapshot = r:snapshot(15)
snapshot.members[1].balance = 999; snapshot.leaderboard[1].money = 999
assert(r.crew.alice.balance == 12)
r:advance(15); r:advance(18)
local result = r:snapshot(18); result.lastRound[1].money = 999
assert(r.lastRound[1].money == 12)
local fresh = realm()
assert(#fresh.crewOrder == 0 and fresh.wins == 0 and fresh.followerCount == 0)
`));

test('targeted simulated gifts validate counts, expire, and never change earnings or votes', () => runLua(`
local r = realm(); r:addCrew("Alice", 1)
for _, value in ipairs({ 0, -1, 1.5, 21, math.huge, "1" }) do assert(not r:gift("Alice", "giant", value, 1)) end
assert(not r:gift("Alice", "giant", 0/0, 1))
assert(not r:gift("Missing", "bloom", 1, 1))
assert(not r:gift("Alice", "win", 1, 1))
assert(r:gift("ALICE", "giant", 2, 1))
assert(r.crew.alice.gifts == 2 and r:snapshot(2).members[1].effect == "giant")
assert(r:snapshot(19).members[1].effect == "")
assert(r:rate(r.crew.alice) == 5 and r.crew.alice.balance == 0)
r:advance(10); r:advance(15); r:advance(18)
assert(not r.success and r.wins == 0)
`));

test('follows are deduplicated, bounded, and memory-only', () => runLua(`
local r = realm()
assert(r:follow("stable:1") and r.followerCount == 1)
assert(not r:follow("stable:1") and not r:follow("") and not r:follow({}))
assert(r:snapshot(0).followers == 1 and r.wins == 0)
r.followerCount = 10000
assert(not r:follow("stable:2"))
assert(realm().followerCount == 0)
`));
