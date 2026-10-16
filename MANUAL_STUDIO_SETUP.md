# Riftbound Live v11 — fresh registration and cinematic tournament

The shared v10 track is unchanged. This update changes race entry, presentation
and actor lifecycle around it. **Replace all five complete raw sources together.**

## Exact Studio replacement

Stop Play, save a backup, then use GitHub **Raw** to replace each entire source:

| Complete file | Studio parent → instance name | Type |
| --- | --- | --- |
| [Config.lua](roblox/ServerScriptService/Config.lua) | ServerScriptService → Config | ModuleScript |
| [RealmState.lua](roblox/ServerScriptService/RealmState.lua) | ServerScriptService → RealmState | ModuleScript |
| [World.lua](roblox/ServerScriptService/World.lua) | ServerScriptService → World | ModuleScript |
| [Realm.server.lua](roblox/ServerScriptService/Realm.server.lua) | ServerScriptService → Realm | Script, Enabled, RunContext Legacy |
| [Realm.client.lua](roblox/StarterPlayerScripts/Realm.client.lua) | StarterPlayer → StarterPlayerScripts → Realm | LocalScript, Enabled |

Keep your HostUserIds and intentional economy values. Keep AutoActivities=true,
SprintOnly=true and AutoJoinPlayers=false for this tournament. Keep one instance of each
script. Edit StarterPlayerScripts, not a runtime Players/PlayerScripts copy. Keep
**Workspace.StreamingEnabled=false**, save and start a fresh **Play**. HTTP Requests
and Studio API Services access remain unnecessary. MANUAL_STUDIO_SETUP.md contains
the same five complete source blocks. No new game module or installer is required.

Expect server `[Riftbound] Ready` and client `presentation=race-show-v11`.
The course revision deliberately remains `show-v10-shared-road`: its road builder,
shared checkpoints, branching geometry and obstacle motion have not changed.
GitHub updates do not automatically modify an open Studio place.


The sections below contain the complete current raw Luau sources.

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
    AutoActivities = true, -- Required for the automatic tournament.
    AutoJoinPlayers = false, -- host is a spectator; JOIN tools still enqueue any username.
    SprintOnly = true, -- Tournament mode keeps the existing physical Skybridge course.
    SprintCompetitors = 20,
    RegistrationSeconds = 30, -- begins only after at least two valid registrations.
    MinimumRacers = 2,
    StartCountdownSeconds = 4, -- READY, 3, 2, 1; GO starts physical racing.
    MaxSessionMembers = 500, -- ledger history; only the current roster has avatars.
    SprintRaceSeconds = 120,
    SprintWalkSpeed = 12.5, -- Shared skyway: physical travel, not a finish timer.
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
    MaxCrew = 40,
    MaxQueuedArrivals = 30,
    OfflineDemoEnabled = false,
    DemoStudioOnly = true, -- Never imply the seeded crew are real LIVE viewers.
    DemoNames = { "Demo_Astra", "Demo_Lumen", "Demo_Nova", "Demo_Fern", "Demo_Orion", "Demo_Lyra", "Demo_Atlas", "Demo_Iris", "Demo_Rune", "Demo_Vega", "Demo_Echo", "Demo_Sage", "Demo_Kai", "Demo_Ember", "Demo_Jade", "Demo_Sol", "Demo_Cora", "Demo_Zen", "Demo_Milo", "Demo_Skye" },
    DemoPowerups = true, -- cosmetic showcases only while explicit demo testing is ON.
    AutoSimulateGifts = false,
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
    { id = "sprint", name = "SKYBRIDGE SPRINT", instruction = "Shared skyway / 48 gates / 2 forks. Falls recover to the last verified gate.", goal = 48, teamPerMember = 10 },
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
    if config.RegistrationSeconds then
        assert(type(config.RegistrationSeconds)=="number" and config.RegistrationSeconds>0 and config.RegistrationSeconds<math.huge,"RegistrationSeconds must be finite and positive")
        local minimum,capacity=config.MinimumRacers or 2,config.SprintCompetitors or 20
        assert(type(minimum)=="number" and minimum>=2 and minimum==math.floor(minimum),"MinimumRacers must be a whole number of at least 2")
        assert(type(capacity)=="number" and capacity>=minimum and capacity<=20 and capacity==math.floor(capacity),"SprintCompetitors must fit MinimumRacers through 20")
    end
    local state = setmetatable({
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
    -- Server configuration always supplies RegistrationSeconds. Older pure-domain
    -- callers without it retain their legacy activity/economy contract.
    if config.RegistrationSeconds then
        state.registrationEnabled = true
        state.phase, state.round, state.deadline = "registration", 1, 0
        state.registrationOpenedAt = now
        state.roster, state.registrations, state.registrationEvents, state.lockedRoster = {}, {}, {}, {}
        state.powerupEvents, state.highlightQueue, state.raceHistory = {}, {}, {}
        state.powerupSequence = 0
        state.message = "WAITING FOR CHALLENGERS / COMMENT YOUR ROBLOX USERNAME TO JOIN!"
    end
    return state
end

function Realm:addCrew(username, userId)
    local key = string.lower(username)
    if self.crew[key] then return false, "That traveler is already on the island." end
    if #self.crewOrder >= (self.registrationEnabled and (self.config.MaxSessionMembers or 500) or self.config.MaxCrew) then return false, "The island is full for this session." end
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

local function finite(value) return type(value)=="number" and value==value and math.abs(value)<math.huge end
local function eventKey(value)
    return type(value)=="string" and #value>0 and #value<=96 and string.match(value,"^[%w_:%-%.]+$")~=nil
end
function Realm:registrationCheck(username, roundId, submittedAt, now, eventId)
    if not self.registrationEnabled then return false,"Round registration is unavailable." end
    if self.phase~="registration" or roundId~=self.round then return false,"Registration is closed or this round ID has expired. Submit again in the next open window." end
    if not finite(now) or not finite(submittedAt) or submittedAt<self.registrationOpenedAt or submittedAt>now
        or (self.deadline>0 and (submittedAt>=self.deadline or now>=self.deadline)) then
        return false,"That entry arrived outside this registration window."
    end
    if not eventKey(eventId) or self.registrationEvents[eventId] then return false,"A unique event ID is required; replayed entry rejected." end
    if type(username)~="string" or #username<3 or #username>20 or not string.match(username,"^[%w_]+$") then return false,"Enter a Roblox username." end
    if self.registrations[string.lower(username)] then return false,"Already registered for this round." end
    if #self.roster >= (self.config.SprintCompetitors or 20) then return false,"All competitor slots are filled for this round." end
    return true
end
function Realm:register(username, userId, roundId, submittedAt, now, eventId)
    local ok,issue=self:registrationCheck(username,roundId,submittedAt,now,eventId)
    if not ok then return false,issue end
    local key=string.lower(username)
    local member=self.crew[key]
    if not member then
        local added; added,member=self:addCrew(username,userId)
        if not added then return false,member end
    elseif userId and userId>0 then member.userId=userId end
    self.registrationEvents[eventId]=true
    self.registrations[key]=true;self.roster[#self.roster+1]=key
    member.registeredRound,member.registrationSlot=self.round,#self.roster
    member.activityEntered,member.score,member.distance,member.finishedAt=false,0,0,0
    member.raceStatus,member.placement,member.recoveries="registered",0,0
    member.route,member.effect,member.effectUntil="shared","",0
    member.powerup,member.powerupUntil,member.powerupReadyAt="",0,0
    member.lastRecoveryGate,member.lastRecoveryReason=nil,nil
    self:queueEntrance(member.username)
    if #self.roster>=(self.config.MinimumRacers or 2) and self.deadline==0 then self.deadline=now+self.config.RegistrationSeconds end
    self.message=member.username.." registered for round "..self.round.."."
    return true,member
end
function Realm:unregister(username, roundId, now, eventId)
    if self.phase~="registration" or roundId~=self.round or not finite(now) or (self.deadline>0 and now>=self.deadline)
        or not eventKey(eventId) or self.registrationEvents[eventId] then return false,"Withdrawal is closed or stale." end
    local key=type(username)=="string" and string.lower(username)
    if not key or not self.registrations[key] then return false,"That username is not registered." end
    self.registrationEvents[eventId]=true;self.registrations[key]=nil
    self.crew[key].registeredRound=nil;self.crew[key].entranceDone=true
    for i=#self.roster,1,-1 do if self.roster[i]==key then table.remove(self.roster,i) end end
    for i,name in ipairs(self.roster) do self.crew[name].registrationSlot=i end
    for i=#self.entranceQueue,1,-1 do if string.lower(self.entranceQueue[i])==key then table.remove(self.entranceQueue,i) end end
    if self.entrance then
        for i=#self.entrance.names,1,-1 do if string.lower(self.entrance.names[i])==key then table.remove(self.entrance.names,i) end end
        if #self.entrance.names==0 then self.entrance=nil end
    end
    if #self.roster<(self.config.MinimumRacers or 2) then self.deadline=0 end
    self.message="Registration updated / everyone must submit again each round."
    return true,self.message
end
function Realm:activatePowerup(username, kind, now, roundId, eventId)
    local member=type(username)=="string" and self.crew[string.lower(username)]
    if self.phase~="storm" or self.round~=roundId or not member or not member.activityEntered or member.raceStatus~="racing"
        or not finite(now) or now>=self.deadline then return false,"Power-up visuals require an active competitor in this race." end
    if kind~="trail" and kind~="shield" and kind~="starburst" then return false,"Choose trail, shield or starburst." end
    if not eventKey(eventId) or self.powerupEvents[eventId] then return false,"Replayed power-up rejected." end
    if now<(member.powerupReadyAt or 0) then return false,"Each competitor has the same 12-second visual cooldown." end
    -- Explicit fair rules: every power-up is cosmetic. No speed, collision,
    -- jump, checkpoints, damage immunity, rewards or score are changed.
    self.powerupEvents[eventId]=true;self.powerupSequence=self.powerupSequence+1
    member.powerup,member.powerupUntil,member.powerupReadyAt=kind,now+4,now+12
    member.powerupSequence=self.powerupSequence
    for i=#self.highlightQueue,1,-1 do if self.highlightQueue[i].username==member.username then table.remove(self.highlightQueue,i) end end
    if #self.highlightQueue>=12 then table.remove(self.highlightQueue,1) end
    self.highlightQueue[#self.highlightQueue+1]={username=member.username,kind=kind,sequence=self.powerupSequence,roundId=self.round,expiresAt=now+5}
    return true,member.username.." / "..string.upper(kind).." VISUAL (cosmetic)"
end
function Realm:advanceHighlights(now)
    if not self.registrationEnabled then return end
    if self.phase~="storm" then self.highlightQueue,self.highlight={},nil;return end
    local critical=false
    for _,row in ipairs(self:activityLeaderboard()) do if row.status=="racing" and row.distance>=45 then critical=true;break end end
    local subject=self.highlight and self.crew[string.lower(self.highlight.username)]
    if self.highlight and (now>=self.highlight.endsAt or critical or not subject or subject.raceStatus~="racing") then self.highlight=nil end
    if self.highlight or critical then return end
    while #self.highlightQueue>0 do
        local item=table.remove(self.highlightQueue,1)
        local member=self.crew[string.lower(item.username)]
        if item.roundId==self.round and now<item.expiresAt and member and member.raceStatus=="racing" then
            item.startedAt,item.endsAt=now,now+1.5;self.highlight=item;break
        end
    end
end

-- A bounded presentation queue. It never changes the race clock or standings.
function Realm:queueEntrance(username)
    local member = self.crew[string.lower(username)]
    if not member or not member.entranceDone then return false end
    if self.registrationEnabled and (self.phase~="registration" or member.registeredRound~=self.round) then return false end
    if #self.entranceQueue >= (self.config.MaxQueuedArrivals or 30) then return false end
    member.entranceDone = false
    table.insert(self.entranceQueue, member.username)
    return true
end

function Realm:advanceEntrances(now)
    self:advanceHighlights(now)
    if self.registrationEnabled and self.phase~="registration" then self.entranceQueue,self.entrance={},nil;return end
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
    if self.registrationEnabled then
        local cohort={}
        local names=self.phase=="registration" and self.roster or (self.phase=="countdown" or self.phase=="storm") and self.lockedRoster or {}
        for _,key in ipairs(names) do if self.crew[key] then cohort[#cohort+1]=self.crew[key] end end
        return cohort
    end
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
    if self.registrationEnabled and (member.registeredRound~=self.round or self.phase~="countdown" and self.phase~="storm") then return 0 end
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

function Realm:enterActivity(member, now, grid)
    if self.registrationEnabled and not self.registrations[string.lower(member.username)] then return false end
    member.activityEntered, member.enteredAt, member.lastRacedRound = true, now, self.round
    member.gridSlot = grid
    member.pace = self.activity.id == "sprint" and 0 or pace(member.username, self.round, self.activity.id)
    member.raceStatus = self.activity.id == "sprint" and "racing" or "waiting"
    member.checkpointAt = now
    self.activityEntrants = self.activityEntrants + 1
    self.teamTarget = self.activityEntrants * self.activity.teamPerMember
end

function Realm:tick(now)
    if now <= self.lastTick then return end
    -- Split at the phase boundary so a delayed heartbeat never pays for result time.
    local earningEnd = self.deadline>0 and math.min(now, self.deadline) or self.lastTick
    local elapsed = math.max(0, earningEnd - self.lastTick)
    if self.phase == "voting" or self.phase == "storm" or self.phase=="countdown" then
        for _, key in ipairs(self.crewOrder) do
            local member = self.crew[key]
            if not self.registrationEnabled or member.registeredRound==self.round then self:credit(member, self:rate(member) * elapsed) end
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
function Realm:recordCheckpoint(username, checkpoint, at, round, route)
    local member = type(username) == "string" and self.crew[string.lower(username)]
    if self.phase ~= "storm" or self.activity.id ~= "sprint" or round ~= self.round or not member
        or member.raceStatus ~= "racing" or not member.activityEntered then return false end
    if type(at) ~= "number" or at ~= at or at < member.checkpointAt or at > self.deadline
        or type(checkpoint) ~= "number" or checkpoint ~= member.score + 1 or checkpoint > self.activity.goal then return false end
    if route and route ~= "shared" and route ~= "main" and route ~= "shortcut" then return false end
    if route and route ~= "shared" and not ((checkpoint>=11 and checkpoint<=18) or (checkpoint>=29 and checkpoint<=36)) then return false end
    if route == "shared" and ((checkpoint>12 and checkpoint<18) or (checkpoint>30 and checkpoint<36)) then return false end
    member.lastGateRoute = route or "shared"
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

function Realm:advanceLegacy(now)
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
            self.crew[key].lastRecoveryGate, self.crew[key].lastRecoveryReason, self.crew[key].route = nil, nil, "shared"
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

local function clearPresentation(self)
    self.entranceQueue,self.entrance,self.highlightQueue,self.highlight={},nil,{},nil
    for _,member in pairs(self.crew) do member.entranceDone=true;member.powerup="";member.powerupUntil=0 end
end
function Realm:advance(now)
    if not self.registrationEnabled then return self:advanceLegacy(now) end
    if self.phase=="registration" then
        if #self.roster<(self.config.MinimumRacers or 2) then self.deadline=0;return false end
        if self.deadline==0 or now<self.deadline then return false end
        self:tick(now)
        self.lockedRoster={};for _,key in ipairs(self.roster) do self.lockedRoster[#self.lockedRoster+1]=key end
        clearPresentation(self)
        self.phase,self.deadline="countdown",now+(self.config.StartCountdownSeconds or 4)
        self.message="READY / ROSTER LOCKED / 3, 2, 1"
        return true
    elseif self.phase=="countdown" then
        if now<self.deadline then return false end
        self:tick(now)
        if #self.lockedRoster<(self.config.MinimumRacers or 2) then
            self.roster,self.registrations,self.lockedRoster={},{},{}
            self.round,self.phase,self.deadline,self.registrationOpenedAt=self.round+1,"registration",0,now
            self.registrationEvents={};return true
        end
        self.phase,self.activityStarted="storm",now
        self.activityEntrants,self.teamScore,self.teamTarget=0,0,0
        for i,key in ipairs(self.lockedRoster) do self:enterActivity(self.crew[key],now,i) end
        self.deadline=now+(self.config.SprintRaceSeconds or 120)
        self.message="GO! / 120 SECOND SKYBRIDGE RACE"
        return true
    elseif self.phase=="storm" then
        local changed=self:advanceLegacy(now)
        if changed then
            clearPresentation(self)
            local result={roundId=self.round,finishers={},dnfs={}}
            for _,row in ipairs(self:activityLeaderboard()) do
                local member=self.crew[string.lower(row.username)]
                member.races=(member.races or 0)+1
                if row.finishedAt>0 then
                    member.finishes=(member.finishes or 0)+1
                    member.bestTime=math.min(member.bestTime or math.huge,row.elapsed)
                    result.finishers[#result.finishers+1]={username=row.username,elapsed=row.elapsed,placement=row.placement}
                else member.dnfs=(member.dnfs or 0)+1;result.dnfs[#result.dnfs+1]=row.username end
                member.registeredRound=nil
            end
            self.raceHistory[#self.raceHistory+1]=result
            if #self.raceHistory>50 then table.remove(self.raceHistory,1) end
            self.roster,self.registrations,self.lockedRoster={},{},{}
        end
        return changed
    elseif self.phase=="result" and now>=self.deadline then
        self:tick(now)
        clearPresentation(self)
        self.round,self.phase,self.deadline,self.registrationOpenedAt=self.round+1,"registration",0,now
        self.roster,self.registrations,self.lockedRoster,self.registrationEvents,self.powerupEvents={},{},{},{},{}
        self.winners,self.votes,self.totals={}, {}, {ward=0,sail=0}
        self.activityEntrants,self.teamScore,self.teamTarget=0,0,0
        self.success,self.choice=false,"ward"
        for _,member in pairs(self.crew) do
            member.registeredRound,member.activityEntered,member.roundMoney=nil,false,0
            member.score,member.distance,member.finishedAt,member.placement=0,0,0,0
            member.raceStatus,member.recoveries="waiting",0
        end
        self.message="WAITING FOR CHALLENGERS / COMMENT YOUR ROBLOX USERNAME TO JOIN! / REGISTER AGAIN"
        return true
    end
    return false
end

function Realm:snapshot(now)
    local crew = {}
    local members = {}
    for _, key in ipairs(self.crewOrder) do
        local member = self.crew[key]
        table.insert(crew, member.username)
        table.insert(members, {
            registered = member.registeredRound==self.round, registrationSlot = member.registrationSlot,
            races = member.races or 0, finishes = member.finishes or 0, dnfs = member.dnfs or 0, bestTime = member.bestTime or 0,
            powerup = now<(member.powerupUntil or 0) and member.powerup or "", powerupUntil = member.powerupUntil or 0,
            powerupSequence = member.powerupSequence or 0,
            username = member.username, balance = member.balance, roundMoney = member.roundMoney,
            perSecond = self:rate(member), gifts = member.gifts,
            effect = now < member.effectUntil and member.effect or "",
            slot = member.slot, score = member.score, distance = member.distance, pace = member.pace,
            roundWins = member.roundWins, activityEntered = member.activityEntered,
            finished = member.finishedAt > 0, finishedAt = member.finishedAt,
            elapsed = member.finishedAt > 0 and member.finishedAt - member.enteredAt or 0,
            raceStatus = member.raceStatus, placement = member.placement,
            entranceDone = member.entranceDone, recoveries = member.recoveries, route = member.route or "shared",
            lastRecoveryGate = member.lastRecoveryGate, lastRecoveryReason = member.lastRecoveryReason,
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
    local registration
    if self.registrationEnabled then
        registration={roundId=self.round,open=self.phase=="registration" and (self.deadline==0 or now<self.deadline),
            locked=self.phase~="registration",count=#self.roster,capacity=self.config.SprintCompetitors or 20,
            minimum=self.config.MinimumRacers or 2,endsAt=self.phase=="registration" and self.deadline or 0,
            openedAt=self.registrationOpenedAt,roster={}}
        for _,key in ipairs(self.roster) do registration.roster[#registration.roster+1]=self.crew[key].username end
    end
    local lastRace
    local history=self.raceHistory and self.raceHistory[#self.raceHistory]
    if history then
        lastRace={roundId=history.roundId,finishers={},dnfs={}}
        for _,row in ipairs(history.finishers) do lastRace.finishers[#lastRace.finishers+1]={username=row.username,elapsed=row.elapsed,placement=row.placement} end
        for _,name in ipairs(history.dnfs) do lastRace.dnfs[#lastRace.dnfs+1]=name end
    end
    local highlight
    if self.highlight then
        highlight={username=self.highlight.username,kind=self.highlight.kind,sequence=self.highlight.sequence,
            roundId=self.highlight.roundId,startedAt=self.highlight.startedAt,endsAt=self.highlight.endsAt}
    end
    return {
        registration=registration, highlight=highlight, highlightWaiting=self.highlightQueue and #self.highlightQueue or 0,
        lastRace=lastRace,
        entrance = entrance, entranceWaiting = #self.entranceQueue, nextCohort = nextCohort,
        phase = self.phase, seconds = math.max(0, math.ceil(self.deadline - now)),
        round = self.round, crew = crew, wins = self.wins, storms = self.storms,
        ward = self.totals.ward, sail = self.totals.sail, requiredVotes = self.requiredVotes,
        choice = self.choice, success = self.success, message = self.message,
        blessing = now < self.blessingUntil and self.blessing or "",
        members = members, leaderboard = self:leaderboard(false), roundLeaders = self:leaderboard(true),
        lastRound = lastRound, followers = self.followerCount,
        earning = self.phase == "voting" or self.phase == "storm" or self.phase=="countdown",
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
local PhysicsService = game:GetService("PhysicsService")
local World = {}
local root, core, gate, rift, shield, constellation, bloom, winds, scoreText
local monuments = {}
local avatars = {}
local scenery = { clouds = {}, runes = {}, ribbons = {}, particles = {}, stars = {}, shrines = {}, sprintObstacles = {}, sprintHurdles = {}, waterfalls = {} }
local tournament = { braziers = {}, portal = {}, fireworks = {} }
local fantasyFolder
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

-- A single road, with two genuine fork/rejoin junctions. Z is monotonic:
-- adjacent cells share their boundary vertices, never cross another track.
local sectionNames = { "STARTING DASH", "MOVING BRIDGES", "HAZARD ZONE", "FINAL SPRINT" }
local TRAIL_AMPLITUDE, TRAIL_STRIDE = 64, 24
local ROAD_HALF_WIDTH = 32
local forks = { { first = 12, last = 18, safeSide = -1 }, { first = 30, last = 36, safeSide = 1 } }
local function forkAt(cp)
    for _, fork in ipairs(forks) do if cp >= fork.first and cp <= fork.last then return fork end end
end
local function roadSection(cp, route)
    local center, half = math.sin(cp * math.pi / 12) * TRAIL_AMPLITUDE, ROAD_HALF_WIDTH
    local fork = forkAt(cp)
    if fork and route and route ~= "shared" then
        local t = (cp - fork.first) / (fork.last - fork.first)
        local wave = (t == 0 or t == 1) and 0 or math.sin(math.pi * t)
        local side = route == "main" and fork.safeSide or -fork.safeSide
        center = center + side * (16 + 16 * wave)
        half = route == "shortcut" and (16 - 5 * wave) or 16
    end
    return center, half
end
-- Surface height (roots are +3): gentle climbs and real, shallow banking.
local function roadPoint(cp, route, lateral)
    local center = roadSection(cp, route)
    local x = center + (lateral or 0)
    local base = math.sin(cp * math.pi / 12) * TRAIL_AMPLITUDE
    return Vector3.new(x, 68 + cp * .25 + math.sin(cp * math.pi / 12) * .06 * (x - base), 60 - cp * TRAIL_STRIDE)
end
function World.sprintPoint(grid, checkpoint)
    if checkpoint <= 0 then
        local index = math.max(0, math.min(19, grid - 1))
        return Vector3.new((index % 5 - 2) * 8, 68, 60 + math.floor(index / 5) * 6)
    end
    return roadPoint(math.min(48, checkpoint), "shared", 0)
end
function World.routePoint(checkpoint, route, lateral) return roadPoint(checkpoint, route, lateral) end
function World.roadSection(checkpoint, route) return roadSection(checkpoint, route) end
function World.cameraBounds(state)
    if state.physicalSprint then
        return { minX = -170, maxX = 170, minY = 54, maxY = 110, minZ = -1140, maxZ = 102, yaw = 60 }
    end
end
function World.courseInfo()
    local length, headings = 0, {}
    for cp = 1, 48 do
        local delta = roadPoint(cp, "shared") - roadPoint(cp - 1, "shared")
        length = length + Vector3.new(delta.X, 0, delta.Z).Magnitude
        headings[cp] = math.deg(math.atan(delta.X / delta.Z))
    end
    return { revision = "show-v10-shared-road", checkpoints = 48, length = length, stride = 24, roadWidth = 64,
        maxRacers = 20, forks = forks, sections = sectionNames, headings = headings,
        finishZ = -1092, gate = { x = -64, y = 80, z = 66 } }
end
local function routeDirection(cp)
    local a, b = roadPoint(math.max(0, cp - 1), "shared"), roadPoint(math.min(48, cp + 1), "shared")
    local delta = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
    return delta * (1 / delta.Magnitude)
end
local function routeFrame(point, cp) return CFrame.lookAt(point, point + routeDirection(cp)) end

local function decoration(name, size, frame, color, material, transparency)
    local object = part(name, size, frame, color, material, fantasyFolder)
    object.CanCollide, object.CanTouch, object.CastShadow = false, false, size.Magnitude > 6
    object.Transparency = transparency or 0
    object:SetAttribute("RiftboundScenery", true)
    return object
end

local function fantasyCrystal(position, scale, color)
    local stone = decoration("Aether crystal", Vector3.new(1.7,5,1.7)*scale,
        CFrame.new(position)*CFrame.Angles(0,math.pi/4,0.12),color,Enum.Material.Neon)
    -- Small emissive details carry the magic; broad surfaces remain natural.
    decoration("Crystal stone socket",Vector3.new(3,0.5,3)*scale,CFrame.new(position-Vector3.new(0,2.4*scale,0)),colors.stone,Enum.Material.Rock)
    return stone
end

local function buildFantasyIsland(point, side, section)
    local center = point + Vector3.new(side*108,-12,0)
    local radius = 20 + section*1.5
    local stone = decoration("Sky island stone",Vector3.new(9,radius*2,radius*2),
        CFrame.new(center-Vector3.new(0,4.6,0))*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(88,103,113),Enum.Material.Rock)
    stone.Shape=Enum.PartType.Cylinder
    local grass = decoration("Sky island meadow",Vector3.new(1,radius*2-1,radius*2-1),
        CFrame.new(center)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(93,151,91),Enum.Material.Grass)
    grass.Shape=Enum.PartType.Cylinder
    for i=1,4 do
        local a=i*math.pi/2+section*.3
        decoration("Hanging island stone",Vector3.new(9,13,9),
            CFrame.new(center+Vector3.new(math.cos(a)*radius*.5,-11,math.sin(a)*radius*.5))*CFrame.Angles(.15,a,.2),colors.rock,Enum.Material.Slate)
    end
    for i=1,3 do
        local base=center+Vector3.new((i-2)*8,1,-8+(i%2)*4)
        decoration("Elderwood trunk",Vector3.new(1.4,8,1.4),CFrame.new(base+Vector3.new(0,4,0)),Color3.fromRGB(102,77,60),Enum.Material.Wood)
        local leaves=decoration("Elderwood canopy",Vector3.new(8,7,8),CFrame.new(base+Vector3.new(0,9,0)),
            section%2==0 and Color3.fromRGB(113,151,141) or Color3.fromRGB(85,132,89),Enum.Material.Grass)
        leaves.Shape=Enum.PartType.Ball
    end
    local accent=({colors.mint,Color3.fromRGB(125,191,243),Color3.fromRGB(239,184,126),colors.violet})[section]
    for i=1,3 do fantasyCrystal(center+Vector3.new((i-2)*4,3,7),.65+i*.1,accent) end
    -- An open portal frame has no giant translucent shell around the camera.
    for _,x in ipairs({-5,5}) do
        decoration("Island portal pillar",Vector3.new(1.3,12,1.3),CFrame.new(center+Vector3.new(x,6,0)),Color3.fromRGB(165,163,145),Enum.Material.Marble)
    end
    decoration("Island portal lintel",Vector3.new(11,1.5,2),CFrame.new(center+Vector3.new(0,12,0)),accent,Enum.Material.Neon)
    local portal=decoration("Island portal veil",Vector3.new(8,10,.2),CFrame.new(center+Vector3.new(0,6,0)),accent,Enum.Material.Glass,.72)
    portal.CastShadow=false
    -- Water is bounded translucent geometry: no asset downloads, terrain floods
    -- or collision surfaces over the racing route.
    local water=center+Vector3.new(side*(radius-3),-14,4)
    decoration("Waterfall curtain",Vector3.new(4,28,.7),CFrame.new(water),Color3.fromRGB(132,219,231),Enum.Material.Glass,.4)
    for i=1,3 do
        local band=decoration("Waterfall flow",Vector3.new(4.3,.7,.9),CFrame.new(water),Color3.fromRGB(218,249,247),Enum.Material.SmoothPlastic,.35)
        scenery.waterfalls[#scenery.waterfalls+1]={part=band,center=water,phase=i*9}
    end
    local foam=decoration("Waterfall mist",Vector3.new(9,3,7),CFrame.new(water-Vector3.new(0,14,0)),Color3.fromRGB(223,241,244),Enum.Material.SmoothPlastic,.68)
    foam.Shape=Enum.PartType.Ball
    for i=1,3 do
        local cloud=decoration("Trail cloud",Vector3.new(15,7,11),CFrame.new(center+Vector3.new((i-2)*9,-24,18)),Color3.fromRGB(219,234,239),Enum.Material.SmoothPlastic,.48)
        cloud.Shape=Enum.PartType.Ball
    end
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
    if not main:FindFirstChild("PowerTrail") then
        local a,b=Instance.new("Attachment"),Instance.new("Attachment")
        a.Name,b.Name="TrailLeft","TrailRight"
        a.Position,b.Position,a.Parent,b.Parent=Vector3.new(-.85,-2,.7),Vector3.new(.85,-2,.7),main,main
        local trail=Instance.new("Trail")
        trail.Name,trail.Attachment0,trail.Attachment1="PowerTrail",a,b
        trail.Lifetime,trail.MinLength,trail.FaceCamera,trail.Enabled=.45,.1,true,false
        trail.Color,trail.Transparency=ColorSequence.new(colors.mint),NumberSequence.new(.15,1)
        trail.Parent=main
        local bubble=ball("PowerShield",main.Position,6,Color3.fromRGB(116,189,255),1,model)
        bubble.Size,bubble.Massless,bubble.CanCollide,bubble.CanTouch,bubble.CanQuery=Vector3.new(6,7,6),true,false,false,false
        bubble.Anchored=true
        local weld=Instance.new("WeldConstraint");weld.Part0,weld.Part1,weld.Parent=main,bubble,bubble
        local sparks=Instance.new("Sparkles");sparks.Name,sparks.Enabled,sparks.SparkleColor,sparks.Parent="PowerSparks",false,colors.violet,main
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
            object.CollisionGroup = "RiftboundRacers"
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

-- Triangulated road quads use native WedgeParts, requiring no mesh assets.
-- Each triangle is two right triangles with a one-stud extrusion BELOW the
-- authored surface. Exact shared vertices remove the old rectangular overlaps.
local function triangle(a, b, c, parent, cp, route, color, material)
    local ab, ac, bc = b-a, c-a, c-b
    if ab:Dot(ab) > ac:Dot(ac) and ab:Dot(ab) > bc:Dot(bc) then c,a=a,c
    elseif ac:Dot(ac) > ab:Dot(ab) and ac:Dot(ac) > bc:Dot(bc) then a,b=b,a end
    ab, ac, bc = b-a, c-a, c-b
    local right = ac:Cross(ab); right = right * (1 / right.Magnitude)
    local back = bc * (1 / bc.Magnitude)
    local up = back:Cross(right)
    local height = math.abs(ab:Dot(up))
    local d = b + back * ab:Dot(back) * -1
    for i, tip in ipairs({ b, c }) do
        local length = math.abs((tip-a):Dot(back))
        if length > .001 and height > .001 then
            local sign = i == 1 and 1 or -1
            local normal = right.Y > 0 and right or -right
            local wedge = Instance.new("WedgePart")
            wedge.Name, wedge.Size = "Road "..cp.." "..route.." triangle", Vector3.new(1, height, length)
            wedge.CFrame = CFrame.fromMatrix((a+tip)*.5-normal*.5, right*sign, up, back*sign)
            wedge.Anchored, wedge.CanCollide = true, true
            wedge.TopSurface, wedge.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
            wedge.Color, wedge.Material, wedge.Parent = color, material, parent
            wedge:SetAttribute("Checkpoint", cp); wedge:SetAttribute("Route", route)
            -- Exact collision-face vertices support independent offline geometry checks.
            wedge:SetAttribute("SurfaceA", a); wedge:SetAttribute("SurfaceB", tip); wedge:SetAttribute("SurfaceC", d)
        end
    end
end
local function roadQuad(a, b, c, d, course, cp, route, color, material)
    triangle(a,b,c,course,cp,route,color,material)
    triangle(a,c,d,course,cp,route,color,material)
end
local function surface(cp, route, offset) return roadPoint(cp,route,offset)-Vector3.new(0,3,0) end
local function buildSprint()
    local course = Instance.new("Model")
    course.Name, course.Parent = "SkybridgeSprint", root
    course:SetAttribute("CourseRevision", "show-v10-shared-road")
    course:SetAttribute("SharedCheckpoints",48)
    local start=part("START platform",Vector3.new(96,2,42),CFrame.new(0,64,81),Color3.fromRGB(117,132,103),Enum.Material.Grass,course)
    label(start,"SHARED SKYWAY / 120 SECOND RACE",Vector3.new(0,9,0),colors.gold,350)
    for row=0,3 do for col=0,4 do
        local mark=part("Grid "..(row*5+col+1),Vector3.new(5,.05,3),CFrame.new((col-2)*8,65.03,60+row*6),colors.gold,Enum.Material.Neon,course)
        mark.CanCollide=false
    end end
    for _,x in ipairs({-37,0,37}) do
        decoration("Starting island roots",Vector3.new(29,14,27),CFrame.new(x,55,81)*CFrame.Angles(.05,x*.02,.12),colors.rock,Enum.Material.Rock)
    end
    for _,x in ipairs({-44,44}) do fantasyCrystal(Vector3.new(x,69,81),1.15,colors.mint) end
    local stoneColors={Color3.fromRGB(126,137,121),Color3.fromRGB(139,108,75),Color3.fromRGB(115,121,134),Color3.fromRGB(186,179,159)}
    for cp=1,48 do
        local section=math.floor((cp-1)/12)+1
        local fork=forkAt(cp-.5)
        local routes=fork and {"main","shortcut"} or {"shared"}
        for _,route in ipairs(routes) do
            -- Only the risky shortcut has a gap. The broad main route is continuous.
            local jump=route=="shortcut" and (cp==15 or cp==33)
            local spans=jump and {{cp-1,cp-.55},{cp-.425,cp}} or {{cp-1,cp}}
            for _,span in ipairs(spans) do
                local lo,hi=span[1],span[2]
                local _,w0=roadSection(lo,route); local _,w1=roadSection(hi,route)
                roadQuad(surface(lo,route,-w0),surface(lo,route,w0),surface(hi,route,w1),surface(hi,route,-w1),
                    course,cp,route,stoneColors[section],section==2 and Enum.Material.WoodPlanks or (section==4 and Enum.Material.Marble or Enum.Material.Slate))
                -- Borders stay outside the driving surface; never block a junction.
                for _,side in ipairs({-1,1}) do
                    local a,b=surface(lo,route,side*(w0+1)),surface(hi,route,side*(w1+1))
                    local beam=part("Skyway border",Vector3.new(.6,1,(b-a).Magnitude),CFrame.lookAt((a+b)*.5,b),route=="shortcut" and colors.gold or colors.mint,Enum.Material.Neon,course)
                    beam.CanCollide,beam.CanTouch=false,false
                end
            end
            local point=roadPoint(cp,route)
            local marker=part("Checkpoint "..cp.." "..route,Vector3.new(3,.1,2),CFrame.new(point-Vector3.new(0,2.9,0)),colors.gold,Enum.Material.Neon,course)
            marker.CanCollide=false; marker:SetAttribute("Checkpoint",cp)
            -- Direction chevrons are small, non-colliding and shared by all racers.
            for _,side in ipairs({-1,1}) do
                local arrow=part("Direction chevron",Vector3.new(.35,.1,2.6),routeFrame(point-Vector3.new(side*.7,2.85,0),cp)*CFrame.Angles(0,side*.5,0),colors.gold,Enum.Material.Neon,course)
                arrow.CanCollide=false
            end
        end
        local point=roadPoint(cp,"shared")
        if cp%6==0 and cp<48 then
            local frame=routeFrame(point,cp)
            for _,side in ipairs({-1,1}) do
                decoration("Trail arch pillar",Vector3.new(1.5,13,1.5),frame*CFrame.new(side*46,3,0),Color3.fromRGB(154,158,143),Enum.Material.Marble)
                fantasyCrystal(frame:PointToWorldSpace(Vector3.new(side*50,-1,0)),.8,colors.mint)
            end
            local beam=decoration("Trail arch beam",Vector3.new(94,1,1.5),frame*CFrame.new(0,10,0),colors.mint,Enum.Material.Neon)
            label(beam,sectionNames[section].." / "..cp.." OF 48",Vector3.new(0,3,0),colors.gold,300)
            buildFantasyIsland(point,cp%12==0 and -1 or 1,section)
        end
        if cp%12==1 then
            local beacon=decoration("Section "..section.." beacon",Vector3.new(2,12,2),CFrame.new(point.X-65,point.Y+2,point.Z),colors.violet,Enum.Material.Neon)
            label(beacon,section.." / "..sectionNames[section],Vector3.new(0,9,0),colors.gold,330)
            buildFantasyIsland(point,1,section)
        end
    end
    -- Moving bridge slalom: broad fixed timber deck, moving partial-width gates.
    -- The road remains connected; NPCs can pass beside these and overtake.
    for i,cp in ipairs({20,23,26,29,38,42}) do
        local point=roadPoint(cp-.5,"shared")
        local obstacle=part("Moving wind gate "..i,Vector3.new(9,5,1.5),CFrame.new(point),colors.violet,Enum.Material.Neon,course)
        scenery.sprintObstacles[#scenery.sprintObstacles+1]={part=obstacle,origin=point,phase=i*2.1,checkpoint=cp}
    end
    for _,cp in ipairs({4,8,40,44}) do
        local point=roadPoint(cp-.5,"shared")
        local hurdle=part("Jump hurdle "..cp,Vector3.new(18,1.6,1),CFrame.new(point-Vector3.new(0,2.2,0)),colors.violet,Enum.Material.Neon,course)
        scenery.sprintHurdles[cp]=hurdle
    end
    part("FINISH island",Vector3.new(96,3,36),CFrame.new(0,75.5,-1110),colors.grass,Enum.Material.Grass,course)
    for _,x in ipairs({-46,46}) do part("Finish arch column",Vector3.new(2,21,2),CFrame.new(x,86,-1092),colors.gold,Enum.Material.Neon,course) end
    local arch=part("Finish arch",Vector3.new(94,2,3),CFrame.new(0,97,-1092),colors.mint,Enum.Material.Neon,course)
    label(arch,"THE RIFTBOUND CROWN / FINISH",Vector3.new(0,6,0),colors.gold,350)
    for rank,x in ipairs({0,-10,10}) do
        local h=({4,2.5,1.5})[rank]
        part("Sprint podium "..rank,Vector3.new(8,h,8),CFrame.new(x,77+h/2,-1115),rank==1 and colors.gold or colors.stone,Enum.Material.Marble,course)
    end
end
function World.stepCourse(now)
    for _,obstacle in ipairs(scenery.sprintObstacles) do
        obstacle.part.CFrame=CFrame.new(obstacle.origin+Vector3.new(math.sin(now*.75+obstacle.phase)*20,-.5,0))
    end
end
local function gridSlot(member, state, index)
    return (((member.gridSlot or index)-1+(state.round-1)*7)%math.max(1,state.activityEntrants))+1
end
local function resetRacer(record, member, now)
    local race=record.race
    local point=member.score==0 and World.sprintPoint(race.grid,0) or roadPoint(member.score,race.route,race.lateral)
    local target=roadPoint(math.min(48,member.score+1),race.route,race.lateral)
    record.model:PivotTo(CFrame.lookAt(point+Vector3.new(0,.15,0),Vector3.new(target.X,point.Y+.15,target.Z)))
    local main=record.model.PrimaryPart
    main.AssemblyLinearVelocity,main.AssemblyAngularVelocity=Vector3.new(),Vector3.new()
    race.position,race.sampleAt,race.lastMoved=main.Position,now,now
    race.lastJump,race.lastCommand,race.jumpGate=now-1,now-1,nil
    record.model.Humanoid.Jump=false
end
-- Interpolate the AUTHORED road edges, rather than a sine approximation between
-- vertices. The same corridor is used for steering and physical gate validation.
local function corridor(cp, route)
    local lo=math.max(0,math.min(47,math.floor(cp)))
    local t=math.max(0,math.min(1,cp-lo))
    local a,wa=roadSection(lo,route); local b,wb=roadSection(lo+1,route)
    return a+(b-a)*t,wa+(wb-wa)*t
end
local function chooseRoute(member, race, bodies, fork)
    local counts={main=0,shortcut=0}
    for _,body in ipairs(bodies) do
        if body.member~=member and math.abs(body.member.distance-member.distance)<4 then
            local other=body.record.race
            if other and counts[other.route] then counts[other.route]=counts[other.route]+1 end
        end
    end
    local current=race.position.X-math.sin(fork.first*math.pi/12)*TRAIL_AMPLITUDE
    -- Observed congestion, turn distance and recovery risk. Never rank/name/pace.
    local safeCost=counts.main*4+math.abs(current-fork.safeSide*16)*.1
    local riskCost=counts.shortcut*5+math.abs(current+fork.safeSide*16)*.1+((member.recoveries or 0)>0 and 8 or 1)
    race.route=safeCost<=riskCost and "main" or "shortcut"
    race.fork=fork.first; member.route=race.route
    race.lateral=math.max(-7,math.min(7,race.lateral))
end
function World.sprintStep(state, now)
    World.stepCourse(now)
    if state.phase~="storm" or state.activity.id~="sprint" then return end
    local bodies={}
    for index,key in ipairs(state.crewOrder) do
        local member,record=state.crew[key],avatars[key]
        if member.activityEntered then
            if not record or not record.model.PrimaryPart or not record.model:FindFirstChild("Head") or not record.model:FindFirstChildOfClass("Humanoid") then
                state:raceDNF(member.username,state.round)
            else
                if not record.race or record.race.round~=state.round then
                    if record.scale~=1 then record.model:ScaleTo(1);record.scale=1 end
                    local grid=gridSlot(member,state,index)
                    record.race={round=state.round,grid=grid,route="shared",lateral=((grid-1)%5-2)*8}
                    member.route="shared"
                    physical(record,true);resetRacer(record,member,now)
                end
                if member.raceStatus=="racing" then bodies[#bodies+1]={member=member,record=record,position=record.model.PrimaryPart.Position} end
            end
        end
    end
    for _,body in ipairs(bodies) do
        local member,record=body.member,body.record
        local model,race=record.model,record.race
        local humanoid,main=model:FindFirstChildOfClass("Humanoid"),model.PrimaryPart
        if humanoid.Health<=0 then state:raceDNF(member.username,state.round)
        else
            local position=main.Position
            local dt=math.max(.001,now-race.sampleAt)
            local cp=(60-position.Z)/TRAIL_STRIDE
            local center,half=corridor(cp,race.route)
            local offRoad=cp>0 and (math.abs(position.X-center)>half+1.5 or cp<member.score-.5 or cp>member.score+1.25)
            if position.Y<54 or math.abs(position.X)>150 or position.Z < -1120 or position.Z>102 or offRoad
                or (position-race.position).Magnitude>math.max(8,dt*90) or now-race.lastMoved>6 then
                member.recoveries=(member.recoveries or 0)+1
                member.lastRecoveryGate=member.score
                member.lastRecoveryReason=position.Y<54 and "fall" or (offRoad and "route corridor" or (now-race.lastMoved>6 and "stalled" or "position jump"))
                resetRacer(record,member,now)
                position=main.Position;cp=(60-position.Z)/TRAIL_STRIDE
            end
            local gate=member.score+1
            local target=roadPoint(gate,race.route)
            local gateCenter,gateHalf=roadSection(gate,race.route)
            local grounded=humanoid.FloorMaterial~=Enum.Material.Air
            local passed=position.Z<=target.Z+.65 and math.abs(position.X-gateCenter)<=gateHalf-1
                and math.abs(position.Y-roadPoint(gate,race.route,position.X-gateCenter).Y)<3.5 and grounded
            local at=now
            if gate==48 then
                passed=passed and race.position.Z>target.Z and position.Z<=target.Z
                if passed then at=race.sampleAt+(now-race.sampleAt)*(race.position.Z-target.Z)/math.max(.0001,race.position.Z-position.Z) end
            end
            if passed then
                if state:recordCheckpoint(member.username,gate,at,state.round,race.route) then race.lastCommand=now-1 end
            end
            if (position-race.position).Magnitude>.08 then race.lastMoved=now end
            if member.raceStatus=="racing" then
                local sectionFork
                for _,fork in ipairs(forks) do
                    if member.score>=fork.first-2 and member.score<fork.last then sectionFork=fork end
                end
                if sectionFork and race.fork~=sectionFork.first then chooseRoute(member,race,bodies,sectionFork)
                elseif not sectionFork then race.route,race.fork,member.route="shared",nil,"shared" end
                gate=member.score+1
                state:raceDistance(member.username,member.score+math.max(0,cp-member.score),state.round)
                if now-race.lastCommand>=.3 then
                    local goalCenter,goalHalf=roadSection(gate,race.route)
                    local best,cost=race.lateral,math.huge
                    for _,shift in ipairs({0,-4,4,-8,8}) do
                        local lateral=math.max(-goalHalf+3,math.min(goalHalf-3,race.lateral+shift))
                        local x=goalCenter+lateral
                        local score=math.abs(shift)*.25
                        for _,other in ipairs(bodies) do
                            if other.member~=member then
                                local ahead=position.Z-other.position.Z
                                if ahead>=-1 and ahead<16 then score=score+math.max(0,5-math.abs(x-(other.position.X+goalCenter-center)))*(16-ahead)*.5 end
                            end
                        end
                        for _,obstacle in ipairs(scenery.sprintObstacles) do
                            if obstacle.checkpoint==gate then score=score+math.max(0,9-math.abs(x-obstacle.part.Position.X))*4 end
                        end
                        if score<cost then best,cost=lateral,score end
                    end
                    -- Small lateral steps permit overtaking without crossing a fork median.
                    race.lateral=best
                    local goal=roadPoint(gate,race.route,best)
                    if gate==48 then goal=goal+Vector3.new(0,0,-3) end
                    humanoid:MoveTo(goal);race.lastCommand=now
                end
                local fork=forkAt(gate-.5)
                local jump=race.route=="shortcut" and fork and (gate==15 or gate==33)
                local edgeZ=60-(gate-.55)*TRAIL_STRIDE
                local hurdle=scenery.sprintHurdles[gate]
                local obstacleZ=hurdle and hurdle.Position.Z+1.5
                local distance=jump and (position.Z-edgeZ) or (obstacleZ and math.abs(position.X-hurdle.Position.X)<11 and position.Z-obstacleZ)
                if distance and distance>=-.5 and distance<=2.5 and grounded and race.jumpGate~=gate and now-race.lastJump>.4 then
                    humanoid.Jump,race.lastJump,race.jumpGate=true,now,gate
                end
                -- Slow sweeping gates are waited out if directly in front of a body.
                for _,obstacle in ipairs(scenery.sprintObstacles) do
                    local d=position-obstacle.part.Position
                    if obstacle.checkpoint==gate and d.Z>1 and d.Z<5 and math.abs(d.X)<6 then
                        humanoid:MoveTo(position);race.lastCommand=0;race.lastMoved=now
                    end
                end
            end
            race.position,race.sampleAt=position,now
        end
        if member.raceStatus~="racing" and record.physical then record.frame=main.CFrame;physical(record,false) end
    end
end

-- Presentation is deliberately outside SkybridgeSprint: the road geometry and
-- every collidable checkpoint/obstacle remain exactly as authored in v10.
local function buildTournamentPresentation()
    local folder=Instance.new("Folder");folder.Name,folder.Parent="TournamentPresentation",root
    local function prop(name,size,position,color)
        local p=part(name,size,CFrame.new(position),color,Enum.Material.Neon,folder)
        p.CanCollide,p.CanTouch,p.CanQuery=false,false,false
        p:SetAttribute("RiftboundPresentation",true)
        return p
    end
    for _,side in ipairs({-1,1}) do
        local bowl=prop("Starting flame brazier",Vector3.new(2,1,2),Vector3.new(side*36,66,59),colors.gold)
        local fire=Instance.new("Fire");fire.Name,fire.Enabled,fire.Size,fire.Heat="Tournament flame",false,7,8
        fire.Color,fire.SecondaryColor,fire.Parent=Color3.fromRGB(255,143,45),colors.violet,bowl
        local sparks=Instance.new("Sparkles");sparks.Enabled,sparks.SparkleColor,sparks.Parent=false,colors.gold,bowl
        local smoke=Instance.new("Smoke");smoke.Enabled,smoke.Size,smoke.Opacity,smoke.RiseVelocity=false,4,.12,4
        smoke.Color,smoke.Parent=Color3.fromRGB(188,166,216),bowl
        tournament.braziers[#tournament.braziers+1]={fire=fire,sparks=sparks,smoke=smoke}
        local pedestal=prop("Podium fireworks",Vector3.new(1,1,1),Vector3.new(side*24,82,-1115),colors.violet)
        local bursts=Instance.new("Sparkles");bursts.Enabled,bursts.SparkleColor,bursts.Parent=false,colors.gold,pedestal
        tournament.fireworks[#tournament.fireworks+1]=bursts
    end
    tournament.bar=prop("Starting gate energy",Vector3.new(64,.4,.4),Vector3.new(0,68,57),colors.gold)
    for i=1,6 do
        local angle=i*math.pi/3
        local point=Vector3.new(-64+math.cos(angle)*8,80+math.sin(angle)*8,65)
        local rune=prop("Arrival portal rune",Vector3.new(1.2,2.4,.5),point,colors.violet)
        tournament.portal[#tournament.portal+1]={part=rune,angle=angle}
    end
end
local function animateTournament(state, now)
    if not tournament.bar then return end
    local starting=state.phase=="countdown"
    local launch=state.phase=="storm" and now-state.activityStarted<1.5
    tournament.bar.Transparency=starting and .15 or 1
    for _,entry in ipairs(tournament.braziers) do
        entry.fire.Enabled,entry.sparks.Enabled,entry.smoke.Enabled=starting or launch,launch,starting or launch
        entry.fire.Size=launch and 11 or (starting and 5+math.sin(now*8) or 5)
    end
    for _,entry in ipairs(tournament.portal) do
        local angle=entry.angle+now*.35
        entry.part.CFrame=CFrame.new(-64+math.cos(angle)*8,80+math.sin(angle)*8,65)*CFrame.Angles(0,0,-angle)
        entry.part.Transparency=state.entrance and .05 or .45+math.sin(now*2+angle)*.15
    end
    for _,effect in ipairs(tournament.fireworks) do effect.Enabled=state.phase=="result" and #state.winners>0 end
end

function World.build(config)
    settings = config or {}
    if not PhysicsService:IsCollisionGroupRegistered("RiftboundRacers") then PhysicsService:RegisterCollisionGroup("RiftboundRacers") end
    PhysicsService:CollisionGroupSetCollidable("RiftboundRacers","RiftboundRacers",false)
    root = Instance.new("Model")
    root.Name = "RiftboundRealm"
    root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    root.Parent = workspace
    fantasyFolder=Instance.new("Folder")
    fantasyFolder.Name,fantasyFolder.Parent="FantasyScenery",root
    Lighting.FogStart, Lighting.FogEnd = 1000, 5000
    Lighting.ClockTime, Lighting.Brightness = 14, 2.5
    Lighting.GlobalShadows = true
    Lighting.Ambient = Color3.fromRGB(128,141,155)
    Lighting.OutdoorAmbient = Color3.fromRGB(170,185,190)
    if not Lighting:FindFirstChildOfClass("Sky") then
        local sky=Instance.new("Sky")
        sky.Name,sky.CelestialBodiesShown,sky.StarCount="Riftbound sky",true,1200
        sky.SunAngularSize,sky.MoonAngularSize,sky.Parent=12,9,Lighting
    end
    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Density, atmosphere.Offset = 0.15, 0
    atmosphere.Color, atmosphere.Decay = Color3.fromRGB(170, 213, 233), Color3.fromRGB(89, 74, 130)
    atmosphere.Parent = Lighting
    local glow = Instance.new("BloomEffect")
    glow.Intensity, glow.Size, glow.Threshold, glow.Parent = 0.45, 32, 1.3, Lighting
    buildSprint()
    buildTournamentPresentation()
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
    local angle = slot * math.pi * 2 / math.max(18, settings.MaxCrew or 40)
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
    -- Staged actors use authored limb poses. Disable joints while anchored so
    -- native motors cannot snap them back; racing re-enables the whole rig.
    physical(avatars[string.lower(username)], false)
end

local function track(distance, radius, count)
    local node = math.floor(distance)
    local fraction = distance - node
    local a, b = node * math.pi * 2 / count, (node + 1) * math.pi * 2 / count
    local from = Vector3.new(math.sin(a) * radius, 0, math.cos(a) * radius)
    local to = Vector3.new(math.sin(b) * radius, 0, math.cos(b) * radius)
    return from:Lerp(to, fraction)
end

local function registeredGrid(member,state)
    local count=state.registration and (state.phase=="storm" and #state.nextCohort or state.registration.count) or #state.nextCohort
    local index=member.registrationSlot or member.gridSlot or 1
    return World.sprintPoint(((index-1+(state.round-1)*7)%math.max(1,count))+1,0)
end
local function destination(member, state, now, scale)
    local y = 35 + 3 * scale
    if state.entrance then
        for index, name in ipairs(state.entrance.names) do
            if name == member.username then return World.entrancePoint(index, #state.entrance.names), true end
        end
    end
    if state.registration and member.registered and (state.phase=="registration" or state.phase=="countdown") then return registeredGrid(member,state),false end
    if member.entranceDone == false then return Vector3.new(-64 + ((member.slot - 1) % 5 - 2) * 5, 80, 82), false end
    if state.phase == "result" then
        for rank, row in ipairs(state.winners or {}) do
            if row.username == member.username then
                return Vector3.new(({ 0, -10, 10 })[rank], (state.activity.id == "sprint" and 77 or 35) + 3 * scale + ({ 4, 2.5, 1.5 })[rank], state.activity.id == "sprint" and -1115 or 14), true
            end
        end
    end
    if state.activity.id == "sprint" then
        if state.phase == "voting" or state.phase == "gathering" then
            for lane, username in ipairs(state.nextCohort or {}) do
                if username == member.username then return World.sprintPoint(((lane-1+((state.phase == "gathering" and state.round+1 or state.round)-1)*7)%math.max(1,#state.nextCohort))+1,0), false end
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
    local a = member.slot * math.pi * 2 / math.max(18, settings.MaxCrew or 40) + math.sin(now * 0.2 + member.slot) * 0.035
    return Vector3.new(math.sin(a) * 28, y, math.cos(a) * 28), false
end

function World.render(state, now)
    sceneState = state
    if state.registration then
        local keep={}
        for _,member in ipairs(state.members) do if member.registered or (state.phase=="result" and member.activityEntered) then keep[string.lower(member.username)]=true end end
        for key,record in pairs(avatars) do
            if not keep[key] then
                if record.pendingAppearance then record.pendingAppearance:Destroy() end
                record.model:Destroy();avatars[key]=nil
            end
        end
    end
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
            if state.registration and state.phase=="countdown" and member.registered and record.readyRound~=state.round then
                local point=registeredGrid(member,state)
                record.frame=CFrame.lookAt(point,point+Vector3.new(0,0,-1));model:PivotTo(record.frame)
                record.readyRound=state.round
            end
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
    animateTournament(state,now)
    rift.Transparency = storm and 0.3 or (state.phase == "voting" and 0.55 or 0.92)
    rift.CFrame = CFrame.new(0, 90 + math.sin(now) * 2, -50) * CFrame.Angles(0, now * 0.2, 0)
    core.CFrame = CFrame.new(0, 42 + math.sin(now * 1.2) * 0.6, 0) * CFrame.Angles(0, now * 0.3, 0.12)
    shield.Transparency = storm and state.choice == "ward" and 0.88 or 1
    gate.Transparency = 0.6 + math.sin(now) * 0.08
    World.stepCourse(now)
    for _,fall in ipairs(scenery.waterfalls) do
        fall.part.CFrame=CFrame.new(fall.center+Vector3.new(0,14-((now*10+fall.phase)%28),0))
    end
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
    Lighting.Ambient = state.blessing == "Aurora veil" and Color3.fromHSV((now * 0.025) % 1, 0.35, 0.65) or Color3.fromRGB(128,141,155)
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
            local baseZ = state.activity.id == "sprint" and (celebration and -1115 or 0) or 10
            p.CFrame = CFrame.new(math.cos(a) * radius, baseY + ((now * (celebration and 8 or 5) + i * 2) % (state.activity.id == "sprint" and 18 or 30)), baseZ + math.sin(a) * radius)
            p.Color = Color3.fromHSV((i / 36 + now * 0.03) % 1, 0.5, 1)
        end
    end
    for _, member in ipairs(state.members) do
        local record = avatars[string.lower(member.username)]
        if record then
            local power=member.powerup or ""
            record.model.PrimaryPart.PowerTrail.Enabled=power=="trail"
            record.model.PowerShield.Transparency=power=="shield" and (.72+math.sin(now*8)*.08) or 1
            record.model.PowerShield.Size=Vector3.new(6,7,6)*(1+math.sin(now*6)*.04)
            if not record.physical then record.model.PowerShield.CFrame=record.model.PrimaryPart.CFrame end
            record.model.PrimaryPart.PowerSparks.Enabled=power=="starburst"
            if power~="" then record.model.GiftAura.Enabled=true end
            if state.activity.id == "sprint" and state.phase == "storm" and record.race and record.race.round == state.round then
                -- Physics owns the root. Only pose the massless limbs for walking.
                local speed = record.model.PrimaryPart and record.model.PrimaryPart.AssemblyLinearVelocity.Magnitude or 0
                local gait = speed > 1 and math.sin(now * 9) * 0.45 or 0
                for _, joint in ipairs(record.model:GetDescendants()) do
                    if joint:IsA("Motor6D") and (string.find(joint.Name, "Shoulder") or string.find(joint.Name, "Hip")) then
                        if not joint:GetAttribute("SprintBaseC0") then joint:SetAttribute("SprintBaseC0", joint.C0) end
                        local shoulder=string.find(joint.Name,"Shoulder")
                        local flourish=power=="starburst" and shoulder and math.sin(now*12)*.3 or 0
                        joint.C0 = joint:GetAttribute("SprintBaseC0") * CFrame.Angles(gait * (string.find(joint.Name, "Left") and 1 or -1)+flourish, 0, 0)
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
            -- Anchored waiting/entrance/podium actors can emote freely. Racing
            -- roots above remain entirely owned by the Humanoid controller.
            local poseIndex=math.floor(now/3.5+member.slot)%5
            local poseNames={"wave","stretch","cheer","look around","celebrate"}
            if (state.registration and member.registered and not moving) or entering or winner then
                local index=(winner or entering) and 3 or poseIndex+1
                model:SetAttribute("RiftboundPose",poseNames[index])
                local left,right=model["Left Arm"],model["Right Arm"]
                local cheer=index==3 or index==5
                local leftY=(cheer and 1.1 or index==2 and .4 or 0)*size
                local rightY=(cheer and 1.1 or index==1 and 1.2 or index==2 and .4 or 0)*size
                local leftRoll=index==2 and -math.pi/2 or cheer and -.65 or .05
                local rightRoll=index==2 and math.pi/2 or index==1 and .4+math.sin(now*7)*.3 or cheer and .65 or -.05
                left.CFrame=body*CFrame.new(-1.5*size,leftY,0)*CFrame.Angles(cheer and math.sin(now*7)*.2 or 0,0,leftRoll)
                right.CFrame=body*CFrame.new(1.5*size,rightY,0)*CFrame.Angles(index==1 and -.15 or cheer and math.sin(now*7)*.2 or 0,0,rightRoll)
                if index==4 then model.Head.CFrame=body*CFrame.new(0,1.5*size,0)*CFrame.Angles(0,math.sin(now)*.35,0) end
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
    remotes:SetAttribute("StartupStage", label)
    remotes:SetAttribute("StartupError", string.sub(tostring(issue), 1, 3500))
    remotes:SetAttribute("StartupState", "failed")
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
        RoundPrizes = { 120, 75, 40 }, OfflineDemoEnabled = false, DemoStudioOnly = true,
        DemoNames = { "Demo_Astra", "Demo_Lumen", "Demo_Nova", "Demo_Fern", "Demo_Orion" },
        AutoSimulateGifts = false, DemoPowerups = true, DemoGiftSeconds = 18, StreamCameraDefault = true, HostUserIds = {},
        BaseMoneyPerSecond = 5, VoteMoneyPerSecond = 3, WinMoneyPerSecond = 2,
        MaxMoneyPerSecond = 100, MaxBalance = 1000000000, MaxCrew = 40, MaxQueuedArrivals = 30,
        PersistenceEnabled = false, AutoJoinPlayers = false, SprintOnly = true, SprintCompetitors = 20, SprintRaceSeconds = 120, SprintWalkSpeed = 12.5, ResolveViewerUsernames = true, EntranceSeconds = 4,
        RegistrationSeconds = 30, MinimumRacers = 2, StartCountdownSeconds = 4, MaxSessionMembers = 500,
        SprintFinishBonus = 40, LoadAvatarAppearances = false, AppearanceTimeoutSeconds = 8,
        DemoAppearanceUserIds = { 1, 156, 261, 2, 3 },
    }
    for name, value in pairs(defaults) do if Config[name] == nil then Config[name] = value end end
    assert(Config.AutoActivities == true, "AutoActivities must stay true for the automatic tournament")
    assert(Config.SprintOnly == true, "SprintOnly must stay true for the physical Skybridge tournament")
    assert(Config.AutoJoinPlayers == false, "AutoJoinPlayers must stay false; viewers must register freshly each round")
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
    range("RegistrationSeconds", 5, 120)
    range("MinimumRacers", 2, 20)
    range("StartCountdownSeconds", 4, 8)
    range("MaxSessionMembers", 40, 1000)
    range("SprintCompetitors", 2, 20)
    assert(Config.MinimumRacers<=Config.SprintCompetitors, "MinimumRacers cannot exceed SprintCompetitors")
    assert(Config.SprintCompetitors == math.floor(Config.SprintCompetitors), "SprintCompetitors must be a whole number")
    range("SprintFinishBonus", 0, 1000000)
    range("AppearanceTimeoutSeconds", 1, 30)
    range("SceneUpdatesPerSecond", 4, 30)
    range("SnapshotSeconds", 0.25, 5)
    range("DemoGiftSeconds", 5, 3600)
    range("MaxCrew", 1, 40)
    range("MaxQueuedArrivals", 1, 200)
    assert(Config.MaxCrew == math.floor(Config.MaxCrew) and Config.MaxQueuedArrivals == math.floor(Config.MaxQueuedArrivals), "Crew and queue limits must be whole numbers")
    for _, name in ipairs({ "BaseMoneyPerSecond", "VoteMoneyPerSecond", "WinMoneyPerSecond", "ActivityMoneyPerSecond", "RoundWinMoneyPerSecond", "CoinsPerPoint" }) do range(name, 0, 1000) end
    range("MaxMoneyPerSecond", 1, 1000)
    range("MaxBalance", 1, 1000000000)
    for _, name in ipairs({ "AutoActivities", "OfflineDemoEnabled", "DemoStudioOnly", "AutoSimulateGifts", "DemoPowerups", "StreamCameraDefault", "SprintOnly", "LoadAvatarAppearances", "AutoJoinPlayers", "ResolveViewerUsernames" }) do
        assert(type(Config[name]) == "boolean", "Config." .. name .. " must be true or false")
    end
    assert(type(Config.DemoAppearanceUserIds) == "table", "DemoAppearanceUserIds must be a table")
    for _, id in ipairs(Config.DemoAppearanceUserIds) do assert(type(id) == "number" and id > 0 and id < 9007199254740991 and id == math.floor(id), "Appearance IDs must be positive whole numbers") end
    assert(type(Config.HostUserIds) == "table" and type(Config.DemoNames) == "table" and type(Config.RoundPrizes) == "table", "HostUserIds, DemoNames and RoundPrizes must be tables")
    for i, name in ipairs(Config.DemoNames) do assert(type(name) == "string" and #name >= 3 and #name <= 20 and string.match(name, "^[%w_]+$"), "DemoNames contains an invalid username label") end
    for i = 1, 3 do assert(type(Config.RoundPrizes[i]) == "number" and Config.RoundPrizes[i] >= 0 and Config.RoundPrizes[i] <= 1000000, "RoundPrizes needs three finite nonnegative amounts") end
    stage("Creating RealmState")
    local state = Realm.new(Config, os.clock())
    for _, name in ipairs({ "tick", "advance", "snapshot", "addCrew", "vote", "gift", "follow", "bless", "recordCheckpoint", "raceDistance", "raceComplete", "raceDNF", "queueEntrance", "advanceEntrances", "nextCohort", "registrationCheck", "register", "unregister", "activatePowerup" }) do
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

    local inputSequence, seenInputs, seenRound = 0, {}, state.round
    local inputCount = 0
    local function envelope(kind, username, roundId, extra)
        inputSequence=inputSequence+1
        local event={type=kind,username=username,roundId=roundId,eventId="offline:"..inputSequence,submittedAt=os.clock()}
        for key,value in pairs(extra or {}) do event[key]=value end
        return event
    end
    local function arrival(event)
        local username=event.username
        local ok,issue=state:registrationCheck(username,event.roundId,event.submittedAt,os.clock(),event.eventId)
        if not ok then return false,issue end
        if not World.validUsername(username) then return false,"Enter a Roblox username, not a display name." end
        local userId=type(event.appearanceUserId)=="number" and event.appearanceUserId or 0
        if userId==0 and event.offline~=true then
            userId,issue=World.resolveUsername(username)
            if not userId then return false,issue end
        end
        -- Native lookup yields. Revalidate the original window AFTER it returns.
        state:tick(os.clock())
        local registered,member=state:register(username,userId,event.roundId,event.submittedAt,os.clock(),event.eventId)
        if not registered then return false,member end
        local model=World.offlineAvatar(member.username)
        World.arrive(model,member.slot,member.username)
        World.loadAppearance(member.username,userId)
        state:advanceEntrances(os.clock())
        return true,member.username.." registered for round "..event.roundId..(event.offline and " / OFFLINE" or " / ROBLOX")
    end
    local function apply(event)
        if event.type=="register" or event.type=="join" then return arrival(event) end
        if event.type=="withdraw" then return state:unregister(event.username,event.roundId,os.clock(),event.eventId) end
        if event.type=="powerup" then return state:activatePowerup(event.username,event.kind,os.clock(),event.roundId,event.eventId) end
        if event.type=="vote" then return state:vote("live:"..event.viewer,event.choice,event.username,os.clock()) end
        if event.type=="blessing" then return state:bless(event.kind,os.clock()) end
        if event.type=="gift" then return state:gift(event.username,event.kind,event.count,os.clock()) end
        if event.type=="follow" then return state:follow(event.viewer) end
        return false,"Unsupported event."
    end
    local function enqueue(event, done)
        if type(event)~="table" then return false,"An event table is required." end
        local scoped=event.type=="register" or event.type=="join" or event.type=="withdraw" or event.type=="powerup"
        if scoped then
            if event.roundId~=state.round then return false,"Stale round ID. Submit again during the correct registration window." end
            if type(event.eventId)~="string" or #event.eventId<1 or #event.eventId>96 or not string.match(event.eventId,"^[%w_:%-%.]+$") then return false,"A valid unique eventId is required." end
            if type(event.submittedAt)~="number" or event.submittedAt~=event.submittedAt or event.submittedAt>os.clock()
                or event.submittedAt<state.registrationOpenedAt then return false,"An entry timestamp from this server window is required." end
            if event.type=="register" or event.type=="join" then
                local ok,issue=state:registrationCheck(event.username,event.roundId,event.submittedAt,os.clock(),event.eventId)
                if not ok then return false,issue end
            elseif event.type=="withdraw" and state.phase~="registration" then return false,"The roster is locked."
            elseif event.type=="powerup" and (state.phase~="storm" or event.submittedAt<state.activityStarted) then return false,"Power-up visuals require a new request during racing." end
            if seenRound~=state.round then seenInputs,seenRound,inputCount={},state.round,0 end
            if seenInputs[event.eventId] then return false,"Repeated event rejected." end
            if inputCount>=1024 then return false,"This window's event budget is full." end
            seenInputs[event.eventId]=true;inputCount=inputCount+1
        end
        if #tasks>=Config.MaxQueuedArrivals then return false,"The event queue is full. Try again shortly." end
        -- Copy scalar fields: callers cannot mutate a table already queued.
        local copy={}
        for _,key in ipairs({"type","username","roundId","eventId","submittedAt","offline","appearanceUserId","kind","count","viewer","choice","demo"}) do copy[key]=event[key] end
        tasks[#tasks+1]={event=copy,done=done}
        return true
    end

    -- Server-only hook for a separately installed future adapter. This is not HTTP.
    local eventHook = Instance.new("BindableFunction")
    eventHook.Name, eventHook.Parent = "RiftboundEvent", script.Parent
    eventHook.OnInvoke = function(event)
        if not running then return false, "Riftbound is not running. Check StartupError." end
        if type(event) ~= "table" then return false, "An event table is required." end
        local completed, accepted, message = false, false, "Queue full."
        local queued,issue=enqueue(event, function(ok, result) accepted, message, completed = ok, result, true end)
        if not queued then return false,issue end
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

    end
    Players.PlayerAdded:Connect(playerAdded)
    for _, player in ipairs(Players:GetPlayers()) do task.spawn(playerAdded, player) end
    Players.PlayerRemoving:Connect(function(player) lastAction[player.UserId] = nil end)

    actionRemote.OnServerEvent:Connect(function(player, action, payload, roundId)
        if not running then return end
        if type(action) ~= "string" or type(payload) ~= "string" or #payload > 100 then return end
        local now = os.clock()
        if lastAction[player.UserId] and now - lastAction[player.UserId] < 0.5 then return end
        lastAction[player.UserId] = now
        if action == "vote" then
            local _, message = state:vote("player:" .. player.UserId, payload, player.Name, now)
            notify(player, message)
        elseif host(player) then
            if action=="join" or action=="offlineJoin" or action=="withdraw" or action=="powerupTrail" or action=="powerupShield" or action=="powerupStarburst" then
                local kind=({powerupTrail="trail",powerupShield="shield",powerupStarburst="starburst"})[action]
                local event=envelope(kind and "powerup" or action=="withdraw" and "withdraw" or "register",payload,roundId,{offline=action=="offlineJoin",kind=kind})
                local ok,issue=enqueue(event,function(_,message) notify(player,message) end)
                if not ok then notify(player,issue) end
            elseif action=="demoToggle" then
                if Config.DemoStudioOnly and not RunService:IsStudio() then notify(player,"Demo testing is Studio-only.");return end
                demoEnabled=not demoEnabled
                notify(player,demoEnabled and "DEMO TESTING ON / fresh registration events each round" or "DEMO TESTING OFF / waiting for challengers")
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
            elseif action=="rift" then
                notify(player,"The race starts automatically after 2+ fresh registrations and the countdown.")
            end
        end
        guarded("Publishing player action", publish)
    end)

    task.spawn(function()
        local seededRound=0
        local nextGift,visualIndex=0,0
        while running do
            if demoEnabled and state.phase=="registration" and seededRound~=state.round then
                local registrationRound=state.round;seededRound=registrationRound
                for i,name in ipairs(Config.DemoNames) do
                    if not demoEnabled or state.phase~="registration" or state.round~=registrationRound then break end
                    enqueue(envelope("register",name,registrationRound,{offline=true,appearanceUserId=Config.DemoAppearanceUserIds[i],demo=true}))
                    task.wait(.35)
                end
            end
            if demoEnabled and (Config.DemoPowerups or Config.AutoSimulateGifts) and state.phase=="storm" and os.clock()>=nextGift then
                nextGift=os.clock()+math.max(5,Config.DemoGiftSeconds);visualIndex=visualIndex+1
                local key=state.lockedRoster[(visualIndex-1)%math.max(1,#state.lockedRoster)+1]
                if key then
                    local name=state.crew[key].username
                    if Config.DemoPowerups then enqueue(envelope("powerup",name,state.round,{kind=({"trail","shield","starburst"})[(visualIndex-1)%3+1]})) end
                    if Config.AutoSimulateGifts then
                        enqueue({type="gift",username=name,kind="bloom",count=1})
                        enqueue({type="follow",viewer="demo:"..string.lower(name)})
                    end
                end
            end
            task.wait(.5)
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
                local previousPhase=state.phase
                local changed = state:advance(now)
                if changed and (state.phase=="countdown" or state.phase=="result" or previousPhase=="result") then
                    -- Cancel pending old-window tasks as well as presentation queues.
                    for i=#tasks,1,-1 do
                        local item=tasks[i]
                        if item.event.roundId and (item.event.type=="register" or item.event.type=="join" or item.event.roundId~=state.round) then
                            table.remove(tasks,i)
                            if item.done then item.done(false,"Registration closed. Submit again in the next registration window.") end
                        end
                    end
                end
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
local SprintBounds = { minX = -170, maxX = 170, minY = 54, maxY = 110, minZ = -1140, maxZ = 102, yaw = 60 }
-- A bounded starting-grid envelope. Competition shots fit observed roots below.
-- Fallback frames the starting grid, NEVER the full winding course.
local SprintVolumes = {
    { minX = -39, maxX = 39, minY = 61, maxY = 90, minZ = 24, maxZ = 78 },
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
local function cinematicCamera(width, height, positions, yawDegrees, elevationDegrees, entrance, wide)
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
    local fov = wide and 65 or entrance and 35 or 55
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
        -- Include the minimum lens height during fitting, not after choosing a
        -- close pose; otherwise a valid low-angle shot can fall back to the grid.
        if cf.Position.Y<112 or cf.Position.Y>220 then return false end
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
    local near, far = entrance and 60 or 85, wide and 190 or 150
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
local previousRanks, rankRound, overtakeUntil, overtakeUsername, nextOvertake = {}, 0, 0, nil, 0
local handoffUntil=0
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
local sceneryMasks, nextSceneryScan, directorTargets = {}, 0, {}
local streamLighting = {
    ClockTime = 14, Brightness = 2.5, ExposureCompensation = 0.05,
    EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 0.5,
    OutdoorAmbient = Color3.fromRGB(170,185,190), GlobalShadows = true,
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
local phase = text(header, "Activity", "WAITING FOR CHALLENGERS", { x = 12, y = 24, w = 318, h = 20 }, 18, mint)
local stats = text(header, "Stats", "REGISTER FRESHLY EACH ROUND", { x = 12, y = 45, w = 318, h = 14 }, 11, muted)
local timer = text(header, "Countdown", "—", { x = 338, y = 3, w = 82, h = 36 }, 30, gold)
timer.TextXAlignment, timer.Font = Enum.TextXAlignment.Center, Enum.Font.GothamBlack
local timingLabel = text(header, "CountdownLabel", "WAITING", { x = 338, y = 41, w = 82, h = 16 }, 10, muted)
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
local noticeUntil = 0
local entranceAnnouncementActive = false
local function notify(value)
    noticeUntil=os.clock()+4
    noticeVersion = noticeVersion + 1
    local version = noticeVersion
    noticeText.Text, notice.Visible = tostring(value), true
    task.delay(4, function() if noticeVersion == version and not entranceAnnouncementActive then notice.Visible = false end end)
end
noticeRemote.OnClientEvent:Connect(notify)

-- Results reuse this dock. There is no winner banner floating over the arena.
local dock = frame(canvas, "RoundDock", Layout.round)
local instruction = text(dock, "Instruction", "COMMENT YOUR ROBLOX USERNAME TO JOIN!", { x = 10, y = 4, w = 412, h = 21 }, 14)
local roundStatus = text(dock, "Status", "WAITING FOR CHALLENGERS", { x = 10, y = 28, w = 412, h = 24 }, 14, mint)
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
button(controls, "Join", "OFFLINE JOIN", { x = 290, y = 52, w = 126, h = 38 }, function() actionRemote:FireServer("offlineJoin", input.Text, latestState and latestState.round or 0) end)
button(controls, "DemoToggle", "DEMO TESTING: OFF", { x = 16, y = 102, w = 194, h = 38 }, function() actionRemote:FireServer("demoToggle", "") end)
button(controls, "Follow", "TEST FOLLOW", { x = 222, y = 102, w = 194, h = 38 }, function() actionRemote:FireServer("follow", input.Text) end)
for i, item in ipairs({ { "Bloom sky", "bloom" }, { "Aurora sky", "aurora" }, { "Titan sky", "giant" } }) do
    button(controls, "Sky" .. i, item[1], { x = 16 + (i - 1) * 137, y = 152, w = 126, h = 38 }, function() actionRemote:FireServer("blessing", item[2]) end)
end
for i, item in ipairs({ { "Gift bloom", "giftBloom" }, { "Gift aurora", "giftAurora" }, { "Gift giant", "giftGiant" } }) do
    button(controls, "Gift" .. i, item[1], { x = 16 + (i - 1) * 137, y = 202, w = 126, h = 38 }, function() actionRemote:FireServer(item[2], input.Text) end)
end
for i,item in ipairs({{"TRAIL VISUAL","powerupTrail"},{"SHIELD VISUAL","powerupShield"},{"STARBURST","powerupStarburst"}}) do
    button(controls,"Powerup"..i,item[1],{x=16+(i-1)*137,y=252,w=126,h=38},function() actionRemote:FireServer(item[2],input.Text,latestState and latestState.round or 0) end)
end
button(controls, "VerifiedJoin", "ROBLOX JOIN / VERIFY ACCOUNT", { x = 16, y = 300, w = 400, h = 32 }, function() actionRemote:FireServer("join", input.Text, latestState and latestState.round or 0) end)
text(controls, "Hint2", "Offline join = stand-in. Roblox join = account lookup.", { x = 16, y = 342, w = 400, h = 24 }, 13, muted)
button(controls,"Withdraw","WITHDRAW ENTRY",{x=16,y=368,w=194,h=32},function() actionRemote:FireServer("withdraw",input.Text,latestState and latestState.round or 0) end)
button(controls,"TestStale","TEST STALE ROUND",{x=222,y=368,w=194,h=32},function() actionRemote:FireServer("offlineJoin",input.Text,(latestState and latestState.round or 0)-1) end)
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
            and p.Z >= -1140 and p.Z <= 102 and math.abs(p.X) <= 150 then return p end
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
    local wideShot=false
    local yaw, elevation = -18, 34
    local highlight=state and state.highlight
    if state and state.registration and (state.phase=="countdown" or state.phase=="storm" and liveTime-state.activityStarted<1.8) then
        key,shot,yaw,elevation,wideShot="launch/"..state.round,"tournament starting grid",0,42,true
        for _,name in ipairs(state.nextCohort or {}) do local p=position(name);if p then targets[#targets+1]=p end end
    elseif not nearFinish and state and state.phase=="storm" and now<overtakeUntil and position(overtakeUsername) then
        key,shot="overtake/"..overtakeUsername,"overtake close-up"
        targets={position(overtakeUsername)}
        for _,row in ipairs(state.activityLeaders) do
            local p=position(row.username)
            if row.username~=overtakeUsername and row.status=="racing" and p and (p-targets[1]).Magnitude<12 then targets[#targets+1]=p;break end
        end
    elseif not nearFinish and highlight and highlight.roundId==state.round and liveTime<highlight.endsAt and position(highlight.username) then
        key,shot="powerup/"..highlight.sequence,"power-up / "..highlight.kind
        targets={position(highlight.username)}
    elseif entrance and liveTime < entrance.endsAt and not nearFinish then
        key, shot, yaw, elevation = "entrance/" .. entrance.sequence, "Star Gate entrance", 10, 35
        for _, name in ipairs(entrance.names) do local p = position(name, true); if p then targets[#targets + 1] = p end end
    elseif state and state.registration and state.phase=="registration" then
        key,shot,yaw,elevation,wideShot="lobby/"..state.round,"waiting lobby",-12+math.sin(now*.09)*9,38,true
        if #state.registration.roster==0 then
            targets={Vector3.new(-64,80,66),Vector3.new(0,68,55)}
        else
            local names=state.registration.roster
            local subject=names[(math.floor(now/5)%#names)+1]
            local p=position(subject)
            if p then targets={p};wideShot=false end
        end
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
            if not spotlight then directorSubject = lead.username end
            local subject = lead
            for _, row in ipairs(state.activityLeaders) do if row.username == directorSubject and row.status == "racing" and position(row.username) then subject = row end end
            if nearFinish then subject = lead end
            local heading = state.course and state.course.headings and state.course.headings[math.max(1, math.min(48, math.floor(subject.distance)+1))]
            if finite(heading) and math.abs(heading)<=90 then yaw=heading-18 end
            local p = position(subject.username)
            if p then targets[1] = p end
            shot = spotlight and "competitor spotlight" or ((state.course and state.course.sections[section] or "section " .. section) .. " / lead pack")
            if not spotlight then
                for _,member in ipairs(state.members) do
                    if member.username==subject.username and member.route=="shortcut" then shot="shortcut battle / "..subject.username end
                end
                local neighbors={}
                for _, row in ipairs(state.activityLeaders) do
                    if row.status == "racing" and row.username ~= subject.username and math.abs(row.distance - subject.distance) <= 1.5 then
                        local other = position(row.username)
                        if other and p then neighbors[#neighbors+1]={position=other,distance=(other-p).Magnitude} end
                    end
                end
                table.sort(neighbors,function(a,b) return a.distance<b.distance end)
                for i=1,math.min(2,#neighbors) do targets[#targets+1]=neighbors[i].position end
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
            -- Show the front pack, never fit twenty bodies into a tiny full-grid shot.
            for i, name in ipairs(state.nextCohort or {}) do local p = position(name); if p and p.Z > 30 and i<=5 then targets[#targets + 1] = p end end
        end
    end
    if #targets > 0 then
        local w, h = cameraWidth, cameraHeight
        if not usableViewport(w, h) then w, h = 390, 844 end
        local cf, aim, d, angle = cinematicCamera(w, h, targets, yaw, elevation, shot == "Star Gate entrance" or shot=="overtake close-up" or string.find(shot,"power-up",1,true)~=nil, wideShot)
        if not cf then
            -- A dispersed pack gets a real competitor close-up, never a zoom-out.
            targets = { targets[1] }
            cf, aim, d, angle = cinematicCamera(w, h, targets, -18, shot == "Star Gate entrance" and 35 or 34, shot == "Star Gate entrance", false)
        end
        if cf then desired, focus, distance, fov = cf, aim, d, angle end
    end
    if not desired or not focus then return end
    local changed = directorKey ~= key or not directorFrame or shot ~= directorShot
    local candidate = desired
    if directorFrame and (directorFrame.Position-desired.Position).Magnitude>=100 and changed then handoffUntil=now+.18 end
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
    directorTargets=targets
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

local handoff=Instance.new("Frame")
handoff.Name,handoff.Size,handoff.BackgroundColor3,handoff.BackgroundTransparency="ShotHandoff",UDim2.fromScale(1,1),gold,1
handoff.BorderSizePixel,handoff.Parent=0,gui
local lastGift, giftFocusUntil, lastWinnerAnnouncement = 0, 0, -1
snapshotRemote.OnClientEvent:Connect(function(state)
    if not latestState or latestState.phase ~= state.phase then nextCameraDiagnostic = 0; entranceAnnouncementActive=false end
    if state.registration and state.phase=="storm" and rankRound==state.round and os.clock()>=nextOvertake then
        for i,row in ipairs(state.activityLeaders) do
            if row.status=="racing" and previousRanks[row.username] and i<previousRanks[row.username] then
                overtakeUsername,overtakeUntil,nextOvertake=row.username,os.clock()+1.5,os.clock()+4
                break
            end
        end
    end
    previousRanks,rankRound={},state.round
    for i,row in ipairs(state.activityLeaders) do if row.status=="racing" then previousRanks[row.username]=i end end
    latestState, receivedAt = state, os.clock()
    -- Validate EVERY snapshot. Corrected/missing bounds can arrive without an
    -- activity change; never leave the camera stuck on the first received box.
    if resize then resize() end
    competitorPanel.Title.Text = state.physicalSprint and "SPRINT / TIME" or "ROUND LEADERS / PT"
    phase.Text = state.activity.name
    stats.Text = string.format("%s / %d TRAVELERS / %d SHARDS", state.demo and "DEMO" or "LOCAL CREW", #state.crew, state.wins)
    timingLabel.Text = ({ registration="JOIN CLOSES",countdown="GET READY",gathering = "NEXT ROUND", voting = "STARTS IN", storm = "TIME LEFT", result = "NEXT UP" })[state.phase]
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
        roundStatus.Text = string.format("%d RACERS / LEAD %d%% / CP %d/%d", #state.activityLeaders, math.floor(raceLead.distance/state.activity.goal*100), raceLead.score, state.activity.goal)
    end
    if state.registration then
        local reg=state.registration
        stats.Text=reg.open and string.format("ROUND %d / %d/%d RACERS / %d OPEN",state.round,reg.count,reg.capacity,math.max(0,reg.capacity-reg.count))
            or string.format("ROUND %d / REGISTRATION CLOSED",state.round)
        controls.DemoToggle.Text=state.demo and "DEMO TESTING: ON" or "DEMO TESTING: OFF"
        if state.phase=="registration" then
            phase.Text=not reg.open and "REGISTRATION CLOSED" or reg.endsAt==0 and "WAITING FOR CHALLENGERS" or "REGISTRATION OPEN"
            timingLabel.Text=reg.endsAt==0 and "NEED "..reg.minimum or "JOIN CLOSES"
            instruction.Text="COMMENT YOUR ROBLOX USERNAME TO JOIN!"
            roundStatus.Text=reg.count.."/"..reg.capacity.." REGISTERED / SUBMIT AGAIN EACH ROUND"
            competitorPanel.Title.Text="REGISTERED / "..reg.count
            for i=1,5 do
                competitors[i].name.Text=reg.roster[i] and (i..". "..reg.roster[i]) or (i..". Open slot")
                competitors[i].score.Text=reg.roster[i] and "READY" or "—"
            end
        elseif state.phase=="countdown" then
            phase.Text="ROSTER LOCKED / GET READY"
            instruction.Text="REGISTRATION CLOSED / ENTER AGAIN NEXT ROUND"
            roundStatus.Text=#state.nextCohort.." COMPETITORS / FIRE GATE OPENING"
        elseif state.phase=="result" then
            phase.Text=#state.winners>0 and "PODIUM / TOP FINISHERS" or "RACE COMPLETE / DNFs"
            instruction.Text="ROUND CLOSED / EVERYONE MUST REGISTER AGAIN"
            earnerPanel.Title.Text="PODIUM / REWARDS"
            for i=1,5 do
                local winner=state.winners[i]
                earners[i].name.Text=winner and (winner.placement..". "..winner.username) or ""
                earners[i].score.Text=winner and ("+$"..money(winner.prize)) or ""
            end
        end
        if state.phase~="result" then earnerPanel.Title.Text="TOP EARNERS / $" end
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
    -- Shared road wedges, border segments, checkpoint markers and finish anchors.
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
    print(string.format("[Riftbound camera] presentation=race-show-v11 daylight=%s clock=%.2f brightness=%.2f exposure=%.2f",
        tostring(STREAM_DAYLIGHT and streamCamera and gui.Enabled), Lighting.ClockTime, Lighting.Brightness, Lighting.ExposureCompensation))
    print(string.format("[Riftbound render] revision=race-show-v11 shot=%s clearEffects=%s probes=%s effectiveOpacity min=%.3f mean=%.3f max=%.3f intervalPositionDrift=%.3f intervalAimDrift=%.6f",
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
local function updateSceneryVisibility(now)
    local camera=workspace.CurrentCamera
    local active=streamCamera and gui.Enabled and camera and #directorTargets>0
    if active and now<nextSceneryScan then return end
    nextSceneryScan=now+.15
    local hidden={}
    if active and type(camera.GetPartsObscuringTarget)=="function" then
        local realm=workspace:FindFirstChild("RiftboundRealm")
        local folder=realm and realm:FindFirstChild("FantasyScenery")
        local ignore={}
        if player.Character then ignore[#ignore+1]=player.Character end
        for _,member in ipairs(latestState and latestState.members or {}) do
            local model=realm and realm:FindFirstChild("Traveler_"..member.username)
            if model then ignore[#ignore+1]=model end
        end
        local probes={}
        for _,point in ipairs(directorTargets) do
            probes[#probes+1]=point; probes[#probes+1]=point+Vector3.new(0,4,0)
        end
        local ok,parts=pcall(function() return camera:GetPartsObscuringTarget(probes,ignore) end)
        if ok and type(parts)=="table" and folder then
            for _,object in ipairs(parts) do
                if object:IsA("BasePart") and object:GetAttribute("RiftboundScenery")==true then
                    local ancestor=object.Parent
                    while ancestor do
                        if ancestor==folder then hidden[object]=true; break end
                        ancestor=ancestor.Parent
                    end
                end
            end
        end
    end
    for object,original in pairs(sceneryMasks) do
        if not hidden[object] then object.LocalTransparencyModifier=original; sceneryMasks[object]=nil end
    end
    for object in pairs(hidden) do
        if sceneryMasks[object]==nil then sceneryMasks[object]=object.LocalTransparencyModifier or 0 end
        object.LocalTransparencyModifier=1
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
    if latestState then
        local waiting=latestState.registration and latestState.phase=="registration" and latestState.registration.endsAt==0
        timer.Text=waiting and "—" or tostring(math.max(0,math.ceil(latestState.seconds-(os.clock()-receivedAt))))
    end
    handoff.BackgroundTransparency=streamCamera and math.max(.9,1-math.max(0,handoffUntil-os.clock())/.18*.1) or 1
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
        local liveTime=latestState and latestState.now+os.clock()-receivedAt or os.clock()
        local tournamentActive=false
        if latestState and latestState.registration then
            local state=latestState
            local remaining=math.max(0,math.ceil(state.deadline-liveTime))
            if state.phase=="countdown" then
                noticeText.Text,noticeText.TextSize,notice.Visible=remaining>3 and "READY" or tostring(math.max(1,remaining)),28,true
                tournamentActive=true
            elseif state.phase=="storm" and liveTime-state.activityStarted<1.8 then
                noticeText.Text,noticeText.TextSize,notice.Visible="GO!",28,true;tournamentActive=true
            elseif state.highlight and directorShot=="power-up / "..state.highlight.kind and liveTime<state.highlight.endsAt then
                noticeText.Text,noticeText.TextSize,notice.Visible=state.highlight.username.." / "..string.upper(state.highlight.kind),22,true;tournamentActive=true
            elseif state.phase=="registration" and not entryActive and os.clock()>noticeUntil then
                noticeText.Text,noticeText.TextSize,notice.Visible="COMMENT YOUR ROBLOX USERNAME TO JOIN!",17,true;tournamentActive=true
            end
        end
        if tournamentActive then
            entranceAnnouncementActive=true
        elseif entryActive then
            entranceAnnouncementActive = true
            noticeText.Text, noticeText.TextSize, notice.Visible = entry.names[1] .. (#entry.names > 1 and (" +" .. (#entry.names - 1) .. " ARRIVALS") or " / WELCOME"), 22, true
        elseif entranceAnnouncementActive then
            entranceAnnouncementActive, notice.Visible, noticeText.TextSize = false, false, 14
        end
        updateLensMasks(os.clock())
        applyCamera(camera)
        updateSceneryVisibility(os.clock())
        cameraDiagnostics(os.clock())
    end
    if not streamCamera or not gui.Enabled then updateLensMasks(os.clock()); updateSceneryVisibility(os.clock()) end
    updateRenderCheck()
    labelAccumulator = labelAccumulator + dt
    if labelAccumulator >= 0.12 then labelAccumulator = 0; updateLabels(os.clock()) end
end)
```
