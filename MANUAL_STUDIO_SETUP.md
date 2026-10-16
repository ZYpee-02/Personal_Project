# Riftbound Live Phase 2: complete raw scripts and manual replacement

Use the Script Editor and Explorer. Do not paste this document or any script into
the Command Bar. There is no generated installer or serialized source wrapper.

**Updating the working Phase 1 game?** Save a backup of your Studio place, stop
Play, and replace the ENTIRE source of each of the five existing instances below.
Keep their names, types and parents. Replace all five together; do not mix versions
or add duplicates. Restore any custom HostUserIds into the new Config afterward.
**Updating the working Phase 2 game to the presentation fix?** Replace the ENTIRE
source of **World.lua and Realm.client.lua** together. Config, RealmState and the
server Realm are unchanged from the working startup repair. All five complete
files are provided below in case your copies are mixed. Follow
`docs/PRESENTATION_REPLACEMENT.md` for exact replacement and resolution checks.
`docs/STARTUP_FIX.md` documents the earlier startup repair;
`docs/PHASE2_REPLACEMENT.md` covers the first-three-round checklist.

## Step-by-step

1. Open a new Roblox Studio place and stop Play mode. Keep HTTP Requests and Studio
   API Services access disabled. No publication, Node process or plugin is needed.
2. Open Explorer and Properties from Studio's View/Window menu.
3. Under **ServerScriptService**, insert three **ModuleScript** instances. Name
   them exactly **Config**, **RealmState**, and **World** (without `.lua`).
4. Under **ServerScriptService**, insert one normal **Script** named **Realm**.
   Its source is the file `Realm.server.lua`. Leave RunContext at Legacy/default.
5. Expand **StarterPlayer → StarterPlayerScripts**. Insert one **LocalScript**
   named **Realm** there. Its source is `Realm.client.lua`. This client script
   belongs in StarterPlayerScripts, not StarterCharacterScripts or the server.
6. Double-click each instance to open its Script Editor. Select **all** of its
   default/template text and replace it with its matching complete source below.
   Copy only the code inside that file's code block, without Markdown fences.
   In a raw file preview, copy the source itself. Do not combine the five files.
7. Make sure the server Script and LocalScript are enabled. Finish all five files
   before pressing Play. Do not keep duplicate Realm server/client scripts active.
8. Press **Play**, not Run. The server creates the islands, stand-in avatars, event
   objects and money/round state; the LocalScript builds the player HUD.
9. Wait: six clearly named Demo_ travelers arrive automatically in Studio. After
   12 seconds gathering and 8 seconds optional voting, they compete for 30 seconds.
   A 10-second result/celebration phase follows, then the next round starts itself.
10. Watch three rounds: Starfall Scramble, Skybridge Sprint, then Heartseed Relay.
    No votes, clicks or Keeper Tools are needed. Demo gifts/follows also run in Studio.
    Usernames label local procedural avatars; no real account/outfit is downloaded.
11. Optional **TEST TOOLS** can add a username, start gathering early, simulate votes,
    gifts or a follow. **ROAM VIEW** restores normal character camera controls;
    **STREAM VIEW** returns to the fitted 9:16 arena view. Keep tools closed for capture.
    Base income is $5/s in voting/competition, plus $2/s for automatic activity,
    a $3/s voting bonus, checkpoint bounties and podium prizes. Gifts stay cosmetic.
12. Stop and Play again to confirm all money, crew, gifts, follows and shards reset.

Expected Explorer tree:

```text
ServerScriptService
├── Config       (ModuleScript)
├── RealmState   (ModuleScript)
├── World        (ModuleScript)
└── Realm        (Script; source: Realm.server.lua)
StarterPlayer
└── StarterPlayerScripts
    └── Realm    (LocalScript; source: Realm.client.lua)
```

The server's three `require(script.Parent.NAME)` calls refer to the three sibling
ModuleScripts above. Config, RealmState and World each return their module table.
The client requires no modules; it waits for `ReplicatedStorage.Riftbound` and its
Snapshot, Action and Notice RemoteEvents, which the server creates automatically.
Do not create those remotes or install anything from `integrations/` manually.
The corrected server creates them BEFORE loading modules and publishes Ready only
after a successful world build and first render. The client shows loading progress
and a bounded error panel. Success in SERVER Output starts with `[Riftbound] Ready`.
Check the server Realm is enabled with RunContext Legacy, and has no duplicates.

The presentation update keeps a clear central arena area, puts both leaderboards
in separate bottom panels, and reuses the bottom round dock for results. Stream
view hides duplicate world/scenery boards and limits projected avatar labels to
four names/two earnings rows. Roam view restores nearby world boards. Camera
distance adapts to the viewport; no result zoom or central winner banner is used.

All game data is in memory, with `PersistenceEnabled = false`. These sources have
no save-service access, HTTP calls, external asset fetches, or TikTok connection.
Roblox Studio/engine behavior still requires a local Windows/macOS playtest.

## Complete source files

### Config.lua

Create a **ModuleScript** named **Config** under **ServerScriptService**.

```luau
-- Offline playtest settings. No network transport or save implementation is bundled.
return {
    HostUserIds = {}, -- Your numeric Roblox user ID(s), required for published host controls.
    PersistenceEnabled = false, -- Must stay false: all game state is in memory.
    BaseMoneyPerSecond = 5,
    VoteMoneyPerSecond = 3,
    WinMoneyPerSecond = 2,
    MaxMoneyPerSecond = 100,
    MaxBalance = 1000000000,
    AutoActivities = true,
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
    DemoNames = { "Demo_Astra", "Demo_Lumen", "Demo_Nova", "Demo_Fern", "Demo_Orion", "Demo_Lyra" },
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
    { id = "sprint", name = "SKYBRIDGE SPRINT", instruction = "Race twelve checkpoints to the finish arch.", goal = 12, teamPerMember = 10 },
    { id = "relay", name = "HEARTSEED RELAY", instruction = "Carry energy between the shrines and heartseed.", goal = 0, teamPerMember = 16 },
}

local function pace(username, round, activity)
    local hash = round * 193 + #activity * 37
    for i = 1, #username do hash = (hash * 31 + string.byte(username, i)) % 65521 end
    return (activity == "sprint" and 0.42 or 0.55) + (hash % 401) / 1000
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
        activity = activities[1],
        activityStarted = now,
        activityEntrants = 0,
        teamScore = 0,
        teamTarget = 0,
        winners = {},
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
        enteredAt = self.lastTick, pace = 0, finishedAt = 0,
    }
    table.insert(self.crewOrder, key)
    if self.config.AutoActivities and self.phase == "storm" and self.lastTick < self.deadline then self:enterActivity(self.crew[key], self.lastTick) end
    self.message = username .. " stepped through the star gate."
    return true, self.crew[key]
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

function Realm:enterActivity(member, now)
    member.activityEntered, member.enteredAt = true, now
    member.pace = pace(member.username, self.round, self.activity.id)
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
            if self.config.AutoActivities and self.phase == "storm" and member.activityEntered then
                local distance = math.max(0, earningEnd - member.enteredAt) * member.pace
                if self.activity.goal > 0 then distance = math.min(self.activity.goal, distance) end
                local score = math.floor(distance + 0.000001)
                self:credit(member, math.max(0, score - member.score) * (self.config.CoinsPerPoint or 2))
                member.distance, member.score = distance, score
                if self.activity.goal > 0 and distance >= self.activity.goal then
                    member.finishedAt = member.enteredAt + self.activity.goal / member.pace
                end
            end
        end
    end
    self.teamScore = 0
    for _, key in ipairs(self.crewOrder) do self.teamScore = self.teamScore + self.crew[key].score end
    self.lastTick = now
end

function Realm:activityLeaderboard()
    local rows = {}
    for _, key in ipairs(self.crewOrder) do
        local member = self.crew[key]
        if member.activityEntered then
            table.insert(rows, { username = member.username, score = member.score, distance = member.distance, finishedAt = member.finishedAt, slot = member.slot })
        end
    end
    table.sort(rows, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.finishedAt > 0 and b.finishedAt > 0 and a.finishedAt ~= b.finishedAt then return a.finishedAt < b.finishedAt end
        if a.distance ~= b.distance then return a.distance > b.distance end
        return a.slot < b.slot
    end)
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
    if now < self.deadline then return false end
    self:tick(now)
    if self.phase == "gathering" then
        self.phase = "voting"
        self.round = self.round + 1
        self.activity = activities[((self.round - 1) % #activities) + 1]
        self.activityEntrants, self.teamScore, self.teamTarget = 0, 0, 0
        self.votes = {}
        self.totals = { ward = 0, sail = 0 }
        for _, key in ipairs(self.crewOrder) do
            self.crew[key].roundMoney = 0
            self.crew[key].participated = false
            self.crew[key].activityEntered = false
            self.crew[key].score, self.crew[key].distance, self.crew[key].finishedAt = 0, 0, 0
        end
        self.requiredVotes = math.max(1, math.ceil(#self.crewOrder / 3))
        self.deadline = now + self.config.VotingSeconds
        self.message = self.config.AutoActivities and (self.activity.name .. " begins soon. Vote Ward or Sail for the scenery!")
            or "A storm rift is opening. Raise a ward, or sail through it?"
    elseif self.phase == "voting" then
        self.phase = "storm"
        self.activityStarted = now
        if self.config.AutoActivities then
            for _, key in ipairs(self.crewOrder) do self:enterActivity(self.crew[key], now) end
        end
        self.choice = self.totals.sail > self.totals.ward and "sail" or "ward"
        self.success = self.totals.ward + self.totals.sail >= self.requiredVotes
        self.deadline = now + self.config.StormSeconds
        self.message = self.config.AutoActivities and self.activity.instruction
            or (self.choice == "ward" and "The crew raises a starlight ward!" or "The island rides the storm winds!")
    elseif self.phase == "storm" then
        self.phase = "result"
        self.winners = {}
        if self.config.AutoActivities then
            local ranking = self:activityLeaderboard()
            for i = 1, math.min(3, #ranking) do
                local row = ranking[i]
                local prize = (self.config.RoundPrizes or { 120, 75, 40 })[i] or 0
                self:credit(self.crew[string.lower(row.username)], prize)
                table.insert(self.winners, { username = row.username, score = row.score, prize = prize, slot = row.slot })
            end
            if ranking[1] then self.crew[string.lower(ranking[1].username)].roundWins = self.crew[string.lower(ranking[1].username)].roundWins + 1 end
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
            finished = member.finishedAt > 0,
        })
    end
    local lastRound = {}
    for _, row in ipairs(self.lastRound) do
        table.insert(lastRound, { username = row.username, money = row.money, perSecond = row.perSecond, gifts = row.gifts, slot = row.slot })
    end
    local winners = {}
    for _, row in ipairs(self.winners) do table.insert(winners, { username = row.username, score = row.score, prize = row.prize, slot = row.slot }) end
    return {
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
        teamScore = self.teamScore, teamTarget = self.teamTarget,
        lastGift = { username = self.lastGift.username, kind = self.lastGift.kind, count = self.lastGift.count, sequence = self.lastGift.sequence },
    }
end

return Realm
```

### World.lua

Create a **ModuleScript** named **World** under **ServerScriptService**.

```luau
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local World = {}
local root, core, gate, rift, shield, constellation, bloom, winds, scoreText
local monuments = {}
local avatars = {}
local scenery = { clouds = {}, runes = {}, ribbons = {}, particles = {}, stars = {}, shrines = {} }
local settings = {}
local sceneState
local lastFrame = 0
local sessionText
local colors = {
    rock = Color3.fromRGB(47, 46, 78), grass = Color3.fromRGB(68, 112, 111),
    mint = Color3.fromRGB(106, 255, 213), gold = Color3.fromRGB(255, 208, 128),
    violet = Color3.fromRGB(173, 130, 255), stone = Color3.fromRGB(108, 99, 139),
}

local function part(name, size, cf, color, material, parent)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, cf
    p.Anchored = true
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

function World.build(config)
    settings = config or {}
    root = Instance.new("Folder")
    root.Name, root.Parent = "RiftboundRealm", workspace
    Lighting.ClockTime, Lighting.Brightness = 18.3, 2
    Lighting.GlobalShadows = true
    Lighting.Ambient = Color3.fromRGB(111, 109, 148)
    Lighting.OutdoorAmbient = Color3.fromRGB(116, 133, 158)
    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Density, atmosphere.Offset = 0.3, 0.2
    atmosphere.Color, atmosphere.Decay = Color3.fromRGB(170, 213, 233), Color3.fromRGB(89, 74, 130)
    atmosphere.Parent = Lighting
    local glow = Instance.new("BloomEffect")
    glow.Intensity, glow.Size, glow.Threshold, glow.Parent = 0.45, 32, 1.3, Lighting
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
    gate = part("Star gate", Vector3.new(1, 16, 16), CFrame.new(0, 43, -25) * CFrame.Angles(0, math.pi / 2, 0), colors.violet, Enum.Material.Neon)
    gate.Shape, gate.CanCollide, gate.Transparency = Enum.PartType.Cylinder, false, 0.62
    for i = 1, 12 do
        local a = i * math.pi * 2 / 12
        crystal(Vector3.new(math.sin(a) * 9, 43 + math.cos(a) * 9, -25), 0.45, colors.gold)
    end
    label(gate, "THE STAR GATE  /  ARRIVALS", Vector3.new(0, 13, 0), colors.gold, 340)
    local spawn = Instance.new("SpawnLocation")
    spawn.Name, spawn.Size, spawn.CFrame = "Arrival", Vector3.new(7, 0.3, 7), CFrame.new(0, 35, 22)
    spawn.Anchored, spawn.Neutral, spawn.Duration = true, true, 0
    spawn.Color, spawn.Material, spawn.Parent = colors.gold, Enum.Material.Neon, root
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
    return model
end

local function number(value)
    if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
    if value >= 1000 then return string.format("%.1fK", value / 1000) end
    return tostring(math.floor(value))
end

function World.arrive(model, slot, username)
    model.Name = "Traveler_" .. username
    model:PivotTo(CFrame.new(0, 38, -25))
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
        balance = 0, popText = popText, scale = 1,
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
    if state.phase == "result" then
        for rank, row in ipairs(state.winners or {}) do
            if row.username == member.username then
                return Vector3.new(({ 0, -9, 9 })[rank], y + ({ 4, 2.5, 1.5 })[rank], 14), true
            end
        end
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
        local record = avatars[string.lower(member.username)]
        if record then
            local model = record.model
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
            local targetScale = member.effect == "giant" and 1.85 or 1
            if record.scale ~= targetScale then model:ScaleTo(targetScale); record.scale = targetScale end
            model.GiftAura.Enabled = member.effect ~= ""
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
            local radius = celebration and 16 or 25
            p.CFrame = CFrame.new(math.cos(a) * radius, 37 + ((now * (celebration and 8 or 5) + i * 2) % 30), 10 + math.sin(a) * radius)
            p.Color = Color3.fromHSV((i / 36 + now * 0.03) % 1, 0.5, 1)
        end
    end
    for _, member in ipairs(state.members) do
        local record = avatars[string.lower(member.username)]
        if record then
            local target, winner = destination(member, state, now, record.scale)
            local age = now - record.arrivedAt
            if age < 2 then target = Vector3.new(0, 38, -25):Lerp(target, math.min(1, age / 2)) end
            local current = record.frame.Position
            local position = current:Lerp(target, math.min(1, dt * 7))
            local delta = target - current
            local direction = Vector3.new(delta.X, 0, delta.Z)
            if direction.Magnitude < 0.1 then direction = Vector3.new(0, 0, -1) end
            local frame = CFrame.lookAt(position, position + direction)
            record.frame = record.frame:Lerp(frame, math.min(1, dt * 9))
            local moving = Vector3.new(delta.X, 0, delta.Z).Magnitude > 0.2
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
            model["Winner crown"].Transparency = winner and 0 or 1
            for i = 1, 3 do model["Crown spike " .. i].Transparency = winner and 0 or 1 end
            model["Relay energy"].Transparency = storm and state.activity.id == "relay" and member.activityEntered and 0 or 1
            model["Relay energy"].CFrame = body * CFrame.new(0, size, -1.5 * size)
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
    for _, name in ipairs({ "build", "render", "animate", "offlineAvatar", "arrive" }) do
        assert(type(World[name]) == "function", "World is missing " .. name .. "(). Replace the entire World ModuleScript with the Phase 2 file.")
    end
    stage("Validating Config")
    -- Phase 1 Config tables lacked these fields. Supply only missing values; never hide invalid explicit values.
    local defaults = {
        SceneUpdatesPerSecond = 12, SnapshotSeconds = 0.5, AutoActivities = true,
        ActivityMoneyPerSecond = 2, RoundWinMoneyPerSecond = 1, CoinsPerPoint = 2,
        RoundPrizes = { 120, 75, 40 }, OfflineDemoEnabled = true, DemoStudioOnly = true,
        DemoNames = { "Demo_Astra", "Demo_Lumen", "Demo_Nova", "Demo_Fern", "Demo_Orion", "Demo_Lyra" },
        AutoSimulateGifts = true, DemoGiftSeconds = 18, StreamCameraDefault = true, HostUserIds = {},
        BaseMoneyPerSecond = 5, VoteMoneyPerSecond = 3, WinMoneyPerSecond = 2,
        MaxMoneyPerSecond = 100, MaxBalance = 1000000000, MaxCrew = 18, MaxQueuedArrivals = 30,
        PersistenceEnabled = false,
    }
    for name, value in pairs(defaults) do if Config[name] == nil then Config[name] = value end end
    assert(Config.PersistenceEnabled == false, "PersistenceEnabled must stay false; this game has no save implementation")
    local function range(name, minimum, maximum)
        local value = Config[name]
        assert(type(value) == "number" and value == value and value >= minimum and value <= maximum,
            "Config." .. name .. " must be a finite number from " .. minimum .. " to " .. maximum)
    end
    for _, name in ipairs({ "GatheringSeconds", "VotingSeconds", "StormSeconds", "ResultSeconds" }) do range(name, 0.1, 3600) end
    range("SceneUpdatesPerSecond", 4, 30)
    range("SnapshotSeconds", 0.25, 5)
    range("DemoGiftSeconds", 5, 3600)
    range("MaxCrew", 1, 18)
    range("MaxQueuedArrivals", 1, 200)
    assert(Config.MaxCrew == math.floor(Config.MaxCrew) and Config.MaxQueuedArrivals == math.floor(Config.MaxQueuedArrivals), "Crew and queue limits must be whole numbers")
    for _, name in ipairs({ "BaseMoneyPerSecond", "VoteMoneyPerSecond", "WinMoneyPerSecond", "ActivityMoneyPerSecond", "RoundWinMoneyPerSecond", "CoinsPerPoint" }) do range(name, 0, 1000) end
    range("MaxMoneyPerSecond", 1, 1000)
    range("MaxBalance", 1, 1000000000)
    for _, name in ipairs({ "AutoActivities", "OfflineDemoEnabled", "DemoStudioOnly", "AutoSimulateGifts", "StreamCameraDefault" }) do
        assert(type(Config[name]) == "boolean", "Config." .. name .. " must be true or false")
    end
    assert(type(Config.HostUserIds) == "table" and type(Config.DemoNames) == "table" and type(Config.RoundPrizes) == "table", "HostUserIds, DemoNames and RoundPrizes must be tables")
    for _, name in ipairs(Config.DemoNames) do assert(type(name) == "string" and #name >= 3 and #name <= 20 and string.match(name, "^[%w_]+$"), "DemoNames contains an invalid username label") end
    for i = 1, 3 do assert(type(Config.RoundPrizes[i]) == "number" and Config.RoundPrizes[i] >= 0 and Config.RoundPrizes[i] <= 1000000, "RoundPrizes needs three finite nonnegative amounts") end
    stage("Creating RealmState")
    local state = Realm.new(Config, os.clock())
    for _, name in ipairs({ "tick", "advance", "snapshot", "addCrew", "vote", "gift", "follow", "bless" }) do
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
        World.render(snapshot, now)
        snapshotRemote:FireAllClients(snapshot)
    end

    local function notify(player, message)
        if player and player.Parent then noticeRemote:FireClient(player, message) end
    end

    local function arrival(username)
        if type(username) ~= "string" or #username < 3 or #username > 20 or not string.match(username, "^[%w_]+$") then
            return false, "Enter a Roblox username, not a display name."
        end
        if state.crew[string.lower(username)] then return false, "That traveler is already here." end
        if #state.crewOrder >= Config.MaxCrew then return false, "The island is full for this session." end
        local userId = 0 -- Offline labels are not verified Roblox accounts.
        local model = World.offlineAvatar(username)
        state:tick(os.clock())
        local added, member = state:addCrew(username, userId)
        if not added then model:Destroy(); return false, member end
        World.arrive(model, member.slot, username)
        return true, username .. " arrived through the star gate."
    end

    local function apply(event)
        if event.type == "join" then return arrival(event.username) end
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
        player:SetAttribute("RiftboundHost", host(player))
        player:SetAttribute("RiftboundStreamCamera", Config.StreamCameraDefault)
        enqueue({ type = "join", username = player.Name }, function(_, message) notify(player, message) end)
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
            if action == "join" then
                if not enqueue({ type = "join", username = payload }, function(_, message) notify(player, message) end) then
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
        for _, name in ipairs(Config.DemoNames) do
            if not running then return end
            enqueue({ type = "join", username = name })
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

    local sceneAccumulator = 0
    table.insert(connections, RunService.Heartbeat:Connect(function(dt)
        sceneAccumulator = sceneAccumulator + dt
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

-- BEGIN PRESENTATION MATH (pure geometry, also exercised by automated checks)
local Layout = {
    width = 480, height = 854,
    toolbar = { x = 216, y = 18, w = 240, h = 30 },
    header = { x = 24, y = 56, w = 432, h = 64 },
    notice = { x = 24, y = 128, w = 432, h = 28 },
    arena = { x = 16, y = 166, w = 448, h = 344 },
    earners = { x = 24, y = 522, w = 210, h = 110 },
    competitors = { x = 246, y = 522, w = 210, h = 110 },
    round = { x = 24, y = 640, w = 432, h = 64 },
    footer = { x = 24, y = 708, w = 432, h = 10 },
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
-- Fit the main island (including bedrock), avatar routes and giant rigs into the
-- clear arena rectangle. Side islands remain scenery, not a reason to shrink racers.
local function arenaCamera(width, height)
    local scale, ox, oy = viewportLayout(width, height)
    local area = screenRect(Layout.arena, scale, ox, oy)
    local tanV = math.tan(math.rad(50) / 2)
    local tanH = tanV * width / height
    local elevation = math.rad(52)
    local up, back = math.sin(elevation), math.cos(elevation)
    local centerY, distance = 26, 100
    local function project(x, y, z, d, shift)
        local localY = back * (y - centerY) - up * z
        local localZ = up * (y - centerY) + back * z
        local depth = d - localZ
        return width / 2 + x * width / (2 * tanH * depth),
            height / 2 - (localY + shift) * height / (2 * tanV * depth), depth
    end
    for _ = 1, 100 do
        local shift = (0.5 - (area.y + area.h / 2) / height) * 2 * distance * tanV
        local safe = true
        for _, x in ipairs({ -54, 54 }) do
            for _, y in ipairs({ -10, 60 }) do
                for _, z in ipairs({ -54, 54 }) do
                    local px, py, depth = project(x, y, z, distance, shift)
                    if depth <= 1 or px < area.x + 10 * scale or px > area.x + area.w - 10 * scale
                        or py < area.y + 10 * scale or py > area.y + area.h - 10 * scale then safe = false end
                end
            end
        end
        if safe then return distance, shift, up, back, centerY end
        distance = distance * 1.05
    end
    return distance, 0, up, back, centerY
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
local cameraTarget
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
    for i = 1, 3 do
        local y = 28 + (i - 1) * 25
        local username = text(container, "Name" .. i, i .. ". Waiting", { x = 10, y = y, w = 126, h = 23 }, 16)
        local score = text(container, "Score" .. i, "—", { x = 140, y = y, w = 60, h = 23 }, 16, mint)
        score.TextXAlignment, score.Font = Enum.TextXAlignment.Right, Enum.Font.GothamBold
        rows[i] = { name = username, score = score }
    end
    return container, rows
end
local earnerPanel, earners = board("TopEarners", "TOP EARNERS / $", Layout.earners)
local competitorPanel, competitors = board("RoundLeaders", "ROUND LEADERS / PT", Layout.competitors)
local notice = frame(canvas, "EventStrip", Layout.notice)
notice.Visible = false
local noticeText = text(notice, "Message", "", { x = 10, y = 2, w = 412, h = 24 }, 14, gold)
local noticeVersion = 0
local function notify(value)
    noticeVersion = noticeVersion + 1
    local version = noticeVersion
    noticeText.Text, notice.Visible = tostring(value), true
    task.delay(4, function() if noticeVersion == version then notice.Visible = false end end)
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
button(controls, "Join", "JOIN", { x = 290, y = 52, w = 126, h = 38 }, function() actionRemote:FireServer("join", input.Text) end)
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
text(controls, "Hint", "Testing only. All rounds advance automatically.", { x = 16, y = 312, w = 400, h = 24 }, 14, muted)
text(controls, "Hint2", "Gifts/follows are simulated. Progress resets on Stop.", { x = 16, y = 342, w = 400, h = 24 }, 13, muted)
text(controls, "Hint3", "Close tools to restore the leaderboard dock.", { x = 16, y = 372, w = 400, h = 24 }, 14, mint)
local keeper = button(canvas, "KeeperToggle", "TEST TOOLS", { x = 342, y = 18, w = 114, h = 30 }, function() showTools(not controls.Visible) end)
keeper.TextSize = 11
local cameraButton
local function setCamera(enabled)
    streamCamera = enabled
    if cameraButton then cameraButton.Text = enabled and "ROAM VIEW" or "STREAM VIEW" end
    local camera = workspace.CurrentCamera
    if camera and not enabled then
        camera.CameraType, camera.FieldOfView = Enum.CameraType.Custom, cameraDefaultFov
        camera.FieldOfViewMode = cameraDefaultFovMode
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then camera.CameraSubject = humanoid end
    elseif camera and cameraTarget then
        -- Apply the fitted view immediately; never sweep through the scene at boot.
        camera.CameraType, camera.FieldOfView, camera.CFrame = Enum.CameraType.Scriptable, 50, cameraTarget
        camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical
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

local lastGift, giftFocusUntil = 0, 0
snapshotRemote.OnClientEvent:Connect(function(state)
    latestState, receivedAt = state, os.clock()
    phase.Text = state.activity.name
    stats.Text = string.format("%s / %d TRAVELERS / %d SHARDS", state.demo and "DEMO" or "LOCAL CREW", #state.crew, state.wins)
    timingLabel.Text = ({ gathering = "NEXT ROUND", voting = "STARTS IN", storm = "TIME LEFT", result = "NEXT UP" })[state.phase]
    for i = 1, 3 do
        local earner = state.leaderboard[i]
        earners[i].name.Text = earner and (i .. ". " .. earner.username) or (i .. ". Waiting")
        earners[i].score.Text = earner and ("$" .. money(earner.money)) or "—"
        local row = state.phase == "result" and state.winners[i] or state.activityLeaders[i]
        competitors[i].name.Text = row and (i .. ". " .. row.username) or (i .. ". Ready")
        competitors[i].score.Text = row and (row.score .. " pt") or "—"
    end
    local champion = state.phase == "result" and state.winners[1]
    instruction.Text = champion and ("WINNER: " .. champion.username .. " / +$" .. money(champion.prize))
        or (state.phase == "voting" and "Choose the sky effect; all travelers compete." or state.activity.instruction)
    ward.Visible, sail.Visible = state.phase == "voting", state.phase == "voting"
    roundStatus.Visible = state.phase ~= "voting"
    ward.Text, sail.Text = "WARD / " .. state.ward, "SAIL / " .. state.sail
    local lead = state.leaderboard[1]
    local income = lead and (lead.username .. " $" .. (state.earning and lead.perSecond or 0) .. "/s") or "Waiting for travelers"
    roundStatus.Text = champion and (champion.score .. " pt / " .. (state.success and "SHARD SAVED" or "ROUND COMPLETE"))
        or (state.phase == "storm" and string.format("TEAM %d/%d / %s", state.teamScore, state.teamTarget, income) or income)
    progressFill.Size = UDim2.fromScale(state.teamTarget > 0 and math.min(1, state.teamScore / state.teamTarget) or 0, 1)
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
local function resize()
    local camera = workspace.CurrentCamera
    if not camera or camera.ViewportSize.X <= 0 or camera.ViewportSize.Y <= 0 then return end
    local width, height = camera.ViewportSize.X, camera.ViewportSize.Y
    canvasScale.Scale = viewportLayout(width, height)
    local distance, shift, up, back, centerY = arenaCamera(width, height)
    local focus = Vector3.new(0, centerY, 0)
    cameraTarget = CFrame.lookAt(focus + Vector3.new(0, up * distance, back * distance), focus) * CFrame.new(0, -shift, 0)
    if streamCamera and gui.Enabled then setCamera(true) end
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
RunService:BindToRenderStep("RiftboundPortraitCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if latestState then timer.Text = tostring(math.max(0, math.ceil(latestState.seconds - (os.clock() - receivedAt)))) end
    if streamCamera and gui.Enabled and workspace.CurrentCamera and cameraTarget then
        local camera = workspace.CurrentCamera
        camera.CameraType, camera.FieldOfView, camera.CFrame = Enum.CameraType.Scriptable, 50, cameraTarget
    end
    labelAccumulator = labelAccumulator + dt
    if labelAccumulator >= 0.12 then labelAccumulator = 0; updateLabels(os.clock()) end
end)
```
