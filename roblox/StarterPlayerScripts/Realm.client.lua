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
local CAMERA_DIAGNOSTICS = true -- Temporary: set false after the Studio camera playtest.
local STREAM_HIDE_WARD = true -- Set false to test the closer camera without hiding the ward.
local STREAM_HIDE_RIFT = true -- The large sphere crosses the sightline to the finish gate.
local STREAM_DAYLIGHT = true -- Local presentation only; Roam restores the previous lighting.
local STREAM_CLEAR_EFFECTS = true -- Reversible local Atmosphere/PostEffect isolation on EVERY Play.
local STREAM_CINEMATIC = true -- False retains the close full-course overview.
local Lighting = game:GetService("Lighting")

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
local SprintBounds = { minX = -26, maxX = 26, minY = 54, maxY = 88, minZ = -82, maxZ = 76, yaw = 60 }
-- Fit actual course regions rather than imaginary low corners under the start.
-- Includes every authored course part, racing/jump space and the giant podium rigs.
local SprintVolumes = {
    { minX = -21, maxX = 21, minY = 61, maxY = 82, minZ = 55, maxZ = 73 },
    { minX = -20, maxX = 20, minY = 60, maxY = 82, minZ = -65, maxZ = 55 },
    { minX = -22, maxX = 22, minY = 60, maxY = 88, minZ = -82, maxZ = -55 },
}
local LegacyBounds = { minX = -54, maxX = 54, minY = -10, maxY = 62, minZ = -54, maxZ = 54, yaw = 0 }
local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function usableViewport(width, height)
    return finite(width) and finite(height) and width >= 64 and height >= 64
        and width <= 32768 and height <= 32768 and width / height >= 0.25 and width / height <= 4
end
local function cameraBounds(bounds, physicalSprint)
    -- Never fall back to the lower original island while awaiting a Sprint snapshot.
    local expected = physicalSprint == false and LegacyBounds or SprintBounds
    if bounds == nil then return expected, physicalSprint == false and "legacy defaults" or "missing; Skybridge fallback" end
    if type(bounds) ~= "table" then return expected, "invalid type; fallback" end
    for _, axis in ipairs({ "X", "Y", "Z" }) do
        local lo, hi = bounds["min" .. axis], bounds["max" .. axis]
        if not finite(lo) or not finite(hi) or lo >= hi then return expected, "invalid " .. axis .. "; fallback" end
        -- This is a fixed, known course. Reject translated, undersized or enormous
        -- server boxes instead of following them below the map or into the fog.
        if lo > expected["min" .. axis] or hi < expected["max" .. axis]
            or lo < expected["min" .. axis] - 16 or hi > expected["max" .. axis] + 16 then
            return expected, "outside course envelope; fallback"
        end
    end
    if not finite(bounds.yaw) or bounds.yaw ~= expected.yaw then return expected, "invalid yaw; fallback" end
    -- Symmetric padding preserves the same course center and heading in every phase.
    local box = { yaw = expected.yaw }
    for _, axis in ipairs({ "X", "Y", "Z" }) do
        local center = (expected["min" .. axis] + expected["max" .. axis]) / 2
        local radius = math.max(center - bounds["min" .. axis], bounds["max" .. axis] - center)
        box["min" .. axis], box["max" .. axis] = center - radius, center + radius
    end
    return box, "server bounds verified"
end
-- Fixed heading/elevation; aspect-ratio fitting adjusts distance and lens width. Always
-- return a finite, bounded solution, even before a usable viewport/snapshot exists.
local function arenaCamera(width, height, receivedBounds, physicalSprint)
    local bounds, reason = cameraBounds(receivedBounds, physicalSprint)
    local viewportReady = usableViewport(width, height)
    if not viewportReady then width, height = 390, 844 end
    local scale, ox, oy = viewportLayout(width, height)
    local area = screenRect(Layout.arena, scale, ox, oy)
    local sprint = physicalSprint ~= false
    local fov = sprint and 55 or 50
    local tanV = math.tan(math.rad(fov) / 2)
    local tanH = tanV * width / height
    local elevation = math.rad(sprint and 35 or 52)
    local up, back = math.sin(elevation), math.cos(elevation)
    local centerY = (bounds.minY + bounds.maxY) / 2
    local centerX, centerZ = (bounds.minX + bounds.maxX) / 2, (bounds.minZ + bounds.maxZ) / 2
    -- Keep the lens near the course. The old start-biased 55-degree overview
    -- put the finish about 400 studs away while close shots remained visible.
    if sprint then centerX, centerY, centerZ = 0, 71, -3 end
    local yaw = math.rad(sprint and 0 or bounds.yaw)
    local volumes = { bounds }
    if sprint then volumes = SprintVolumes end -- Padding does not move the authored course.
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
    local shiftRatio = (0.5 - (area.y + area.h / 2) / height) * 2 * tanV
    local function fitsCourse(distance)
        for _, volume in ipairs(volumes) do
            for _, x in ipairs({ volume.minX, volume.maxX }) do
                for _, y in ipairs({ volume.minY, volume.maxY }) do
                    for _, z in ipairs({ volume.minZ, volume.maxZ }) do
                        local shift = shiftRatio * distance
                        local px, py, depth = project(x, y, z, distance, shift)
                        if depth <= 1 or px < area.x + 10 * scale or px > area.x + area.w - 10 * scale
                            or py < area.y + 10 * scale or py > area.y + area.h - 10 * scale then return false end
                    end
                end
            end
        end
        return true
    end
    local far, fitted = sprint and 210 or 850, false
    for angle = sprint and 85 or 50, sprint and 120 or 50, 5 do
        fov, tanV = angle, math.tan(math.rad(angle) / 2)
        tanH = tanV * width / height
        shiftRatio = (0.5 - (area.y + area.h / 2) / height) * 2 * tanV
        local near, candidate = sprint and 100 or 120, sprint and 210 or 850
        local fitsAtLimit = fitsCourse(candidate)
        if fitsAtLimit then
            for _ = 1, 24 do
                local middle = (near + candidate) / 2
                if fitsCourse(middle) then candidate = middle else near = middle end
            end
        end
        far, fitted = candidate, fitsAtLimit
        if not sprint then break end
        -- Prefer <=180 studs and <=260 to every course/jump corner. Narrow
        -- viewports can widen to 120 degrees, with hard limits of 210/290.
        local shift = shiftRatio * far
        local lensY, lensZ = centerY + up * far - back * shift, centerZ + back * far + up * shift
        local reach = 0
        for _, volume in ipairs(volumes) do
            for _, x in ipairs({ volume.minX, volume.maxX }) do for _, y in ipairs({ volume.minY, volume.maxY }) do for _, z in ipairs({ volume.minZ, volume.maxZ }) do
                reach = math.max(reach, math.sqrt(x * x + (y - lensY)^2 + (z - lensZ)^2))
            end end end
        end
        fitted = fitted and lensY >= 112 and reach <= 290
        if fitted and far <= 180 and reach <= 260 then break end
    end
    local shift = shiftRatio * far
    if sprint then
        -- Move lens AND Focus together along screen-up, then look directly at
        -- that optical-axis Focus. No post-lookAt local translation is applied.
        centerY, centerZ = centerY - back * shift, centerZ + up * shift
        shift = 0
    end
    return far, shift, up, back, centerY, centerX, centerZ, yaw, bounds, reason, fitted and viewportReady, fov
end
local function containsPartBounds(object, point)
    local p = object.CFrame:PointToObjectSpace(point)
    local half = object.Size * 0.5
    if object:IsA("Part") and object.Shape == Enum.PartType.Ball then
        return (p.X / half.X) ^ 2 + (p.Y / half.Y) ^ 2 + (p.Z / half.Z) ^ 2 <= 1
    end
    return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end
-- Fit observed avatar positions into the existing clear portrait rectangle.
-- This is presentation only: no race progress, winner or avatar motion is generated.
local function cinematicCamera(width, height, positions, yawDegrees, elevationDegrees)
    if not usableViewport(width, height) or #positions == 0 then return nil end
    local lo, hi = positions[1], positions[1]
    for _, p in ipairs(positions) do
        if not finite(p.X) or not finite(p.Y) or not finite(p.Z) then return nil end
        lo = Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z))
        hi = Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
    end
    local center = (lo + hi) * 0.5
    local yaw, elevation = math.rad(yawDegrees), math.rad(elevationDegrees)
    local sn, c, up, back = math.sin(yaw), math.cos(yaw), math.sin(elevation), math.cos(elevation)
    local fov, tanV = 55, math.tan(math.rad(55) / 2)
    local scale, ox, oy = viewportLayout(width, height)
    local area = screenRect(Layout.arena, scale, ox, oy)
    local shiftRatio = (0.5 - (area.y + area.h / 2) / height) * 2 * tanV
    local outward = Vector3.new(sn * back, up, c * back)
    local screenUp = Vector3.new(-sn * up, back, -c * up)
    local function pose(distance)
        local focus = center - screenUp * (shiftRatio * distance)
        return CFrame.lookAt(focus + outward * distance, focus), focus
    end
    local function fit(distance)
        local cf = pose(distance)
        -- Margin includes giant avatars, head labels, jump and celebration motion.
        for _, p in ipairs(positions) do
            for _, x in ipairs({ -5, 5 }) do for _, y in ipairs({ -5, 12 }) do for _, z in ipairs({ -5, 5 }) do
                local v = cf:PointToObjectSpace(p + Vector3.new(x, y, z))
                local depth = -v.Z
                if depth <= 1 then return false end
                local px = width / 2 + v.X * height / (2 * tanV * depth)
                local py = height / 2 - v.Y * height / (2 * tanV * depth)
                if px < area.x + 10 * scale or px > area.x + area.w - 10 * scale
                    or py < area.y + 10 * scale or py > area.y + area.h - 10 * scale then return false end
            end end end
        end
        return true
    end
    local near, far = 65, 220
    if not fit(far) then return nil end -- Use the independently fitted overview.
    for _ = 1, 18 do
        local middle = (near + far) / 2
        if fit(middle) then far = middle else near = middle end
    end
    local cf, focus = pose(far)
    if cf.Position.Y < 94 or cf.Position.Y > 500 or math.abs(cf.Position.X) > 300 or math.abs(cf.Position.Z) > 400 then return nil end
    return cf, focus, far, fov
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
local cameraTarget, cameraFocus, activeBounds
local overviewTarget, overviewFocus, overviewDistance, overviewFov
local directorFrame, directorFocus, directorKey, directorSubject
local directorShot = "overview"
local heldCamera, holdCameraButton
local boundsReason, cameraDistance, cameraFitted = "waiting for snapshot", 0, false
local cameraFov = 55
local hiddenWard, originalWardTransparency = nil, 0
local hiddenRift, originalRiftTransparency = nil, 0
local cameraPositionDrift, cameraAimDrift = 0, 0
local maximumPositionDrift, maximumAimDrift = 0, 0
local renderCheckEnabled, renderCheckFolder, nearProbe, farProbe = false, nil, nil, nil
local savedStreamLighting
local suspendedEffects = {}
local effectRefreshAt = 0
local lensMasks, nextLensScan = {}, 0
local streamLighting = {
    ClockTime = 14, Brightness = 3, ExposureCompensation = 0.25,
    EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 0.5,
    OutdoorAmbient = Color3.fromRGB(180, 195, 215), GlobalShadows = false,
    FogStart = 10000, FogEnd = 100000,
}
local cameraWidth, cameraHeight = 0, 0
local nextCameraDiagnostic = 0
local streamRequestPending, streamRequests, nextStreamRequest = false, 0, 0
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
local renderCheckButton
renderCheckButton = button(controls, "RenderCheck", "RENDER CHECK: OFF", { x = 16, y = 410, w = 194, h = 36 }, function()
    renderCheckEnabled = not renderCheckEnabled
    renderCheckButton.Text = renderCheckEnabled and "RENDER CHECK: ON" or "RENDER CHECK: OFF"
    nextCameraDiagnostic = 0
    showTools(false)
    notify(renderCheckEnabled and "RENDER CHECK / near PINK + distant GREEN cubes" or "RENDER CHECK / removed")
end)
holdCameraButton = button(controls, "HoldCamera", "HOLD CAMERA: OFF", { x = 222, y = 410, w = 194, h = 36 }, function()
    local camera = workspace.CurrentCamera
    if heldCamera then
        heldCamera = nil
    elseif camera and streamCamera then
        heldCamera = { frame = camera.CFrame, focus = camera.Focus.Position, fov = camera.FieldOfView }
    end
    holdCameraButton.Text = heldCamera and "HOLD CAMERA: ON" or "HOLD CAMERA: OFF"
    directorKey, nextCameraDiagnostic = nil, 0
    showTools(false)
    notify(heldCamera and "CAMERA HELD / rounds continue normally" or "CAMERA RELEASED / automatic shots")
end)
local keeper = button(canvas, "KeeperToggle", "TEST TOOLS", { x = 342, y = 18, w = 114, h = 30 }, function() showTools(not controls.Visible) end)
keeper.TextSize = 11
local cameraButton
local function updateRenderCheck()
    local camera = workspace.CurrentCamera
    local active = renderCheckEnabled and streamCamera and gui.Enabled and camera ~= nil
    if not active then
        if renderCheckFolder then renderCheckFolder:Destroy() end
        renderCheckFolder, nearProbe, farProbe = nil, nil, nil
        return
    end
    if not renderCheckFolder then
        renderCheckFolder = Instance.new("Folder")
        renderCheckFolder.Name, renderCheckFolder.Parent = "RiftboundLocalRenderCheck", workspace
        local function probe(name, size, color)
            local part = Instance.new("Part")
            part.Name, part.Size, part.Color = name, size, color
            part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
            part.Material, part.Transparency, part.LocalTransparencyModifier = Enum.Material.Neon, 0, 0
            part.CastShadow, part.Parent = false, renderCheckFolder
            return part
        end
        nearProbe = probe("Near_PINK_12_studs", Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(255, 30, 180))
        farProbe = probe("Course_GREEN", Vector3.new(8, 8, 8), Color3.fromRGB(80, 255, 40))
    end
    -- Native 3D parts, NOT AlwaysOnTop adornments or GUI stand-ins. The near
    -- cube tests this camera's rendering; the far cube tests course-distance draw.
    nearProbe.CFrame = camera.CFrame * CFrame.new(-1.2, 0, -12)
    farProbe.CFrame = CFrame.new(0, 104, 0)
end
local function updateStreamLighting()
    if STREAM_DAYLIGHT and streamCamera and gui.Enabled then
        if not savedStreamLighting then
            savedStreamLighting = {}
            for property in pairs(streamLighting) do savedStreamLighting[property] = Lighting[property] end
        end
        for property, value in pairs(streamLighting) do
            if Lighting[property] ~= value then Lighting[property] = value end
        end
    elseif savedStreamLighting then
        for property, value in pairs(savedStreamLighting) do Lighting[property] = value end
        savedStreamLighting = nil
    end
end
local function updateStreamEffects(now)
    if not (STREAM_CLEAR_EFFECTS and streamCamera and gui.Enabled) then
        for object, record in pairs(suspendedEffects) do
            -- Effects can be removed by another script while this view is active.
            pcall(function()
                if record.atmosphere then
                    if object.Parent == nil then object.Parent = record.parent end
                elseif object.Parent then object.Enabled = record.enabled end
            end)
        end
        suspendedEffects, effectRefreshAt = {}, 0
        return
    end
    if now < effectRefreshAt then return end
    effectRefreshAt = now + 0.5
    for _, container in ipairs({ Lighting, workspace.CurrentCamera }) do
        if container then
            for _, object in ipairs(container:GetDescendants()) do
                if not suspendedEffects[object] then
                    if object:IsA("Atmosphere") then
                        suspendedEffects[object] = { atmosphere = true, parent = object.Parent }
                        object.Parent = nil -- Keep the Instance; restore it in Roam.
                    elseif object:IsA("PostEffect") then
                        suspendedEffects[object] = { enabled = object.Enabled }
                        object.Enabled = false
                    end
                elseif object:IsA("PostEffect") then object.Enabled = false end
            end
        end
    end
end
local function updateStreamScenery()
    local realm = workspace:FindFirstChild("RiftboundRealm")
    local ward = realm and realm:FindFirstChild("Starlight ward")
    local hide = STREAM_HIDE_WARD and streamCamera and gui.Enabled
    if hiddenWard and (hiddenWard ~= ward or not hide) then
        hiddenWard.LocalTransparencyModifier = originalWardTransparency
        hiddenWard = nil
    end
    if hide and ward and ward:IsA("BasePart") then
        if hiddenWard ~= ward then
            hiddenWard, originalWardTransparency = ward, ward.LocalTransparencyModifier or 0
        end
        -- Local-only presentation. The server's ward/vote state is untouched;
        -- its subsequent Transparency updates cannot reintroduce the shell.
        ward.LocalTransparencyModifier = 1
    end
    local rift = realm and realm:FindFirstChild("Storm rift")
    local hideRift = STREAM_HIDE_RIFT and streamCamera and gui.Enabled
    if hiddenRift and (hiddenRift ~= rift or not hideRift) then
        hiddenRift.LocalTransparencyModifier = originalRiftTransparency
        hiddenRift = nil
    end
    if hideRift and rift and rift:IsA("BasePart") then
        if hiddenRift ~= rift then hiddenRift, originalRiftTransparency = rift, rift.LocalTransparencyModifier or 0 end
        rift.LocalTransparencyModifier = 1
    end
end
local function streamRayExclusions()
    local result = {}
    if hiddenWard then result[#result + 1] = hiddenWard end
    if hiddenRift then result[#result + 1] = hiddenRift end
    for object in pairs(lensMasks) do result[#result + 1] = object end
    return result
end
local function updateLensMasks(now)
    local active = streamCamera and gui.Enabled and cameraTarget ~= nil
    if active and now < nextLensScan then return end
    nextLensScan = now + 0.25
    local enclosing = {}
    if active then
        local realm = workspace:FindFirstChild("RiftboundRealm")
        local course = realm and realm:FindFirstChild("SkybridgeSprint")
        for _, object in ipairs(workspace:GetDescendants()) do
            if object:IsA("BasePart") and not object:IsA("Terrain") and object.Size.Magnitude >= 20 and (object.Transparency or 0) < 0.95
                and containsPartBounds(object, cameraTarget.Position) then
                local ancestor, protected = object, false
                while ancestor do
                    if ancestor == course or ancestor == player.Character or ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then protected = true; break end
                    ancestor = ancestor.Parent
                end
                if not protected then enclosing[object] = true end
            end
        end
    end
    for object, original in pairs(lensMasks) do
        if not enclosing[object] then object.LocalTransparencyModifier = original; lensMasks[object] = nil end
    end
    for object in pairs(enclosing) do
        if lensMasks[object] == nil then
            lensMasks[object] = object.LocalTransparencyModifier or 0
            if CAMERA_DIAGNOSTICS then
                local ok, path = pcall(function() return object:GetFullName() end)
                print("[Riftbound render] locally masking camera-enclosing geometry: " .. (ok and path or object.Name))
            end
        end
        object.LocalTransparencyModifier = 1
    end
end
local function updateDirector(now, dt)
    if heldCamera then
        cameraTarget, cameraFocus, cameraFov = heldCamera.frame, heldCamera.focus, heldCamera.fov
        cameraDistance, directorShot = (cameraTarget.Position - cameraFocus).Magnitude, "held camera"
        return
    end
    local desired, focus, distance, fov = overviewTarget, overviewFocus, overviewDistance, overviewFov
    local key, shot = "overview", "overview"
    local state = latestState
    if STREAM_CINEMATIC and state and state.physicalSprint then
        local realm = workspace:FindFirstChild("RiftboundRealm")
        local function position(username)
            local model = realm and realm:FindFirstChild("Traveler_" .. username)
            local main = model and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart"))
            local p = main and main.Position
            if p and finite(p.X) and finite(p.Y) and finite(p.Z)
                and math.abs(p.X) <= 27 and p.Y >= 54 and p.Y <= 110 and p.Z >= -85 and p.Z <= 80 then return p end
        end
        local age = math.max(0, (state.now or 0) + now - receivedAt - (state.activityStarted or 0))
        local points, yaw, elevation = {}, 0, 40
        if state.phase == "storm" then
            local beat = math.floor(age / 3)
            key = "race/" .. tostring(state.round) .. "/" .. beat
            if beat % 3 == 1 then
                shot, yaw = "racing pack", -20
                for _, member in ipairs(state.members) do
                    if member.raceStatus == "racing" then
                        local p = position(member.username)
                        if p then points[#points + 1] = p end
                    end
                end
            elseif beat % 3 == 2 then
                shot, yaw, elevation = "racer close-up", 35, 35
                if directorKey ~= key then
                    directorSubject = nil
                    for _, row in ipairs(state.activityLeaders) do
                        if row.status == "racing" and position(row.username) then directorSubject = row.username; break end
                    end
                end
                if directorSubject then
                    local p = position(directorSubject)
                    if p then points[1] = p end
                end
            end
        elseif state.phase == "result" and #state.winners > 0 then
            local remaining = math.max(0, state.seconds - (now - receivedAt))
            -- First show all podium winners; then alternate hero/group shots.
            local hero = remaining <= 6 and remaining > 3
            key, shot, yaw, elevation = "podium/" .. tostring(state.round) .. (hero and "/hero" or "/group"), hero and "winner close-up" or "podium celebration", 175, 35
            for i, row in ipairs(state.winners) do
                if not hero or i == 1 then
                    local p = position(row.username)
                    -- Wait for winners to actually arrive; do not aim at empty podiums.
                    if p and p.Z < -52 then points[#points + 1] = p end
                end
            end
        end
        if #points > 0 then
            local cf, aim, d, angle = cinematicCamera(cameraWidth, cameraHeight, points, yaw, elevation)
            if cf then desired, focus, distance, fov = cf, aim, d, angle else shot = "overview / fit fallback" end
        elseif shot ~= "overview" then shot = "overview / awaiting avatars" end
    end
    if not desired or not focus then return end
    local changed = directorKey ~= key or not directorFrame or shot ~= directorShot
    if string.sub(shot, 1, 8) == "overview" or changed then
        directorFrame, directorFocus = desired, focus -- Safe cut; never fly through the arena.
    else
        local alpha = 1 - math.exp(-math.max(0, math.min(dt, 0.25)) * 5)
        directorFrame, directorFocus = directorFrame:Lerp(desired, alpha), directorFocus:Lerp(focus, alpha)
    end
    -- Overview refitting is not a shot change. Resetting these every frame
    -- bypassed both throttles and flooded Studio Output with full scene scans.
    if changed then nextLensScan, nextCameraDiagnostic = 0, 0 end
    directorKey, directorShot = key, shot
    cameraTarget = directorFrame
    -- Keep Focus exactly on the optical axis, even during smoothing.
    cameraDistance, cameraFov = distance, fov
    cameraFocus = cameraTarget.Position + cameraTarget.LookVector * distance
end
local function applyCamera(camera)
    if not cameraTarget or not cameraFocus then return end
    -- FOV mode must be set BEFORE FieldOfView, including after another camera
    -- controller changes it. Scriptable cameras also need an explicit Focus.
    camera.CameraType = Enum.CameraType.Scriptable
    camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical
    camera.FieldOfView = heldCamera and heldCamera.fov or cameraFov
    camera.CFrame, camera.Focus = heldCamera and heldCamera.frame or cameraTarget, CFrame.new(heldCamera and heldCamera.focus or cameraFocus)
end
local function setCamera(enabled)
    if enabled and not streamCamera then
        nextCameraDiagnostic, streamRequests, nextStreamRequest = 0, 0, 0
        maximumPositionDrift, maximumAimDrift = 0, 0
    end
    streamCamera = enabled
    if not enabled then
        directorFrame, directorFocus, directorKey, heldCamera = nil, nil, nil, nil
        if holdCameraButton then holdCameraButton.Text = "HOLD CAMERA: OFF" end
    end
    updateRenderCheck()
    updateStreamScenery()
    updateStreamLighting()
    updateStreamEffects(os.clock())
    updateLensMasks(os.clock())
    if cameraButton then cameraButton.Text = enabled and "ROAM VIEW" or "STREAM VIEW" end
    local camera = workspace.CurrentCamera
    if camera and not enabled then
        camera.FieldOfViewMode = cameraDefaultFovMode
        camera.CameraType, camera.FieldOfView = Enum.CameraType.Custom, cameraDefaultFov
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then camera.CameraSubject = humanoid end
        local main = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if main then
            local focus = main.Position + Vector3.new(0, 2, 0)
            camera.CFrame, camera.Focus = CFrame.lookAt(focus + Vector3.new(22, 16, 24), focus), CFrame.new(focus)
        end
    elseif camera and cameraTarget then
        -- Apply the fitted view immediately; never sweep through the scene at boot.
        applyCamera(camera)
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
    if not latestState or latestState.phase ~= state.phase then nextCameraDiagnostic = 0 end
    latestState, receivedAt = state, os.clock()
    -- Validate EVERY snapshot. Corrected/missing bounds can arrive without an
    -- activity change; never leave the camera stuck on the first received box.
    if resize then resize() end
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
    if not camera then return end
    local width, height = camera.ViewportSize.X, camera.ViewportSize.Y
    if width ~= cameraWidth or height ~= cameraHeight then
        directorFrame, directorFocus, directorKey = nil, nil, nil
        nextLensScan = 0
    end
    cameraWidth, cameraHeight = width, height
    if usableViewport(width, height) then canvasScale.Scale = viewportLayout(width, height) end
    local physicalSprint = not latestState or latestState.physicalSprint ~= false
    local distance, shift, up, back, centerY, cx, cz, yaw, bounds, reason, fitted, fov = arenaCamera(width, height,
        latestState and latestState.cameraBounds, physicalSprint)
    local focus = Vector3.new(cx, centerY, cz)
    local target = CFrame.lookAt(focus + Vector3.new(math.sin(yaw) * back * distance, up * distance, math.cos(yaw) * back * distance), focus)
    if not physicalSprint then target = target * CFrame.new(0, -shift, 0) end -- preserved legacy-island view only
    local position = target.Position
    if not finite(position.X) or not finite(position.Y) or not finite(position.Z)
        or math.abs(position.X) > 700 or math.abs(position.Z) > 700
        or position.Y < bounds.maxY + 24 or position.Y > 900 or (position - focus).Magnitude > 950 then
        -- Last-resort known view. Do not clamp individual CFrame components:
        -- that would change the viewing direction and could clip the course.
        distance, shift, up, back, centerY, cx, cz, yaw, bounds, reason, fitted, fov = arenaCamera(390, 844, nil, physicalSprint)
        focus = Vector3.new(cx, centerY, cz)
        target = CFrame.lookAt(focus + Vector3.new(math.sin(yaw) * back * distance, up * distance, math.cos(yaw) * back * distance), focus)
        if not physicalSprint then target = target * CFrame.new(0, -shift, 0) end
        reason, fitted = "unsafe position rejected; fixed fallback", false
    end
    if reason ~= boundsReason then nextCameraDiagnostic = 0 end
    overviewTarget, overviewFocus, overviewDistance, overviewFov = target, focus, distance, fov
    cameraTarget, cameraFocus, activeBounds = directorFrame or target, directorFrame and cameraFocus or focus, bounds
    boundsReason, cameraFitted = reason, fitted
    if not directorFrame then cameraDistance, cameraFov = distance, fov end
    if streamCamera and gui.Enabled then setCamera(true) end
end

local function cameraDiagnostics(now)
    if now < nextCameraDiagnostic or not cameraFocus then return end
    nextCameraDiagnostic = now + 10
    local realm = workspace:FindFirstChild("RiftboundRealm")
    local sprint = not latestState or latestState.physicalSprint ~= false
    local course = sprint and realm and realm:FindFirstChild("SkybridgeSprint") or (not sprint and realm)
    local parts, opaque, visibleParts = 0, 0, 0
    local minOpacity, maxOpacity, sumOpacity = 1, 0, 0
    if course then
        for _, object in ipairs(course:GetDescendants()) do
            if object:IsA("BasePart") then
                parts = parts + 1
                local opacity = (1 - (object.Transparency or 0)) * (1 - (object.LocalTransparencyModifier or 0))
                minOpacity, maxOpacity, sumOpacity = math.min(minOpacity, opacity), math.max(maxOpacity, opacity), sumOpacity + opacity
                if opacity >= 0.95 then opaque = opaque + 1 end
                if opacity > 0.05 then visibleParts = visibleParts + 1 end
            end
        end
    end
    local anchors, projected = 0, 0
    local anchorObjects = {}
    local camera = workspace.CurrentCamera
    for _, name in ipairs(sprint and { "START platform", "FINISH island", "Finish arch", "Sprint podium 1", "Sprint podium 2", "Sprint podium 3" } or {}) do
        local object = course and course:FindFirstChild(name)
        if object and object:IsA("BasePart") then
            anchors = anchors + 1
            anchorObjects[#anchorObjects + 1] = object
            if camera then
                local _, visible = camera:WorldToViewportPoint(object.Position)
                if visible then projected = projected + 1 end
            end
        end
    end
    -- Persistent is the server's replication policy, not evidence of local
    -- geometry readiness. Check actual parts/anchors before calling it loaded.
    -- buildSprint currently authors 155 BaseParts, including all sixty lane pads.
    local missingGeometry = not course or visibleParts == 0 or (sprint and (anchors < 6 or parts < 155))
    if workspace.StreamingEnabled and missingGeometry and not streamRequestPending and streamRequests < 3 and now >= nextStreamRequest then
        streamRequestPending, streamRequests, nextStreamRequest = true, streamRequests + 1, now + 15
        local requestFocus = cameraFocus
        task.spawn(function()
            -- Native Roblox geometry streaming only; no custom HTTP/TikTok.
            -- A completed request does NOT prove geometry has replicated.
            local ok, issue = pcall(function() player:RequestStreamAroundAsync(requestFocus, 5) end)
            streamRequestPending = false
            if CAMERA_DIAGNOSTICS then
                print("[Riftbound camera] native stream request " .. (ok and "returned; rechecking geometry" or ("failed: " .. tostring(issue))))
            end
        end)
    end
    if not CAMERA_DIAGNOSTICS or not camera then return end
    print(string.format("[Riftbound camera] presentation=near-course-v6 daylight=%s clock=%.2f brightness=%.2f exposure=%.2f",
        tostring(STREAM_DAYLIGHT and streamCamera and gui.Enabled), Lighting.ClockTime, Lighting.Brightness, Lighting.ExposureCompensation))
    print(string.format("[Riftbound render] revision=near-course-v6 shot=%s clearEffects=%s probes=%s effectiveOpacity min=%.3f mean=%.3f max=%.3f intervalPositionDrift=%.3f intervalAimDrift=%.6f",
        directorShot, tostring(STREAM_CLEAR_EFFECTS), tostring(renderCheckEnabled), parts > 0 and minOpacity or 0, parts > 0 and sumOpacity / parts or 0, maxOpacity, maximumPositionDrift, maximumAimDrift))
    local atmosphereCount, effectCount, enclosureCount = 0, 0, 0
    for _, record in pairs(suspendedEffects) do
        if record.atmosphere then atmosphereCount = atmosphereCount + 1 else effectCount = effectCount + 1 end
    end
    for _ in pairs(lensMasks) do enclosureCount = enclosureCount + 1 end
    print(string.format("[Riftbound render] suspendedAtmospheres=%d disabledPostEffects=%d maskedEnclosures=%d FogStart=%.1f FogEnd=%.1f",
        atmosphereCount, effectCount, enclosureCount, Lighting.FogStart, Lighting.FogEnd))
    maximumPositionDrift, maximumAimDrift = 0, 0
    local renderOk, renderFrame = pcall(function() return camera:GetRenderCFrame() end)
    if renderOk then
        local rp = renderFrame.Position
        print(string.format("[Riftbound render] renderedPosition=(%.1f,%.1f,%.1f) renderedPositionDelta=%.3f renderedAimDelta=%.6f",
            rp.X, rp.Y, rp.Z, (rp - camera.CFrame.Position).Magnitude, 1 - renderFrame.LookVector:Dot(camera.CFrame.LookVector)))
    else
        print("[Riftbound render] GetRenderCFrame unavailable")
    end
    local p, f, box = camera.CFrame.Position, camera.Focus.Position, activeBounds
    local ok, hit = pcall(function() return workspace:Raycast(p, f - p) end)
    local hitText = ok and "clear" or "unavailable"
    if ok and hit then hitText = hit.Instance.Name .. " at " .. string.format("%.1f studs", (hit.Position - p).Magnitude) end
    local visibleRay = "unavailable"
    local rayOk, rayHit = pcall(function()
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = streamRayExclusions()
        return workspace:Raycast(p, f - p, params)
    end)
    if rayOk then visibleRay = rayHit and (rayHit.Instance.Name .. " at " .. string.format("%.1f studs", (rayHit.Position - p).Magnitude)) or "clear" end
    print(string.format("[Riftbound camera] phase=%s round=%s viewport=%sx%s pos=(%.1f,%.1f,%.1f) focus=(%.1f,%.1f,%.1f) distance=%.1f fit=%s FOV=%.1f mode=%s",
        latestState and latestState.phase or "awaiting snapshot", latestState and tostring(latestState.round) or "unknown", tostring(camera.ViewportSize.X), tostring(camera.ViewportSize.Y),
        p.X, p.Y, p.Z, f.X, f.Y, f.Z, cameraDistance, tostring(cameraFitted), camera.FieldOfView, tostring(camera.FieldOfViewMode)))
    local look, up = camera.CFrame.LookVector, camera.CFrame.UpVector
    local delta = f - p
    local aimDot = delta.Magnitude > 0 and look:Dot(delta) / delta.Magnitude or 0
    print(string.format("[Riftbound camera] actual look=(%.4f,%.4f,%.4f) up=(%.4f,%.4f,%.4f) aimDot=%.6f focusError=%.3f preApplyPositionDrift=%.3f preApplyAimDrift=%.6f filteredRay=%s",
        look.X, look.Y, look.Z, up.X, up.Y, up.Z, aimDot, (f - cameraFocus).Magnitude, cameraPositionDrift, cameraAimDrift, visibleRay))
    local inside = {}
    if realm then
        for _, object in ipairs(realm:GetDescendants()) do
            if object:IsA("BasePart") and object.Size.Magnitude >= 20 and (object.Transparency or 0) < 0.95
                and (object.LocalTransparencyModifier or 0) < 0.95 and containsPartBounds(object, p) then
                if #inside < 5 then inside[#inside + 1] = object.Name end
            end
        end
    end
    local ward = realm and realm:FindFirstChild("Starlight ward")
    local wardInfo = "ward=absent"
    if ward and ward:IsA("BasePart") then
        wardInfo = string.format("ward transparency=%.2f localModifier=%.2f cameraInside=%s focusInside=%s",
            ward.Transparency, ward.LocalTransparencyModifier or 0, tostring(containsPartBounds(ward, p)), tostring(containsPartBounds(ward, f)))
    end
    print("[Riftbound camera] " .. wardInfo .. " riftLocalMask=" .. tostring(hiddenRift ~= nil) .. " largeGeometryAtLens=" .. (#inside > 0 and table.concat(inside, ", ") or "none"))
    -- Projection is not visibility. Probe every key sightline, not just the
    -- start/Focus ray, and identify accessory Handles by their full hierarchy.
    for _, object in ipairs(anchorObjects) do
        local point, onScreen = camera:WorldToViewportPoint(object.Position)
        local probeOk, probe = pcall(function()
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = streamRayExclusions()
            return workspace:Raycast(p, object.Position - p, params)
        end)
        local obstacle = probeOk and "clear" or "unavailable"
        if probeOk and probe then
            local pathOk, path = pcall(function() return probe.Instance:GetFullName() end)
            obstacle = (pathOk and path or probe.Instance.Name) .. " at " .. string.format("%.1f", (probe.Position - p).Magnitude)
        end
        print(string.format("[Riftbound camera] anchor=%s world=(%.1f,%.1f,%.1f) screen=(%.1f,%.1f) projected=%s sightline=%s",
            object.Name, object.Position.X, object.Position.Y, object.Position.Z, point.X, point.Y, tostring(onScreen), obstacle))
        print(string.format("[Riftbound render] anchor=%s Transparency=%.3f LocalTransparencyModifier=%.3f effectiveOpacity=%.3f",
            object.Name, object.Transparency or 0, object.LocalTransparencyModifier or 0,
            (1 - (object.Transparency or 0)) * (1 - (object.LocalTransparencyModifier or 0))))
    end
    print(string.format("[Riftbound camera] bounds=(%.1f..%.1f,%.1f..%.1f,%.1f..%.1f) yaw=%d %s; streaming=%s realm=%s policy=%s parts=%d opaque=%d anchors=%d/6 projected=%d geometry=%s ray=%s requests=%d/3",
        box.minX, box.maxX, box.minY, box.maxY, box.minZ, box.maxZ, box.yaw, boundsReason,
        tostring(workspace.StreamingEnabled), tostring(realm ~= nil), realm and tostring(realm.ModelStreamingMode) or "absent",
        parts, opaque, anchors, projected, missingGeometry and "MISSING/PARTIAL" or "present", hitText, streamRequests))
    local received = latestState and latestState.cameraBounds
    if type(received) == "table" then
        print(string.format("[Riftbound camera] received bounds=(%s..%s,%s..%s,%s..%s) yaw=%s",
            tostring(received.minX), tostring(received.maxX), tostring(received.minY), tostring(received.maxY),
            tostring(received.minZ), tostring(received.maxZ), tostring(received.yaw)))
    end
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
RunService:BindToRenderStep("RiftboundPortraitCamera", Enum.RenderPriority.Last.Value, function(dt)
    if latestState then timer.Text = tostring(math.max(0, math.ceil(latestState.seconds - (os.clock() - receivedAt)))) end
    updateStreamScenery()
    updateStreamLighting()
    updateStreamEffects(os.clock())
    if streamCamera and gui.Enabled and workspace.CurrentCamera and cameraTarget then
        local camera = workspace.CurrentCamera
        if camera.ViewportSize.X ~= cameraWidth or camera.ViewportSize.Y ~= cameraHeight then resize() end
        cameraPositionDrift = (camera.CFrame.Position - cameraTarget.Position).Magnitude
        cameraAimDrift = 1 - camera.CFrame.LookVector:Dot(cameraTarget.LookVector)
        maximumPositionDrift, maximumAimDrift = math.max(maximumPositionDrift, cameraPositionDrift), math.max(maximumAimDrift, cameraAimDrift)
        updateDirector(os.clock(), dt)
        updateLensMasks(os.clock())
        applyCamera(camera)
        cameraDiagnostics(os.clock())
    end
    if not streamCamera or not gui.Enabled then updateLensMasks(os.clock()) end
    updateRenderCheck()
    labelAccumulator = labelAccumulator + dt
    if labelAccumulator >= 0.12 then labelAccumulator = 0; updateLabels(os.clock()) end
end)
