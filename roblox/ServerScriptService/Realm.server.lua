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
