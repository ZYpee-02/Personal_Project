local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
gui.IgnoreGuiInset = true
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

-- All stream graphics stay inside this centered 9:16 canvas, even in landscape.
local canvas = Instance.new("Frame")
canvas.Name, canvas.Size = "VerticalStreamCanvas", UDim2.fromOffset(480, 854)
canvas.AnchorPoint, canvas.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
canvas.BackgroundTransparency, canvas.Parent = 1, gui
local canvasScale = scale(canvas)
local latestState
local receivedAt = 0
local streamCamera = player:GetAttribute("RiftboundStreamCamera") ~= false
local cameraDefaultFov = 70

local function money(value)
    if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
    if value >= 1000 then return string.format("%.1fK", value / 1000) end
    return tostring(math.floor(value))
end

local header = frame(canvas, UDim2.fromOffset(432, 82), UDim2.fromOffset(24, 56))
text(header, "RIFTBOUND / LIVE", UDim2.fromOffset(290, 22), UDim2.fromOffset(16, 8), 20, gold).Font = Enum.Font.GothamBlack
local phase = text(header, "THE ISLAND IS AWAKENING", UDim2.fromOffset(305, 25), UDim2.fromOffset(16, 34), 14, mint)
local stats = text(header, "AUTOPLAY / LOCAL DEMO", UDim2.fromOffset(305, 18), UDim2.fromOffset(16, 59), 11, muted)
local timer = text(header, "12", UDim2.fromOffset(82, 48), UDim2.fromOffset(334, 4), 35, gold)
timer.TextXAlignment, timer.Font = Enum.TextXAlignment.Center, Enum.Font.GothamBlack
local timingLabel = text(header, "NEXT ROUND", UDim2.fromOffset(90, 22), UDim2.fromOffset(330, 50), 10, muted)
timingLabel.TextXAlignment = Enum.TextXAlignment.Center

local function board(value, x)
    local container = frame(canvas, UDim2.fromOffset(210, 168), UDim2.fromOffset(x, 148))
    text(container, value, UDim2.fromOffset(186, 24), UDim2.fromOffset(12, 6), 14, gold).Font = Enum.Font.GothamBold
    local rows = {}
    for i = 1, 3 do
        local name = text(container, i .. ". Waiting", UDim2.fromOffset(186, 19), UDim2.fromOffset(12, 35 + (i - 1) * 42), 13)
        name.TextTruncate, name.TextWrapped = Enum.TextTruncate.AtEnd, false
        local score = text(container, "—", UDim2.fromOffset(186, 20), UDim2.fromOffset(12, 53 + (i - 1) * 42), 16, mint)
        score.Font = Enum.Font.GothamBold
        rows[i] = { name = name, score = score }
    end
    return rows
end
local earners = board("TOP EARNERS", 24)
local competitors = board("ROUND LEADERS", 246)

local banner = frame(canvas, UDim2.fromOffset(432, 106), UDim2.fromOffset(24, 330))
banner.Visible = false
text(banner, "ROUND CHAMPION", UDim2.fromOffset(400, 22), UDim2.fromOffset(16, 8), 12, gold)
local champion = text(banner, "", UDim2.fromOffset(400, 35), UDim2.fromOffset(16, 30), 27, mint)
champion.Font = Enum.Font.GothamBlack
local prize = text(banner, "", UDim2.fromOffset(400, 28), UDim2.fromOffset(16, 68), 14)
local toast = frame(canvas, UDim2.fromOffset(432, 62), UDim2.fromOffset(24, 444))
toast.Visible = false
local toastText = text(toast, "", UDim2.new(1, -28, 1, 0), UDim2.fromOffset(14, 0), 15, gold)
local toastVersion = 0
local function notify(value)
    toastVersion = toastVersion + 1
    local version = toastVersion
    toastText.Text, toast.Visible = tostring(value), true
    task.delay(4, function() if toastVersion == version then toast.Visible = false end end)
end
noticeRemote.OnClientEvent:Connect(notify)

local panel = frame(canvas, UDim2.fromOffset(432, 120), UDim2.fromOffset(24, 564))
local instruction = text(panel, "Travelers enter and compete automatically.", UDim2.fromOffset(400, 38), UDim2.fromOffset(16, 6), 14)
local progressTrack = frame(panel, UDim2.fromOffset(400, 6), UDim2.fromOffset(16, 50))
local progressFill = Instance.new("Frame")
progressFill.Size, progressFill.BackgroundColor3, progressFill.BorderSizePixel = UDim2.fromScale(0, 1), mint, 0
progressFill.Parent = progressTrack
round(progressFill, 3)
local ward = button(panel, "WARD", UDim2.fromOffset(194, 34), UDim2.fromOffset(16, 73), function() actionRemote:FireServer("vote", "ward") end)
local sail = button(panel, "SAIL", UDim2.fromOffset(194, 34), UDim2.fromOffset(222, 73), function() actionRemote:FireServer("vote", "sail") end)
local roundStatus = text(panel, "Next competition starts automatically.", UDim2.fromOffset(400, 42), UDim2.fromOffset(16, 67), 15, mint)
local footer = text(canvas, "OFFLINE / MEMORY ONLY", UDim2.fromOffset(432, 24), UDim2.fromOffset(24, 690), 11, muted)
footer.TextXAlignment = Enum.TextXAlignment.Center
-- Keep y=718..854 free for TikTok's lower interface/chat during a center crop.

local controls = frame(canvas, UDim2.fromOffset(432, 390), UDim2.fromOffset(24, 326))
controls.Visible = false
text(controls, "KEEPER / OFFLINE TESTS", UDim2.fromOffset(350, 25), UDim2.fromOffset(16, 12), 16, gold)
button(controls, "X", UDim2.fromOffset(32, 28), UDim2.fromOffset(384, 10), function() controls.Visible = false end)
local input = Instance.new("TextBox")
input.Size, input.Position = UDim2.fromOffset(264, 38), UDim2.fromOffset(16, 52)
input.BackgroundColor3, input.TextColor3 = Color3.fromRGB(31, 45, 61), pale
input.Font, input.TextSize, input.Text = Enum.Font.Gotham, 15, "Demo_Astra"
input.PlaceholderText, input.ClearTextOnFocus, input.Parent = "Traveler username", false, controls
round(input, 10)
button(controls, "JOIN", UDim2.fromOffset(126, 38), UDim2.fromOffset(290, 52), function() actionRemote:FireServer("join", input.Text) end)
button(controls, "START EARLY", UDim2.fromOffset(194, 38), UDim2.fromOffset(16, 102), function() actionRemote:FireServer("rift", "") end)
button(controls, "TEST FOLLOW", UDim2.fromOffset(194, 38), UDim2.fromOffset(222, 102), function() actionRemote:FireServer("follow", input.Text) end)
for i, item in ipairs({ { "Bloom sky", "bloom" }, { "Aurora sky", "aurora" }, { "Titan sky", "giant" } }) do
    button(controls, item[1], UDim2.fromOffset(126, 38), UDim2.fromOffset(16 + (i - 1) * 137, 152), function() actionRemote:FireServer("blessing", item[2]) end)
end
for i, item in ipairs({ { "Gift bloom", "giftBloom" }, { "Gift aurora", "giftAurora" }, { "Gift giant", "giftGiant" } }) do
    button(controls, item[1], UDim2.fromOffset(126, 38), UDim2.fromOffset(16 + (i - 1) * 137, 202), function() actionRemote:FireServer(item[2], input.Text) end)
end
button(controls, "VOTE AS: WARD", UDim2.fromOffset(194, 38), UDim2.fromOffset(16, 252), function() actionRemote:FireServer("demoWard", input.Text) end)
button(controls, "VOTE AS: SAIL", UDim2.fromOffset(194, 38), UDim2.fromOffset(222, 252), function() actionRemote:FireServer("demoSail", input.Text) end)
text(controls, "Testing only. The game does not need these controls to advance. Gifts and follows here are simulated; all progress resets on Stop.", UDim2.fromOffset(400, 72), UDim2.fromOffset(16, 302), 13, muted)
local keeper = button(canvas, "TEST TOOLS", UDim2.fromOffset(114, 28), UDim2.fromOffset(342, 18), function() controls.Visible = not controls.Visible end)
keeper.TextSize = 11
local cameraButton
local function setCamera(enabled)
    streamCamera = enabled
    if cameraButton then cameraButton.Text = enabled and "ROAM VIEW" or "STREAM VIEW" end
    local camera = workspace.CurrentCamera
    if camera and not enabled then
        camera.CameraType, camera.FieldOfView = Enum.CameraType.Custom, cameraDefaultFov
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then camera.CameraSubject = humanoid end
    end
end
cameraButton = button(canvas, "ROAM VIEW", UDim2.fromOffset(114, 28), UDim2.fromOffset(216, 18), function() setCamera(not streamCamera) end)
cameraButton.TextSize = 11
local function updateHost()
    keeper.Visible = player:GetAttribute("RiftboundHost") == true
    if not keeper.Visible then controls.Visible = false end
end
player:GetAttributeChangedSignal("RiftboundHost"):Connect(updateHost)
player:GetAttributeChangedSignal("RiftboundStreamCamera"):Connect(function() setCamera(player:GetAttribute("RiftboundStreamCamera") ~= false) end)
updateHost()

local lastGift = 0
snapshotRemote.OnClientEvent:Connect(function(state)
    latestState, receivedAt = state, os.clock()
    phase.Text = state.phase == "gathering" and "NEXT: " .. state.activity.name or state.activity.name
    stats.Text = string.format("%s / %d TRAVELERS / %d SHARDS", state.demo and "OFFLINE DEMO" or "LOCAL CREW", #state.crew, state.wins)
    timingLabel.Text = ({ gathering = "NEXT ROUND", voting = "STARTS IN", storm = "TIME LEFT", result = "NEXT UP" })[state.phase]
    for i = 1, 3 do
        local earner = state.leaderboard[i]
        earners[i].name.Text = earner and (i .. ". " .. earner.username) or (i .. ". Waiting")
        earners[i].score.Text = earner and ("$" .. money(earner.money) .. " / $" .. (state.earning and earner.perSecond or 0) .. "/s") or "—"
        local row = state.phase == "result" and state.winners[i] or state.activityLeaders[i]
        competitors[i].name.Text = row and (i .. ". " .. row.username) or (i .. ". Ready to compete")
        competitors[i].score.Text = row and (row.score .. " POINTS" .. (row.prize and (" / +$" .. row.prize) or "")) or "—"
    end
    banner.Visible = state.phase == "result" and #state.winners > 0
    if banner.Visible then
        champion.Text = state.winners[1].username
        prize.Text = string.format("%d points / +$%d / %s", state.winners[1].score, state.winners[1].prize, state.success and "SHARD SAVED" or "ROUND COMPLETE")
    end
    instruction.Text = state.phase == "voting" and "Vote for the sky effect. All travelers enter automatically." or state.activity.instruction
    ward.Visible, sail.Visible = state.phase == "voting", state.phase == "voting"
    roundStatus.Visible = state.phase ~= "voting"
    ward.Text, sail.Text = "WARD / " .. state.ward, "SAIL / " .. state.sail
    roundStatus.Text = state.phase == "storm" and string.format("TEAM ENERGY %d / %d", state.teamScore, state.teamTarget)
        or (state.phase == "result" and state.message or "The next round starts automatically.")
    progressFill.Size = UDim2.fromScale(state.teamTarget > 0 and math.min(1, state.teamScore / state.teamTarget) or 0, 1)
    footer.Text = string.format("%s / %d FOLLOWS / SESSION ONLY", state.demo and "SIMULATED LIVE EVENTS" or "OFFLINE", state.followers)
    if state.lastGift.sequence > lastGift then
        lastGift = state.lastGift.sequence
        notify(string.upper(state.lastGift.kind) .. " x" .. state.lastGift.count .. " → " .. state.lastGift.username .. " (demo)")
    end
end)

local cameraConnection
local function resize()
    local camera = workspace.CurrentCamera
    if camera then canvasScale.Scale = math.min(camera.ViewportSize.X / 480, camera.ViewportSize.Y / 854) end
end
local function bindCamera()
    if cameraConnection then cameraConnection:Disconnect() end
    local camera = workspace.CurrentCamera
    if camera then
        cameraDefaultFov = camera.FieldOfView
        cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
    end
    resize()
    setCamera(streamCamera)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()
RunService:BindToRenderStep("RiftboundPortraitCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if latestState then timer.Text = tostring(math.max(0, math.ceil(latestState.seconds - (os.clock() - receivedAt)))) end
    if streamCamera and workspace.CurrentCamera then
        local camera = workspace.CurrentCamera
        local result = latestState and latestState.phase == "result"
        local position = result and Vector3.new(0, 99, 157) or Vector3.new(0, 113, 180)
        local focus = result and Vector3.new(0, 42, 10) or Vector3.new(0, 40, 0)
        camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, 58
        camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(position, focus), 1 - math.exp(-dt * 3))
    end
end)
