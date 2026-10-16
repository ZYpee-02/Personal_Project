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
local function arenaCamera(width, height, bounds)
    local scale, ox, oy = viewportLayout(width, height)
    local area = screenRect(Layout.arena, scale, ox, oy)
    local tanV = math.tan(math.rad(50) / 2)
    local tanH = tanV * width / height
    local elevation = math.rad(52)
    local up, back = math.sin(elevation), math.cos(elevation)
    local centerY, distance = bounds and (bounds.minY + bounds.maxY) / 2 or 26, 100
    local centerX, centerZ = bounds and (bounds.minX + bounds.maxX) / 2 or 0, bounds and (bounds.minZ + bounds.maxZ) / 2 or 0
    local yaw = math.rad(bounds and bounds.yaw or 0)
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
    for _ = 1, 100 do
        local shift = (0.5 - (area.y + area.h / 2) / height) * 2 * distance * tanV
        local safe = true
        for _, x in ipairs({ bounds and bounds.minX or -54, bounds and bounds.maxX or 54 }) do
            for _, y in ipairs({ bounds and bounds.minY or -10, bounds and bounds.maxY or 60 }) do
                for _, z in ipairs({ bounds and bounds.minZ or -54, bounds and bounds.maxZ or 54 }) do
                    local px, py, depth = project(x, y, z, distance, shift)
                    if depth <= 1 or px < area.x + 10 * scale or px > area.x + area.w - 10 * scale
                        or py < area.y + 10 * scale or py > area.y + area.h - 10 * scale then safe = false end
                end
            end
        end
        if safe then return distance, shift, up, back, centerY, centerX, centerZ, yaw end
        distance = distance * 1.05
    end
    return distance, 0, up, back, centerY, centerX, centerZ, yaw
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
local competitorPanel, competitors = board("RoundLeaders", "ROUND LEADERS", Layout.competitors)
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
    local changedCamera = not latestState or latestState.physicalSprint ~= state.physicalSprint
    latestState, receivedAt = state, os.clock()
    if changedCamera and resize then resize() end
    competitorPanel.Title.Text = state.physicalSprint and "SPRINT / TIME" or "ROUND LEADERS / PT"
    phase.Text = state.activity.name
    stats.Text = string.format("%s / %d TRAVELERS / %d SHARDS", state.demo and "DEMO" or "LOCAL CREW", #state.crew, state.wins)
    timingLabel.Text = ({ gathering = "NEXT ROUND", voting = "STARTS IN", storm = "TIME LEFT", result = "NEXT UP" })[state.phase]
    for i = 1, 3 do
        local earner = state.leaderboard[i]
        earners[i].name.Text = earner and (i .. ". " .. earner.username) or (i .. ". Waiting")
        earners[i].score.Text = earner and ("$" .. money(earner.money)) or "—"
        local row = state.phase == "result" and (state.winners[i] or state.activityLeaders[i]) or state.activityLeaders[i]
        competitors[i].name.Text = row and ((row.placement and row.placement > 0 and row.placement or i) .. ". " .. row.username) or (i .. ". Ready")
        competitors[i].score.Text = row and (state.physicalSprint and (row.finishedAt > 0 and string.format("%.2fs", row.elapsed) or (row.status == "dnf" and "DNF" or row.score .. "/12")) or row.score .. " pt") or "—"
    end
    local champion = state.phase == "result" and state.winners[1]
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
resize = function()
    local camera = workspace.CurrentCamera
    if not camera or camera.ViewportSize.X <= 0 or camera.ViewportSize.Y <= 0 then return end
    local width, height = camera.ViewportSize.X, camera.ViewportSize.Y
    canvasScale.Scale = viewportLayout(width, height)
    local distance, shift, up, back, centerY, cx, cz, yaw = arenaCamera(width, height, latestState and latestState.cameraBounds)
    local focus = Vector3.new(cx, centerY, cz)
    cameraTarget = CFrame.lookAt(focus + Vector3.new(math.sin(yaw) * back * distance, up * distance, math.cos(yaw) * back * distance), focus) * CFrame.new(0, -shift, 0)
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
