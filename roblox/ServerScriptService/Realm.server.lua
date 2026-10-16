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
