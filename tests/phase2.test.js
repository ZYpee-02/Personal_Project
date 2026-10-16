import test from 'node:test';
import { readFileSync } from 'node:fs';
import { runLua } from './helpers/lua.js';
import { instances } from './helpers/instances.js';
const read = name => readFileSync(new URL(`../roblox/ServerScriptService/${name}`, import.meta.url), 'utf8');
const config = read('Config.lua');
const domain = read('RealmState.lua');
const server = read('Realm.server.lua');
const setup = `local Realm = (function() ${domain} end)()\nlocal Config = (function() ${config} end)()\nConfig.SprintOnly=false; Config.SprintRaceSeconds=120; Config.LoadAvatarAppearances=false\n`;

test('automatic competitions rotate through three activities without a single vote or host action', () => runLua(setup + `
local r = Realm.new(Config, 0)
for i = 1, 6 do r:addCrew("Demo_Crew" .. i, i) end
local seen, results = {}, 0
for now = 0, 185, 0.1 do
    r:tick(now)
    if r.phase=="storm" and r.activity.id=="sprint" then
        for _,key in ipairs(r.crewOrder) do
            local m=r.crew[key]
            if m.activityEntered and m.score<48 and now-r.activityStarted>(m.score+1)*0.5 then r:recordCheckpoint(m.username,m.score+1,now,r.round) end
        end
    end
    if r:advance(now) and r.phase == "result" then
        results = results + 1
        assert(#r.winners == 3 and r.winners[1].score > 0)
        assert(r.winners[1].prize == 120)
        assert(r.teamScore > 0, "automatic entrants must accumulate points without votes")
    end
    if r.phase == "storm" then seen[r.activity.id] = true end
end
assert(results == 3 and seen.starfall and seen.sprint and seen.relay)
assert(r.wins >= 2, "automatic participation must save shards without manual input")
assert(next(r.votes) == nil)
for _, key in ipairs(r.crewOrder) do assert(r.crew[key].balance > 0) end
`));

test('competition score, progress and bounty are independent of heartbeat frequency', () => runLua(setup + `
local function simulate(step)
    local r = Realm.new(Config, 0)
    r:addCrew("Alice", 1); r:addCrew("Bobby", 2)
    r:advance(12); r:advance(20)
    local t = 20 + step
    while t < 50 - 0.00001 do r:tick(t); t = t + step end
    r:tick(50); r:advance(50)
    return r
end
local a, b = simulate(0.1), simulate(1)
for _, key in ipairs(a.crewOrder) do
    assert(a.crew[key].score == b.crew[key].score)
    assert(math.abs(a.crew[key].balance - b.crew[key].balance) < 0.0001)
end
assert(a.winners[1].username == b.winners[1].username)
`));

test('sprint winners use finish time, not gifts, money, iteration order, or polling order', () => runLua(setup + `
local function simulate(withGift)
    local r = Realm.new(Config, 0); r.round = 1
    r:addCrew("Alice", 1); r:addCrew("Bobby", 2); r:addCrew("Clara", 3)
    r:advance(12); assert(r.activity.id == "sprint")
    r:advance(20)
    if withGift then r:gift("Bobby", "giant", 20, 21) end
    -- Explicit simulated gate observations, not elapsed-time race progress.
    for cp=1,48 do
        assert(r:recordCheckpoint("Alice",cp,20+cp*0.5,r.round))
        assert(r:recordCheckpoint("Bobby",cp,20+cp*0.45,r.round))
        assert(r:recordCheckpoint("Clara",cp,20+cp*0.4,r.round))
    end
    r:tick(50); r:advance(50)
    assert(r.crew.alice.finishedAt > 0 and r.crew.bobby.finishedAt > 0)
    return r
end
local a, b = simulate(false), simulate(true)
for i, row in ipairs(a.winners) do assert(row.username == b.winners[i].username and row.score == 48) end
for _, key in ipairs(a.crewOrder) do assert(a.crew[key].balance == b.crew[key].balance) end
`));

test('mid-competition arrivals receive no retroactive progress, and expired rounds cannot accept entrants', () => runLua(setup + `
local r = Realm.new(Config, 0); r:addCrew("Early", 1)
r:advance(12); r:advance(20); r:tick(45); r:addCrew("Late", 2)
r:tick(50)
assert(r.crew.late.score < r.crew.early.score)
assert(math.abs(r.crew.late.distance - 5 * r.crew.late.pace) < 0.00001)
r:addCrew("Expired", 3)
assert(not r.crew.expired.activityEntered and r.crew.expired.score == 0)
r:advance(50)
for _, winner in ipairs(r.winners) do assert(winner.username ~= "Expired") end
`));

test('round results pay once, snapshots are isolated, and balances remain bounded', () => runLua(setup + `
Config.MaxBalance = 30
local r = Realm.new(Config, 0); r:addCrew("Alice", 1)
r:advance(12); r:advance(20); r:advance(50)
assert(r.crew.alice.balance == 30 and r.crew.alice.roundWins == 1)
assert(not r:advance(50))
assert(r.crew.alice.balance == 30 and r.crew.alice.roundWins == 1)
local snapshot = r:snapshot(50)
snapshot.winners[1].prize = 999; snapshot.activity.name = "mutated"; snapshot.lastGift.sequence = 99
snapshot.activityLeaders[1].score = 999
assert(r.winners[1].prize == 120 and r.activity.name ~= "mutated" and r.giftSequence == 0)
assert(r.crew.alice.score ~= 999)
`));

test('unattended empty rounds advance safely and invalid durations fail clearly', () => runLua(setup + `
local r = Realm.new(Config, 0)
r:advance(12); r:advance(20); r:advance(50)
assert(r.phase == "result" and #r.winners == 0 and r.wins == 0)
r:advance(60); assert(r.phase == "gathering")
Config.StormSeconds = 0
assert(not pcall(function() Realm.new(Config, 0) end))
`));

function serverSimulation(isStudio, enabled) {
  return setup + instances + `
local now, jobs, heartbeat, captures = 0, {}, {}, {}
local arrivals, frames, sawResult, gifts = 0, 0, false, false
Config.OfflineDemoEnabled = ${enabled}
local players = { PlayerAdded = { Connect = function() end }, PlayerRemoving = { Connect = function() end }, GetPlayers = function() return {} end }
local runtime = { IsStudio = function() return ${isStudio} end, Heartbeat = signal() }
workspace={StreamingEnabled=false}
local storage = instance("ReplicatedStorage", "ReplicatedStorage")
local world = {
    build = function(c) assert(c.PersistenceEnabled == false) end,
    offlineAvatar = function() return { Destroy = function() end } end,
    arrive = function(_, slot, username) arrivals = arrivals + 1; assert(slot <= 18) end,
    render = function(s)
        captures[#captures + 1] = s
        if s.phase == "result" and #s.winners > 0 then sawResult = true end
        if s.lastGift.sequence > 0 then gifts = true end
    end,
    animate = function() frames = frames + 1 end,
    loadAppearance = function() end,
    cameraBounds = function() end,
    courseInfo = function() return {checkpoints=48} end,
    resolveUsername = function() return 123 end,
    validUsername = function(name) return type(name)=="string" and #name>=3 end,
    sprintStep = function(state,time)
        if state.phase=="storm" and state.activity.id=="sprint" then
            for _,key in ipairs(state.crewOrder) do
                local m=state.crew[key]
                if m.activityEntered and m.score<48 and time-state.activityStarted>(m.score+1)*0.5 then state:recordCheckpoint(m.username,m.score+1,time,state.round) end
            end
        end
    end,
}
local modules = instance("ServerScriptService", "ServerScriptService")
for _, name in ipairs({ "Config", "RealmState", "World" }) do instance("ModuleScript", name, modules) end
script = { Parent = modules }
require = function(token)
    if token == modules.Config then return Config end
    if token == modules.RealmState then return Realm end
    if token == modules.World then return world end
    error("Unexpected dependency")
end
os.clock = function() return now end
game = { GetService = function(_, name)
    if name == "Players" then return players end
    if name == "ReplicatedStorage" then return storage end
    if name == "RunService" then return runtime end
    error("Unexpected service: " .. name)
end }
warn = function(message) error(message) end
task = {
    spawn = function(fn, ...) local args = {...}; table.insert(jobs, { co = coroutine.create(function() fn(table.unpack(args)) end), wake = now }) end,
    wait = function(seconds) return coroutine.yield(seconds or 0.03) end,
}
(function() ${server} end)()
for step = 1, 3400 do
    now = step / 10
    runtime.Heartbeat:Fire(0.1)
    local count = #jobs
    for i = 1, count do
        local job = jobs[i]
        if coroutine.status(job.co) ~= "dead" and job.wake <= now + 0.00001 then
            local ok, waitFor = coroutine.resume(job.co)
            assert(ok, waitFor)
            job.wake = now + (waitFor or 0)
        end
    end
end
assert(frames > 1000 and #captures > 100)
local final = captures[#captures]
`;
}

test('actual server orchestration runs demo arrivals, gifts and multiple rounds without any human/keeper actions', () => runLua(serverSimulation('true', 'true') + `
assert(arrivals == #Config.DemoNames and sawResult and gifts)
assert(final.round >= 3 and final.followers > 0 and final.demo)
for _, member in ipairs(final.members) do assert(member.balance > 0 and member.gifts >= 1) end
`));

test('Studio-only demo never invents viewers or gifts in a non-Studio server', () => runLua(serverSimulation('false', 'true') + `
assert(arrivals == 0 and not sawResult and not gifts and not final.demo)
assert(final.round >= 3 and #final.members == 0)
`));

test('turning offline demo off leaves the automatic round scheduler running', () => runLua(serverSimulation('true', 'false') + `
assert(arrivals == 0 and not gifts and not final.demo and final.round >= 3)
`));
