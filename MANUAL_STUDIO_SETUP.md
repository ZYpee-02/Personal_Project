# Riftbound Live: install five separate scripts manually

Use the Script Editor and Explorer. Do not paste this document or any script into
the Command Bar. There is no generated installer or serialized source wrapper.

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
9. Open **Keeper Tools**, enter `Alice_01`, and click **Open the Star Gate**. Repeat
   with `Bobby_02`. Usernames label locally built avatars; no account is fetched.
10. Click **Awaken a Storm**. Use the main Ward/Sail buttons for your player, or
    enter a joined username in Keeper Tools and use **Vote as: Ward / Sail**.
    Watch balances/leaderboards during voting and the storm. Base income is $5/s;
    voting adds $3/s that round. Successful rounds add $2/s for subsequent rounds.
11. With a joined username in the input, try **Gift bloom**, **Gift aurora** and
    **Gift giant**. They expire after 18 seconds and do not change income or votes.
    **Simulate Follow** counts a session-only follow. All events are offline demos.
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
    GatheringSeconds = 55,
    VotingSeconds = 35,
    StormSeconds = 12,
    ResultSeconds = 12,
    MaxCrew = 18,
    MaxQueuedArrivals = 30,
}
```

### RealmState.lua

Create a **ModuleScript** named **RealmState** under **ServerScriptService**.

```luau
-- Pure Lua domain logic, shared by the Roblox server and the automated tests.
local Realm = {}
Realm.__index = Realm

function Realm.new(config, now)
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
    }
    table.insert(self.crewOrder, key)
    self.message = username .. " stepped through the star gate."
    return true, self.crew[key]
end

function Realm:rate(member)
    return math.min(self.config.MaxMoneyPerSecond or 100,
        (self.config.BaseMoneyPerSecond or 5) + self.wins * (self.config.WinMoneyPerSecond or 2)
        + (member.participated and (self.config.VoteMoneyPerSecond or 3) or 0))
end

function Realm:tick(now)
    if now <= self.lastTick then return end
    -- Split at the phase boundary so a delayed heartbeat never pays for result time.
    local earningEnd = math.min(now, self.deadline)
    local elapsed = math.max(0, earningEnd - self.lastTick)
    if self.phase == "voting" or self.phase == "storm" then
        for _, key in ipairs(self.crewOrder) do
            local member = self.crew[key]
            local amount = math.min(self:rate(member) * elapsed, (self.config.MaxBalance or 1000000000) - member.balance)
            member.balance = member.balance + amount
            member.roundMoney = member.roundMoney + amount
        end
    end
    self.lastTick = now
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
        self.votes = {}
        self.totals = { ward = 0, sail = 0 }
        for _, key in ipairs(self.crewOrder) do
            self.crew[key].roundMoney = 0
            self.crew[key].participated = false
        end
        self.requiredVotes = math.max(1, math.ceil(#self.crewOrder / 3))
        self.deadline = now + self.config.VotingSeconds
        self.message = "A storm rift is opening. Raise a ward, or sail through it?"
    elseif self.phase == "voting" then
        self.phase = "storm"
        self.choice = self.totals.sail > self.totals.ward and "sail" or "ward"
        self.success = self.totals.ward + self.totals.sail >= self.requiredVotes
        self.deadline = now + self.config.StormSeconds
        self.message = self.choice == "ward" and "The crew raises a starlight ward!" or "The island rides the storm winds!"
    elseif self.phase == "storm" then
        self.phase = "result"
        self.lastRound = self:leaderboard(true)
        self.storms = self.storms + 1
        if self.success then self.wins = self.wins + 1 end
        self.deadline = now + self.config.ResultSeconds
        self.message = self.success and "Together, you saved a star shard. Your realm grows!"
            or "The rift faded. Gather more voices for the next crossing."
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
        })
    end
    local lastRound = {}
    for _, row in ipairs(self.lastRound) do
        table.insert(lastRound, { username = row.username, money = row.money, perSecond = row.perSecond, gifts = row.gifts, slot = row.slot })
    end
    return {
        phase = self.phase, seconds = math.max(0, math.ceil(self.deadline - now)),
        round = self.round, crew = crew, wins = self.wins, storms = self.storms,
        ward = self.totals.ward, sail = self.totals.sail, requiredVotes = self.requiredVotes,
        choice = self.choice, success = self.success, message = self.message,
        blessing = now < self.blessingUntil and self.blessing or "",
        members = members, leaderboard = self:leaderboard(false), roundLeaders = self:leaderboard(true),
        lastRound = lastRound, followers = self.followerCount,
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
    gui.Name, gui.Size = "Caption", UDim2.fromOffset(width or 300, 55)
    gui.StudsOffset, gui.MaxDistance = offset or Vector3.new(0, 5, 0), 170
    gui.AlwaysOnTop = false
    gui.Parent = adornee
    local t = Instance.new("TextLabel")
    t.Size, t.BackgroundTransparency = UDim2.fromScale(1, 1), 1
    t.Font, t.TextSize = Enum.Font.GothamBold, 16
    t.Text, t.TextColor3 = text, color or colors.mint
    t.TextStrokeTransparency = 0.65
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

function World.build()
    root = Instance.new("Folder")
    root.Name, root.Parent = "RiftboundRealm", workspace
    Lighting.ClockTime, Lighting.Brightness = 18.3, 2
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
    local scoreAnchor = part("Round leaderboard", Vector3.new(1, 1, 1), CFrame.new(0, 62, 7), colors.gold)
    scoreAnchor.Transparency, scoreAnchor.CanCollide = 1, false
    local scoreGui = Instance.new("BillboardGui")
    scoreGui.Size, scoreGui.MaxDistance, scoreGui.Parent = UDim2.fromOffset(520, 210), 200, scoreAnchor
    scoreText = Instance.new("TextLabel")
    scoreText.Size, scoreText.BackgroundTransparency = UDim2.fromScale(1, 1), 1
    scoreText.Font, scoreText.TextSize, scoreText.TextColor3 = Enum.Font.GothamBold, 23, colors.gold
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
    return model
end

function World.arrive(model, slot, username)
    model.Name = "Traveler_" .. username
    model:PivotTo(CFrame.new(0, 38, -25))
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.WalkSpeed = 0
    end
    local rootPart = model:FindFirstChild("HumanoidRootPart")
    if rootPart then rootPart.Anchored = true end
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
        if p:IsA("Script") or p:IsA("LocalScript") or p:IsA("Tool") then p:Destroy() end
    end
    model.Parent = root
    if model:FindFirstChild("Head") then label(model.Head, username .. "\n$0 | $5/s", Vector3.new(0, 3, 0), colors.gold, 240) end
    avatars[string.lower(username)] = model
    local cf = Instance.new("CFrameValue")
    cf.Value = model:GetPivot()
    local connection = cf.Changed:Connect(function(value)
        if model.Parent then model:PivotTo(value) end
    end)
    local tween = TweenService:Create(cf, TweenInfo.new(2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Value = World.crewPosition(slot) })
    tween:Play()
    tween.Completed:Once(function() connection:Disconnect(); cf:Destroy() end)
end

function World.render(state, now)
    local storm = state.phase == "storm"
    rift.Transparency = storm and 0.25 or (state.phase == "voting" and 0.55 or 0.9)
    rift.CFrame = CFrame.new(0, 90 + math.sin(now) * 2, -50) * CFrame.Angles(now * 0.12, now * 0.2, 0)
    core.CFrame = CFrame.new(0, 42 + math.sin(now * 1.2) * 0.6, 0) * CFrame.Angles(0, now * 0.3, 0.12)
    shield.Transparency = (storm and state.choice == "ward") and 0.85 or 1
    gate.Transparency = 0.6 + math.sin(now) * 0.1
    Lighting.ClockTime = storm and 0.5 or 18.3
    local leaders = state.phase == "result" and state.lastRound or state.roundLeaders
    local lines = { "TOP EARNERS", state.phase == "result" and "LAST ROUND" or "THIS ROUND" }
    for i = 1, math.min(3, #(leaders or {})) do
        local row = leaders[i]
        table.insert(lines, string.format("%d. %s  $%d", i, row.username, math.floor(row.money)))
    end
    scoreText.Text = table.concat(lines, "\n")
    for _, p in ipairs(constellation:GetChildren()) do p.Transparency = state.blessing == "Titan constellation" and 0 or 1 end
    for _, p in ipairs(bloom:GetChildren()) do p.Transparency = state.blessing == "Starbloom" and 0 or 1 end
    for i, p in ipairs(winds:GetChildren()) do
        p.Transparency = (storm and state.choice == "sail") and 0.35 or 1
        p.CFrame = CFrame.new((i - 7) * 8, 39 + (i % 4) * 4, ((now * 35 + i * 11) % 120) - 60)
    end
    if state.blessing == "Aurora veil" then
        Lighting.Ambient = Color3.fromHSV((now * 0.025) % 1, 0.4, 0.75)
    else
        Lighting.Ambient = Color3.fromRGB(111, 109, 148)
    end
    for _, member in ipairs(state.members or {}) do
        local model = avatars[string.lower(member.username)]
        if model then
            local head = model:FindFirstChild("Head")
            local caption = head and head:FindFirstChild("Caption")
            local captionText = caption and caption:FindFirstChildOfClass("TextLabel")
            if captionText then
                captionText.Text = string.format("%s\n$%d | $%d/s", member.username, math.floor(member.balance), member.perSecond)
            end
            local aura = model:FindFirstChild("GiftAura")
            if aura then
                aura.Enabled = member.effect ~= ""
                aura.OutlineColor = member.effect == "aurora" and Color3.fromHSV((now * 0.1) % 1, 0.5, 1) or colors.gold
            end
            local targetScale = member.effect == "giant" and 1.65 or 1
            if model:GetAttribute("GiftScale") ~= targetScale then
                model:ScaleTo(targetScale)
                model:SetAttribute("GiftScale", targetScale)
            end
        end
    end
    -- A capped garden records this session's star shards; all data resets on Stop.
    local target = math.min(24, state.wins)
    for i = #monuments + 1, target do
        local a = i * 2.399
        local p = crystal(Vector3.new(87 + math.cos(a) * 13, 41, 21 + math.sin(a) * 13), 0.5 + (i % 3) * 0.2, colors.gold)
        table.insert(monuments, p)
    end
end

return World
```

### Realm.server.lua

Create a **Script** named **Realm** under **ServerScriptService**.

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)
local Realm = require(script.Parent.RealmState)
local World = require(script.Parent.World)
local state = Realm.new(Config, os.clock())

local remotes = Instance.new("Folder")
remotes.Name, remotes.Parent = "Riftbound", ReplicatedStorage
local snapshotRemote = Instance.new("RemoteEvent")
snapshotRemote.Name, snapshotRemote.Parent = "Snapshot", remotes
local actionRemote = Instance.new("RemoteEvent")
actionRemote.Name, actionRemote.Parent = "Action", remotes
local noticeRemote = Instance.new("RemoteEvent")
noticeRemote.Name, noticeRemote.Parent = "Notice", remotes

World.build()
local tasks = {}
local lastAction = {}
assert(Config.PersistenceEnabled == false, "This build supports session-only testing.")

local function host(player)
    if RunService:IsStudio() then return true end
    if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
    for _, id in ipairs(Config.HostUserIds) do if player.UserId == id then return true end end
    return false
end

local function publish()
    local snapshot = state:snapshot(os.clock())
    snapshot.persistence, snapshot.bridge = "memory only", "offline simulator"
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
    if type(event) ~= "table" then return false, "An event table is required." end
    local completed, accepted, message = false, false, "Queue full."
    if not enqueue(event, function(ok, result) accepted, message, completed = ok, result, true end) then return false, message end
    while not completed do task.wait(0.1) end
    return accepted, message
end

task.spawn(function()
    while true do
        local item = table.remove(tasks, 1)
        if item then
            local ok, applied, message = pcall(apply, item.event)
            if not ok then
                warn("Riftbound event failed; inspect the server output.")
                applied, message = false, "The island could not apply this event. Try again later."
            end
            if not applied then state.message = message end
            if item.done then item.done(applied, message) end
            publish()
            task.wait(0.35)
        else task.wait(0.2) end
    end
end)

local function playerAdded(player)
    player:SetAttribute("RiftboundHost", host(player))
    enqueue({ type = "join", username = player.Name }, function(_, message) notify(player, message) end)
end
Players.PlayerAdded:Connect(playerAdded)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(playerAdded, player) end
Players.PlayerRemoving:Connect(function(player) lastAction[player.UserId] = nil end)

actionRemote.OnServerEvent:Connect(function(player, action, payload)
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
    publish()
end)

task.spawn(function()
    while true do
        local now = os.clock()
        state:tick(now)
        state:advance(now)
        publish()
        World.render(state:snapshot(now), now)
        task.wait(1)
    end
end)
```

### Realm.client.lua

Create a **LocalScript** named **Realm** under **StarterPlayer → StarterPlayerScripts**.

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Riftbound")
local snapshotRemote = remotes:WaitForChild("Snapshot")
local actionRemote = remotes:WaitForChild("Action")
local noticeRemote = remotes:WaitForChild("Notice")
local ink = Color3.fromRGB(17, 27, 43)
local pale = Color3.fromRGB(232, 240, 236)
local muted = Color3.fromRGB(160, 181, 190)
local mint = Color3.fromRGB(127, 239, 204)
local gold = Color3.fromRGB(245, 211, 155)

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.ZIndexBehavior = "RiftboundHUD", false, Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function round(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius, corner.Parent = UDim.new(0, radius or 16), object
end
local function frame(parent, size, position, anchor)
    local f = Instance.new("Frame")
    f.Size, f.Position, f.AnchorPoint = size, position, anchor or Vector2.new(0, 0)
    f.BackgroundColor3, f.BackgroundTransparency, f.BorderSizePixel = ink, 0.12, 0
    f.Parent = parent
    round(f)
    local stroke = Instance.new("UIStroke")
    stroke.Color, stroke.Transparency, stroke.Parent = muted, 0.78, f
    return f
end
local function text(parent, value, size, position, textSize, color)
    local t = Instance.new("TextLabel")
    t.Size, t.Position, t.BackgroundTransparency = size, position, 1
    t.Text, t.Font, t.TextSize, t.TextColor3 = value, Enum.Font.Gotham, textSize or 15, color or pale
    t.TextXAlignment, t.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Center
    t.TextWrapped, t.Parent = true, parent
    return t
end
local function button(parent, value, size, position, callback)
    local b = Instance.new("TextButton")
    b.Size, b.Position, b.BackgroundColor3, b.BorderSizePixel = size, position, Color3.fromRGB(41, 67, 76), 0
    b.Text, b.Font, b.TextSize, b.TextColor3 = value, Enum.Font.GothamBold, 15, pale
    b.AutoButtonColor, b.Parent = true, parent
    round(b, 12)
    b.Activated:Connect(callback)
    return b
end
local function scale(parent)
    local s = Instance.new("UIScale")
    s.Parent = parent
    return s
end

local title = frame(gui, UDim2.fromOffset(370, 106), UDim2.fromOffset(24, 20))
local titleScale = scale(title)
text(title, "R I F T B O U N D   /   L I V E", UDim2.fromOffset(330, 22), UDim2.fromOffset(20, 13), 13, gold)
local phase = text(title, "THE QUIET BETWEEN STORMS", UDim2.fromOffset(330, 30), UDim2.fromOffset(20, 37), 19)
phase.Font = Enum.Font.GothamBold
local timer = text(title, "Welcome to your sky island", UDim2.fromOffset(330, 23), UDim2.fromOffset(20, 74), 13, muted)

local ledger = frame(gui, UDim2.fromOffset(236, 106), UDim2.new(1, -24, 0, 20), Vector2.new(1, 0))
local ledgerScale = scale(ledger)
text(ledger, "THE SKY GARDEN", UDim2.fromOffset(200, 22), UDim2.fromOffset(18, 13), 12, gold)
local totals = text(ledger, "0 shards  /  0 travelers", UDim2.fromOffset(200, 30), UDim2.fromOffset(18, 37), 17)
local connection = text(ledger, "Studio demo · session only", UDim2.fromOffset(200, 26), UDim2.fromOffset(18, 70), 11, muted)

local panel = frame(gui, UDim2.fromOffset(680, 188), UDim2.new(0.5, 0, 1, -22), Vector2.new(0.5, 1))
local panelScale = scale(panel)
text(panel, "YOUR VOICE SHAPES THIS WORLD", UDim2.fromOffset(630, 20), UDim2.fromOffset(24, 14), 11, gold)
local message = text(panel, "Travelers are gathering around the heartseed.", UDim2.fromOffset(630, 46), UDim2.fromOffset(24, 39), 16)
local ward = button(panel, "01   RAISE A WARD", UDim2.fromOffset(307, 48), UDim2.fromOffset(24, 92), function() actionRemote:FireServer("vote", "ward") end)
local sail = button(panel, "02   SAIL THE RIFT", UDim2.fromOffset(307, 48), UDim2.fromOffset(349, 92), function() actionRemote:FireServer("vote", "sail") end)
local progress = text(panel, "Voting opens when the rift awakens. No gifts required.", UDim2.fromOffset(630, 24), UDim2.fromOffset(24, 150), 12, muted)

local toast = frame(gui, UDim2.fromOffset(530, 52), UDim2.new(0.5, 0, 0, 142), Vector2.new(0.5, 0))
local toastScale = scale(toast)
toast.Visible = false
local toastText = text(toast, "", UDim2.new(1, -28, 1, 0), UDim2.fromOffset(14, 0), 14, mint)
local toastVersion = 0
local function notify(value)
    toastVersion = toastVersion + 1
    local version = toastVersion
    toastText.Text, toast.Visible = tostring(value), true
    task.delay(5, function() if toastVersion == version then toast.Visible = false end end)
end
noticeRemote.OnClientEvent:Connect(notify)

local controls = frame(gui, UDim2.fromOffset(300, 474), UDim2.new(1, -24, 0, 190), Vector2.new(1, 0))
local controlsScale = scale(controls)
controls.Visible = false
text(controls, "REALM KEEPER / DEMO", UDim2.fromOffset(260, 24), UDim2.fromOffset(20, 16), 12, gold)
text(controls, "Username labels spawn local stand-in avatars. No account lookup.", UDim2.fromOffset(260, 36), UDim2.fromOffset(20, 46), 13, muted)
local input = Instance.new("TextBox")
input.Size, input.Position = UDim2.fromOffset(260, 42), UDim2.fromOffset(20, 92)
input.BackgroundColor3, input.TextColor3 = Color3.fromRGB(31, 45, 61), pale
input.Font, input.TextSize, input.Text = Enum.Font.Gotham, 15, ""
input.PlaceholderText, input.ClearTextOnFocus, input.Parent = "Roblox username", false, controls
round(input, 10)
button(controls, "OPEN THE STAR GATE", UDim2.fromOffset(260, 40), UDim2.fromOffset(20, 144), function()
    actionRemote:FireServer("join", input.Text)
end)
button(controls, "AWAKEN A STORM", UDim2.fromOffset(260, 40), UDim2.fromOffset(20, 194), function()
    actionRemote:FireServer("rift", "")
end)
for i, item in ipairs({ { "Bloom", "bloom" }, { "Aurora", "aurora" }, { "Titan", "giant" } }) do
    button(controls, item[1], UDim2.fromOffset(80, 40), UDim2.fromOffset(20 + (i - 1) * 90, 246), function()
        actionRemote:FireServer("blessing", item[2])
    end)
end
for i, item in ipairs({ { "Gift bloom", "giftBloom" }, { "Gift aurora", "giftAurora" }, { "Gift giant", "giftGiant" } }) do
    button(controls, item[1], UDim2.fromOffset(80, 38), UDim2.fromOffset(20 + (i - 1) * 90, 294), function()
        actionRemote:FireServer(item[2], input.Text)
    end)
end
button(controls, "Vote as: WARD", UDim2.fromOffset(125, 38), UDim2.fromOffset(20, 342), function()
    actionRemote:FireServer("demoWard", input.Text)
end)
button(controls, "Vote as: SAIL", UDim2.fromOffset(125, 38), UDim2.fromOffset(155, 342), function()
    actionRemote:FireServer("demoSail", input.Text)
end)
button(controls, "SIMULATE FOLLOW", UDim2.fromOffset(260, 38), UDim2.fromOffset(20, 390), function()
    actionRemote:FireServer("follow", input.Text)
end)
text(controls, "Gift / vote / follow target: the username above. All events are simulated.", UDim2.fromOffset(260, 30), UDim2.fromOffset(20, 436), 11, muted)
local keeper = button(gui, "KEEPER TOOLS", UDim2.fromOffset(160, 42), UDim2.new(1, -24, 0, 138), function()
    controls.Visible = not controls.Visible
end)
keeper.AnchorPoint = Vector2.new(1, 0)
local keeperScale = scale(keeper)
local function updateHost()
    keeper.Visible = player:GetAttribute("RiftboundHost") == true
    if not keeper.Visible then controls.Visible = false end
end
player:GetAttributeChangedSignal("RiftboundHost"):Connect(updateHost)
updateHost()

local board = frame(gui, UDim2.fromOffset(300, 296), UDim2.fromOffset(24, 156))
local boardScale = scale(board)
text(board, "LIVE TOP EARNERS", UDim2.fromOffset(260, 24), UDim2.fromOffset(20, 12), 13, gold)
local rows = {}
for i = 1, 5 do
    rows[i] = text(board, i .. ". Waiting for travelers", UDim2.fromOffset(260, 38), UDim2.fromOffset(20, 42 + (i - 1) * 42), 12, pale)
end
local boardFooter = text(board, "Session money / money per second", UDim2.fromOffset(260, 34), UDim2.fromOffset(20, 253), 11, muted)

local phaseNames = { gathering = "THE QUIET BETWEEN STORMS", voting = "THE RIFT IS CALLING", storm = "HOLD FAST, TRAVELERS", result = "A NEW PAGE IN YOUR LEGEND" }
snapshotRemote.OnClientEvent:Connect(function(state)
    phase.Text = phaseNames[state.phase] or "RIFTBOUND LIVE"
    timer.Text = string.format("Chapter %02d   /   %ds until the next horizon", state.round, state.seconds)
    totals.Text = string.format("%d shards  /  %d travelers", state.wins, #state.crew)
    connection.Text = state.bridge .. " · " .. state.persistence
    message.Text = state.blessing ~= "" and (state.blessing .. " lights the sky. " .. state.message) or state.message
    if state.phase == "result" and state.lastRound[1] then
        message.Text = string.format("TOP THIS ROUND: %s / $%d. %s", state.lastRound[1].username, math.floor(state.lastRound[1].money), state.message)
    end
    for i, row in ipairs(rows) do
        local entry = state.leaderboard[i]
        row.Text = entry and string.format("%d. %s  /  $%d\n$%d/s  |  %d simulated gifts", i, entry.username, math.floor(entry.money), entry.perSecond, entry.gifts)
            or (i .. ". Waiting for travelers")
    end
    boardFooter.Text = string.format("%d follows / session only\nMoney accrues during voting + storm.", state.followers)
    ward.Text = "01   RAISE A WARD   ·   " .. state.ward
    sail.Text = "02   SAIL THE RIFT   ·   " .. state.sail
    local voting = state.phase == "voting"
    ward.BackgroundColor3 = voting and Color3.fromRGB(39, 99, 89) or Color3.fromRGB(37, 47, 61)
    sail.BackgroundColor3 = voting and Color3.fromRGB(83, 62, 113) or Color3.fromRGB(37, 47, 61)
    progress.Text = voting and string.format("%d / %d voices to save a shard. You can change your vote. Gifts are cosmetic.", state.ward + state.sail, state.requiredVotes)
        or "Vote during the next rift. Every voice counts; no gifts required."
end)

local function resize()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local view = camera.ViewportSize
    local factor = math.min(1, (view.X - 24) / 680, (view.Y - 24) / 900)
    factor = math.max(0.35, factor)
    for _, s in ipairs({ titleScale, ledgerScale, panelScale, controlsScale, toastScale, keeperScale, boardScale }) do s.Scale = factor end
    title.Position = UDim2.fromOffset(12, 12)
    ledger.Position = UDim2.new(1, -12, 0, 12)
    keeper.Position = UDim2.new(1, -12, 0, 126 * factor)
    controls.Position = UDim2.new(1, -12, 0, 176 * factor)
    toast.Position = UDim2.new(0.5, 0, 0, 126 * factor)
    board.Position = UDim2.fromOffset(12, 176 * factor)
end
local cameraConnection
local function bindCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    if workspace.CurrentCamera then cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
    resize()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()
```
