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
