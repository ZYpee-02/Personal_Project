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
    for _, name in ipairs({ "build", "render", "animate", "offlineAvatar", "arrive", "sprintStep", "loadAppearance", "cameraBounds" }) do
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
        PersistenceEnabled = false, AutoJoinPlayers = true, SprintOnly = true, SprintCompetitors = 5, SprintRaceSeconds = 80,
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
    range("SprintRaceSeconds", 10, 600)
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
    for _, name in ipairs({ "AutoActivities", "OfflineDemoEnabled", "DemoStudioOnly", "AutoSimulateGifts", "StreamCameraDefault", "SprintOnly", "LoadAvatarAppearances", "AutoJoinPlayers" }) do
        assert(type(Config[name]) == "boolean", "Config." .. name .. " must be true or false")
    end
    assert(type(Config.DemoAppearanceUserIds) == "table", "DemoAppearanceUserIds must be a table")
    for _, id in ipairs(Config.DemoAppearanceUserIds) do assert(type(id) == "number" and id > 0 and id < 9007199254740991 and id == math.floor(id), "Appearance IDs must be positive whole numbers") end
    assert(type(Config.HostUserIds) == "table" and type(Config.DemoNames) == "table" and type(Config.RoundPrizes) == "table", "HostUserIds, DemoNames and RoundPrizes must be tables")
    for i, name in ipairs(Config.DemoNames) do assert(type(name) == "string" and #name >= 3 and #name <= 20 and string.match(name, "^[%w_]+$"), "DemoNames contains an invalid username label") end
    for i = 1, 3 do assert(type(Config.RoundPrizes[i]) == "number" and Config.RoundPrizes[i] >= 0 and Config.RoundPrizes[i] <= 1000000, "RoundPrizes needs three finite nonnegative amounts") end
    stage("Creating RealmState")
    local state = Realm.new(Config, os.clock())
    for _, name in ipairs({ "tick", "advance", "snapshot", "addCrew", "vote", "gift", "follow", "bless", "recordCheckpoint", "raceDistance", "raceComplete", "raceDNF" }) do
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
        World.render(snapshot, now)
        snapshotRemote:FireAllClients(snapshot)
    end

    local function notify(player, message)
        if player and player.Parent then noticeRemote:FireClient(player, message) end
    end

    local function arrival(username, appearanceUserId)
        if type(username) ~= "string" or #username < 3 or #username > 20 or not string.match(username, "^[%w_]+$") then
            return false, "Enter a Roblox username, not a display name."
        end
        if state.crew[string.lower(username)] then return false, "That traveler is already here." end
        if #state.crewOrder >= Config.MaxCrew then return false, "The island is full for this session." end
        local userId = type(appearanceUserId) == "number" and appearanceUserId or 0 -- appearance source only, never a LIVE identity.
        local model = World.offlineAvatar(username)
        state:tick(os.clock())
        local added, member = state:addCrew(username, userId)
        if not added then model:Destroy(); return false, member end
        World.arrive(model, member.slot, username)
        World.loadAppearance(username, userId)
        return true, username .. " arrived through the star gate."
    end

    local function apply(event)
        if event.type == "join" then return arrival(event.username, event.appearanceUserId) end
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
        for i, name in ipairs(Config.DemoNames) do
            if not running then return end
            enqueue({ type = "join", username = name, appearanceUserId = Config.DemoAppearanceUserIds[i] })
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
