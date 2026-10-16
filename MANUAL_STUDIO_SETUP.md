# Riftbound Live v7 — complete raw scripts for the two-minute race show

**Replace all FIVE complete sources together.** The long course, state contract,
entrance queue and section director must match. Follow docs/RACE_SHOW_REPLACEMENT.md
for exact behavior, offline/verified join modes and the native Studio checklist.
No Command Bar installer, serialized code wrapper or new game module is used.

## Install with Play stopped

1. Back up the working place. Stop Play. Set Workspace.StreamingEnabled=false in
   Properties and save. The generated place already has streaming disabled. The
   server refuses this playtest configuration if streaming is enabled.
2. Under ServerScriptService, keep one ModuleScript each named Config, RealmState
   and World. Keep one normal Script named Realm, Enabled, RunContext=Legacy.
3. Under StarterPlayer → StarterPlayerScripts, keep one LocalScript named Realm,
   Enabled. This is a different Realm from the server Script.
4. Replace each entire source with its matching raw Luau block below, without
   Markdown fences. Do not append/combine sources or create duplicate scripts.
   Preserve configured HostUserIds in Config. Edit the saved StarterPlayerScripts
   template, not Players → your name → PlayerScripts (the runtime copy).
5. Save, then press Play. Expect server [Riftbound] Ready and client diagnostics
   presentation=race-show-v7. Watch at least three automatic rounds, then Stop/Play
   again to verify the saved source and fresh-start behavior.

```text
ServerScriptService
├── Config       (ModuleScript)
├── RealmState   (ModuleScript)
├── World        (ModuleScript)
└── Realm        (Script; Realm.server.lua)
StarterPlayer
└── StarterPlayerScripts
    └── Realm    (LocalScript; Realm.client.lua)
```

The server creates ReplicatedStorage.Riftbound plus Snapshot/Action/Notice remotes.
Do not create them manually. Missing-module/type/duplicate errors are reported by
bounded startup checks. Keep HTTP Requests and Studio API Services access disabled;
no publication, plugin, Node bridge or external TikTok connection is needed.

## Expected show

The route is 1,152 studs with 48 measured gates across Starting Dash, Moving Bridges,
Hazard Zone and Final Sprint. Five server-owned Humanoids use the same movement
settings. The 120-second deadline does not manufacture winners: actual checkpoint
observations and a finish-plane crossing determine times, DNFs and rewards. The
12-stud/second baseline is about 96 seconds before waits/jumps/recovery. Fall/stall
recovery returns only to the last verified pad and retains the clock.

The director follows nearby real competitors and the active section, periodically
shows another racer, covers the final stretch and celebrates podium winners. It
uses medium shots and a close starting-grid fallback, never a whole-route zoom-out.
ROAM VIEW and STREAM VIEW remain available. The named template Baseplate is hidden
locally in Stream and restored in Roam. Light/effect/shell isolation remains reversible.

TEST TOOLS → OFFLINE JOIN creates a local labeled stand-in with no account request.
ROBLOX JOIN / VERIFY ACCOUNT uses a bounded native Roblox username lookup and optional
appearance APIs. A normal entrance lasts four seconds; bursts group three for 2.5
seconds. New montages defer near a contested finish. Movement, scoring and round
clocks continue; newcomers enter the next eligible cohort after presentation.

Demo_ viewers, gifts/follows and all money are fictional/offline test data. Set
ResolveViewerUsernames=false and LoadAvatarAppearances=false for zero authored
account/appearance requests. Data persistence and real TikTok integration remain
disabled. Optional native avatar loading can fetch normal Roblox outfit assets;
it is separate from custom HTTP. Failed/late appearance loads retain fallback rigs.

Automated checks cover authored geometry, jump feasibility, command following,
measured results, economy, queues, failure handling, camera framing and exports.
**They do not simulate native Roblox collision, Humanoid jumping, moving-platform
contact or rendering.** Real Studio playtests must establish native completion times,
section traversal, avatar loading, portrait readability and absence of blank views.
See docs/RACE_SHOW_REPLACEMENT.md for the precise playtest and tuning checklist.

## Complete source files

### Config.lua

Create a **ModuleScript** named **Config** under **ServerScriptService**.

```luau
-- Simulated LIVE events; optional Roblox appearance loading only. No TikTok or saves.
return {
    HostUserIds = {}, -- Your numeric Roblox user ID(s), required for published host controls.
    PersistenceEnabled = false, -- Must stay false: all game state is in memory.
    BaseMoneyPerSecond = 5,
    VoteMoneyPerSecond = 3,
    WinMoneyPerSecond = 2,
    MaxMoneyPerSecond = 100,
    MaxBalance = 1000000000,
    AutoActivities = true,
    AutoJoinPlayers = false, -- host is a spectator; JOIN tools still enqueue any username.
    SprintOnly = true, -- false restores Starfall/Sprint/Relay rotation. Sprint is always physical.
    SprintCompetitors = 5,
    SprintRaceSeconds = 120,
    SprintWalkSpeed = 12, -- 1,152-stud route: about 96 seconds before jumps/recovery.
    ResolveViewerUsernames = true, -- Verified JOIN uses native Roblox account lookup.
    EntranceSeconds = 4, -- Normal individual montage; bursts group three for 2.5s.
    SprintFinishBonus = 40,
    LoadAvatarAppearances = true, -- false disables outfits; OFFLINE JOIN also skips account lookup.
    AppearanceTimeoutSeconds = 8,
    DemoAppearanceUserIds = { 1, 156, 261, 2, 3 }, -- cosmetic accounts, not LIVE viewers.
    ActivityMoneyPerSecond = 2,
    RoundWinMoneyPerSecond = 1,
    CoinsPerPoint = 2,
    RoundPrizes = { 120, 75, 40 },
    GatheringSeconds = 12,
    VotingSeconds = 8,
    StormSeconds = 30, -- The automatic competition plays during this phase.
    ResultSeconds = 10,
    MaxCrew = 18,
    MaxQueuedArrivals = 30,
    OfflineDemoEnabled = true,
    DemoStudioOnly = true, -- Never imply the seeded crew are real LIVE viewers.
    DemoNames = { "Demo_Astra", "Demo_Lumen", "Demo_Nova", "Demo_Fern", "Demo_Orion" },
    AutoSimulateGifts = true,
    DemoGiftSeconds = 18,
    SceneUpdatesPerSecond = 12, -- Bound server-side procedural animation replication.
    SnapshotSeconds = 0.5,
    StreamCameraDefault = true,
}
```

### RealmState.lua

Create a **ModuleScript** named **RealmState** under **ServerScriptService**.

```luau
-- Pure Lua domain logic, shared by the Roblox server and the automated tests.
local Realm = {}
Realm.__index = Realm

local activities = {
    { id = "starfall", name = "STARFALL SCRAMBLE", instruction = "Collect falling stars around the crystal ring.", goal = 0, teamPerMember = 20 },
    { id = "sprint", name = "SKYBRIDGE SPRINT", instruction = "48 gates / 4 sections. Falls recover to the last verified pad.", goal = 48, teamPerMember = 10 },
    { id = "relay", name = "HEARTSEED RELAY", instruction = "Carry energy between the shrines and heartseed.", goal = 0, teamPerMember = 16 },
}

local function pace(username, round, activity)
    local hash = round * 193 + #activity * 37
    for i = 1, #username do hash = (hash * 31 + string.byte(username, i)) % 65521 end
    return 0.55 + (hash % 401) / 1000
end

function Realm.new(config, now)
    for _, key in ipairs({ "GatheringSeconds", "VotingSeconds", "StormSeconds", "ResultSeconds" }) do
        assert(type(config[key]) == "number" and config[key] > 0 and config[key] < math.huge, key .. " must be a finite positive duration")
    end
    return setmetatable({
        config = config,
        phase = "gathering",
        deadline = now + config.GatheringSeconds,
        round = 0,
        crew = {},
        crewOrder = {},
        votes = {},
        totals = { ward = 0, sail = 0 },
        wins = 0,
        storms = 0,
        lastTick = now,
        followers = {},
        followerCount = 0,
        lastRound = {},
        choice = "ward",
        success = false,
        requiredVotes = 1,
        message = "The rift is quiet. Welcome a traveler to your sky island.",
        blessing = "",
        blessingUntil = 0,
        activity = config.SprintOnly == true and activities[2] or activities[1],
        activityStarted = now,
        activityEntrants = 0,
        teamScore = 0,
        teamTarget = 0,
        winners = {},
        entranceQueue = {}, entranceSequence = 0, entrance = nil,
        giftSequence = 0,
        lastGift = { username = "", kind = "", count = 0, sequence = 0 },
    }, Realm)
end

function Realm:addCrew(username, userId)
    local key = string.lower(username)
    if self.crew[key] then return false, "That traveler is already on the island." end
    if #self.crewOrder >= self.config.MaxCrew then return false, "The island is full for this session." end
    self.crew[key] = {
        username = username, userId = userId, slot = #self.crewOrder + 1,
        balance = 0, roundMoney = 0, participated = false,
        gifts = 0, effect = "", effectUntil = 0,
        roundWins = 0, score = 0, distance = 0, activityEntered = false,
        enteredAt = self.lastTick, pace = 0, finishedAt = 0, checkpointAt = 0,
        raceStatus = "waiting", placement = 0, lastRacedRound = -1, entranceDone = true, recoveries = 0,
    }
    table.insert(self.crewOrder, key)
    if self.config.AutoActivities and self.phase == "storm" and self.activity.id ~= "sprint" and self.lastTick < self.deadline then self:enterActivity(self.crew[key], self.lastTick) end
    self.message = username .. " stepped through the star gate."
    return true, self.crew[key]
end

-- A bounded presentation queue. It never changes the race clock or standings.
function Realm:queueEntrance(username)
    local member = self.crew[string.lower(username)]
    if not member or not member.entranceDone then return false end
    if #self.entranceQueue >= (self.config.MaxQueuedArrivals or 30) then return false end
    member.entranceDone = false
    table.insert(self.entranceQueue, member.username)
    return true
end

function Realm:advanceEntrances(now)
    if self.entrance and now >= self.entrance.endsAt then
        for _, name in ipairs(self.entrance.names) do self.crew[string.lower(name)].entranceDone = true end
        self.entrance = nil
    end
    if self.entrance or #self.entranceQueue == 0 then return end
    -- Keep new camera interruptions away from a live finish contest.
    if self.phase == "storm" and self.activity.id == "sprint" then
        for _, member in pairs(self.crew) do
            if member.raceStatus == "racing" and member.distance >= self.activity.goal - 5 then return end
        end
    end
    local count = #self.entranceQueue >= 4 and math.min(3, #self.entranceQueue) or 1
    local names = {}
    for _ = 1, count do names[#names + 1] = table.remove(self.entranceQueue, 1) end
    self.entranceSequence = self.entranceSequence + 1
    self.entrance = { sequence = self.entranceSequence, names = names, startedAt = now,
        endsAt = now + (count > 1 and 2.5 or (self.config.EntranceSeconds or 4)) }
end

function Realm:nextCohort()
    local waiting = {}
    for _, key in ipairs(self.crewOrder) do
        local member = self.crew[key]
        if member.entranceDone then waiting[#waiting + 1] = member end
    end
    table.sort(waiting, function(a, b)
        if a.lastRacedRound ~= b.lastRacedRound then return a.lastRacedRound < b.lastRacedRound end
        return a.slot < b.slot
    end)
    local cohort = {}
    for i = 1, math.min(#waiting, self.config.SprintCompetitors or 5) do cohort[i] = waiting[i] end
    return cohort
end

function Realm:rate(member)
    return math.min(self.config.MaxMoneyPerSecond or 100,
        (self.config.BaseMoneyPerSecond or 5) + self.wins * (self.config.WinMoneyPerSecond or 2)
        + (member.participated and (self.config.VoteMoneyPerSecond or 3) or 0)
        + (member.activityEntered and self.phase == "storm" and (self.config.ActivityMoneyPerSecond or 2) or 0)
        + member.roundWins * (self.config.RoundWinMoneyPerSecond or 1))
end

function Realm:credit(member, amount)
    local credited = math.max(0, math.min(amount, (self.config.MaxBalance or 1000000000) - member.balance))
    member.balance = member.balance + credited
    member.roundMoney = member.roundMoney + credited
end

function Realm:enterActivity(member, now, lane)
    member.activityEntered, member.enteredAt, member.lastRacedRound = true, now, self.round
    member.raceLane = lane
    member.pace = self.activity.id == "sprint" and 0 or pace(member.username, self.round, self.activity.id)
    member.raceStatus = self.activity.id == "sprint" and "racing" or "waiting"
    member.checkpointAt = now
    self.activityEntrants = self.activityEntrants + 1
    self.teamTarget = self.activityEntrants * self.activity.teamPerMember
end

function Realm:tick(now)
    if now <= self.lastTick then return end
    -- Split at the phase boundary so a delayed heartbeat never pays for result time.
    local earningEnd = math.min(now, self.deadline)
    local elapsed = math.max(0, earningEnd - self.lastTick)
    if self.phase == "voting" or self.phase == "storm" then
        for _, key in ipairs(self.crewOrder) do
            local member = self.crew[key]
            self:credit(member, self:rate(member) * elapsed)
            if self.config.AutoActivities and self.phase == "storm" and member.activityEntered and self.activity.id ~= "sprint" then
                local distance = math.max(0, earningEnd - member.enteredAt) * member.pace
                local score = math.floor(distance + 0.000001)
                self:credit(member, math.max(0, score - member.score) * (self.config.CoinsPerPoint or 2))
                member.distance, member.score = distance, score
            end
        end
    end
    self.teamScore = 0
    for _, key in ipairs(self.crewOrder) do self.teamScore = self.teamScore + self.crew[key].score end
    self.lastTick = now
end

-- Only the server's physical controller calls these methods. Elapsed time alone
-- NEVER advances Sprint or produces a finisher. Reject stale/skipped/replayed gates.
function Realm:recordCheckpoint(username, checkpoint, at, round)
    local member = type(username) == "string" and self.crew[string.lower(username)]
    if self.phase ~= "storm" or self.activity.id ~= "sprint" or round ~= self.round or not member
        or member.raceStatus ~= "racing" or not member.activityEntered then return false end
    if type(at) ~= "number" or at ~= at or at < member.checkpointAt or at > self.deadline
        or type(checkpoint) ~= "number" or checkpoint ~= member.score + 1 or checkpoint > self.activity.goal then return false end
    member.score, member.distance, member.checkpointAt = checkpoint, checkpoint, at
    self:credit(member, self.config.CoinsPerPoint or 2)
    if checkpoint == self.activity.goal then
        member.finishedAt, member.raceStatus = at, "finished"
        self:credit(member, self.config.SprintFinishBonus or 40)
        for _, row in ipairs(self:activityLeaderboard()) do self.crew[string.lower(row.username)].placement = row.placement end
    end
    self.teamScore = 0
    for _, key in ipairs(self.crewOrder) do self.teamScore = self.teamScore + self.crew[key].score end
    return true
end

function Realm:raceDistance(username, distance, round)
    local member = self.crew[string.lower(username)]
    if self.phase ~= "storm" or self.activity.id ~= "sprint" or round ~= self.round or not member or member.raceStatus ~= "racing" then return false end
    if type(distance) ~= "number" or distance ~= distance then return false end
    member.distance = math.max(member.score, math.min(member.score + 0.999, distance))
    return true
end

function Realm:raceDNF(username, round)
    local member = self.crew[string.lower(username)]
    if round ~= self.round or self.phase ~= "storm" or not member or member.raceStatus ~= "racing" then return false end
    member.raceStatus = "dnf"
    return true
end

function Realm:raceComplete()
    if self.phase ~= "storm" or self.activity.id ~= "sprint" or self.activityEntrants == 0 then return false end
    for _, key in ipairs(self.crewOrder) do
        local member = self.crew[key]
        if member.activityEntered and member.raceStatus == "racing" then return false end
    end
    return true
end

function Realm:activityLeaderboard()
    local rows = {}
    for _, key in ipairs(self.crewOrder) do
        local member = self.crew[key]
        if member.activityEntered then
            table.insert(rows, { username = member.username, score = member.score, distance = member.distance, finishedAt = member.finishedAt, elapsed = member.finishedAt > 0 and member.finishedAt - member.enteredAt or 0, status = member.raceStatus, slot = member.slot })
        end
    end
    table.sort(rows, function(a, b)
        if self.activity.id == "sprint" and (a.finishedAt > 0) ~= (b.finishedAt > 0) then return a.finishedAt > 0 end
        if self.activity.id == "sprint" and a.status ~= b.status and (a.status == "dnf" or b.status == "dnf") then return b.status == "dnf" end
        if a.score ~= b.score then return a.score > b.score end
        if a.finishedAt > 0 and b.finishedAt > 0 and a.finishedAt ~= b.finishedAt then return a.finishedAt < b.finishedAt end
        if a.distance ~= b.distance then return a.distance > b.distance end
        return a.slot < b.slot
    end)
    local lastTime, place = nil, 0
    for i, row in ipairs(rows) do
        if row.finishedAt > 0 then
            if row.finishedAt ~= lastTime then place = i end
            row.placement, lastTime = place, row.finishedAt
        else row.placement = 0 end
    end
    return rows
end

function Realm:leaderboard(roundOnly)
    local rows = {}
    for _, key in ipairs(self.crewOrder) do
        local member = self.crew[key]
        table.insert(rows, {
            username = member.username, money = roundOnly and member.roundMoney or member.balance,
            perSecond = self:rate(member), gifts = member.gifts, slot = member.slot,
        })
    end
    table.sort(rows, function(a, b)
        if a.money == b.money then return a.slot < b.slot end
        return a.money > b.money
    end)
    return rows
end

function Realm:vote(viewer, choice, username, now)
    if self.phase ~= "voting" then return false, "Voting opens when the rift awakens." end
    if choice ~= "ward" and choice ~= "sail" then return false, "Choose ward or sail." end
    if type(viewer) ~= "string" or #viewer < 1 or #viewer > 100 then return false, "A viewer identity is required." end
    if self.votes[viewer] == choice then return false, "Your vote is already counted." end
    if now then self:tick(now) end
    -- One vote per viewer. Changing sides moves the existing vote.
    if self.votes[viewer] then
        self.totals[self.votes[viewer]] = self.totals[self.votes[viewer]] - 1
    end
    self.votes[viewer] = choice
    self.totals[choice] = self.totals[choice] + 1
    local member = type(username) == "string" and self.crew[string.lower(username)] or nil
    if member then member.participated = true end
    return true, "Your voice reached the island."
end

function Realm:gift(username, kind, count, now)
    if type(username) ~= "string" then return false, "Choose a traveler first." end
    local member = self.crew[string.lower(username)]
    if not member then return false, "Join that username before sending a simulated gift." end
    if kind ~= "bloom" and kind ~= "aurora" and kind ~= "giant" then return false, "Unknown gift effect." end
    if type(count) ~= "number" or count ~= count or count < 1 or count > 20 or count ~= math.floor(count) then
        return false, "Gift count must be a whole number from 1 to 20."
    end
    member.gifts = member.gifts + count
    member.effect, member.effectUntil = kind, now + 18
    self:bless(kind, now)
    self.giftSequence = self.giftSequence + 1
    self.lastGift = { username = member.username, kind = kind, count = count, sequence = self.giftSequence }
    self.message = username .. " received " .. kind .. " x" .. count .. " (simulated)."
    return true, self.message
end

function Realm:follow(viewer)
    if type(viewer) ~= "string" or #viewer < 1 or #viewer > 100 then return false, "A viewer identity is required." end
    if self.followers[viewer] then return false, "That follow was already counted this session." end
    if self.followerCount >= 10000 then return false, "This test session's follower limit was reached." end
    self.followers[viewer] = true
    self.followerCount = self.followerCount + 1
    self.message = "A new star joined the constellation. Thank you for following!"
    return true, self.message
end

function Realm:bless(kind, now)
    local names = { bloom = "Starbloom", aurora = "Aurora veil", giant = "Titan constellation" }
    if not names[kind] then return false, "Unknown blessing." end
    self.blessing = names[kind]
    self.blessingUntil = now + 18
    return true, self.blessing .. " shimmers above the island."
end

function Realm:advance(now)
    if now < self.deadline and not self:raceComplete() then return false end
    self:tick(now)
    if self.phase == "gathering" then
        self.phase = "voting"
        self.round = self.round + 1
        self.activity = self.config.SprintOnly == true and activities[2] or activities[((self.round - 1) % #activities) + 1]
        self.activityEntrants, self.teamScore, self.teamTarget = 0, 0, 0
        self.votes = {}
        self.totals = { ward = 0, sail = 0 }
        for _, key in ipairs(self.crewOrder) do
            self.crew[key].roundMoney = 0
            self.crew[key].participated = false
            self.crew[key].activityEntered = false
            self.crew[key].score, self.crew[key].distance, self.crew[key].finishedAt = 0, 0, 0
            self.crew[key].raceStatus, self.crew[key].placement, self.crew[key].recoveries = "waiting", 0, 0
        end
        self.requiredVotes = math.max(1, math.ceil(#self.crewOrder / 3))
        self.deadline = now + self.config.VotingSeconds
        self.message = self.config.AutoActivities and (self.activity.name .. " begins soon. Vote Ward or Sail for the scenery!")
            or "A storm rift is opening. Raise a ward, or sail through it?"
    elseif self.phase == "voting" then
        self.phase = "storm"
        self.activityStarted = now
        if self.config.AutoActivities then
            local count = #self.crewOrder
            local limit = self.activity.id == "sprint" and math.min(count, self.config.SprintCompetitors or 5) or count
            local cohort = self:nextCohort()
            for i = 1, limit do
                local member = self.activity.id == "sprint" and cohort[i] or self.crew[self.crewOrder[i]]
                if member then self:enterActivity(member, now, i) end
            end
        end
        self.choice = self.totals.sail > self.totals.ward and "sail" or "ward"
        self.success = self.totals.ward + self.totals.sail >= self.requiredVotes
        self.deadline = now + (self.activity.id == "sprint" and (self.config.SprintRaceSeconds or 120) or self.config.StormSeconds)
        self.message = self.config.AutoActivities and self.activity.instruction
            or (self.choice == "ward" and "The crew raises a starlight ward!" or "The island rides the storm winds!")
    elseif self.phase == "storm" then
        self.phase = "result"
        self.winners = {}
        if self.config.AutoActivities then
            local ranking = self:activityLeaderboard()
            for i, row in ipairs(ranking) do
                if self.activity.id ~= "sprint" or row.finishedAt > 0 then
                    local place = self.activity.id == "sprint" and row.placement or i
                    local prize = (self.config.RoundPrizes or { 120, 75, 40 })[place] or 0
                    local member = self.crew[string.lower(row.username)]
                    member.placement = place
                    self:credit(member, prize)
                    if place == 1 then member.roundWins = member.roundWins + 1 end
                    if #self.winners < 3 then
                        table.insert(self.winners, { username = row.username, score = row.score, prize = prize, slot = row.slot,
                            elapsed = row.elapsed, finishedAt = row.finishedAt, placement = place })
                    end
                end
            end
            if self.activity.id == "sprint" then
                for _, key in ipairs(self.crewOrder) do
                    if self.crew[key].raceStatus == "racing" then self.crew[key].raceStatus = "dnf" end
                end
            end
            self.success = self.success or (self.activityEntrants > 0 and self.teamScore >= self.teamTarget)
        end
        self.lastRound = self:leaderboard(true)
        self.storms = self.storms + 1
        if self.success then self.wins = self.wins + 1 end
        self.deadline = now + self.config.ResultSeconds
        self.message = self.success and "Together, you saved a star shard. Your realm grows!"
            or "The rift faded. Gather more voices for the next crossing."
        if self.winners[1] then self.message = self.winners[1].username .. " wins " .. self.activity.name .. "! +$" .. self.winners[1].prize end
    else
        self.phase = "gathering"
        self.deadline = now + self.config.GatheringSeconds
        self.message = "A new horizon awaits. Invite another traveler through the gate."
    end
    return true
end

function Realm:snapshot(now)
    local crew = {}
    local members = {}
    for _, key in ipairs(self.crewOrder) do
        local member = self.crew[key]
        table.insert(crew, member.username)
        table.insert(members, {
            username = member.username, balance = member.balance, roundMoney = member.roundMoney,
            perSecond = self:rate(member), gifts = member.gifts,
            effect = now < member.effectUntil and member.effect or "",
            slot = member.slot, score = member.score, distance = member.distance, pace = member.pace,
            roundWins = member.roundWins, activityEntered = member.activityEntered,
            finished = member.finishedAt > 0, finishedAt = member.finishedAt,
            elapsed = member.finishedAt > 0 and member.finishedAt - member.enteredAt or 0,
            raceStatus = member.raceStatus, placement = member.placement,
            entranceDone = member.entranceDone, recoveries = member.recoveries,
            section = math.min(4, math.floor(member.distance / 12) + 1),
        })
    end
    local lastRound = {}
    for _, row in ipairs(self.lastRound) do
        table.insert(lastRound, { username = row.username, money = row.money, perSecond = row.perSecond, gifts = row.gifts, slot = row.slot })
    end
    local winners = {}
    for _, row in ipairs(self.winners) do table.insert(winners, { username = row.username, score = row.score, prize = row.prize, slot = row.slot, elapsed = row.elapsed, finishedAt = row.finishedAt, placement = row.placement }) end
    local nextCohort = {}
    for _, member in ipairs(self:nextCohort()) do nextCohort[#nextCohort + 1] = member.username end
    local entrance
    if self.entrance then
        local names = {}; for _, name in ipairs(self.entrance.names) do names[#names + 1] = name end
        entrance = { sequence = self.entrance.sequence, names = names, startedAt = self.entrance.startedAt, endsAt = self.entrance.endsAt }
    end
    return {
        entrance = entrance, entranceWaiting = #self.entranceQueue, nextCohort = nextCohort,
        phase = self.phase, seconds = math.max(0, math.ceil(self.deadline - now)),
        round = self.round, crew = crew, wins = self.wins, storms = self.storms,
        ward = self.totals.ward, sail = self.totals.sail, requiredVotes = self.requiredVotes,
        choice = self.choice, success = self.success, message = self.message,
        blessing = now < self.blessingUntil and self.blessing or "",
        members = members, leaderboard = self:leaderboard(false), roundLeaders = self:leaderboard(true),
        lastRound = lastRound, followers = self.followerCount,
        earning = self.phase == "voting" or self.phase == "storm",
        now = now, deadline = self.deadline, activityStarted = self.activityStarted,
        autoActivities = self.config.AutoActivities == true,
        activity = { id = self.activity.id, name = self.activity.name, instruction = self.activity.instruction, goal = self.activity.goal },
        activityLeaders = self:activityLeaderboard(), winners = winners,
        physicalSprint = self.config.AutoActivities == true and self.activity.id == "sprint",
        teamScore = self.teamScore, teamTarget = self.teamTarget,
        lastGift = { username = self.lastGift.username, kind = self.lastGift.kind, count = self.lastGift.count, sequence = self.lastGift.sequence },
    }
end

return Realm
```

### World.lua

Create a **ModuleScript** named **World** under **ServerScriptService**.

```luau
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local World = {}
local root, core, gate, rift, shield, constellation, bloom, winds, scoreText
local monuments = {}
local avatars = {}
local scenery = { clouds = {}, runes = {}, ribbons = {}, particles = {}, stars = {}, shrines = {}, sprintObstacles = {}, movingBridges = {} }
local settings = {}
local sceneState
local lastFrame = 0
local sessionText
local arrival
local colors = {
    rock = Color3.fromRGB(47, 46, 78), grass = Color3.fromRGB(68, 112, 111),
    mint = Color3.fromRGB(106, 255, 213), gold = Color3.fromRGB(255, 208, 128),
    violet = Color3.fromRGB(173, 130, 255), stone = Color3.fromRGB(108, 99, 139),
}

local function part(name, size, cf, color, material, parent)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, cf
    p.Anchored, p.CanCollide = true, true
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Color, p.Material = color, material or Enum.Material.Slate
    p.Parent = parent or root
    return p
end

local function ball(name, position, size, color, transparency, parent)
    local p = part(name, Vector3.new(size, size, size), CFrame.new(position), color, Enum.Material.Neon, parent)
    p.Shape, p.CanCollide, p.Transparency = Enum.PartType.Ball, false, transparency or 0
    return p
end

local function label(adornee, text, offset, color, width)
    local gui = Instance.new("BillboardGui")
    gui.Name, gui.Size = "Caption", UDim2.fromOffset(width or 180, 24)
    gui:SetAttribute("RiftboundLabelKind", "scenery")
    gui.StudsOffset, gui.MaxDistance = offset or Vector3.new(0, 5, 0), 70
    gui.AlwaysOnTop, gui.Enabled = false, false
    gui.Parent = adornee
    local t = Instance.new("TextLabel")
    t.Size, t.BackgroundTransparency = UDim2.fromScale(1, 1), 1
    t.Font, t.TextSize = Enum.Font.GothamBold, 14
    t.Text, t.TextColor3 = text, color or colors.mint
    t.TextStrokeTransparency, t.TextWrapped, t.TextTruncate = 0.65, false, Enum.TextTruncate.AtEnd
    t.Parent = gui
end

local function island(position, radius)
    local top = part("Moss crown", Vector3.new(5, radius * 2, radius * 2),
        CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), colors.grass, Enum.Material.Grass)
    top.Shape = Enum.PartType.Cylinder
    local rng = Random.new(math.floor(radius * 112 + position.X))
    for i = 1, 9 do
        local angle = i * math.pi * 2 / 9
        local rockSize = radius * rng:NextNumber(0.35, 0.55)
        local p = part("Floating bedrock", Vector3.new(rockSize, rockSize * 1.6, rockSize),
            CFrame.new(position + Vector3.new(math.cos(angle) * radius * 0.62, -rockSize * 0.6, math.sin(angle) * radius * 0.62))
                * CFrame.Angles(0.2, angle, 0.3), colors.rock)
        p.Shape = Enum.PartType.Block
    end
    return top
end

local function crystal(position, scale, color)
    local p = part("Star crystal", Vector3.new(2, 5, 2) * scale,
        CFrame.new(position) * CFrame.Angles(0, math.pi / 4, 0.14), color, Enum.Material.Neon)
    p.CanCollide = false
    local light = Instance.new("PointLight")
    light.Color, light.Brightness, light.Range = color, 0.7, 12 * scale
    light.Parent = p
    return p
end

local function tree(position, scale)
    part("Silverwood trunk", Vector3.new(1.5, 10, 1.5) * scale,
        CFrame.new(position + Vector3.new(0, 5 * scale, 0)) * CFrame.Angles(0, 0, 0.09), colors.stone, Enum.Material.Wood)
    for i = 1, 3 do
        local canopy = ball("Moonleaf canopy", position + Vector3.new((i - 2) * 3 * scale, (10 + i) * scale, 0),
            (8 - i) * scale, colors.violet, 0.1)
        canopy.Material = Enum.Material.SmoothPlastic
    end
end

-- 48 measured gates over 1,152 studs. Race motion belongs to Humanoid physics.
local sectionNames = { "STARTING DASH", "MOVING BRIDGES", "HAZARD ZONE", "FINAL SPRINT" }
function World.cameraBounds(state)
    if state.physicalSprint then
        return { minX = -38, maxX = 38, minY = 54, maxY = 110, minZ = -1120, maxZ = 82, yaw = 60 }
    end
end
function World.courseInfo()
    return { revision = "show-v7", checkpoints = 48, length = 1152, stride = 24,
        sections = sectionNames, finishZ = -1092, gate = { x = -64, y = 80, z = 66 } }
end
function World.sprintPoint(lane, checkpoint)
    local cp = math.max(0, math.min(48, checkpoint))
    local rise = math.floor(cp / 12) * 3 + (cp < 48 and (cp % 4 >= 2 and 1 or 0) or 0)
    return Vector3.new((lane - 3) * 8 + math.sin(cp * math.pi / 6) * 2, 68 + rise, 60 - cp * 24)
end
function World.entrancePoint(index, count)
    return Vector3.new(-64 + (index - (count + 1) / 2) * 7, 80, 66)
end
function World.validUsername(username)
    if type(username) ~= "string" or #username < 3 or #username > 20 or not string.match(username, "^[A-Za-z0-9_]+$")
        or string.sub(username, 1, 1) == "_" or string.sub(username, -1) == "_" then return false end
    local _, underscores = string.gsub(username, "_", "")
    return underscores <= 1
end
local accountCache, accountOrder, lookupsInFlight = {}, {}, 0
function World.resolveUsername(username)
    if not World.validUsername(username) then return nil, "Use a Roblox username: 3-20 letters/digits, at most one internal underscore." end
    if settings.ResolveViewerUsernames ~= true then return nil, "Account verification is disabled. Use OFFLINE JOIN for a local test." end
    local key = string.lower(username)
    if accountCache[key] then return accountCache[key] end
    if lookupsInFlight >= 2 then return nil, "Roblox verification is busy. Use OFFLINE JOIN or try again later." end
    lookupsInFlight = lookupsInFlight + 1
    local complete, userId = false, nil
    local deadline = os.clock() + (settings.AppearanceTimeoutSeconds or 8)
    task.spawn(function()
        local ok, result = pcall(function() return Players:GetUserIdFromNameAsync(username) end)
        if os.clock() <= deadline and ok and type(result) == "number" and result > 0 and result == math.floor(result) then userId = result end
        complete = true
        lookupsInFlight = lookupsInFlight - 1
    end)
    while not complete and os.clock() < deadline do task.wait(0.05) end
    if not userId then return nil, "Roblox could not verify that account in time. Check spelling, or use OFFLINE JOIN." end
    accountCache[key] = userId; accountOrder[#accountOrder + 1] = key
    if #accountOrder > 128 then accountCache[table.remove(accountOrder, 1)] = nil end
    return userId
end

local function prepareRig(model)
    for i, object in ipairs(model:GetChildren()) do
        if object:IsA("Accessory") or object:IsA("Hat") then object.Name = "OutfitAccessory_" .. i end
    end
    local main = model:FindFirstChild("HumanoidRootPart")
    local torso, head = model:FindFirstChild("Torso"), model:FindFirstChild("Head")
    assert(main and main:IsA("BasePart") and torso and torso:IsA("BasePart") and head and head:IsA("BasePart"), "A Sprint avatar needs an R6 root, torso and head")
    for _, name in ipairs({ "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
        assert(model:FindFirstChild(name), "Missing R6 limb: " .. name)
    end
    model.PrimaryPart = main
    main.Size = Vector3.new(2, 2, 1)
    local humanoid = model:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid")
    humanoid.Name, humanoid.Parent = "Humanoid", model
    humanoid.WalkSpeed, humanoid.UseJumpPower, humanoid.JumpPower = settings.SprintWalkSpeed or 12, true, 50
    humanoid.HipHeight, humanoid.MaxSlopeAngle = 0, 40
    humanoid.BreakJointsOnDeath, humanoid.RequiresNeck = false, false
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    if not main:FindFirstChild("RootJoint") then
        local joints = {
            { "RootJoint", main, torso, CFrame.new(), CFrame.new() },
            { "Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0) },
            { "Left Shoulder", torso, model["Left Arm"], CFrame.new(-1.5, 0.5, 0), CFrame.new(0, 0.5, 0) },
            { "Right Shoulder", torso, model["Right Arm"], CFrame.new(1.5, 0.5, 0), CFrame.new(0, 0.5, 0) },
            { "Left Hip", torso, model["Left Leg"], CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0) },
            { "Right Hip", torso, model["Right Leg"], CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0) },
        }
        for _, spec in ipairs(joints) do
            local joint = Instance.new("Motor6D")
            joint.Name, joint.Part0, joint.Part1, joint.C0, joint.C1 = spec[1], spec[2], spec[3], spec[4], spec[5]
            joint.Parent = spec[2]
        end
    end
    if not model:FindFirstChild("RaceCollider") then
        local collider = part("RaceCollider", Vector3.new(2, 5, 2), main.CFrame * CFrame.new(0, -0.5, 0), colors.mint, Enum.Material.SmoothPlastic, model)
        collider.Transparency = 1
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1, weld.Parent = main, collider, collider
    end
    if not model:FindFirstChild("GiftAura") then
        local glow = Instance.new("Highlight")
        glow.Name, glow.FillTransparency, glow.OutlineColor, glow.Enabled, glow.Parent = "GiftAura", 0.8, colors.mint, false, model
        local crown = part("Winner crown", Vector3.new(2.4, 0.3, 1.3), main.CFrame * CFrame.new(0, 2.5, 0), colors.gold, Enum.Material.Neon, model)
        crown.Transparency = 1
        for i = 1, 3 do
            local spike = part("Crown spike " .. i, Vector3.new(0.3, 0.7, 0.3), main.CFrame * CFrame.new((i - 2) * 0.8, 2.9, 0), colors.gold, Enum.Material.Neon, model)
            spike.Transparency = 1
        end
        ball("Relay energy", main.Position + Vector3.new(0, 0, -1.5), 0.9, colors.mint, 1, model)
    end
    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript") or object:IsA("Tool") then object:Destroy()
        elseif object:IsA("BasePart") then
            object.Anchored, object.CanCollide, object.Massless = true, false, object ~= main
            if object.Name == "Winner crown" or string.match(object.Name, "^Crown spike") or object.Name == "Relay energy" then
                local weld = Instance.new("WeldConstraint")
                weld.Part0, weld.Part1, weld.Parent = main, object, object
            end
        end
    end
    return model
end

local function physical(record, enabled)
    record.physical = enabled
    local model = record.model
    local main, humanoid = model.PrimaryPart, model:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then humanoid:MoveTo(main.Position) end
    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("BasePart") then
            object.Anchored, object.CanCollide = not enabled, enabled and object.Name == "RaceCollider"
        elseif object:IsA("Motor6D") or object:IsA("Weld") or object:IsA("WeldConstraint") then
            object.Enabled = enabled
        end
    end
    if enabled then
        -- Server owns every racer. Player inputs/clients cannot move an NPC.
        main:SetNetworkOwner(nil)
        main.AssemblyLinearVelocity, main.AssemblyAngularVelocity = Vector3.new(), Vector3.new()
    end
end

function World.loadAppearance(username, userId)
    local record = avatars[string.lower(username)]
    if not record or record.appearanceAttempted or settings.LoadAvatarAppearances ~= true
        or type(userId) ~= "number" or userId < 1 or userId ~= math.floor(userId) then return end
    record.appearanceAttempted = true
    local deadline = os.clock() + (settings.AppearanceTimeoutSeconds or 8)
    task.spawn(function()
        if os.clock() > deadline or not root.Parent then return end
        local description, model
        local ok, issue = pcall(function()
            -- Explicitly optional Roblox appearance APIs; no custom HTTP/TikTok.
            description = Players:GetHumanoidDescriptionFromUserIdAsync(userId)
            description.HeightScale, description.WidthScale, description.DepthScale, description.HeadScale = 1, 1, 1, 1
            description.BodyTypeScale, description.ProportionScale = 0, 0
            if os.clock() > deadline then return end
            model = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
            if os.clock() <= deadline and root.Parent and avatars[string.lower(username)] == record then
                prepareRig(model)
                record.pendingAppearance = model -- install only when this avatar is outside the race
                model = nil
            end
        end)
        if description then description:Destroy() end
        if model then model:Destroy() end
        if not ok then warn("[Riftbound appearance] " .. username .. ": fallback kept (" .. tostring(issue) .. ")") end
    end)
end

local function buildSprint()
    local course = Instance.new("Model")
    course.Name, course.Parent = "SkybridgeSprint", root
    course:SetAttribute("CourseRevision", "show-v7")
    local start = part("START platform", Vector3.new(46, 2, 26), CFrame.new(0, 64, 65), colors.stone, Enum.Material.Slate, course)
    label(start, "SKYBRIDGE / 120 SECOND CROSSING", Vector3.new(0, 9, 0), colors.gold, 350)
    for cp = 1, 48 do
        local section = math.min(4, math.floor((cp - 1) / 12) + 1)
        local gap = (section == 2 or cp % 4 == 2) and 4 or 0
        for lane = 1, 5 do
            local point = World.sprintPoint(lane, cp)
            local pad = part("Lane " .. lane .. " checkpoint " .. cp, Vector3.new(7.4, 1, 24 - gap),
                CFrame.new(point - Vector3.new(0, 3.5, 0)), section % 2 == 0 and colors.violet or colors.mint, Enum.Material.Slate, course)
            pad:SetAttribute("Checkpoint", cp); pad:SetAttribute("Section", section)
            if section == 2 and cp % 2 == 0 then
                scenery.movingBridges[#scenery.movingBridges + 1] = { part = pad, frame = pad.CFrame, phase = cp * 0.7 }
            end
            local edge = part("Checkpoint glow", Vector3.new(7.4, 0.12, 0.35), pad.CFrame * CFrame.new(0, 0.55, 0), colors.gold, Enum.Material.Neon, course)
            edge.CanCollide = false
            if section == 2 and cp % 2 == 0 then
                scenery.movingBridges[#scenery.movingBridges + 1] = { part = edge, frame = edge.CFrame, phase = cp * 0.7 }
            end
        end
        local point = World.sprintPoint(3, cp)
        for _, sign in ipairs({ -1, 1 }) do
            part("Bridge support", Vector3.new(0.7, 5, 0.7), CFrame.new(sign * 24, point.Y - 6, point.Z), colors.stone, Enum.Material.Metal, course)
        end
        if cp % 12 == 1 then
            local index = math.floor((cp - 1) / 12) + 1
            local beacon = part("Section " .. index .. " beacon", Vector3.new(2, 12, 2), CFrame.new(-29, point.Y + 2, point.Z), colors.gold, Enum.Material.Neon, course)
            label(beacon, index .. " / " .. sectionNames[index], Vector3.new(0, 9, 0), colors.gold, 330)
            -- Break up the long skyline with floating section islands and crystal fans.
            island(Vector3.new(52, point.Y - 14, point.Z), 24)
            for i = -2, 2 do crystal(Vector3.new(52 + i * 5, point.Y - 10, point.Z), 0.9 + math.abs(i) * 0.2, colors.violet) end
        end
    end
    for i, cp in ipairs({ 26, 30, 34 }) do
        local from, to = World.sprintPoint(3, cp - 1), World.sprintPoint(3, cp)
        local point = (from + to) * 0.5
        local obstacle = part("Moving wind gate " .. i, Vector3.new(4, 11, 2), CFrame.new(0, point.Y + 2, point.Z), colors.gold, Enum.Material.Neon, course)
        scenery.sprintObstacles[#scenery.sprintObstacles + 1] = { part = obstacle, point = point, phase = i * 2.1, checkpoint = cp }
    end
    for _, cp in ipairs({ 8, 28, 36, 42 }) do
        local point = (World.sprintPoint(3, cp - 1) + World.sprintPoint(3, cp)) * 0.5
        part("Jump hurdle " .. cp, Vector3.new(42, 1.6, 1), CFrame.new(0, point.Y - 2.2, point.Z), colors.violet, Enum.Material.Neon, course)
    end
    local finish = World.sprintPoint(3, 48)
    part("FINISH island", Vector3.new(48, 3, 38), CFrame.new(0, finish.Y - 5, finish.Z - 8), colors.grass, Enum.Material.Grass, course)
    for _, x in ipairs({ -23, 23 }) do
        part("Finish arch column", Vector3.new(2, 21, 2), CFrame.new(x, finish.Y + 6, finish.Z), colors.gold, Enum.Material.Neon, course)
    end
    local arch = part("Finish arch", Vector3.new(48, 2, 3), CFrame.new(0, finish.Y + 17, finish.Z), colors.mint, Enum.Material.Neon, course)
    label(arch, "THE RIFTBOUND CROWN / FINISH", Vector3.new(0, 6, 0), colors.gold, 350)
    for rank, x in ipairs({ 0, -10, 10 }) do
        local h = ({ 4, 2.5, 1.5 })[rank]
        part("Sprint podium " .. rank, Vector3.new(8, h, 8), CFrame.new(x, finish.Y - 3.5 + h / 2, finish.Z - 12), rank == 1 and colors.gold or colors.stone, Enum.Material.Marble, course)
    end
end

function World.stepCourse(now)
    for _, obstacle in ipairs(scenery.sprintObstacles) do
        obstacle.part.CFrame = CFrame.new(math.sin(now * 1.2 + obstacle.phase) * 25, obstacle.point.Y + 2, obstacle.point.Z)
    end
    for _, bridge in ipairs(scenery.movingBridges) do
        bridge.part.CFrame = bridge.frame * CFrame.new(math.sin(now * 0.65 + bridge.phase) * 1.25, math.sin(now * 0.65 + bridge.phase) * 0.2, 0)
        bridge.part.AssemblyLinearVelocity = Vector3.new(math.cos(now * 0.65 + bridge.phase) * 0.8125, math.cos(now * 0.65 + bridge.phase) * 0.13, 0)
    end
end

local function resetRacer(record, member, lane, now)
    local point = World.sprintPoint(lane, member.score)
    local target = World.sprintPoint(lane, math.min(48, member.score + 1))
    record.model:PivotTo(CFrame.lookAt(point + Vector3.new(0, 1, 0), target))
    local main = record.model.PrimaryPart
    main.AssemblyLinearVelocity, main.AssemblyAngularVelocity = Vector3.new(), Vector3.new()
    record.race.position, record.race.sampleAt, record.race.lastMoved = main.Position, now, now
    record.race.lastJump, record.race.lastCommand = now - 1, 0
    record.model.Humanoid.Jump = false
end

function World.sprintStep(state, now)
    World.stepCourse(now)
    if state.phase ~= "storm" or state.activity.id ~= "sprint" then return end
    local lane = 0
    for _, key in ipairs(state.crewOrder) do
        local member, record = state.crew[key], avatars[key]
        if member.activityEntered then
            lane = lane + 1
            if not record or not record.model.PrimaryPart or not record.model:FindFirstChild("Head") or not record.model:FindFirstChildOfClass("Humanoid") then
                state:raceDNF(member.username, state.round)
            else
                local model, humanoid = record.model, record.model:FindFirstChildOfClass("Humanoid")
                if not record.race or record.race.round ~= state.round then
                    if record.scale ~= 1 then model:ScaleTo(1); record.scale = 1 end
                    local rotatedLane = (((member.raceLane or lane) + state.round - 2) % 5) + 1
                    record.race = { round = state.round, lane = rotatedLane }
                    physical(record, true)
                    resetRacer(record, member, rotatedLane, now)
                end
                local race, main = record.race, model.PrimaryPart
                if member.raceStatus == "racing" then
                    if humanoid.Health <= 0 then state:raceDNF(member.username, state.round)
                    else
                        local position = main.Position
                        local dt = math.max(0.001, now - race.sampleAt)
                        if position.Y < 54 or math.abs(position.X) > 38 or position.Z < -1120 or position.Z > 82
                            or (position - race.position).Magnitude > math.max(8, dt * 90) or now - race.lastMoved > 6 then
                            member.recoveries = (member.recoveries or 0) + 1
                            resetRacer(record, member, race.lane, now)
                            position = main.Position
                        end
                        local nextGate = member.score + 1
                        local target = World.sprintPoint(race.lane, nextGate)
                        local delta = target - position
                        local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
                        local passed, at = false, now
                        if nextGate == 48 then
                            if race.position.Z > target.Z and position.Z <= target.Z and math.abs(delta.X) <= 2.8 and math.abs(delta.Y) <= 4 then
                                local fraction = (race.position.Z - target.Z) / math.max(0.0001, race.position.Z - position.Z)
                                at = race.sampleAt + (now - race.sampleAt) * math.max(0, math.min(1, fraction))
                                passed = true
                            end
                        else passed = horizontal <= 2.8 and math.abs(delta.Y) <= 3.5 and humanoid.FloorMaterial ~= Enum.Material.Air end
                        if passed then state:recordCheckpoint(member.username, nextGate, at, state.round) end
                        if (position - race.position).Magnitude > 0.08 then race.lastMoved = now end
                        if member.raceStatus == "racing" then
                            local from = World.sprintPoint(race.lane, member.score)
                            local to = World.sprintPoint(race.lane, member.score + 1)
                            local segment = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
                            local offset = Vector3.new(position.X - from.X, 0, position.Z - from.Z)
                            state:raceDistance(member.username, member.score + offset:Dot(segment) / segment:Dot(segment), state.round)
                            local blocked = false
                            for _, obstacle in ipairs(scenery.sprintObstacles) do
                                if obstacle.checkpoint == member.score + 1 and position.Z > obstacle.point.Z + 2
                                    and position.Z - obstacle.point.Z < 9 and math.abs(position.X - obstacle.part.Position.X) < 4 then blocked = true end
                            end
                            if blocked then
                                humanoid:MoveTo(position); race.lastMoved, race.lastCommand = now, 0
                            elseif now - race.lastCommand > 0.4 then
                                local goal = World.sprintPoint(race.lane, member.score + 1)
                                if member.score == 47 then goal = goal + Vector3.new(0, 0, -4) end
                                humanoid:MoveTo(goal)
                                race.lastCommand = now
                            end
                            local jumpGoal = World.sprintPoint(race.lane, member.score + 1)
                            local jumpDelta = jumpGoal - position
                            local jumpDistance = Vector3.new(jumpDelta.X, 0, jumpDelta.Z).Magnitude
                            if jumpDistance <= 14.5 and jumpDistance >= 10.5 and now - race.lastJump > 0.4 and humanoid.FloorMaterial ~= Enum.Material.Air then
                                humanoid.Jump, race.lastJump = true, now
                            end
                        end
                        race.position, race.sampleAt = position, now
                    end
                end
                if member.raceStatus ~= "racing" and record.physical then
                    record.frame = main.CFrame
                    physical(record, false)
                end
            end
        end
    end
end

function World.build(config)
    settings = config or {}
    root = Instance.new("Model")
    root.Name = "RiftboundRealm"
    root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    root.Parent = workspace
    Lighting.FogStart, Lighting.FogEnd = 1000, 5000
    Lighting.ClockTime, Lighting.Brightness = 14, 2.5
    Lighting.GlobalShadows = true
    Lighting.Ambient = Color3.fromRGB(111, 109, 148)
    Lighting.OutdoorAmbient = Color3.fromRGB(116, 133, 158)
    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Density, atmosphere.Offset = 0.15, 0
    atmosphere.Color, atmosphere.Decay = Color3.fromRGB(170, 213, 233), Color3.fromRGB(89, 74, 130)
    atmosphere.Parent = Lighting
    local glow = Instance.new("BloomEffect")
    glow.Intensity, glow.Size, glow.Threshold, glow.Parent = 0.45, 32, 1.3, Lighting
    buildSprint()
    island(Vector3.new(0, 32, 0), 50)
    island(Vector3.new(87, 36, 21), 23)
    island(Vector3.new(-85, 28, -20), 21)
    island(Vector3.new(6, 61, -133), 31)
    for _, sign in ipairs({ -1, 1 }) do
        for i = 1, 15 do
            local x = sign * (39 + i * 2.4)
            local y = 35 + sign * i * 0.14
            part("Skybridge plank", Vector3.new(2.1, 0.55, 7), CFrame.new(x, y, sign * i * 0.37), colors.stone, Enum.Material.Wood)
        end
    end
    for i = 1, 18 do
        local angle = i * math.pi * 2 / 18
        local pos = Vector3.new(math.sin(angle) * 32, 35, math.cos(angle) * 32)
        local pad = part("Traveler berth " .. i, Vector3.new(0.3, 5, 5),
            CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), colors.mint, Enum.Material.Neon)
        pad.Shape = Enum.PartType.Cylinder
        pad.Transparency = 0.35
    end
    for _, p in ipairs({ Vector3.new(-22, 35, -22), Vector3.new(23, 35, -21), Vector3.new(-30, 35, 10), Vector3.new(91, 39, 22) }) do
        tree(p, 0.85)
        crystal(p + Vector3.new(4, 1, 3), 0.7, colors.mint)
    end
    for i = 1, 14 do
        local a = i * math.pi * 2 / 14
        crystal(Vector3.new(math.sin(a) * 44, 35, math.cos(a) * 44), 0.5, i % 2 == 0 and colors.gold or colors.violet)
    end
    core = crystal(Vector3.new(0, 42, 0), 2, colors.mint)
    label(core, "THE HEARTSEED", Vector3.new(0, 8, 0), colors.gold)
    local scoreAnchor = part("Round leaderboard", Vector3.new(1, 1, 1), CFrame.new(-85, 44, -20), colors.gold)
    scoreAnchor.Transparency, scoreAnchor.CanCollide = 1, false
    local scoreGui = Instance.new("BillboardGui")
    scoreGui.Name = "RoundBoard"
    scoreGui:SetAttribute("RiftboundLabelKind", "worldBoard")
    scoreGui.AlwaysOnTop, scoreGui.Enabled = false, false
    scoreGui.Size, scoreGui.MaxDistance, scoreGui.Parent = UDim2.fromOffset(300, 124), 95, scoreAnchor
    scoreText = Instance.new("TextLabel")
    scoreText.Size, scoreText.BackgroundTransparency = UDim2.fromScale(1, 1), 1
    scoreText.Font, scoreText.TextSize, scoreText.TextColor3 = Enum.Font.GothamBold, 18, colors.gold
    scoreText.TextWrapped, scoreText.TextTruncate = false, Enum.TextTruncate.AtEnd
    scoreText.TextStrokeTransparency, scoreText.Text, scoreText.Parent = 0.3, "TOP EARNERS\nWaiting for the next round", scoreGui
    gate = part("Star gate", Vector3.new(1, 16, 16), CFrame.new(-64, 86, 54) * CFrame.Angles(0, math.pi / 2, 0), colors.violet, Enum.Material.Neon)
    gate.Shape, gate.CanCollide, gate.Transparency = Enum.PartType.Cylinder, false, 0.62
    for i = 1, 12 do
        local a = i * math.pi * 2 / 12
        crystal(Vector3.new(-64 + math.sin(a) * 9, 86 + math.cos(a) * 9, 54), 0.45, colors.gold)
    end
    label(gate, "THE STAR GATE  /  ARRIVALS", Vector3.new(0, 13, 0), colors.gold, 340)
    part("Star Gate stage", Vector3.new(34, 2, 28), CFrame.new(-64, 76, 66), colors.stone, Enum.Material.Marble)
    for i = 1, 5 do
        local pad = part("Arrival spotlight " .. i, Vector3.new(4, 0.2, 4), CFrame.new(-64 + (i - 3) * 6, 77.2, 66), colors.mint, Enum.Material.Neon)
        pad.CanCollide = false
    end
    -- Host/player characters belong outside the racing lanes and above the old
    -- island ceiling. The previous spawn at (0,35,22) was underneath Skybridge.
    part("Spectator deck", Vector3.new(22, 2, 26), CFrame.new(48, 82, 58), colors.stone, Enum.Material.Slate)
    for _, x in ipairs({ 37, 59 }) do
        part("Spectator rail", Vector3.new(0.5, 2, 26), CFrame.new(x, 84, 58), colors.gold, Enum.Material.Neon)
    end
    for _, z in ipairs({ 45, 71 }) do
        part("Spectator rail", Vector3.new(22, 2, 0.5), CFrame.new(48, 84, z), colors.gold, Enum.Material.Neon)
    end
    arrival = Instance.new("SpawnLocation")
    arrival.Name, arrival.Size, arrival.CFrame = "Arrival", Vector3.new(7, 0.3, 7), CFrame.new(48, 83.2, 58)
    arrival.Anchored, arrival.Neutral, arrival.Duration = true, true, 0
    arrival.Color, arrival.Material, arrival.Parent = colors.gold, Enum.Material.Neon, root
    rift = ball("Storm rift", Vector3.new(0, 90, -50), 28, colors.violet, 0.88)
    shield = ball("Starlight ward", Vector3.new(0, 35, 0), 110, colors.mint, 1)
    constellation = Instance.new("Folder")
    constellation.Name, constellation.Parent = "Titan constellation", root
    for i = 1, 9 do
        ball("Titan star", Vector3.new(-70 + (i % 3) * 8, 61 + math.floor(i / 3) * 9, -45), 2.2, colors.gold, 1, constellation)
    end
    bloom = Instance.new("Folder")
    bloom.Name, bloom.Parent = "Starbloom", root
    for i = 1, 16 do
        local a = i * math.pi * 2 / 16
        ball("Bloom mote", Vector3.new(math.cos(a) * 40, 43 + (i % 4) * 2, math.sin(a) * 40), 1.4, colors.gold, 1, bloom)
    end
    winds = Instance.new("Folder")
    winds.Name, winds.Parent = "Rift wind trails", root
    for i = 1, 14 do
        local p = part("Wind ribbon", Vector3.new(0.3, 0.3, 18), CFrame.new((i - 7) * 8, 39 + (i % 4) * 4, 0), colors.mint, Enum.Material.Neon, winds)
        p.Transparency, p.CanCollide = 1, false
    end
    for i = 1, 45 do
        local a = i * 2.399
        ball("Distant star", Vector3.new(math.cos(a) * (120 + i), 80 + i * 2, math.sin(a) * (120 + i)), 0.7, colors.gold, 0.25)
    end
    -- Raised sprint checkpoints, a star collection ring, and three relay shrines.
    for i = 1, 12 do
        local a = i * math.pi * 2 / 12
        local p = part("Sprint checkpoint " .. i, Vector3.new(9, 0.5, 7),
            CFrame.new(math.sin(a) * 35, 37, math.cos(a) * 35) * CFrame.Angles(0, a, 0), colors.stone)
        if i % 3 == 0 then crystal(p.Position + Vector3.new(0, 3, 0), 0.35, colors.gold) end
    end
    for i = 1, 8 do
        local a = i * math.pi * 2 / 8
        local p = crystal(Vector3.new(math.sin(a) * 18, 39, math.cos(a) * 18), 0.65, colors.gold)
        table.insert(scenery.stars, { part = p, origin = p.CFrame })
    end
    for i = 1, 3 do
        local a = i * math.pi * 2 / 3
        local position = Vector3.new(math.sin(a) * 22, 38, math.cos(a) * 22)
        local shrine = crystal(position, 1.1, colors.mint)
        table.insert(scenery.shrines, shrine)
        label(shrine, "RELAY SHRINE " .. i, Vector3.new(0, 4, 0), colors.mint, 160)
    end
    for rank, x in ipairs({ 0, -9, 9 }) do
        local height = ({ 4, 2.5, 1.5 })[rank]
        part("Winner podium " .. rank, Vector3.new(7, height, 7), CFrame.new(x, 34.5 + height / 2, 14), rank == 1 and colors.gold or colors.stone)
    end
    local sessionAnchor = part("Session board", Vector3.new(1, 1, 1), CFrame.new(87, 48, 21), colors.mint)
    sessionAnchor.Transparency, sessionAnchor.CanCollide = 1, false
    local sessionGui = Instance.new("BillboardGui")
    sessionGui.Name = "SessionBoard"
    sessionGui:SetAttribute("RiftboundLabelKind", "worldBoard")
    sessionGui.AlwaysOnTop, sessionGui.Enabled = false, false
    sessionGui.Size, sessionGui.MaxDistance, sessionGui.Parent = UDim2.fromOffset(300, 124), 95, sessionAnchor
    sessionText = Instance.new("TextLabel")
    sessionText.Size, sessionText.BackgroundTransparency = UDim2.fromScale(1, 1), 1
    sessionText.Font, sessionText.TextSize, sessionText.TextColor3 = Enum.Font.GothamBold, 18, colors.mint
    sessionText.TextWrapped, sessionText.TextTruncate = false, Enum.TextTruncate.AtEnd
    sessionText.TextStrokeTransparency, sessionText.Parent = 0.25, sessionGui
    for i = 1, 8 do
        local model = Instance.new("Model")
        model.Name, model.Parent = "Drifting cloud", root
        for j = 1, 3 do
            local p = ball("Cloud lobe", Vector3.new((j - 2) * 9, 0, 0), 18 - j, Color3.fromRGB(197, 203, 224), 0.78, model)
            p.Material = Enum.Material.SmoothPlastic
        end
        table.insert(scenery.clouds, { model = model, angle = i * math.pi / 4, height = 9 + (i % 3) * 12 })
    end
    for i = 1, 12 do
        local rune = part("Orbiting rune", Vector3.new(0.5, 1.5, 0.5), CFrame.new(0, 50, 0), colors.gold, Enum.Material.Neon)
        rune.CanCollide = false
        table.insert(scenery.runes, rune)
    end
    for i = 1, 10 do
        local ribbon = part("Aurora ribbon", Vector3.new(17, 0.25, 2), CFrame.new(0, 85, -30), colors.mint, Enum.Material.Neon)
        ribbon.CanCollide, ribbon.Transparency = false, 1
        table.insert(scenery.ribbons, ribbon)
    end
    -- Reusable procedural particle pool: no downloaded textures and no per-frame allocations.
    for i = 1, 36 do
        table.insert(scenery.particles, ball("Celebration mote", Vector3.new(0, -50, 0), 0.55, colors.gold, 1))
    end
end

function World.preparePlayer(player)
    player.RespawnLocation = arrival
    local function place(character)
        local main = character:WaitForChild("HumanoidRootPart", 10)
        if not main or not character.Parent then return end
        -- Also rescue the first character, which can spawn before World.build.
        -- This moves only the actual player character, never a racing NPC.
        character:PivotTo(CFrame.lookAt(Vector3.new(48, 87, 58), Vector3.new(0, 72, 0)))
        main.AssemblyLinearVelocity, main.AssemblyAngularVelocity = Vector3.new(), Vector3.new()
    end
    player.CharacterAdded:Connect(function(character) task.spawn(function() place(character) end) end)
    if player.Character then task.spawn(function() place(player.Character) end) end
end

function World.crewPosition(slot)
    local angle = slot * math.pi * 2 / 18
    return CFrame.lookAt(Vector3.new(math.sin(angle) * 32, 39, math.cos(angle) * 32), Vector3.new(0, 39, 0))
end

function World.offlineAvatar(username)
    -- Build a local R6-style stand-in. No account lookup, meshes, or textures.
    local model = Instance.new("Model")
    local hash = 0
    for i = 1, #username do hash = (hash + string.byte(username, i)) % 360 end
    local robe = Color3.fromHSV(hash / 360, 0.4, 0.8)
    local specs = {
        { "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), robe },
        { "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), robe },
        { "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), colors.gold },
        { "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), robe },
        { "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), robe },
        { "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), colors.rock },
        { "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), colors.rock },
    }
    for _, spec in ipairs(specs) do
        local p = part(spec[1], spec[2], CFrame.new(spec[3]), spec[4], Enum.Material.SmoothPlastic, model)
        p.CanCollide = false
        if spec[1] == "HumanoidRootPart" then p.Transparency = 1; model.PrimaryPart = p end
    end
    local glow = Instance.new("Highlight")
    glow.Name, glow.FillTransparency, glow.OutlineColor, glow.Parent = "GiftAura", 0.8, colors.mint, model
    glow.Enabled = false
    local crown = part("Winner crown", Vector3.new(2.4, 0.3, 1.3), CFrame.new(0, 2.5, 0), colors.gold, Enum.Material.Neon, model)
    crown.Transparency, crown.CanCollide = 1, false
    for i = 1, 3 do
        local spike = part("Crown spike " .. i, Vector3.new(0.3, 0.7, 0.3), CFrame.new((i - 2) * 0.8, 2.9, 0), colors.gold, Enum.Material.Neon, model)
        spike.Transparency, spike.CanCollide = 1, false
    end
    local orb = ball("Relay energy", Vector3.new(0, 0, -1.5), 0.9, colors.mint, 1, model)
    return prepareRig(model)
end

local function number(value)
    if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
    if value >= 1000 then return string.format("%.1fK", value / 1000) end
    return tostring(math.floor(value))
end

function World.arrive(model, slot, username)
    model.Name = "Traveler_" .. username
    model:PivotTo(CFrame.new(World.entrancePoint(1, 1)))
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
        if p:IsA("Script") or p:IsA("LocalScript") or p:IsA("Tool") then p:Destroy() end
    end
    model.Parent = root
    local head = model:FindFirstChild("Head")
    -- One bounded label per traveler: name and earnings occupy separate rows.
    -- The client selects visible labels and keeps their screen rectangles apart.
    local caption = Instance.new("BillboardGui")
    caption.Name, caption.Size = "Caption", UDim2.fromOffset(156, 52)
    caption:SetAttribute("RiftboundLabelKind", "avatar")
    caption:SetAttribute("ViewerUsername", username)
    caption.StudsOffset, caption.MaxDistance = Vector3.new(0, 3, 0), 1200
    caption.AlwaysOnTop, caption.Enabled, caption.Parent = false, false, head
    local nameText = Instance.new("TextLabel")
    nameText.Name, nameText.Size, nameText.Position = "NameLabel", UDim2.fromScale(1, 20 / 52), UDim2.fromScale(0, 32 / 52)
    nameText.BackgroundTransparency, nameText.Font, nameText.TextSize = 1, Enum.Font.GothamBold, 16
    nameText.Text, nameText.TextColor3, nameText.TextStrokeTransparency = username, colors.gold, 0.5
    nameText.TextWrapped, nameText.TextTruncate, nameText.Parent = false, Enum.TextTruncate.AtEnd, caption
    local popText = Instance.new("TextLabel")
    popText.Name, popText.Size, popText.Position = "Earned", UDim2.fromScale(1, 20 / 52), UDim2.fromScale(0, 12 / 52)
    popText.BackgroundTransparency = 1
    popText.TextColor3, popText.Font, popText.TextSize = colors.mint, Enum.Font.GothamBold, 16
    popText.TextStrokeTransparency, popText.TextTransparency, popText.Text = 0.4, 1, ""
    popText.TextWrapped, popText.TextTruncate, popText.Parent = false, Enum.TextTruncate.AtEnd, caption
    avatars[string.lower(username)] = {
        model = model, slot = slot, arrivedAt = os.clock(), frame = model:GetPivot(),
        balance = 0, popText = popText, scale = 1, username = username,
    }
end

local function track(distance, radius, count)
    local node = math.floor(distance)
    local fraction = distance - node
    local a, b = node * math.pi * 2 / count, (node + 1) * math.pi * 2 / count
    local from = Vector3.new(math.sin(a) * radius, 0, math.cos(a) * radius)
    local to = Vector3.new(math.sin(b) * radius, 0, math.cos(b) * radius)
    return from:Lerp(to, fraction)
end

local function destination(member, state, now, scale)
    local y = 35 + 3 * scale
    if state.entrance then
        for index, name in ipairs(state.entrance.names) do
            if name == member.username then return World.entrancePoint(index, #state.entrance.names), true end
        end
    end
    if member.entranceDone == false then return Vector3.new(-64 + ((member.slot - 1) % 5 - 2) * 5, 80, 82), false end
    if state.phase == "result" then
        for rank, row in ipairs(state.winners or {}) do
            if row.username == member.username then
                return Vector3.new(({ 0, -10, 10 })[rank], (state.activity.id == "sprint" and 76.5 or 35) + 3 * scale + ({ 4, 2.5, 1.5 })[rank], state.activity.id == "sprint" and -1104 or 14), true
            end
        end
    end
    if state.activity.id == "sprint" then
        if state.phase == "voting" or state.phase == "gathering" then
            for lane, username in ipairs(state.nextCohort or {}) do
                if username == member.username then return World.sprintPoint(((lane + (state.phase == "gathering" and state.round + 1 or state.round) - 2) % 5) + 1, 0), false end
            end
        end
        return World.crewPosition(member.slot).Position, false
    end
    if state.autoActivities and (state.phase == "voting" or (state.phase == "storm" and member.activityEntered)) then
        local distance = member.distance
        if state.phase == "storm" then
            distance = distance + math.max(0, math.min(now, state.deadline) - state.now) * member.pace
        end
        if state.activity.id == "sprint" then
            distance = math.min(12, distance)
            local p = track(distance, 33 + ((member.slot - 1) % 6) * 0.8, 12)
            return Vector3.new(p.X, y + 2.5, p.Z), false
        elseif state.activity.id == "starfall" then
            local p = track(distance + member.slot, 18 + (member.slot % 2) * 2, 8)
            return Vector3.new(p.X, y + math.sin((distance % 1) * math.pi) * 1.3, p.Z), false
        else
            local a = ((member.slot - 1) % 3 + 1) * math.pi * 2 / 3
            local shrine = Vector3.new(math.sin(a) * 22, y, math.cos(a) * 22)
            local heart = Vector3.new((member.slot % 3 - 1) * 2, y, 4)
            local t = distance % 2
            return t < 1 and shrine:Lerp(heart, t) or heart:Lerp(shrine, t - 1), false
        end
    end
    local a = member.slot * math.pi * 2 / 18 + math.sin(now * 0.2 + member.slot) * 0.035
    return Vector3.new(math.sin(a) * 28, y, math.cos(a) * 28), false
end

function World.render(state, now)
    sceneState = state
    local showLast = state.phase == "result" or state.phase == "gathering"
    local leaders = showLast and state.lastRound or state.roundLeaders
    local lines = { "ROUND TOP EARNERS", showLast and "LAST ROUND" or "THIS ROUND" }
    for i = 1, math.min(3, #leaders) do
        table.insert(lines, string.format("%d. %s   $%s", i, leaders[i].username, number(leaders[i].money)))
    end
    scoreText.Text = table.concat(lines, "\n")
    local sessionLines = { "TOP EARNERS / SESSION" }
    for i = 1, math.min(3, #state.leaderboard) do
        local row = state.leaderboard[i]
        table.insert(sessionLines, string.format("%d. %s   $%s", i, row.username, number(row.money)))
    end
    sessionText.Text = table.concat(sessionLines, "\n")
    for _, member in ipairs(state.members) do
        local key = string.lower(member.username)
        local record = avatars[key]
        if record and not (state.phase == "storm" and member.activityEntered) and (record.pendingAppearance or not record.model.PrimaryPart
            or not record.model:FindFirstChild("Head") or not record.model:FindFirstChildOfClass("Humanoid") or record.model.Humanoid.Health <= 0) then
            local replacement, old = record.pendingAppearance or World.offlineAvatar(member.username), record.model
            local balance, previousFrame = record.balance, old:GetPivot()
            local queuedGiant, deferredGiantUntil = record.queuedGiant, record.deferredGiantUntil
            World.arrive(replacement, record.slot, member.username)
            old:Destroy()
            record = avatars[key]
            record.frame = previousFrame
            replacement:PivotTo(previousFrame)
            record.balance, record.appearanceAttempted = balance, true
            record.queuedGiant, record.deferredGiantUntil = queuedGiant, deferredGiantUntil
        end
        if record then
            local model = record.model
            if record.physical and not (state.phase == "storm" and state.activity.id == "sprint") then
                record.frame = model.PrimaryPart.CFrame
                physical(record, false)
            end
            local delta = member.balance - record.balance
            if delta >= 0.5 and now >= (record.nextPop or 0) then
                if record.fade then record.fade:Cancel(); record.rise:Cancel() end
                record.popText.Text, record.popText.TextTransparency = "+$" .. number(delta), 0
                record.popText.Position = UDim2.fromScale(0, 12 / 52)
                record.fade = TweenService:Create(record.popText, TweenInfo.new(0.95), { TextTransparency = 1 })
                record.rise = TweenService:Create(record.popText, TweenInfo.new(0.95), { Position = UDim2.fromScale(0, 4 / 52) })
                record.fade:Play(); record.rise:Play()
                record.balance, record.nextPop = member.balance, now + 1.05
            end
            local racing = state.phase == "storm" and state.activity.id == "sprint"
            if racing and member.effect == "giant" then record.queuedGiant = true end
            if not racing and record.queuedGiant then
                record.deferredGiantUntil, record.queuedGiant = now + 6, false
            end
            local giant = member.effect == "giant" or now < (record.deferredGiantUntil or 0)
            local targetScale = giant and not racing and 1.85 or 1
            if record.scale ~= targetScale then model:ScaleTo(targetScale); record.scale = targetScale end
            model.GiftAura.Enabled = member.effect ~= "" or now < (record.deferredGiantUntil or 0)
            model.GiftAura.OutlineColor = member.effect == "aurora" and colors.violet or colors.gold
        end
    end
    for i = #monuments + 1, math.min(24, state.wins) do
        local a = i * 2.399
        table.insert(monuments, crystal(Vector3.new(87 + math.cos(a) * 13, 41, 21 + math.sin(a) * 13), 0.5 + (i % 3) * 0.2, colors.gold))
    end
end

function World.animate(now)
    local state = sceneState
    if not state then return end
    local dt = math.min(0.25, math.max(0, now - lastFrame))
    lastFrame = now
    local storm = state.phase == "storm"
    rift.Transparency = storm and 0.3 or (state.phase == "voting" and 0.55 or 0.92)
    rift.CFrame = CFrame.new(0, 90 + math.sin(now) * 2, -50) * CFrame.Angles(0, now * 0.2, 0)
    core.CFrame = CFrame.new(0, 42 + math.sin(now * 1.2) * 0.6, 0) * CFrame.Angles(0, now * 0.3, 0.12)
    shield.Transparency = storm and state.choice == "ward" and 0.88 or 1
    gate.Transparency = 0.6 + math.sin(now) * 0.08
    World.stepCourse(now)
    for i, cloud in ipairs(scenery.clouds) do
        local a = cloud.angle + now * 0.006
        cloud.model:PivotTo(CFrame.new(math.cos(a) * (88 + i * 3), cloud.height + math.sin(now * 0.13 + i), math.sin(a) * (88 + i * 3)))
    end
    for i, rune in ipairs(scenery.runes) do
        local a = i * math.pi / 6 + now * 0.15
        rune.CFrame = CFrame.new(math.cos(a) * 6, 48 + math.sin(a) * 1.5, math.sin(a) * 6) * CFrame.Angles(0, a, 0.3)
    end
    for i, entry in ipairs(scenery.stars) do
        entry.part.CFrame = entry.origin * CFrame.new(0, math.sin(now * 2 + i) * 0.5, 0) * CFrame.Angles(0, now, 0)
    end
    for _, p in ipairs(constellation:GetChildren()) do p.Transparency = state.blessing == "Titan constellation" and 0 or 1 end
    for _, p in ipairs(bloom:GetChildren()) do p.Transparency = state.blessing == "Starbloom" and 0 or 1 end
    for i, ribbon in ipairs(scenery.ribbons) do
        ribbon.Transparency = state.blessing == "Aurora veil" and 0.42 or 1
        ribbon.CFrame = CFrame.new((i - 5.5) * 14, 79 + math.sin(now * 0.6 + i * 0.5) * 5, -35) * CFrame.Angles(0, 0, math.sin(now * 0.3 + i) * 0.2)
        ribbon.Color = Color3.fromHSV((now * 0.025 + i / 20) % 1, 0.45, 1)
    end
    Lighting.Ambient = state.blessing == "Aurora veil" and Color3.fromHSV((now * 0.025) % 1, 0.35, 0.65) or Color3.fromRGB(111, 109, 148)
    for i, p in ipairs(winds:GetChildren()) do
        p.Transparency = storm and state.choice == "sail" and 0.4 or 1
        p.CFrame = CFrame.new((i - 7) * 8, 40 + (i % 4) * 4, ((now * 35 + i * 11) % 120) - 60)
    end
    local celebration = state.phase == "result" and #state.winners > 0
    local gifted = state.blessing ~= ""
    for i, p in ipairs(scenery.particles) do
        p.Transparency = (celebration or gifted) and 0.15 or 1
        if celebration or gifted then
            local a = i * 2.399 + now * 0.6
            local radius = celebration and (state.activity.id == "sprint" and 12 or 16) or 25
            local baseY = state.activity.id == "sprint" and 84 or 37
            local baseZ = state.activity.id == "sprint" and (celebration and -1104 or 0) or 10
            p.CFrame = CFrame.new(math.cos(a) * radius, baseY + ((now * (celebration and 8 or 5) + i * 2) % (state.activity.id == "sprint" and 18 or 30)), baseZ + math.sin(a) * radius)
            p.Color = Color3.fromHSV((i / 36 + now * 0.03) % 1, 0.5, 1)
        end
    end
    for _, member in ipairs(state.members) do
        local record = avatars[string.lower(member.username)]
        if record then
            if state.activity.id == "sprint" and state.phase == "storm" and record.race and record.race.round == state.round then
                -- Physics owns the root. Only pose the massless limbs for walking.
                local speed = record.model.PrimaryPart and record.model.PrimaryPart.AssemblyLinearVelocity.Magnitude or 0
                local gait = speed > 1 and math.sin(now * 9) * 0.45 or 0
                for _, joint in ipairs(record.model:GetDescendants()) do
                    if joint:IsA("Motor6D") and (string.find(joint.Name, "Shoulder") or string.find(joint.Name, "Hip")) then
                        if not joint:GetAttribute("SprintBaseC0") then joint:SetAttribute("SprintBaseC0", joint.C0) end
                        joint.C0 = joint:GetAttribute("SprintBaseC0") * CFrame.Angles(gait * (string.find(joint.Name, "Left") and 1 or -1), 0, 0)
                    end
                end
            else
            local target, winner = destination(member, state, now, record.scale)
            local age = now - record.arrivedAt
            local entering = false
            for _, name in ipairs(state.entrance and state.entrance.names or {}) do if name == member.username then entering = true end end
            if entering then
                -- Hold a recognizable celebratory pose at the gate, never a race root.
                record.frame = CFrame.lookAt(target, target + Vector3.new(0, 0, 1))
                record.model.GiftAura.Enabled, record.model.GiftAura.OutlineColor = true, colors.mint
            end
            local current = record.frame.Position
            local position = current:Lerp(target, math.min(1, dt * 7))
            local delta = target - current
            local direction = Vector3.new(delta.X, 0, delta.Z)
            if direction.Magnitude < 0.1 then direction = Vector3.new(0, 0, entering and 1 or -1) end
            local frame = CFrame.lookAt(position, position + direction)
            record.frame = record.frame:Lerp(frame, math.min(1, dt * 9))
            local moving = not entering and Vector3.new(delta.X, 0, delta.Z).Magnitude > 0.2
            local gait = moving and math.sin(now * 9 + member.slot) * 0.55 or (winner and math.sin(now * 7) * 0.8 or 0)
            local bob = moving and math.abs(math.sin(now * 9)) * 0.16 or (winner and math.abs(math.sin(now * 5)) * 0.65 or 0)
            local body = record.frame * CFrame.new(0, bob, 0)
            local model, size = record.model, record.scale
            model:PivotTo(body)
            for _, spec in ipairs({ { "Left Arm", -1.5, 0, gait }, { "Right Arm", 1.5, 0, -gait }, { "Left Leg", -0.5, -2, -gait }, { "Right Leg", 0.5, -2, gait } }) do
                local arm = math.abs(spec[2]) > 1
                model[spec[1]].CFrame = body * CFrame.new(spec[2] * size, (winner and arm and 1.1 or spec[3]) * size, 0)
                    * CFrame.Angles(spec[4], 0, winner and arm and spec[2] * 0.4 or 0)
            end
            model["Winner crown"].Transparency = winner and not entering and 0 or 1
            for i = 1, 3 do model["Crown spike " .. i].Transparency = winner and not entering and 0 or 1 end
            model["Relay energy"].Transparency = storm and state.activity.id == "relay" and member.activityEntered and 0 or 1
            model["Relay energy"].CFrame = body * CFrame.new(0, size, -1.5 * size)
            end
        end
    end
end

return World
```

### Realm.server.lua

Create a **Script** named **Realm** under **ServerScriptService**.

```luau
-- Startup status is created BEFORE requiring any game modules.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local remotes = ReplicatedStorage:FindFirstChild("Riftbound")
if remotes and not remotes:IsA("Folder") then
    warn("[Riftbound startup] ReplicatedStorage.Riftbound must be a Folder. Check for a conflicting saved instance.")
    return
end
if remotes and remotes:GetAttribute("BootstrapClaimed") then
    warn("[Riftbound startup] Bootstrap already claimed. Keep one enabled server Realm Script; remove any saved runtime Riftbound Folder with Play stopped.")
    return
end
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name, remotes.Parent = "Riftbound", ReplicatedStorage
end
remotes:SetAttribute("BootstrapClaimed", true)
remotes:SetAttribute("Ready", false)
remotes:SetAttribute("StartupState", "starting")
remotes:SetAttribute("StartupStage", "Creating remotes")
remotes:SetAttribute("StartupError", "")
local running, currentStage = false, "Creating remotes"
local connections = {}
local function stage(name)
    currentStage = name
    remotes:SetAttribute("StartupStage", name)
end
local function traceback(issue)
    return debug.traceback(tostring(issue), 2)
end
local function failed(label, issue)
    running = false
    remotes:SetAttribute("Ready", false)
    remotes:SetAttribute("StartupState", "failed")
    remotes:SetAttribute("StartupStage", label)
    remotes:SetAttribute("StartupError", string.sub(tostring(issue), 1, 3500))
    for _, connection in ipairs(connections) do connection:Disconnect() end
    warn("[Riftbound startup/runtime] " .. label .. "\n" .. tostring(issue))
end
local function guarded(label, fn)
    local ok, issue = xpcall(fn, traceback)
    if not ok then failed(label, issue) end
    return ok
end
local function channel(name)
    local event = remotes:FindFirstChild(name)
    if event then
        assert(event:IsA("RemoteEvent"), "ReplicatedStorage.Riftbound." .. name .. " must be a RemoteEvent")
    else
        event = Instance.new("RemoteEvent")
        event.Name, event.Parent = name, remotes
    end
    return event
end

local function initialize()
    local snapshotRemote = channel("Snapshot")
    local actionRemote = channel("Action")
    local noticeRemote = channel("Notice")

    -- Bounded dependency checks give an exact name/type error instead of an infinite wait.
    for _, name in ipairs({ "Config", "RealmState", "World" }) do
        stage("Checking ModuleScript " .. name)
        local child = script.Parent:WaitForChild(name, 5)
        assert(child, "Missing ServerScriptService." .. name .. ". Create a ModuleScript with this exact name (no .lua suffix).")
        assert(child:IsA("ModuleScript"), "ServerScriptService." .. name .. " must be a ModuleScript, not " .. child.ClassName)
        local count = 0
        for _, sibling in ipairs(script.Parent:GetChildren()) do if sibling.Name == name then count = count + 1 end end
        assert(count == 1, "Duplicate ModuleScripts named " .. name .. "; keep exactly one.")
    end
    stage("Requiring Config")
    local Config = require(script.Parent.Config)
    assert(type(Config) == "table", "Config must return a configuration table")
    stage("Requiring RealmState")
    local Realm = require(script.Parent.RealmState)
    assert(type(Realm) == "table" and type(Realm.new) == "function", "RealmState must return its module table with new()")
    stage("Requiring World")
    local World = require(script.Parent.World)
    assert(type(World) == "table", "World must return its module table")
    for _, name in ipairs({ "build", "render", "animate", "offlineAvatar", "arrive", "sprintStep", "loadAppearance", "cameraBounds", "courseInfo", "resolveUsername", "validUsername" }) do
        assert(type(World[name]) == "function", "World is missing " .. name .. "(). Replace the entire World ModuleScript with the Phase 2 file.")
    end
    stage("Validating Config")
    -- Phase 1 Config tables lacked these fields. Supply only missing values; never hide invalid explicit values.
    local defaults = {
        SceneUpdatesPerSecond = 12, SnapshotSeconds = 0.5, AutoActivities = true,
        ActivityMoneyPerSecond = 2, RoundWinMoneyPerSecond = 1, CoinsPerPoint = 2,
        RoundPrizes = { 120, 75, 40 }, OfflineDemoEnabled = true, DemoStudioOnly = true,
        DemoNames = { "Demo_Astra", "Demo_Lumen", "Demo_Nova", "Demo_Fern", "Demo_Orion" },
        AutoSimulateGifts = true, DemoGiftSeconds = 18, StreamCameraDefault = true, HostUserIds = {},
        BaseMoneyPerSecond = 5, VoteMoneyPerSecond = 3, WinMoneyPerSecond = 2,
        MaxMoneyPerSecond = 100, MaxBalance = 1000000000, MaxCrew = 18, MaxQueuedArrivals = 30,
        PersistenceEnabled = false, AutoJoinPlayers = true, SprintOnly = true, SprintCompetitors = 5, SprintRaceSeconds = 120, SprintWalkSpeed = 12, ResolveViewerUsernames = true, EntranceSeconds = 4,
        SprintFinishBonus = 40, LoadAvatarAppearances = false, AppearanceTimeoutSeconds = 8,
        DemoAppearanceUserIds = { 1, 156, 261, 2, 3 },
    }
    for name, value in pairs(defaults) do if Config[name] == nil then Config[name] = value end end
    assert(Config.PersistenceEnabled == false, "PersistenceEnabled must stay false; this game has no save implementation")
    local function range(name, minimum, maximum)
        local value = Config[name]
        assert(type(value) == "number" and value == value and value >= minimum and value <= maximum,
            "Config." .. name .. " must be a finite number from " .. minimum .. " to " .. maximum)
    end
    for _, name in ipairs({ "GatheringSeconds", "VotingSeconds", "StormSeconds", "ResultSeconds" }) do range(name, 0.1, 3600) end
    range("SprintRaceSeconds", 120, 120)
    range("SprintWalkSpeed", 10, 14)
    range("EntranceSeconds", 3, 5)
    assert(workspace.StreamingEnabled ~= true, "For this playtest, Stop Play and set Workspace.StreamingEnabled=false in Properties.")
    range("SprintCompetitors", 1, 5)
    assert(Config.SprintCompetitors == math.floor(Config.SprintCompetitors), "SprintCompetitors must be a whole number")
    range("SprintFinishBonus", 0, 1000000)
    range("AppearanceTimeoutSeconds", 1, 30)
    range("SceneUpdatesPerSecond", 4, 30)
    range("SnapshotSeconds", 0.25, 5)
    range("DemoGiftSeconds", 5, 3600)
    range("MaxCrew", 1, 18)
    range("MaxQueuedArrivals", 1, 200)
    assert(Config.MaxCrew == math.floor(Config.MaxCrew) and Config.MaxQueuedArrivals == math.floor(Config.MaxQueuedArrivals), "Crew and queue limits must be whole numbers")
    for _, name in ipairs({ "BaseMoneyPerSecond", "VoteMoneyPerSecond", "WinMoneyPerSecond", "ActivityMoneyPerSecond", "RoundWinMoneyPerSecond", "CoinsPerPoint" }) do range(name, 0, 1000) end
    range("MaxMoneyPerSecond", 1, 1000)
    range("MaxBalance", 1, 1000000000)
    for _, name in ipairs({ "AutoActivities", "OfflineDemoEnabled", "DemoStudioOnly", "AutoSimulateGifts", "StreamCameraDefault", "SprintOnly", "LoadAvatarAppearances", "AutoJoinPlayers", "ResolveViewerUsernames" }) do
        assert(type(Config[name]) == "boolean", "Config." .. name .. " must be true or false")
    end
    assert(type(Config.DemoAppearanceUserIds) == "table", "DemoAppearanceUserIds must be a table")
    for _, id in ipairs(Config.DemoAppearanceUserIds) do assert(type(id) == "number" and id > 0 and id < 9007199254740991 and id == math.floor(id), "Appearance IDs must be positive whole numbers") end
    assert(type(Config.HostUserIds) == "table" and type(Config.DemoNames) == "table" and type(Config.RoundPrizes) == "table", "HostUserIds, DemoNames and RoundPrizes must be tables")
    for i, name in ipairs(Config.DemoNames) do assert(type(name) == "string" and #name >= 3 and #name <= 20 and string.match(name, "^[%w_]+$"), "DemoNames contains an invalid username label") end
    for i = 1, 3 do assert(type(Config.RoundPrizes[i]) == "number" and Config.RoundPrizes[i] >= 0 and Config.RoundPrizes[i] <= 1000000, "RoundPrizes needs three finite nonnegative amounts") end
    stage("Creating RealmState")
    local state = Realm.new(Config, os.clock())
    for _, name in ipairs({ "tick", "advance", "snapshot", "addCrew", "vote", "gift", "follow", "bless", "recordCheckpoint", "raceDistance", "raceComplete", "raceDNF", "queueEntrance", "advanceEntrances", "nextCohort" }) do
        assert(type(state[name]) == "function", "RealmState is missing " .. name .. "(). Replace its complete Phase 2 source.")
    end
    local initial = state:snapshot(os.clock())
    assert(type(initial.activity) == "table" and type(initial.winners) == "table" and type(initial.lastGift) == "table", "RealmState is from an older version. Replace its complete Phase 2 source.")
    stage("Building World")
    World.build(Config)
    local tasks = {}
    local lastAction = {}
    local demoEnabled = Config.OfflineDemoEnabled and (not Config.DemoStudioOnly or RunService:IsStudio())

    local function host(player)
        if RunService:IsStudio() then return true end
        if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
        for _, id in ipairs(Config.HostUserIds) do if player.UserId == id then return true end end
        return false
    end

    local function publish()
        local now = os.clock()
        local snapshot = state:snapshot(now)
        snapshot.persistence, snapshot.bridge = "memory only", "offline simulator"
        snapshot.demo, snapshot.streamCamera = demoEnabled == true, Config.StreamCameraDefault
        snapshot.cameraBounds = World.cameraBounds(snapshot)
        snapshot.course = World.courseInfo()
        World.render(snapshot, now)
        snapshotRemote:FireAllClients(snapshot)
    end

    local function notify(player, message)
        if player and player.Parent then noticeRemote:FireClient(player, message) end
    end

    local function arrival(username, appearanceUserId, offline)
        if not World.validUsername(username) then
            return false, "Enter a Roblox username, not a display name."
        end
        if state.crew[string.lower(username)] then return false, "That traveler is already here." end
        if #state.crewOrder >= Config.MaxCrew then return false, "The island is full for this session." end
        if #state.entranceQueue >= Config.MaxQueuedArrivals then return false, "The Star Gate entrance queue is full. Try again shortly." end
        local userId = type(appearanceUserId) == "number" and appearanceUserId or 0
        if userId == 0 and not offline then
            local issue
            userId, issue = World.resolveUsername(username)
            if not userId then return false, issue end
        end
        local model = World.offlineAvatar(username)
        state:tick(os.clock())
        local added, member = state:addCrew(username, userId)
        if not added then model:Destroy(); return false, member end
        state:queueEntrance(username)
        state:advanceEntrances(os.clock())
        World.arrive(model, member.slot, username)
        World.loadAppearance(username, userId)
        return true, username .. (offline and " queued / OFFLINE stand-in." or " queued / Roblox avatar.")
    end

    local function apply(event)
        if event.type == "join" then return arrival(event.username, event.appearanceUserId, event.offline == true) end
        if event.type == "vote" then return state:vote("live:" .. event.viewer, event.choice, event.username, os.clock()) end
        if event.type == "blessing" then return state:bless(event.kind, os.clock()) end
        if event.type == "gift" then return state:gift(event.username, event.kind, event.count, os.clock()) end
        if event.type == "follow" then return state:follow(event.viewer) end
        return false, "Unsupported event."
    end

    local function enqueue(event, done)
        if #tasks >= Config.MaxQueuedArrivals then return false end
        table.insert(tasks, { event = event, done = done })
        return true
    end

    -- Server-only hook for a separately installed future adapter. This is not HTTP.
    local eventHook = Instance.new("BindableFunction")
    eventHook.Name, eventHook.Parent = "RiftboundEvent", script.Parent
    eventHook.OnInvoke = function(event)
        if not running then return false, "Riftbound is not running. Check StartupError." end
        if type(event) ~= "table" then return false, "An event table is required." end
        local completed, accepted, message = false, false, "Queue full."
        if not enqueue(event, function(ok, result) accepted, message, completed = ok, result, true end) then return false, message end
        while running and not completed do task.wait(0.1) end
        if not completed then return false, "Riftbound stopped before processing the event." end
        return accepted, message
    end

    stage("Rendering first World snapshot")
    publish()
    running = true
    remotes:SetAttribute("Ready", true)
    remotes:SetAttribute("StartupState", "ready")
    remotes:SetAttribute("StartupStage", "Running Phase 2")
    print("[Riftbound] Ready: modules loaded, world built, first snapshot rendered.")

    task.spawn(function()
        while running do
            local item = table.remove(tasks, 1)
            if item then
                local ok, applied, message = pcall(apply, item.event)
                if not ok then
                    warn("[Riftbound event] " .. tostring(applied))
                    applied, message = false, "The island could not apply this event. Try again later."
                end
                if not applied then state.message = message end
                if item.done then item.done(applied, message) end
                if not guarded("Publishing event result", publish) then break end
                task.wait(0.35)
            else task.wait(0.2) end
        end
    end)

    local function playerAdded(player)
        if not running then return end
        if World.preparePlayer then World.preparePlayer(player) end
        player:SetAttribute("RiftboundHost", host(player))
        player:SetAttribute("RiftboundStreamCamera", Config.StreamCameraDefault)
        if Config.AutoJoinPlayers then
            enqueue({ type = "join", username = player.Name, appearanceUserId = player.UserId }, function(_, message) notify(player, message) end)
        end
    end
    Players.PlayerAdded:Connect(playerAdded)
    for _, player in ipairs(Players:GetPlayers()) do task.spawn(playerAdded, player) end
    Players.PlayerRemoving:Connect(function(player) lastAction[player.UserId] = nil end)

    actionRemote.OnServerEvent:Connect(function(player, action, payload)
        if not running then return end
        if type(action) ~= "string" or type(payload) ~= "string" or #payload > 100 then return end
        local now = os.clock()
        if lastAction[player.UserId] and now - lastAction[player.UserId] < 0.5 then return end
        lastAction[player.UserId] = now
        if action == "vote" then
            local _, message = state:vote("player:" .. player.UserId, payload, player.Name, now)
            notify(player, message)
        elseif host(player) then
            if action == "join" or action == "offlineJoin" then
                if not enqueue({ type = "join", username = payload, offline = action == "offlineJoin" }, function(_, message) notify(player, message) end) then
                    notify(player, "The arrival queue is full. Try again shortly.")
                end
            elseif action == "blessing" then
                local _, message = state:bless(payload, now)
                notify(player, message)
            elseif action == "demoWard" or action == "demoSail" then
                if not state.crew[string.lower(payload)] then notify(player, "Join that username first."); return end
                local _, message = state:vote("demo:" .. string.lower(payload), action == "demoWard" and "ward" or "sail", payload, now)
                notify(player, message)
            elseif action == "giftBloom" or action == "giftAurora" or action == "giftGiant" then
                local kind = ({ giftBloom = "bloom", giftAurora = "aurora", giftGiant = "giant" })[action]
                local _, message = state:gift(payload, kind, 1, now)
                notify(player, message)
            elseif action == "follow" then
                local _, message = state:follow("demo:" .. string.lower(payload))
                notify(player, message)
            elseif action == "rift" then
                if state.phase == "gathering" then state.deadline = now end
            end
        end
        guarded("Publishing player action", publish)
    end)

    task.spawn(function()
        if not demoEnabled then return end
        task.wait(2)
        for i, name in ipairs(Config.DemoNames) do
            if not running then return end
            enqueue({ type = "join", username = name, appearanceUserId = Config.DemoAppearanceUserIds[i], offline = true })
            task.wait(0.65)
        end
        if not Config.AutoSimulateGifts then return end
        local nextTarget, kinds = 0, { "bloom", "aurora", "giant" }
        while running do
            task.wait(math.max(5, Config.DemoGiftSeconds))
            if not running then break end
            if #state.crewOrder > 0 then
                nextTarget = nextTarget + 1
                local username = state.crew[state.crewOrder[((nextTarget - 1) % #state.crewOrder) + 1]].username
                enqueue({ type = "gift", username = username, kind = kinds[((nextTarget - 1) % #kinds) + 1], count = 1 })
                enqueue({ type = "follow", viewer = "demo:" .. string.lower(username) })
            end
        end
    end)

    local sceneAccumulator, raceAccumulator = 0, 0
    table.insert(connections, RunService.Heartbeat:Connect(function(dt)
        sceneAccumulator = sceneAccumulator + dt
        raceAccumulator = raceAccumulator + dt
        if running and raceAccumulator >= 0.05 then
            raceAccumulator = 0
            if not guarded("Observing physical Sprint", function() World.sprintStep(state, os.clock()) end) then return end
        end
        if running and sceneAccumulator >= 1 / Config.SceneUpdatesPerSecond then
            sceneAccumulator = 0
            guarded("Animating World", function() World.animate(os.clock()) end)
        end
    end))

    task.spawn(function()
        local lastSnapshot = 0
        while running do
            if not guarded("Advancing rounds / rendering snapshot", function()
                local now = os.clock()
                state:tick(now)
                state:advanceEntrances(now)
                local changed = state:advance(now)
                if changed or now - lastSnapshot >= Config.SnapshotSeconds then
                    publish()
                    lastSnapshot = now
                end
            end) then break end
            task.wait(0.1)
        end
    end)

end

local ok, issue = xpcall(initialize, traceback)
if not ok then failed(currentStage, issue) end
```

### Realm.client.lua

Create a **LocalScript** named **Realm** under **StarterPlayer → StarterPlayerScripts**.

```luau
-- Show startup progress BEFORE looking for the server's remotes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then warn("[Riftbound client] PlayerGui did not appear. Use Play, not Run."); return end
local mainGui
local startupGui = Instance.new("ScreenGui")
startupGui.Name, startupGui.ResetOnSpawn, startupGui.DisplayOrder = "RiftboundStartup", false, 100
startupGui.Parent = playerGui
local startupText = Instance.new("TextLabel")
startupText.AnchorPoint, startupText.Position, startupText.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.85, 0.42)
startupText.BackgroundColor3, startupText.TextColor3 = Color3.fromRGB(17, 27, 43), Color3.fromRGB(232, 240, 236)
startupText.Font, startupText.TextSize, startupText.TextWrapped = Enum.Font.Gotham, 18, true
startupText.Text, startupText.Parent = "RIFTBOUND / starting server...", startupGui
local function startupError(message)
    startupGui.Enabled = true
    startupText.TextColor3 = Color3.fromRGB(255, 174, 150)
    startupText.Text = "RIFTBOUND STARTUP FAILED\n\n" .. message .. "\n\nStop Play and check the SERVER Output. Keep one enabled Script named Realm in ServerScriptService, with RunContext Legacy/default."
    if mainGui then mainGui.Enabled = false end
    local camera = workspace.CurrentCamera
    if camera then
        camera.CameraType, camera.FieldOfView = Enum.CameraType.Custom, 70
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then camera.CameraSubject = humanoid end
    end
    warn("[Riftbound client] " .. message)
end
local remotes = ReplicatedStorage:WaitForChild("Riftbound", 10)
if not remotes then
    startupError("The server did not publish ReplicatedStorage.Riftbound within 10 seconds. Check that Realm.server.lua is a normal enabled server Script in ServerScriptService, not a ModuleScript or LocalScript.")
    return
end
if not remotes:IsA("Folder") then startupError("ReplicatedStorage.Riftbound is not a Folder. Check for a conflicting saved object."); return end
local function watchStartup()
    if remotes:GetAttribute("StartupState") == "failed" then
        local detail = tostring(remotes:GetAttribute("StartupError"))
        startupError(tostring(remotes:GetAttribute("StartupStage")) .. ":\n" .. (string.match(detail, "^[^\n]*") or detail))
    end
end
remotes:GetAttributeChangedSignal("StartupError"):Connect(watchStartup)
remotes:GetAttributeChangedSignal("StartupState"):Connect(watchStartup)
local timeout = os.clock() + 25
while not remotes:GetAttribute("Ready") and os.clock() < timeout do
    if remotes:GetAttribute("StartupState") == "failed" then watchStartup(); return end
    startupText.Text = "RIFTBOUND / " .. tostring(remotes:GetAttribute("StartupStage") or "waiting for corrected server bootstrap")
    task.wait(0.1)
end
if not remotes:GetAttribute("Ready") then
    startupError("Server startup did not complete. Last stage: " .. tostring(remotes:GetAttribute("StartupStage")) .. ". Replace the server and client together; older servers do not publish readiness.")
    return
end
local snapshotRemote = remotes:WaitForChild("Snapshot", 5)
local actionRemote = remotes:WaitForChild("Action", 5)
local noticeRemote = remotes:WaitForChild("Notice", 5)
for _, pair in ipairs({ { "Snapshot", snapshotRemote }, { "Action", actionRemote }, { "Notice", noticeRemote } }) do
    if not pair[2] or not pair[2]:IsA("RemoteEvent") then startupError("Riftbound." .. pair[1] .. " is missing or is not a RemoteEvent."); return end
end
if remotes:GetAttribute("StartupState") == "failed" then watchStartup(); return end

local ink = Color3.fromRGB(17, 27, 43)
local pale = Color3.fromRGB(232, 240, 236)
local muted = Color3.fromRGB(160, 181, 190)
local mint = Color3.fromRGB(127, 239, 204)
local gold = Color3.fromRGB(245, 211, 155)
local CAMERA_DIAGNOSTICS = true -- Temporary: set false after the Studio camera playtest.
local STREAM_HIDE_WARD = true -- Set false to test the closer camera without hiding the ward.
local STREAM_HIDE_RIFT = true -- The large sphere crosses the sightline to the finish gate.
local STREAM_DAYLIGHT = true -- Local presentation only; Roam restores the previous lighting.
local STREAM_CLEAR_EFFECTS = true -- Reversible local Atmosphere/PostEffect isolation on EVERY Play.
local STREAM_CINEMATIC = true -- False retains the close full-course overview.
local Lighting = game:GetService("Lighting")

-- BEGIN PRESENTATION MATH (pure geometry, also exercised by automated checks)
local Layout = {
    width = 480, height = 854,
    toolbar = { x = 216, y = 18, w = 240, h = 30 },
    header = { x = 24, y = 56, w = 432, h = 64 },
    notice = { x = 24, y = 126, w = 432, h = 32 },
    arena = { x = 16, y = 166, w = 448, h = 344 },
    earners = { x = 24, y = 522, w = 210, h = 130 },
    competitors = { x = 246, y = 522, w = 210, h = 130 },
    round = { x = 24, y = 660, w = 432, h = 64 },
    footer = { x = 24, y = 728, w = 432, h = 10 },
    tools = { x = 24, y = 166, w = 432, h = 466 },
}
local function viewportLayout(width, height)
    local scale = math.min(width / Layout.width, height / Layout.height)
    return scale, (width - Layout.width * scale) / 2, (height - Layout.height * scale) / 2
end
local function screenRect(rect, scale, x, y)
    return { x = x + rect.x * scale, y = y + rect.y * scale, w = rect.w * scale, h = rect.h * scale }
end
local function fits(rect, occupied, bounds, gap)
    if rect.x < bounds.x or rect.y < bounds.y or rect.x + rect.w > bounds.x + bounds.w or rect.y + rect.h > bounds.y + bounds.h then return false end
    gap = gap or 0
    for _, other in ipairs(occupied) do
        if rect.x < other.x + other.w + gap and rect.x + rect.w + gap > other.x
            and rect.y < other.y + other.h + gap and rect.y + rect.h + gap > other.y then return false end
    end
    return true
end
local SprintBounds = { minX = -38, maxX = 38, minY = 54, maxY = 110, minZ = -1120, maxZ = 82, yaw = 60 }
-- A bounded starting-grid envelope. Competition shots fit observed roots below.
-- Fallback frames the starting grid, NEVER the full 1,152-stud course.
local SprintVolumes = {
    { minX = -23, maxX = 23, minY = 61, maxY = 90, minZ = 24, maxZ = 78 },
}
local LegacyBounds = { minX = -54, maxX = 54, minY = -10, maxY = 62, minZ = -54, maxZ = 54, yaw = 0 }
local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function usableViewport(width, height)
    return finite(width) and finite(height) and width >= 64 and height >= 64
        and width <= 32768 and height <= 32768 and width / height >= 0.25 and width / height <= 4
end
local function cameraBounds(bounds, physicalSprint)
    -- Never fall back to the lower original island while awaiting a Sprint snapshot.
    local expected = physicalSprint == false and LegacyBounds or SprintBounds
    if bounds == nil then return expected, physicalSprint == false and "legacy defaults" or "missing; Skybridge fallback" end
    if type(bounds) ~= "table" then return expected, "invalid type; fallback" end
    for _, axis in ipairs({ "X", "Y", "Z" }) do
        local lo, hi = bounds["min" .. axis], bounds["max" .. axis]
        if not finite(lo) or not finite(hi) or lo >= hi then return expected, "invalid " .. axis .. "; fallback" end
        -- This is a fixed, known course. Reject translated, undersized or enormous
        -- server boxes instead of following them below the map or into the fog.
        if lo > expected["min" .. axis] or hi < expected["max" .. axis]
            or lo < expected["min" .. axis] - 16 or hi > expected["max" .. axis] + 16 then
            return expected, "outside course envelope; fallback"
        end
    end
    if not finite(bounds.yaw) or bounds.yaw ~= expected.yaw then return expected, "invalid yaw; fallback" end
    -- Symmetric padding preserves the same course center and heading in every phase.
    local box = { yaw = expected.yaw }
    for _, axis in ipairs({ "X", "Y", "Z" }) do
        local center = (expected["min" .. axis] + expected["max" .. axis]) / 2
        local radius = math.max(center - bounds["min" .. axis], bounds["max" .. axis] - center)
        box["min" .. axis], box["max" .. axis] = center - radius, center + radius
    end
    return box, "server bounds verified"
end
-- Fixed heading/elevation; aspect-ratio fitting adjusts distance and lens width. Always
-- return a finite, bounded solution, even before a usable viewport/snapshot exists.
local function arenaCamera(width, height, receivedBounds, physicalSprint)
    local bounds, reason = cameraBounds(receivedBounds, physicalSprint)
    local viewportReady = usableViewport(width, height)
    if not viewportReady then width, height = 390, 844 end
    local scale, ox, oy = viewportLayout(width, height)
    local area = screenRect(Layout.arena, scale, ox, oy)
    local sprint = physicalSprint ~= false
    local fov = sprint and 55 or 50
    local tanV = math.tan(math.rad(fov) / 2)
    local tanH = tanV * width / height
    local elevation = math.rad(sprint and 40 or 52)
    local up, back = math.sin(elevation), math.cos(elevation)
    local centerY = (bounds.minY + bounds.maxY) / 2
    local centerX, centerZ = (bounds.minX + bounds.maxX) / 2, (bounds.minZ + bounds.maxZ) / 2
    -- Keep the lens near the course. The old start-biased 55-degree overview
    -- put the finish about 400 studs away while close shots remained visible.
    if sprint then centerX, centerY, centerZ = 0, 70, 50 end
    local yaw = math.rad(sprint and 0 or bounds.yaw)
    local volumes = { bounds }
    if sprint then volumes = SprintVolumes end -- Padding does not move the authored course.
    local c, sn = math.cos(yaw), math.sin(yaw)
    local function project(x, y, z, d, shift)
        local across = c * (x - centerX) - sn * (z - centerZ)
        local along = sn * (x - centerX) + c * (z - centerZ)
        local localY = back * (y - centerY) - up * along
        local localZ = up * (y - centerY) + back * along
        local depth = d - localZ
        return width / 2 + across * width / (2 * tanH * depth),
            height / 2 - (localY + shift) * height / (2 * tanV * depth), depth
    end
    local shiftRatio = (0.5 - (area.y + area.h / 2) / height) * 2 * tanV
    local function fitsCourse(distance)
        for _, volume in ipairs(volumes) do
            for _, x in ipairs({ volume.minX, volume.maxX }) do
                for _, y in ipairs({ volume.minY, volume.maxY }) do
                    for _, z in ipairs({ volume.minZ, volume.maxZ }) do
                        local shift = shiftRatio * distance
                        local px, py, depth = project(x, y, z, distance, shift)
                        if depth <= 1 or px < area.x + 10 * scale or px > area.x + area.w - 10 * scale
                            or py < area.y + 10 * scale or py > area.y + area.h - 10 * scale then return false end
                    end
                end
            end
        end
        return true
    end
    local far, fitted = sprint and 210 or 850, false
    for angle = sprint and 85 or 50, sprint and 120 or 50, 5 do
        fov, tanV = angle, math.tan(math.rad(angle) / 2)
        tanH = tanV * width / height
        shiftRatio = (0.5 - (area.y + area.h / 2) / height) * 2 * tanV
        local near, candidate = sprint and 100 or 120, sprint and 210 or 850
        local fitsAtLimit = fitsCourse(candidate)
        if fitsAtLimit then
            for _ = 1, 24 do
                local middle = (near + candidate) / 2
                if fitsCourse(middle) then candidate = middle else near = middle end
            end
        end
        far, fitted = candidate, fitsAtLimit
        if not sprint then break end
        -- Prefer <=180 studs and <=260 to every course/jump corner. Narrow
        -- viewports can widen to 120 degrees, with hard limits of 210/290.
        local shift = shiftRatio * far
        local lensY, lensZ = centerY + up * far - back * shift, centerZ + back * far + up * shift
        local reach = 0
        for _, volume in ipairs(volumes) do
            for _, x in ipairs({ volume.minX, volume.maxX }) do for _, y in ipairs({ volume.minY, volume.maxY }) do for _, z in ipairs({ volume.minZ, volume.maxZ }) do
                reach = math.max(reach, math.sqrt(x * x + (y - lensY)^2 + (z - lensZ)^2))
            end end end
        end
        fitted = fitted and lensY >= 112 and reach <= 290
        if fitted and far <= 180 and reach <= 260 then break end
    end
    local shift = shiftRatio * far
    if sprint then
        -- Move lens AND Focus together along screen-up, then look directly at
        -- that optical-axis Focus. No post-lookAt local translation is applied.
        centerY, centerZ = centerY - back * shift, centerZ + up * shift
        shift = 0
    end
    return far, shift, up, back, centerY, centerX, centerZ, yaw, bounds, reason, fitted and viewportReady, fov
end
local function containsPartBounds(object, point)
    local p = object.CFrame:PointToObjectSpace(point)
    local half = object.Size * 0.5
    if object:IsA("Part") and object.Shape == Enum.PartType.Ball then
        return (p.X / half.X) ^ 2 + (p.Y / half.Y) ^ 2 + (p.Z / half.Z) ^ 2 <= 1
    end
    return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end
-- Fit observed avatar positions into the existing clear portrait rectangle.
-- This is presentation only: no race progress, winner or avatar motion is generated.
local function cinematicCamera(width, height, positions, yawDegrees, elevationDegrees, entrance)
    if not usableViewport(width, height) or #positions == 0 then return nil end
    local lo, hi = positions[1], positions[1]
    for _, p in ipairs(positions) do
        if not finite(p.X) or not finite(p.Y) or not finite(p.Z) then return nil end
        lo = Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z))
        hi = Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
    end
    local center = (lo + hi) * 0.5
    local yaw, elevation = math.rad(yawDegrees), math.rad(elevationDegrees)
    local sn, c, up, back = math.sin(yaw), math.cos(yaw), math.sin(elevation), math.cos(elevation)
    local fov = entrance and 35 or 55
    local tanV = math.tan(math.rad(fov) / 2)
    local scale, ox, oy = viewportLayout(width, height)
    local area = screenRect(Layout.arena, scale, ox, oy)
    local shiftRatio = (0.5 - (area.y + area.h / 2) / height) * 2 * tanV
    local outward = Vector3.new(sn * back, up, c * back)
    local screenUp = Vector3.new(-sn * up, back, -c * up)
    local function pose(distance)
        local focus = center - screenUp * (shiftRatio * distance)
        return CFrame.lookAt(focus + outward * distance, focus), focus
    end
    local function fit(distance)
        local cf = pose(distance)
        -- Margin includes giant avatars, head labels, jump and celebration motion.
        for _, p in ipairs(positions) do
            for _, x in ipairs({ entrance and -3 or -5, entrance and 3 or 5 }) do for _, y in ipairs({ entrance and -4 or -5, entrance and 7 or 12 }) do for _, z in ipairs({ entrance and -3 or -5, entrance and 3 or 5 }) do
                local v = cf:PointToObjectSpace(p + Vector3.new(x, y, z))
                local depth = -v.Z
                if depth <= 1 then return false end
                local px = width / 2 + v.X * height / (2 * tanV * depth)
                local py = height / 2 - v.Y * height / (2 * tanV * depth)
                if px < area.x + 10 * scale or px > area.x + area.w - 10 * scale
                    or py < area.y + 10 * scale or py > area.y + area.h - 10 * scale then return false end
            end end end
        end
        return true
    end
    local near, far = entrance and 60 or 90, entrance and 150 or 180
    if not fit(far) then return nil end -- Use the independently fitted overview.
    for _ = 1, 18 do
        local middle = (near + far) / 2
        if fit(middle) then far = middle else near = middle end
    end
    local cf, focus = pose(far)
    if cf.Position.Y < 112 or cf.Position.Y > 220 or math.abs(cf.Position.X) > 200 or cf.Position.Z < -1250 or cf.Position.Z > 260 then return nil end
    return cf, focus, far, fov
end
-- END PRESENTATION MATH

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.ZIndexBehavior = "RiftboundHUD", false, Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset, gui.Parent = true, playerGui
-- Match WorldToViewportPoint coordinates; top/bottom safe margins are in Layout.
gui.ScreenInsets = Enum.ScreenInsets.None
mainGui = gui
startupGui.Enabled = false

local function round(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius, corner.Parent = UDim.new(0, radius or 12), object
end
local function frame(parent, name, rect)
    local f = Instance.new("Frame")
    f.Name, f.Size, f.Position = name, UDim2.fromOffset(rect.w, rect.h), UDim2.fromOffset(rect.x, rect.y)
    f.BackgroundColor3, f.BackgroundTransparency, f.BorderSizePixel = ink, 0.12, 0
    f.ClipsDescendants, f.Parent = true, parent
    round(f)
    return f
end
local function text(parent, name, value, rect, textSize, color)
    local t = Instance.new("TextLabel")
    t.Name, t.Size, t.Position = name, UDim2.fromOffset(rect.w, rect.h), UDim2.fromOffset(rect.x, rect.y)
    t.BackgroundTransparency, t.Text, t.Font = 1, value, Enum.Font.Gotham
    t.TextSize, t.TextColor3 = textSize or 15, color or pale
    t.TextXAlignment, t.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Center
    t.TextWrapped, t.TextTruncate, t.RichText = false, Enum.TextTruncate.AtEnd, false
    t.Parent = parent
    return t
end
local function button(parent, name, value, rect, callback)
    local b = Instance.new("TextButton")
    b.Name, b.Size, b.Position = name, UDim2.fromOffset(rect.w, rect.h), UDim2.fromOffset(rect.x, rect.y)
    b.BackgroundColor3, b.BorderSizePixel = Color3.fromRGB(41, 67, 76), 0
    b.Text, b.Font, b.TextSize, b.TextColor3 = value, Enum.Font.GothamBold, 14, pale
    b.TextWrapped, b.TextTruncate, b.AutoButtonColor = false, Enum.TextTruncate.AtEnd, true
    b.Parent = parent
    round(b, 9)
    b.Activated:Connect(callback)
    return b
end
local canvas = Instance.new("Frame")
canvas.Name, canvas.Size = "VerticalStreamCanvas", UDim2.fromOffset(Layout.width, Layout.height)
canvas.AnchorPoint, canvas.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
canvas.BackgroundTransparency, canvas.Parent = 1, gui
local canvasScale = Instance.new("UIScale")
canvasScale.Parent = canvas
local latestState, receivedAt = nil, 0
local streamCamera = player:GetAttribute("RiftboundStreamCamera") ~= false
local cameraDefaultFov = 70
local cameraDefaultFovMode = Enum.FieldOfViewMode.Vertical
local cameraTarget, cameraFocus, activeBounds
local overviewTarget, overviewFocus, overviewDistance, overviewFov
local directorFrame, directorFocus, directorKey, directorSubject
local directorShot = "overview"
local heldCamera, holdCameraButton
local boundsReason, cameraDistance, cameraFitted = "waiting for snapshot", 0, false
local cameraFov = 55
local hiddenWard, originalWardTransparency = nil, 0
local hiddenBaseplate, originalBaseplateTransparency = nil, 0
local hiddenRift, originalRiftTransparency = nil, 0
local cameraPositionDrift, cameraAimDrift = 0, 0
local maximumPositionDrift, maximumAimDrift = 0, 0
local renderCheckEnabled, renderCheckFolder, nearProbe, farProbe = false, nil, nil, nil
local savedStreamLighting
local suspendedEffects = {}
local effectRefreshAt = 0
local lensMasks, nextLensScan = {}, 0
local streamLighting = {
    ClockTime = 14, Brightness = 3, ExposureCompensation = 0.25,
    EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 0.5,
    OutdoorAmbient = Color3.fromRGB(180, 195, 215), GlobalShadows = false,
    FogStart = 10000, FogEnd = 100000,
}
local cameraWidth, cameraHeight = 0, 0
local nextCameraDiagnostic = 0
local streamRequestPending, streamRequests, nextStreamRequest = false, 0, 0
local resize
local function money(value)
    if value >= 1000000000 then return string.format("%.1fB", value / 1000000000) end
    if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
    if value >= 1000 then return string.format("%.1fK", value / 1000) end
    return tostring(math.floor(value))
end

local header = frame(canvas, "Header", Layout.header)
text(header, "Brand", "RIFTBOUND / LIVE", { x = 12, y = 5, w = 318, h = 18 }, 16, gold).Font = Enum.Font.GothamBold
local phase = text(header, "Activity", "THE ISLAND IS AWAKENING", { x = 12, y = 24, w = 318, h = 20 }, 18, mint)
local stats = text(header, "Stats", "AUTOPLAY / LOCAL DEMO", { x = 12, y = 45, w = 318, h = 14 }, 11, muted)
local timer = text(header, "Countdown", "12", { x = 338, y = 3, w = 82, h = 36 }, 30, gold)
timer.TextXAlignment, timer.Font = Enum.TextXAlignment.Center, Enum.Font.GothamBlack
local timingLabel = text(header, "CountdownLabel", "NEXT ROUND", { x = 338, y = 41, w = 82, h = 16 }, 10, muted)
timingLabel.TextXAlignment = Enum.TextXAlignment.Center

local function board(name, title, rect)
    local container = frame(canvas, name, rect)
    text(container, "Title", title, { x = 10, y = 5, w = 190, h = 20 }, 15, gold).Font = Enum.Font.GothamBold
    local rows = {}
    for i = 1, 5 do
        local y = 28 + (i - 1) * 19
        local username = text(container, "Name" .. i, i .. ". Waiting", { x = 10, y = y, w = 126, h = 18 }, 14)
        local score = text(container, "Score" .. i, "—", { x = 140, y = y, w = 60, h = 18 }, 14, mint)
        score.TextXAlignment, score.Font = Enum.TextXAlignment.Right, Enum.Font.GothamBold
        rows[i] = { name = username, score = score }
    end
    return container, rows
end
local earnerPanel, earners = board("TopEarners", "TOP EARNERS / $", Layout.earners)
local competitorPanel, competitors = board("RoundLeaders", "ROUND LEADERS", Layout.competitors)
local notice = frame(canvas, "EventStrip", Layout.notice)
notice.Visible = false
local noticeText = text(notice, "Message", "", { x = 10, y = 2, w = 412, h = 28 }, 14, gold)
local noticeVersion = 0
local entranceAnnouncementActive = false
local function notify(value)
    noticeVersion = noticeVersion + 1
    local version = noticeVersion
    noticeText.Text, notice.Visible = tostring(value), true
    task.delay(4, function() if noticeVersion == version and not entranceAnnouncementActive then notice.Visible = false end end)
end
noticeRemote.OnClientEvent:Connect(notify)

-- Results reuse this dock. There is no winner banner floating over the arena.
local dock = frame(canvas, "RoundDock", Layout.round)
local instruction = text(dock, "Instruction", "Travelers compete automatically.", { x = 10, y = 4, w = 412, h = 21 }, 14)
local roundStatus = text(dock, "Status", "Next competition starts automatically.", { x = 10, y = 28, w = 412, h = 24 }, 14, mint)
local ward = button(dock, "Ward", "WARD", { x = 10, y = 28, w = 200, h = 26 }, function() actionRemote:FireServer("vote", "ward") end)
local sail = button(dock, "Sail", "SAIL", { x = 222, y = 28, w = 200, h = 26 }, function() actionRemote:FireServer("vote", "sail") end)
ward.Visible, sail.Visible = false, false
local progressTrack = frame(dock, "Progress", { x = 10, y = 57, w = 412, h = 3 })
local progressFill = Instance.new("Frame")
progressFill.Name, progressFill.Size, progressFill.BackgroundColor3, progressFill.BorderSizePixel = "Fill", UDim2.fromScale(0, 1), mint, 0
progressFill.Parent = progressTrack
local footer = text(canvas, "Footer", "OFFLINE / MEMORY ONLY", Layout.footer, 9, muted)
footer.TextXAlignment = Enum.TextXAlignment.Center
-- y=718..854 remains free for the lower LIVE interface. The middle is scenery.

local controls = frame(canvas, "TestTools", Layout.tools)
controls.Visible = false
local function showTools(visible)
    controls.Visible = visible
    earnerPanel.Visible, competitorPanel.Visible = not visible, not visible
end
text(controls, "Title", "KEEPER / OFFLINE TESTS", { x = 16, y = 12, w = 350, h = 25 }, 16, gold)
button(controls, "Close", "X", { x = 384, y = 10, w = 32, h = 28 }, function() showTools(false) end)
local input = Instance.new("TextBox")
input.Name, input.Size, input.Position = "Username", UDim2.fromOffset(264, 38), UDim2.fromOffset(16, 52)
input.BackgroundColor3, input.TextColor3 = Color3.fromRGB(31, 45, 61), pale
input.Font, input.TextSize, input.Text = Enum.Font.Gotham, 15, "Demo_Astra"
input.PlaceholderText, input.ClearTextOnFocus, input.Parent = "Traveler username", false, controls
round(input, 10)
button(controls, "Join", "OFFLINE JOIN", { x = 290, y = 52, w = 126, h = 38 }, function() actionRemote:FireServer("offlineJoin", input.Text) end)
button(controls, "StartEarly", "START EARLY", { x = 16, y = 102, w = 194, h = 38 }, function() actionRemote:FireServer("rift", "") end)
button(controls, "Follow", "TEST FOLLOW", { x = 222, y = 102, w = 194, h = 38 }, function() actionRemote:FireServer("follow", input.Text) end)
for i, item in ipairs({ { "Bloom sky", "bloom" }, { "Aurora sky", "aurora" }, { "Titan sky", "giant" } }) do
    button(controls, "Sky" .. i, item[1], { x = 16 + (i - 1) * 137, y = 152, w = 126, h = 38 }, function() actionRemote:FireServer("blessing", item[2]) end)
end
for i, item in ipairs({ { "Gift bloom", "giftBloom" }, { "Gift aurora", "giftAurora" }, { "Gift giant", "giftGiant" } }) do
    button(controls, "Gift" .. i, item[1], { x = 16 + (i - 1) * 137, y = 202, w = 126, h = 38 }, function() actionRemote:FireServer(item[2], input.Text) end)
end
button(controls, "VoteWard", "VOTE AS: WARD", { x = 16, y = 252, w = 194, h = 38 }, function() actionRemote:FireServer("demoWard", input.Text) end)
button(controls, "VoteSail", "VOTE AS: SAIL", { x = 222, y = 252, w = 194, h = 38 }, function() actionRemote:FireServer("demoSail", input.Text) end)
button(controls, "VerifiedJoin", "ROBLOX JOIN / VERIFY ACCOUNT", { x = 16, y = 300, w = 400, h = 32 }, function() actionRemote:FireServer("join", input.Text) end)
text(controls, "Hint2", "Offline join = stand-in. Roblox join = account lookup.", { x = 16, y = 342, w = 400, h = 24 }, 13, muted)
text(controls, "Hint3", "Close tools to restore the leaderboard dock.", { x = 16, y = 372, w = 400, h = 24 }, 14, mint)
local renderCheckButton
renderCheckButton = button(controls, "RenderCheck", "RENDER CHECK: OFF", { x = 16, y = 410, w = 194, h = 36 }, function()
    renderCheckEnabled = not renderCheckEnabled
    renderCheckButton.Text = renderCheckEnabled and "RENDER CHECK: ON" or "RENDER CHECK: OFF"
    nextCameraDiagnostic = 0
    showTools(false)
    notify(renderCheckEnabled and "RENDER CHECK / near PINK + distant GREEN cubes" or "RENDER CHECK / removed")
end)
holdCameraButton = button(controls, "HoldCamera", "HOLD CAMERA: OFF", { x = 222, y = 410, w = 194, h = 36 }, function()
    local camera = workspace.CurrentCamera
    if heldCamera then
        heldCamera = nil
    elseif camera and streamCamera then
        heldCamera = { frame = camera.CFrame, focus = camera.Focus.Position, fov = camera.FieldOfView }
    end
    holdCameraButton.Text = heldCamera and "HOLD CAMERA: ON" or "HOLD CAMERA: OFF"
    directorKey, nextCameraDiagnostic = nil, 0
    showTools(false)
    notify(heldCamera and "CAMERA HELD / rounds continue normally" or "CAMERA RELEASED / automatic shots")
end)
local keeper = button(canvas, "KeeperToggle", "TEST TOOLS", { x = 342, y = 18, w = 114, h = 30 }, function() showTools(not controls.Visible) end)
keeper.TextSize = 11
local cameraButton
local function updateRenderCheck()
    local camera = workspace.CurrentCamera
    local active = renderCheckEnabled and streamCamera and gui.Enabled and camera ~= nil
    if not active then
        if renderCheckFolder then renderCheckFolder:Destroy() end
        renderCheckFolder, nearProbe, farProbe = nil, nil, nil
        return
    end
    if not renderCheckFolder then
        renderCheckFolder = Instance.new("Folder")
        renderCheckFolder.Name, renderCheckFolder.Parent = "RiftboundLocalRenderCheck", workspace
        local function probe(name, size, color)
            local part = Instance.new("Part")
            part.Name, part.Size, part.Color = name, size, color
            part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
            part.Material, part.Transparency, part.LocalTransparencyModifier = Enum.Material.Neon, 0, 0
            part.CastShadow, part.Parent = false, renderCheckFolder
            return part
        end
        nearProbe = probe("Near_PINK_12_studs", Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(255, 30, 180))
        farProbe = probe("Course_GREEN", Vector3.new(8, 8, 8), Color3.fromRGB(80, 255, 40))
    end
    -- Native 3D parts, NOT AlwaysOnTop adornments or GUI stand-ins. The near
    -- cube tests this camera's rendering; the far cube tests course-distance draw.
    nearProbe.CFrame = camera.CFrame * CFrame.new(-1.2, 0, -12)
    farProbe.CFrame = CFrame.new(0, 104, 0)
end
local function updateStreamLighting()
    if STREAM_DAYLIGHT and streamCamera and gui.Enabled then
        if not savedStreamLighting then
            savedStreamLighting = {}
            for property in pairs(streamLighting) do savedStreamLighting[property] = Lighting[property] end
        end
        for property, value in pairs(streamLighting) do
            if Lighting[property] ~= value then Lighting[property] = value end
        end
    elseif savedStreamLighting then
        for property, value in pairs(savedStreamLighting) do Lighting[property] = value end
        savedStreamLighting = nil
    end
end
local function updateStreamEffects(now)
    if not (STREAM_CLEAR_EFFECTS and streamCamera and gui.Enabled) then
        for object, record in pairs(suspendedEffects) do
            -- Effects can be removed by another script while this view is active.
            pcall(function()
                if record.atmosphere then
                    if object.Parent == nil then object.Parent = record.parent end
                elseif object.Parent then object.Enabled = record.enabled end
            end)
        end
        suspendedEffects, effectRefreshAt = {}, 0
        return
    end
    if now < effectRefreshAt then return end
    effectRefreshAt = now + 0.5
    for _, container in ipairs({ Lighting, workspace.CurrentCamera }) do
        if container then
            for _, object in ipairs(container:GetDescendants()) do
                if not suspendedEffects[object] then
                    if object:IsA("Atmosphere") then
                        suspendedEffects[object] = { atmosphere = true, parent = object.Parent }
                        object.Parent = nil -- Keep the Instance; restore it in Roam.
                    elseif object:IsA("PostEffect") then
                        suspendedEffects[object] = { enabled = object.Enabled }
                        object.Enabled = false
                    end
                elseif object:IsA("PostEffect") then object.Enabled = false end
            end
        end
    end
end
local function updateStreamScenery()
    -- Hide only Studio's named template floor for the broadcast; keep it in Roam.
    local baseplate = workspace:FindFirstChild("Baseplate")
    local hideBaseplate = streamCamera and gui.Enabled
    if hiddenBaseplate and (hiddenBaseplate ~= baseplate or not hideBaseplate) then
        hiddenBaseplate.LocalTransparencyModifier = originalBaseplateTransparency
        hiddenBaseplate = nil
    end
    if hideBaseplate and baseplate and baseplate:IsA("BasePart") then
        if hiddenBaseplate ~= baseplate then hiddenBaseplate, originalBaseplateTransparency = baseplate, baseplate.LocalTransparencyModifier or 0 end
        baseplate.LocalTransparencyModifier = 1
    end
    local realm = workspace:FindFirstChild("RiftboundRealm")
    local ward = realm and realm:FindFirstChild("Starlight ward")
    local hide = STREAM_HIDE_WARD and streamCamera and gui.Enabled
    if hiddenWard and (hiddenWard ~= ward or not hide) then
        hiddenWard.LocalTransparencyModifier = originalWardTransparency
        hiddenWard = nil
    end
    if hide and ward and ward:IsA("BasePart") then
        if hiddenWard ~= ward then
            hiddenWard, originalWardTransparency = ward, ward.LocalTransparencyModifier or 0
        end
        -- Local-only presentation. The server's ward/vote state is untouched;
        -- its subsequent Transparency updates cannot reintroduce the shell.
        ward.LocalTransparencyModifier = 1
    end
    local rift = realm and realm:FindFirstChild("Storm rift")
    local hideRift = STREAM_HIDE_RIFT and streamCamera and gui.Enabled
    if hiddenRift and (hiddenRift ~= rift or not hideRift) then
        hiddenRift.LocalTransparencyModifier = originalRiftTransparency
        hiddenRift = nil
    end
    if hideRift and rift and rift:IsA("BasePart") then
        if hiddenRift ~= rift then hiddenRift, originalRiftTransparency = rift, rift.LocalTransparencyModifier or 0 end
        rift.LocalTransparencyModifier = 1
    end
end
local function streamRayExclusions()
    local result = {}
    if hiddenWard then result[#result + 1] = hiddenWard end
    if hiddenRift then result[#result + 1] = hiddenRift end
    for object in pairs(lensMasks) do result[#result + 1] = object end
    return result
end
local function updateLensMasks(now)
    local active = streamCamera and gui.Enabled and cameraTarget ~= nil
    if active and now < nextLensScan then return end
    nextLensScan = now + 0.25
    local enclosing = {}
    if active then
        local realm = workspace:FindFirstChild("RiftboundRealm")
        local course = realm and realm:FindFirstChild("SkybridgeSprint")
        for _, object in ipairs(workspace:GetDescendants()) do
            if object:IsA("BasePart") and not object:IsA("Terrain") and object.Size.Magnitude >= 20 and (object.Transparency or 0) < 0.95
                and containsPartBounds(object, cameraTarget.Position) then
                local ancestor, protected = object, false
                while ancestor do
                    if ancestor == course or ancestor == player.Character or ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then protected = true; break end
                    ancestor = ancestor.Parent
                end
                if not protected then enclosing[object] = true end
            end
        end
    end
    for object, original in pairs(lensMasks) do
        if not enclosing[object] then object.LocalTransparencyModifier = original; lensMasks[object] = nil end
    end
    for object in pairs(enclosing) do
        if lensMasks[object] == nil then
            lensMasks[object] = object.LocalTransparencyModifier or 0
            if CAMERA_DIAGNOSTICS then
                local ok, path = pcall(function() return object:GetFullName() end)
                print("[Riftbound render] locally masking camera-enclosing geometry: " .. (ok and path or object.Name))
            end
        end
        object.LocalTransparencyModifier = 1
    end
end
local function updateDirector(now, dt)
    if heldCamera then
        cameraTarget, cameraFocus, cameraFov = heldCamera.frame, heldCamera.focus, heldCamera.fov
        cameraDistance, directorShot = (cameraTarget.Position - cameraFocus).Magnitude, "held camera"
        return
    end
    local desired, focus, distance, fov = overviewTarget, overviewFocus, overviewDistance, overviewFov
    local key, shot, targets = "grid", "starting grid / safe fallback", {}
    local state = latestState
    local realm = workspace:FindFirstChild("RiftboundRealm")
    local function position(username, entrance)
        local model = realm and realm:FindFirstChild("Traveler_" .. username)
        local main = model and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart"))
        local p = main and main.Position
        if p and finite(p.X) and finite(p.Y) and finite(p.Z) and p.Y >= 54 and p.Y <= 110
            and p.Z >= -1120 and p.Z <= 100 and math.abs(p.X) <= (entrance and 90 or 38) then return p end
    end
    local entrance = state and state.entrance
    local liveTime = state and state.now + now - receivedAt or now
    local lead
    if state then
        for _, row in ipairs(state.activityLeaders) do
            if row.status == "racing" and position(row.username) then lead = row; break end
        end
    end
    local nearFinish = state and state.phase == "storm" and lead and lead.distance >= (state.activity.goal or 48) - 3
    local yaw, elevation = -18, 40
    if entrance and liveTime < entrance.endsAt and not nearFinish then
        key, shot, yaw, elevation = "entrance/" .. entrance.sequence, "Star Gate entrance", 10, 35
        for _, name in ipairs(entrance.names) do local p = position(name, true); if p then targets[#targets + 1] = p end end
    elseif STREAM_CINEMATIC and state and state.physicalSprint then
        if state.phase == "storm" and lead then
            local age = math.max(0, liveTime - state.activityStarted)
            local beat = math.floor(age / 8)
            local section = math.min(4, math.floor(lead.distance / 12) + 1)
            local spotlight = beat % 4 == 3 and not nearFinish
            key = "race/" .. state.round .. "/" .. beat .. "/" .. section
            if directorKey ~= key then
                directorSubject = lead.username
                if spotlight then
                    local others = {}
                    for _, row in ipairs(state.activityLeaders) do
                        if row.status == "racing" and row.username ~= lead.username and position(row.username) then others[#others + 1] = row end
                    end
                    if #others > 0 then directorSubject = others[(math.floor(beat / 4) % #others) + 1].username end
                end
            end
            local subject = lead
            for _, row in ipairs(state.activityLeaders) do if row.username == directorSubject and row.status == "racing" and position(row.username) then subject = row end end
            if nearFinish then subject = lead end
            local p = position(subject.username)
            if p then targets[1] = p end
            shot = spotlight and "competitor spotlight" or ((state.course and state.course.sections[section] or "section " .. section) .. " / lead pack")
            if not spotlight then
                for _, row in ipairs(state.activityLeaders) do
                    if row.status == "racing" and row.username ~= subject.username and math.abs(row.distance - subject.distance) <= 1.5 then
                        local other = position(row.username); if other then targets[#targets + 1] = other end
                    end
                end
            end
            if nearFinish then
                key, shot, yaw, elevation = "finish/" .. state.round, "finish line", 155, 42
                targets[#targets + 1] = Vector3.new(0, 80, -1092)
            end
        elseif state.phase == "result" and #state.winners > 0 then
            local remaining = math.max(0, state.seconds - (now - receivedAt))
            local hero = remaining <= 6 and remaining > 3
            key, shot, yaw = "podium/" .. state.round .. (hero and "/hero" or "/group"), hero and "winner close-up" or "podium celebration", 175
            for i, row in ipairs(state.winners) do
                if not hero or i == 1 then local p = position(row.username); if p and p.Z < -1060 then targets[#targets + 1] = p end end
            end
        else
            key, shot = "grid/" .. state.round, "starting grid / countdown"
            for _, name in ipairs(state.nextCohort or {}) do local p = position(name); if p and p.Z > 30 then targets[#targets + 1] = p end end
        end
    end
    if #targets > 0 then
        local w, h = cameraWidth, cameraHeight
        if not usableViewport(w, h) then w, h = 390, 844 end
        local cf, aim, d, angle = cinematicCamera(w, h, targets, yaw, elevation, shot == "Star Gate entrance")
        if not cf then
            -- A dispersed pack gets a real competitor close-up, never a zoom-out.
            targets = { targets[1] }
            cf, aim, d, angle = cinematicCamera(w, h, targets, -18, shot == "Star Gate entrance" and 35 or 40, shot == "Star Gate entrance")
        end
        if cf then desired, focus, distance, fov = cf, aim, d, angle end
    end
    if not desired or not focus then return end
    local changed = directorKey ~= key or not directorFrame or shot ~= directorShot
    local candidate = desired
    -- Blend nearby views only. Distant gate/finish returns cut directly rather
    -- than flying across hundreds of studs of empty air. Never blend below decks.
    if directorFrame and (directorFrame.Position - desired.Position).Magnitude < 100 then
        candidate = directorFrame:Lerp(desired, 1 - math.exp(-math.max(0, math.min(dt, 0.25)) * 4))
        local s, ox, oy = viewportLayout(cameraWidth > 0 and cameraWidth or 390, cameraHeight > 0 and cameraHeight or 844)
        local area = screenRect(Layout.arena, s, ox, oy)
        if candidate.Position.Y < 112 then candidate = desired end
        for _, p in ipairs(targets) do
            local v = candidate:PointToObjectSpace(p)
            local depth = -v.Z
            local h, w = cameraHeight > 0 and cameraHeight or 844, cameraWidth > 0 and cameraWidth or 390
            local px, py = w/2 + v.X*h/(2*math.tan(math.rad(fov)/2)*math.max(1, depth)), h/2 - v.Y*h/(2*math.tan(math.rad(fov)/2)*math.max(1, depth))
            if depth <= 1 or px < area.x or px > area.x+area.w or py < area.y or py > area.y+area.h then candidate = desired; break end
        end
    end
    directorFrame, directorFocus, directorKey, directorShot = candidate, focus, key, shot
    cameraTarget, cameraDistance, cameraFov = directorFrame, distance, fov
    cameraFocus = cameraTarget.Position + cameraTarget.LookVector * distance
    if changed then nextLensScan, nextCameraDiagnostic = 0, 0 end
end
local function applyCamera(camera)
    if not cameraTarget or not cameraFocus then return end
    -- FOV mode must be set BEFORE FieldOfView, including after another camera
    -- controller changes it. Scriptable cameras also need an explicit Focus.
    camera.CameraType = Enum.CameraType.Scriptable
    camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical
    camera.FieldOfView = heldCamera and heldCamera.fov or cameraFov
    camera.CFrame, camera.Focus = heldCamera and heldCamera.frame or cameraTarget, CFrame.new(heldCamera and heldCamera.focus or cameraFocus)
end
local function setCamera(enabled)
    if enabled and not streamCamera then
        nextCameraDiagnostic, streamRequests, nextStreamRequest = 0, 0, 0
        maximumPositionDrift, maximumAimDrift = 0, 0
    end
    streamCamera = enabled
    if not enabled then
        directorFrame, directorFocus, directorKey, heldCamera = nil, nil, nil, nil
        if holdCameraButton then holdCameraButton.Text = "HOLD CAMERA: OFF" end
    end
    updateRenderCheck()
    updateStreamScenery()
    updateStreamLighting()
    updateStreamEffects(os.clock())
    updateLensMasks(os.clock())
    if cameraButton then cameraButton.Text = enabled and "ROAM VIEW" or "STREAM VIEW" end
    local camera = workspace.CurrentCamera
    if camera and not enabled then
        camera.FieldOfViewMode = cameraDefaultFovMode
        camera.CameraType, camera.FieldOfView = Enum.CameraType.Custom, cameraDefaultFov
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then camera.CameraSubject = humanoid end
        local main = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if main then
            local focus = main.Position + Vector3.new(0, 2, 0)
            camera.CFrame, camera.Focus = CFrame.lookAt(focus + Vector3.new(22, 16, 24), focus), CFrame.new(focus)
        end
    elseif camera and cameraTarget then
        -- Apply the fitted view immediately; never sweep through the scene at boot.
        applyCamera(camera)
    end
end
cameraButton = button(canvas, "CameraToggle", "ROAM VIEW", { x = 216, y = 18, w = 114, h = 30 }, function() setCamera(not streamCamera) end)
cameraButton.TextSize = 11
local function updateHost()
    keeper.Visible = player:GetAttribute("RiftboundHost") == true
    if not keeper.Visible then showTools(false) end
end
player:GetAttributeChangedSignal("RiftboundHost"):Connect(updateHost)
player:GetAttributeChangedSignal("RiftboundStreamCamera"):Connect(function() setCamera(player:GetAttribute("RiftboundStreamCamera") ~= false) end)
updateHost()

local lastGift, giftFocusUntil, lastWinnerAnnouncement = 0, 0, -1
snapshotRemote.OnClientEvent:Connect(function(state)
    if not latestState or latestState.phase ~= state.phase then nextCameraDiagnostic = 0 end
    latestState, receivedAt = state, os.clock()
    -- Validate EVERY snapshot. Corrected/missing bounds can arrive without an
    -- activity change; never leave the camera stuck on the first received box.
    if resize then resize() end
    competitorPanel.Title.Text = state.physicalSprint and "SPRINT / TIME" or "ROUND LEADERS / PT"
    phase.Text = state.activity.name
    stats.Text = string.format("%s / %d TRAVELERS / %d SHARDS", state.demo and "DEMO" or "LOCAL CREW", #state.crew, state.wins)
    timingLabel.Text = ({ gathering = "NEXT ROUND", voting = "STARTS IN", storm = "TIME LEFT", result = "NEXT UP" })[state.phase]
    for i = 1, 5 do
        local earner = state.leaderboard[i]
        earners[i].name.Text = earner and (i .. ". " .. earner.username) or (i .. ". Waiting")
        earners[i].score.Text = earner and ("$" .. money(earner.money)) or "—"
        local row = state.phase == "result" and (state.winners[i] or state.activityLeaders[i]) or state.activityLeaders[i]
        competitors[i].name.Text = row and ((row.placement and row.placement > 0 and row.placement or i) .. ". " .. row.username) or (i .. ". Ready")
        competitors[i].score.Text = row and (state.physicalSprint and (row.finishedAt > 0 and string.format("%.2fs", row.elapsed) or (row.status == "dnf" and "DNF" or row.score .. "/" .. state.activity.goal)) or row.score .. " pt") or "—"
    end
    local champion = state.phase == "result" and state.winners[1]
    if champion and lastWinnerAnnouncement ~= state.round then
        lastWinnerAnnouncement = state.round
        notify("WINNER / " .. champion.username)
        noticeText.TextSize = 22
    end
    instruction.Text = champion and ("WINNER: " .. champion.username .. " / +$" .. money(champion.prize))
        or (state.physicalSprint and state.phase == "result" and "NO FINISHERS / NEXT RACE LOADING"
            or (state.phase == "voting" and "Choose the sky effect; all travelers compete." or state.activity.instruction))
    ward.Visible, sail.Visible = state.phase == "voting", state.phase == "voting"
    roundStatus.Visible = state.phase ~= "voting"
    ward.Text, sail.Text = "WARD / " .. state.ward, "SAIL / " .. state.sail
    local lead = state.leaderboard[1]
    local income = lead and (lead.username .. " $" .. (state.earning and lead.perSecond or 0) .. "/s") or "Waiting for travelers"
    roundStatus.Text = champion and ((state.physicalSprint and string.format("%.2fs", champion.elapsed) or champion.score .. " pt") .. " / FICTIONAL PRIZE")
        or (state.physicalSprint and state.phase == "result" and "DNF: no finisher bonuses awarded."
            or (state.phase == "storm" and string.format("TEAM %d/%d / %s", state.teamScore, state.teamTarget, income) or income))
    local raceLead = state.activityLeaders[1]
    progressFill.Size = UDim2.fromScale(state.physicalSprint and raceLead and math.min(1, raceLead.distance / state.activity.goal)
        or (state.teamTarget > 0 and math.min(1, state.teamScore / state.teamTarget) or 0), 1)
    if state.physicalSprint and state.phase == "storm" and raceLead then
        local section = math.min(4, math.floor(raceLead.distance / 12) + 1)
        phase.Text = state.course and state.course.sections[section] or "SKYBRIDGE / SECTION " .. section
        roundStatus.Text = string.format("LEAD %d%% / CP %d/%d / 120s RACE", math.floor(raceLead.distance/state.activity.goal*100), raceLead.score, state.activity.goal)
    end
    footer.Text = string.format("%s / %d FOLLOWS / SESSION ONLY", state.demo and "SIMULATED LIVE EVENTS" or "OFFLINE", state.followers)
    if state.lastGift.sequence > lastGift then
        lastGift, giftFocusUntil = state.lastGift.sequence, os.clock() + 6
        notify(string.upper(state.lastGift.kind) .. " x" .. state.lastGift.count .. " / " .. state.lastGift.username .. " (demo)")
    end
end)

-- Only presentation is local: suppress colliding labels, never avatars or income.
local labels, humanoids, pendingLabels = {}, {}, {}
local function track(object)
    if object:IsA("BillboardGui") then
        local function register()
            if object:GetAttribute("RiftboundLabelKind") then
                labels[object] = true
                object.Enabled = false
                if pendingLabels[object] then pendingLabels[object]:Disconnect(); pendingLabels[object] = nil end
            end
        end
        if object:GetAttribute("RiftboundLabelKind") then register()
        elseif not pendingLabels[object] then pendingLabels[object] = object:GetAttributeChangedSignal("RiftboundLabelKind"):Connect(register) end
    elseif object:IsA("Humanoid") then
        humanoids[object] = object.DisplayDistanceType
    end
end
workspace.DescendantAdded:Connect(track)
workspace.DescendantRemoving:Connect(function(object)
    labels[object], humanoids[object] = nil, nil
    if pendingLabels[object] then pendingLabels[object]:Disconnect(); pendingLabels[object] = nil end
end)
for _, object in ipairs(workspace:GetDescendants()) do track(object) end
local protectedPanels = { header, notice, earnerPanel, competitorPanel, dock, footer, controls, keeper, cameraButton }
local function labelPriority(username, now)
    if not latestState then return 100 end
    if latestState.entrance then
        for index, name in ipairs(latestState.entrance.names) do if name == username then return -10 + index end end
    end
    if latestState.phase == "result" then
        for rank, row in ipairs(latestState.winners) do if row.username == username then return rank end end
    end
    if now < giftFocusUntil and latestState.lastGift.username == username then return 0 end
    if latestState.activityLeaders[1] and latestState.activityLeaders[1].username == username then return 4 end
    for i, member in ipairs(latestState.members) do
        if member.username == username then
            return 10 + ((i - 1 - math.floor(now / 5)) % math.max(1, #latestState.members))
        end
    end
    return 100
end
local function updateLabels(now)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local width, height = camera.ViewportSize.X, camera.ViewportSize.Y
    if width <= 0 or height <= 0 then return end
    local s, ox, oy = viewportLayout(width, height)
    local area = streamCamera and screenRect(Layout.arena, s, ox, oy) or { x = 0, y = 0, w = width, h = height }
    local occupied, candidates = {}, {}
    for _, panel in ipairs(protectedPanels) do
        if panel.Visible then
            table.insert(occupied, { x = panel.AbsolutePosition.X, y = panel.AbsolutePosition.Y, w = panel.AbsoluteSize.X, h = panel.AbsoluteSize.Y })
        end
    end
    for humanoid, original in pairs(humanoids) do
        humanoid.DisplayDistanceType = streamCamera and gui.Enabled and Enum.HumanoidDisplayDistanceType.None or original
    end
    for label in pairs(labels) do
        label.Enabled = false
        local kind = label:GetAttribute("RiftboundLabelKind")
        local adornee = label.Adornee or label.Parent
        if gui.Enabled and adornee and adornee:IsA("BasePart") and (kind == "avatar" or not streamCamera) then
            local distance = (camera.CFrame.Position - adornee.Position).Magnitude
            if distance <= label.MaxDistance then
                local logicalW, logicalH = kind == "avatar" and 156 or (kind == "worldBoard" and 300 or 180), kind == "avatar" and 52 or (kind == "worldBoard" and 124 or 24)
                label.Size = UDim2.fromOffset(logicalW * s, logicalH * s)
                if kind == "avatar" then
                    local headPoint = camera:WorldToViewportPoint(adornee.Position)
                    local worldPerPixel = 2 * math.max(1, headPoint.Z) * math.tan(math.rad(camera.FieldOfView) / 2) / height
                    label.StudsOffset = Vector3.new(0, (logicalH / 2 + 10) * s * worldPerPixel, 0)
                end
                for _, child in ipairs(label:GetChildren()) do
                    if child:IsA("TextLabel") then child.TextSize = (kind == "worldBoard" and 18 or (kind == "avatar" and 16 or 14)) * s end
                end
                local offset = label.StudsOffset
                local worldOffset = label.StudsOffsetWorldSpace
                local point, onScreen = camera:WorldToViewportPoint(adornee.Position + worldOffset
                    + camera.CFrame.RightVector * offset.X + camera.CFrame.UpVector * offset.Y - camera.CFrame.LookVector * offset.Z)
                if onScreen and point.Z > 0 then
                    candidates[#candidates + 1] = {
                        label = label, kind = kind, username = label:GetAttribute("ViewerUsername") or label.Name,
                        rect = { x = point.X - logicalW * s / 2, y = point.Y - logicalH * s / 2, w = logicalW * s, h = logicalH * s },
                    }
                end
            end
        end
    end
    table.sort(candidates, function(a, b)
        local pa = a.kind == "avatar" and labelPriority(a.username, now) or 200
        local pb = b.kind == "avatar" and labelPriority(b.username, now) or 200
        return pa < pb or (pa == pb and a.username < b.username)
    end)
    local names, earnings = 0, 0
    for _, entry in ipairs(candidates) do
        local limit = streamCamera and 4 or 6
        if (entry.kind ~= "avatar" or names < limit) and fits(entry.rect, occupied, area, 6 * s) then
            entry.label.Enabled = true
            occupied[#occupied + 1] = entry.rect
            if entry.kind == "avatar" then
                names = names + 1
                local earned = entry.label:FindFirstChild("Earned")
                if earned then
                    earned.Visible = earned.TextTransparency < 0.95 and earnings < 2
                    if earned.Visible then earnings = earnings + 1 end
                end
            end
        end
    end
end

local cameraConnection
resize = function()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local width, height = camera.ViewportSize.X, camera.ViewportSize.Y
    if width ~= cameraWidth or height ~= cameraHeight then
        directorFrame, directorFocus, directorKey = nil, nil, nil
        nextLensScan = 0
    end
    cameraWidth, cameraHeight = width, height
    if usableViewport(width, height) then canvasScale.Scale = viewportLayout(width, height) end
    local physicalSprint = not latestState or latestState.physicalSprint ~= false
    local distance, shift, up, back, centerY, cx, cz, yaw, bounds, reason, fitted, fov = arenaCamera(width, height,
        latestState and latestState.cameraBounds, physicalSprint)
    local focus = Vector3.new(cx, centerY, cz)
    local target = CFrame.lookAt(focus + Vector3.new(math.sin(yaw) * back * distance, up * distance, math.cos(yaw) * back * distance), focus)
    if not physicalSprint then target = target * CFrame.new(0, -shift, 0) end -- preserved legacy-island view only
    local position = target.Position
    if not finite(position.X) or not finite(position.Y) or not finite(position.Z)
        or math.abs(position.X) > 200 or position.Z < -1250 or position.Z > 260
        or position.Y < 112 or position.Y > 220 or (position - focus).Magnitude > 950 then
        -- Last-resort known view. Do not clamp individual CFrame components:
        -- that would change the viewing direction and could clip the course.
        distance, shift, up, back, centerY, cx, cz, yaw, bounds, reason, fitted, fov = arenaCamera(390, 844, nil, physicalSprint)
        focus = Vector3.new(cx, centerY, cz)
        target = CFrame.lookAt(focus + Vector3.new(math.sin(yaw) * back * distance, up * distance, math.cos(yaw) * back * distance), focus)
        if not physicalSprint then target = target * CFrame.new(0, -shift, 0) end
        reason, fitted = "unsafe position rejected; fixed fallback", false
    end
    if reason ~= boundsReason then nextCameraDiagnostic = 0 end
    overviewTarget, overviewFocus, overviewDistance, overviewFov = target, focus, distance, fov
    cameraTarget, cameraFocus, activeBounds = directorFrame or target, directorFrame and cameraFocus or focus, bounds
    boundsReason, cameraFitted = reason, fitted
    if not directorFrame then cameraDistance, cameraFov = distance, fov end
    if streamCamera and gui.Enabled then setCamera(true) end
end

local function cameraDiagnostics(now)
    if now < nextCameraDiagnostic or not cameraFocus then return end
    nextCameraDiagnostic = now + 10
    local realm = workspace:FindFirstChild("RiftboundRealm")
    local sprint = not latestState or latestState.physicalSprint ~= false
    local course = sprint and realm and realm:FindFirstChild("SkybridgeSprint") or (not sprint and realm)
    local parts, opaque, visibleParts = 0, 0, 0
    local minOpacity, maxOpacity, sumOpacity = 1, 0, 0
    if course then
        for _, object in ipairs(course:GetDescendants()) do
            if object:IsA("BasePart") then
                parts = parts + 1
                local opacity = (1 - (object.Transparency or 0)) * (1 - (object.LocalTransparencyModifier or 0))
                minOpacity, maxOpacity, sumOpacity = math.min(minOpacity, opacity), math.max(maxOpacity, opacity), sumOpacity + opacity
                if opacity >= 0.95 then opaque = opaque + 1 end
                if opacity > 0.05 then visibleParts = visibleParts + 1 end
            end
        end
    end
    local anchors, projected = 0, 0
    local anchorObjects = {}
    local camera = workspace.CurrentCamera
    for _, name in ipairs(sprint and { "START platform", "FINISH island", "Finish arch", "Sprint podium 1", "Sprint podium 2", "Sprint podium 3" } or {}) do
        local object = course and course:FindFirstChild(name)
        if object and object:IsA("BasePart") then
            anchors = anchors + 1
            anchorObjects[#anchorObjects + 1] = object
            if camera then
                local _, visible = camera:WorldToViewportPoint(object.Position)
                if visible then projected = projected + 1 end
            end
        end
    end
    -- Persistent is the server's replication policy, not evidence of local
    -- geometry readiness. Check actual parts/anchors before calling it loaded.
    -- buildSprint currently authors over 500 BaseParts, including all sixty lane pads.
    local missingGeometry = not course or visibleParts == 0 or (sprint and (anchors < 6 or parts < 500))
    if workspace.StreamingEnabled and missingGeometry and not streamRequestPending and streamRequests < 3 and now >= nextStreamRequest then
        streamRequestPending, streamRequests, nextStreamRequest = true, streamRequests + 1, now + 15
        local requestFocus = cameraFocus
        task.spawn(function()
            -- Native Roblox geometry streaming only; no custom HTTP/TikTok.
            -- A completed request does NOT prove geometry has replicated.
            local ok, issue = pcall(function() player:RequestStreamAroundAsync(requestFocus, 5) end)
            streamRequestPending = false
            if CAMERA_DIAGNOSTICS then
                print("[Riftbound camera] native stream request " .. (ok and "returned; rechecking geometry" or ("failed: " .. tostring(issue))))
            end
        end)
    end
    if not CAMERA_DIAGNOSTICS or not camera then return end
    print(string.format("[Riftbound camera] presentation=race-show-v7 daylight=%s clock=%.2f brightness=%.2f exposure=%.2f",
        tostring(STREAM_DAYLIGHT and streamCamera and gui.Enabled), Lighting.ClockTime, Lighting.Brightness, Lighting.ExposureCompensation))
    print(string.format("[Riftbound render] revision=race-show-v7 shot=%s clearEffects=%s probes=%s effectiveOpacity min=%.3f mean=%.3f max=%.3f intervalPositionDrift=%.3f intervalAimDrift=%.6f",
        directorShot, tostring(STREAM_CLEAR_EFFECTS), tostring(renderCheckEnabled), parts > 0 and minOpacity or 0, parts > 0 and sumOpacity / parts or 0, maxOpacity, maximumPositionDrift, maximumAimDrift))
    local atmosphereCount, effectCount, enclosureCount = 0, 0, 0
    for _, record in pairs(suspendedEffects) do
        if record.atmosphere then atmosphereCount = atmosphereCount + 1 else effectCount = effectCount + 1 end
    end
    for _ in pairs(lensMasks) do enclosureCount = enclosureCount + 1 end
    print(string.format("[Riftbound render] suspendedAtmospheres=%d disabledPostEffects=%d maskedEnclosures=%d FogStart=%.1f FogEnd=%.1f",
        atmosphereCount, effectCount, enclosureCount, Lighting.FogStart, Lighting.FogEnd))
    maximumPositionDrift, maximumAimDrift = 0, 0
    local renderOk, renderFrame = pcall(function() return camera:GetRenderCFrame() end)
    if renderOk then
        local rp = renderFrame.Position
        print(string.format("[Riftbound render] renderedPosition=(%.1f,%.1f,%.1f) renderedPositionDelta=%.3f renderedAimDelta=%.6f",
            rp.X, rp.Y, rp.Z, (rp - camera.CFrame.Position).Magnitude, 1 - renderFrame.LookVector:Dot(camera.CFrame.LookVector)))
    else
        print("[Riftbound render] GetRenderCFrame unavailable")
    end
    local p, f, box = camera.CFrame.Position, camera.Focus.Position, activeBounds
    local ok, hit = pcall(function() return workspace:Raycast(p, f - p) end)
    local hitText = ok and "clear" or "unavailable"
    if ok and hit then hitText = hit.Instance.Name .. " at " .. string.format("%.1f studs", (hit.Position - p).Magnitude) end
    local visibleRay = "unavailable"
    local rayOk, rayHit = pcall(function()
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = streamRayExclusions()
        return workspace:Raycast(p, f - p, params)
    end)
    if rayOk then visibleRay = rayHit and (rayHit.Instance.Name .. " at " .. string.format("%.1f studs", (rayHit.Position - p).Magnitude)) or "clear" end
    print(string.format("[Riftbound camera] phase=%s round=%s viewport=%sx%s pos=(%.1f,%.1f,%.1f) focus=(%.1f,%.1f,%.1f) distance=%.1f fit=%s FOV=%.1f mode=%s",
        latestState and latestState.phase or "awaiting snapshot", latestState and tostring(latestState.round) or "unknown", tostring(camera.ViewportSize.X), tostring(camera.ViewportSize.Y),
        p.X, p.Y, p.Z, f.X, f.Y, f.Z, cameraDistance, tostring(cameraFitted), camera.FieldOfView, tostring(camera.FieldOfViewMode)))
    local look, up = camera.CFrame.LookVector, camera.CFrame.UpVector
    local delta = f - p
    local aimDot = delta.Magnitude > 0 and look:Dot(delta) / delta.Magnitude or 0
    print(string.format("[Riftbound camera] actual look=(%.4f,%.4f,%.4f) up=(%.4f,%.4f,%.4f) aimDot=%.6f focusError=%.3f preApplyPositionDrift=%.3f preApplyAimDrift=%.6f filteredRay=%s",
        look.X, look.Y, look.Z, up.X, up.Y, up.Z, aimDot, (f - cameraFocus).Magnitude, cameraPositionDrift, cameraAimDrift, visibleRay))
    local inside = {}
    if realm then
        for _, object in ipairs(realm:GetDescendants()) do
            if object:IsA("BasePart") and object.Size.Magnitude >= 20 and (object.Transparency or 0) < 0.95
                and (object.LocalTransparencyModifier or 0) < 0.95 and containsPartBounds(object, p) then
                if #inside < 5 then inside[#inside + 1] = object.Name end
            end
        end
    end
    local ward = realm and realm:FindFirstChild("Starlight ward")
    local wardInfo = "ward=absent"
    if ward and ward:IsA("BasePart") then
        wardInfo = string.format("ward transparency=%.2f localModifier=%.2f cameraInside=%s focusInside=%s",
            ward.Transparency, ward.LocalTransparencyModifier or 0, tostring(containsPartBounds(ward, p)), tostring(containsPartBounds(ward, f)))
    end
    print("[Riftbound camera] " .. wardInfo .. " riftLocalMask=" .. tostring(hiddenRift ~= nil) .. " largeGeometryAtLens=" .. (#inside > 0 and table.concat(inside, ", ") or "none"))
    -- Projection is not visibility. Probe every key sightline, not just the
    -- start/Focus ray, and identify accessory Handles by their full hierarchy.
    for _, object in ipairs(anchorObjects) do
        local point, onScreen = camera:WorldToViewportPoint(object.Position)
        local probeOk, probe = pcall(function()
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = streamRayExclusions()
            return workspace:Raycast(p, object.Position - p, params)
        end)
        local obstacle = probeOk and "clear" or "unavailable"
        if probeOk and probe then
            local pathOk, path = pcall(function() return probe.Instance:GetFullName() end)
            obstacle = (pathOk and path or probe.Instance.Name) .. " at " .. string.format("%.1f", (probe.Position - p).Magnitude)
        end
        print(string.format("[Riftbound camera] anchor=%s world=(%.1f,%.1f,%.1f) screen=(%.1f,%.1f) projected=%s sightline=%s",
            object.Name, object.Position.X, object.Position.Y, object.Position.Z, point.X, point.Y, tostring(onScreen), obstacle))
        print(string.format("[Riftbound render] anchor=%s Transparency=%.3f LocalTransparencyModifier=%.3f effectiveOpacity=%.3f",
            object.Name, object.Transparency or 0, object.LocalTransparencyModifier or 0,
            (1 - (object.Transparency or 0)) * (1 - (object.LocalTransparencyModifier or 0))))
    end
    print(string.format("[Riftbound camera] bounds=(%.1f..%.1f,%.1f..%.1f,%.1f..%.1f) yaw=%d %s; streaming=%s realm=%s policy=%s parts=%d opaque=%d anchors=%d/6 projected=%d geometry=%s ray=%s requests=%d/3",
        box.minX, box.maxX, box.minY, box.maxY, box.minZ, box.maxZ, box.yaw, boundsReason,
        tostring(workspace.StreamingEnabled), tostring(realm ~= nil), realm and tostring(realm.ModelStreamingMode) or "absent",
        parts, opaque, anchors, projected, missingGeometry and "MISSING/PARTIAL" or "present", hitText, streamRequests))
    local received = latestState and latestState.cameraBounds
    if type(received) == "table" then
        print(string.format("[Riftbound camera] received bounds=(%s..%s,%s..%s,%s..%s) yaw=%s",
            tostring(received.minX), tostring(received.maxX), tostring(received.minY), tostring(received.maxY),
            tostring(received.minZ), tostring(received.maxZ), tostring(received.yaw)))
    end
end
local function bindCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    local camera = workspace.CurrentCamera
    if camera then
        if camera.CameraType ~= Enum.CameraType.Scriptable then
            cameraDefaultFov, cameraDefaultFovMode = camera.FieldOfView, camera.FieldOfViewMode
        end
        cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
    end
    resize()
    setCamera(streamCamera)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()
local labelAccumulator = 0
RunService:BindToRenderStep("RiftboundPortraitCamera", Enum.RenderPriority.Last.Value, function(dt)
    if latestState then timer.Text = tostring(math.max(0, math.ceil(latestState.seconds - (os.clock() - receivedAt)))) end
    updateStreamScenery()
    updateStreamLighting()
    updateStreamEffects(os.clock())
    if streamCamera and gui.Enabled and workspace.CurrentCamera and cameraTarget then
        local camera = workspace.CurrentCamera
        if camera.ViewportSize.X ~= cameraWidth or camera.ViewportSize.Y ~= cameraHeight then resize() end
        cameraPositionDrift = (camera.CFrame.Position - cameraTarget.Position).Magnitude
        cameraAimDrift = 1 - camera.CFrame.LookVector:Dot(cameraTarget.LookVector)
        maximumPositionDrift, maximumAimDrift = math.max(maximumPositionDrift, cameraPositionDrift), math.max(maximumAimDrift, cameraAimDrift)
        updateDirector(os.clock(), dt)
        local entry = latestState and latestState.entrance
        local entryActive = entry and latestState.now + os.clock() - receivedAt < entry.endsAt and directorShot == "Star Gate entrance"
        if entryActive then
            entranceAnnouncementActive = true
            noticeText.Text, noticeText.TextSize, notice.Visible = entry.names[1] .. (#entry.names > 1 and (" +" .. (#entry.names - 1) .. " ARRIVALS") or " / WELCOME"), 22, true
        elseif entranceAnnouncementActive then
            entranceAnnouncementActive, notice.Visible, noticeText.TextSize = false, false, 14
        end
        updateLensMasks(os.clock())
        applyCamera(camera)
        cameraDiagnostics(os.clock())
    end
    if not streamCamera or not gui.Enabled then updateLensMasks(os.clock()) end
    updateRenderCheck()
    labelAccumulator = labelAccumulator + dt
    if labelAccumulator >= 0.12 then labelAccumulator = 0; updateLabels(os.clock()) end
end)
```
