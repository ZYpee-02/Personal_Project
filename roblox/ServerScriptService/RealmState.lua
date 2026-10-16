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
