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
