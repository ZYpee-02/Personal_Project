local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local World = {}
local root, core, gate, rift, shield, constellation, bloom, winds, scoreText
local monuments = {}
local avatars = {}
local scenery = { clouds = {}, runes = {}, ribbons = {}, particles = {}, stars = {}, shrines = {}, sprintObstacles = {}, movingBridges = {} }
local settings = {}
local sceneState
local lastFrame = 0
local sessionText
local arrival
local colors = {
    rock = Color3.fromRGB(47, 46, 78), grass = Color3.fromRGB(68, 112, 111),
    mint = Color3.fromRGB(106, 255, 213), gold = Color3.fromRGB(255, 208, 128),
    violet = Color3.fromRGB(173, 130, 255), stone = Color3.fromRGB(108, 99, 139),
}

local function part(name, size, cf, color, material, parent)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, cf
    p.Anchored, p.CanCollide = true, true
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

-- 48 measured gates over 1,152 studs. Race motion belongs to Humanoid physics.
local sectionNames = { "STARTING DASH", "MOVING BRIDGES", "HAZARD ZONE", "FINAL SPRINT" }
function World.cameraBounds(state)
    if state.physicalSprint then
        return { minX = -38, maxX = 38, minY = 54, maxY = 110, minZ = -1120, maxZ = 82, yaw = 60 }
    end
end
function World.courseInfo()
    return { revision = "show-v7", checkpoints = 48, length = 1152, stride = 24,
        sections = sectionNames, finishZ = -1092, gate = { x = -64, y = 80, z = 66 } }
end
function World.sprintPoint(lane, checkpoint)
    local cp = math.max(0, math.min(48, checkpoint))
    local rise = math.floor(cp / 12) * 3 + (cp < 48 and (cp % 4 >= 2 and 1 or 0) or 0)
    return Vector3.new((lane - 3) * 8 + math.sin(cp * math.pi / 6) * 2, 68 + rise, 60 - cp * 24)
end
function World.entrancePoint(index, count)
    return Vector3.new(-64 + (index - (count + 1) / 2) * 7, 80, 66)
end
function World.validUsername(username)
    if type(username) ~= "string" or #username < 3 or #username > 20 or not string.match(username, "^[A-Za-z0-9_]+$")
        or string.sub(username, 1, 1) == "_" or string.sub(username, -1) == "_" then return false end
    local _, underscores = string.gsub(username, "_", "")
    return underscores <= 1
end
local accountCache, accountOrder, lookupsInFlight = {}, {}, 0
function World.resolveUsername(username)
    if not World.validUsername(username) then return nil, "Use a Roblox username: 3-20 letters/digits, at most one internal underscore." end
    if settings.ResolveViewerUsernames ~= true then return nil, "Account verification is disabled. Use OFFLINE JOIN for a local test." end
    local key = string.lower(username)
    if accountCache[key] then return accountCache[key] end
    if lookupsInFlight >= 2 then return nil, "Roblox verification is busy. Use OFFLINE JOIN or try again later." end
    lookupsInFlight = lookupsInFlight + 1
    local complete, userId = false, nil
    local deadline = os.clock() + (settings.AppearanceTimeoutSeconds or 8)
    task.spawn(function()
        local ok, result = pcall(function() return Players:GetUserIdFromNameAsync(username) end)
        if os.clock() <= deadline and ok and type(result) == "number" and result > 0 and result == math.floor(result) then userId = result end
        complete = true
        lookupsInFlight = lookupsInFlight - 1
    end)
    while not complete and os.clock() < deadline do task.wait(0.05) end
    if not userId then return nil, "Roblox could not verify that account in time. Check spelling, or use OFFLINE JOIN." end
    accountCache[key] = userId; accountOrder[#accountOrder + 1] = key
    if #accountOrder > 128 then accountCache[table.remove(accountOrder, 1)] = nil end
    return userId
end

local function prepareRig(model)
    for i, object in ipairs(model:GetChildren()) do
        if object:IsA("Accessory") or object:IsA("Hat") then object.Name = "OutfitAccessory_" .. i end
    end
    local main = model:FindFirstChild("HumanoidRootPart")
    local torso, head = model:FindFirstChild("Torso"), model:FindFirstChild("Head")
    assert(main and main:IsA("BasePart") and torso and torso:IsA("BasePart") and head and head:IsA("BasePart"), "A Sprint avatar needs an R6 root, torso and head")
    for _, name in ipairs({ "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
        assert(model:FindFirstChild(name), "Missing R6 limb: " .. name)
    end
    model.PrimaryPart = main
    main.Size = Vector3.new(2, 2, 1)
    local humanoid = model:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid")
    humanoid.Name, humanoid.Parent = "Humanoid", model
    humanoid.WalkSpeed, humanoid.UseJumpPower, humanoid.JumpPower = settings.SprintWalkSpeed or 12, true, 50
    humanoid.HipHeight, humanoid.MaxSlopeAngle = 0, 40
    humanoid.BreakJointsOnDeath, humanoid.RequiresNeck = false, false
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    if not main:FindFirstChild("RootJoint") then
        local joints = {
            { "RootJoint", main, torso, CFrame.new(), CFrame.new() },
            { "Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0) },
            { "Left Shoulder", torso, model["Left Arm"], CFrame.new(-1.5, 0.5, 0), CFrame.new(0, 0.5, 0) },
            { "Right Shoulder", torso, model["Right Arm"], CFrame.new(1.5, 0.5, 0), CFrame.new(0, 0.5, 0) },
            { "Left Hip", torso, model["Left Leg"], CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0) },
            { "Right Hip", torso, model["Right Leg"], CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0) },
        }
        for _, spec in ipairs(joints) do
            local joint = Instance.new("Motor6D")
            joint.Name, joint.Part0, joint.Part1, joint.C0, joint.C1 = spec[1], spec[2], spec[3], spec[4], spec[5]
            joint.Parent = spec[2]
        end
    end
    if not model:FindFirstChild("RaceCollider") then
        local collider = part("RaceCollider", Vector3.new(2, 5, 2), main.CFrame * CFrame.new(0, -0.5, 0), colors.mint, Enum.Material.SmoothPlastic, model)
        collider.Transparency = 1
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1, weld.Parent = main, collider, collider
    end
    if not model:FindFirstChild("GiftAura") then
        local glow = Instance.new("Highlight")
        glow.Name, glow.FillTransparency, glow.OutlineColor, glow.Enabled, glow.Parent = "GiftAura", 0.8, colors.mint, false, model
        local crown = part("Winner crown", Vector3.new(2.4, 0.3, 1.3), main.CFrame * CFrame.new(0, 2.5, 0), colors.gold, Enum.Material.Neon, model)
        crown.Transparency = 1
        for i = 1, 3 do
            local spike = part("Crown spike " .. i, Vector3.new(0.3, 0.7, 0.3), main.CFrame * CFrame.new((i - 2) * 0.8, 2.9, 0), colors.gold, Enum.Material.Neon, model)
            spike.Transparency = 1
        end
        ball("Relay energy", main.Position + Vector3.new(0, 0, -1.5), 0.9, colors.mint, 1, model)
    end
    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript") or object:IsA("Tool") then object:Destroy()
        elseif object:IsA("BasePart") then
            object.Anchored, object.CanCollide, object.Massless = true, false, object ~= main
            if object.Name == "Winner crown" or string.match(object.Name, "^Crown spike") or object.Name == "Relay energy" then
                local weld = Instance.new("WeldConstraint")
                weld.Part0, weld.Part1, weld.Parent = main, object, object
            end
        end
    end
    return model
end

local function physical(record, enabled)
    record.physical = enabled
    local model = record.model
    local main, humanoid = model.PrimaryPart, model:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then humanoid:MoveTo(main.Position) end
    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("BasePart") then
            object.Anchored, object.CanCollide = not enabled, enabled and object.Name == "RaceCollider"
        elseif object:IsA("Motor6D") or object:IsA("Weld") or object:IsA("WeldConstraint") then
            object.Enabled = enabled
        end
    end
    if enabled then
        -- Server owns every racer. Player inputs/clients cannot move an NPC.
        main:SetNetworkOwner(nil)
        main.AssemblyLinearVelocity, main.AssemblyAngularVelocity = Vector3.new(), Vector3.new()
    end
end

function World.loadAppearance(username, userId)
    local record = avatars[string.lower(username)]
    if not record or record.appearanceAttempted or settings.LoadAvatarAppearances ~= true
        or type(userId) ~= "number" or userId < 1 or userId ~= math.floor(userId) then return end
    record.appearanceAttempted = true
    local deadline = os.clock() + (settings.AppearanceTimeoutSeconds or 8)
    task.spawn(function()
        if os.clock() > deadline or not root.Parent then return end
        local description, model
        local ok, issue = pcall(function()
            -- Explicitly optional Roblox appearance APIs; no custom HTTP/TikTok.
            description = Players:GetHumanoidDescriptionFromUserIdAsync(userId)
            description.HeightScale, description.WidthScale, description.DepthScale, description.HeadScale = 1, 1, 1, 1
            description.BodyTypeScale, description.ProportionScale = 0, 0
            if os.clock() > deadline then return end
            model = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
            if os.clock() <= deadline and root.Parent and avatars[string.lower(username)] == record then
                prepareRig(model)
                record.pendingAppearance = model -- install only when this avatar is outside the race
                model = nil
            end
        end)
        if description then description:Destroy() end
        if model then model:Destroy() end
        if not ok then warn("[Riftbound appearance] " .. username .. ": fallback kept (" .. tostring(issue) .. ")") end
    end)
end

local function buildSprint()
    local course = Instance.new("Model")
    course.Name, course.Parent = "SkybridgeSprint", root
    course:SetAttribute("CourseRevision", "show-v7")
    local start = part("START platform", Vector3.new(46, 2, 26), CFrame.new(0, 64, 65), colors.stone, Enum.Material.Slate, course)
    label(start, "SKYBRIDGE / 120 SECOND CROSSING", Vector3.new(0, 9, 0), colors.gold, 350)
    for cp = 1, 48 do
        local section = math.min(4, math.floor((cp - 1) / 12) + 1)
        local gap = (section == 2 or cp % 4 == 2) and 4 or 0
        for lane = 1, 5 do
            local point = World.sprintPoint(lane, cp)
            local pad = part("Lane " .. lane .. " checkpoint " .. cp, Vector3.new(7.4, 1, 24 - gap),
                CFrame.new(point - Vector3.new(0, 3.5, 0)), section % 2 == 0 and colors.violet or colors.mint, Enum.Material.Slate, course)
            pad:SetAttribute("Checkpoint", cp); pad:SetAttribute("Section", section)
            if section == 2 and cp % 2 == 0 then
                scenery.movingBridges[#scenery.movingBridges + 1] = { part = pad, frame = pad.CFrame, phase = cp * 0.7 }
            end
            local edge = part("Checkpoint glow", Vector3.new(7.4, 0.12, 0.35), pad.CFrame * CFrame.new(0, 0.55, 0), colors.gold, Enum.Material.Neon, course)
            edge.CanCollide = false
            if section == 2 and cp % 2 == 0 then
                scenery.movingBridges[#scenery.movingBridges + 1] = { part = edge, frame = edge.CFrame, phase = cp * 0.7 }
            end
        end
        local point = World.sprintPoint(3, cp)
        for _, sign in ipairs({ -1, 1 }) do
            part("Bridge support", Vector3.new(0.7, 5, 0.7), CFrame.new(sign * 24, point.Y - 6, point.Z), colors.stone, Enum.Material.Metal, course)
        end
        if cp % 12 == 1 then
            local index = math.floor((cp - 1) / 12) + 1
            local beacon = part("Section " .. index .. " beacon", Vector3.new(2, 12, 2), CFrame.new(-29, point.Y + 2, point.Z), colors.gold, Enum.Material.Neon, course)
            label(beacon, index .. " / " .. sectionNames[index], Vector3.new(0, 9, 0), colors.gold, 330)
            -- Break up the long skyline with floating section islands and crystal fans.
            island(Vector3.new(52, point.Y - 14, point.Z), 24)
            for i = -2, 2 do crystal(Vector3.new(52 + i * 5, point.Y - 10, point.Z), 0.9 + math.abs(i) * 0.2, colors.violet) end
        end
    end
    for i, cp in ipairs({ 26, 30, 34 }) do
        local from, to = World.sprintPoint(3, cp - 1), World.sprintPoint(3, cp)
        local point = (from + to) * 0.5
        local obstacle = part("Moving wind gate " .. i, Vector3.new(4, 11, 2), CFrame.new(0, point.Y + 2, point.Z), colors.gold, Enum.Material.Neon, course)
        scenery.sprintObstacles[#scenery.sprintObstacles + 1] = { part = obstacle, point = point, phase = i * 2.1, checkpoint = cp }
    end
    for _, cp in ipairs({ 8, 28, 36, 42 }) do
        local point = (World.sprintPoint(3, cp - 1) + World.sprintPoint(3, cp)) * 0.5
        part("Jump hurdle " .. cp, Vector3.new(42, 1.6, 1), CFrame.new(0, point.Y - 2.2, point.Z), colors.violet, Enum.Material.Neon, course)
    end
    local finish = World.sprintPoint(3, 48)
    part("FINISH island", Vector3.new(48, 3, 38), CFrame.new(0, finish.Y - 5, finish.Z - 8), colors.grass, Enum.Material.Grass, course)
    for _, x in ipairs({ -23, 23 }) do
        part("Finish arch column", Vector3.new(2, 21, 2), CFrame.new(x, finish.Y + 6, finish.Z), colors.gold, Enum.Material.Neon, course)
    end
    local arch = part("Finish arch", Vector3.new(48, 2, 3), CFrame.new(0, finish.Y + 17, finish.Z), colors.mint, Enum.Material.Neon, course)
    label(arch, "THE RIFTBOUND CROWN / FINISH", Vector3.new(0, 6, 0), colors.gold, 350)
    for rank, x in ipairs({ 0, -10, 10 }) do
        local h = ({ 4, 2.5, 1.5 })[rank]
        part("Sprint podium " .. rank, Vector3.new(8, h, 8), CFrame.new(x, finish.Y - 3.5 + h / 2, finish.Z - 12), rank == 1 and colors.gold or colors.stone, Enum.Material.Marble, course)
    end
end

function World.stepCourse(now)
    for _, obstacle in ipairs(scenery.sprintObstacles) do
        obstacle.part.CFrame = CFrame.new(math.sin(now * 1.2 + obstacle.phase) * 25, obstacle.point.Y + 2, obstacle.point.Z)
    end
    for _, bridge in ipairs(scenery.movingBridges) do
        bridge.part.CFrame = bridge.frame * CFrame.new(math.sin(now * 0.65 + bridge.phase) * 1.25, math.sin(now * 0.65 + bridge.phase) * 0.2, 0)
        bridge.part.AssemblyLinearVelocity = Vector3.new(math.cos(now * 0.65 + bridge.phase) * 0.8125, math.cos(now * 0.65 + bridge.phase) * 0.13, 0)
    end
end

local function resetRacer(record, member, lane, now)
    local point = World.sprintPoint(lane, member.score)
    local target = World.sprintPoint(lane, math.min(48, member.score + 1))
    record.model:PivotTo(CFrame.lookAt(point + Vector3.new(0, 1, 0), target))
    local main = record.model.PrimaryPart
    main.AssemblyLinearVelocity, main.AssemblyAngularVelocity = Vector3.new(), Vector3.new()
    record.race.position, record.race.sampleAt, record.race.lastMoved = main.Position, now, now
    record.race.lastJump, record.race.lastCommand = now - 1, 0
    record.model.Humanoid.Jump = false
end

function World.sprintStep(state, now)
    World.stepCourse(now)
    if state.phase ~= "storm" or state.activity.id ~= "sprint" then return end
    local lane = 0
    for _, key in ipairs(state.crewOrder) do
        local member, record = state.crew[key], avatars[key]
        if member.activityEntered then
            lane = lane + 1
            if not record or not record.model.PrimaryPart or not record.model:FindFirstChild("Head") or not record.model:FindFirstChildOfClass("Humanoid") then
                state:raceDNF(member.username, state.round)
            else
                local model, humanoid = record.model, record.model:FindFirstChildOfClass("Humanoid")
                if not record.race or record.race.round ~= state.round then
                    if record.scale ~= 1 then model:ScaleTo(1); record.scale = 1 end
                    local rotatedLane = (((member.raceLane or lane) + state.round - 2) % 5) + 1
                    record.race = { round = state.round, lane = rotatedLane }
                    physical(record, true)
                    resetRacer(record, member, rotatedLane, now)
                end
                local race, main = record.race, model.PrimaryPart
                if member.raceStatus == "racing" then
                    if humanoid.Health <= 0 then state:raceDNF(member.username, state.round)
                    else
                        local position = main.Position
                        local dt = math.max(0.001, now - race.sampleAt)
                        if position.Y < 54 or math.abs(position.X) > 38 or position.Z < -1120 or position.Z > 82
                            or (position - race.position).Magnitude > math.max(8, dt * 90) or now - race.lastMoved > 6 then
                            member.recoveries = (member.recoveries or 0) + 1
                            resetRacer(record, member, race.lane, now)
                            position = main.Position
                        end
                        local nextGate = member.score + 1
                        local target = World.sprintPoint(race.lane, nextGate)
                        local delta = target - position
                        local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
                        local passed, at = false, now
                        if nextGate == 48 then
                            if race.position.Z > target.Z and position.Z <= target.Z and math.abs(delta.X) <= 2.8 and math.abs(delta.Y) <= 4 then
                                local fraction = (race.position.Z - target.Z) / math.max(0.0001, race.position.Z - position.Z)
                                at = race.sampleAt + (now - race.sampleAt) * math.max(0, math.min(1, fraction))
                                passed = true
                            end
                        else passed = horizontal <= 2.8 and math.abs(delta.Y) <= 3.5 and humanoid.FloorMaterial ~= Enum.Material.Air end
                        if passed then state:recordCheckpoint(member.username, nextGate, at, state.round) end
                        if (position - race.position).Magnitude > 0.08 then race.lastMoved = now end
                        if member.raceStatus == "racing" then
                            local from = World.sprintPoint(race.lane, member.score)
                            local to = World.sprintPoint(race.lane, member.score + 1)
                            local segment = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
                            local offset = Vector3.new(position.X - from.X, 0, position.Z - from.Z)
                            state:raceDistance(member.username, member.score + offset:Dot(segment) / segment:Dot(segment), state.round)
                            local blocked = false
                            for _, obstacle in ipairs(scenery.sprintObstacles) do
                                if obstacle.checkpoint == member.score + 1 and position.Z > obstacle.point.Z + 2
                                    and position.Z - obstacle.point.Z < 9 and math.abs(position.X - obstacle.part.Position.X) < 4 then blocked = true end
                            end
                            if blocked then
                                humanoid:MoveTo(position); race.lastMoved, race.lastCommand = now, 0
                            elseif now - race.lastCommand > 0.4 then
                                local goal = World.sprintPoint(race.lane, member.score + 1)
                                if member.score == 47 then goal = goal + Vector3.new(0, 0, -4) end
                                humanoid:MoveTo(goal)
                                race.lastCommand = now
                            end
                            local jumpGoal = World.sprintPoint(race.lane, member.score + 1)
                            local jumpDelta = jumpGoal - position
                            local jumpDistance = Vector3.new(jumpDelta.X, 0, jumpDelta.Z).Magnitude
                            if jumpDistance <= 14.5 and jumpDistance >= 10.5 and now - race.lastJump > 0.4 and humanoid.FloorMaterial ~= Enum.Material.Air then
                                humanoid.Jump, race.lastJump = true, now
                            end
                        end
                        race.position, race.sampleAt = position, now
                    end
                end
                if member.raceStatus ~= "racing" and record.physical then
                    record.frame = main.CFrame
                    physical(record, false)
                end
            end
        end
    end
end

function World.build(config)
    settings = config or {}
    root = Instance.new("Model")
    root.Name = "RiftboundRealm"
    root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    root.Parent = workspace
    Lighting.FogStart, Lighting.FogEnd = 1000, 5000
    Lighting.ClockTime, Lighting.Brightness = 14, 2.5
    Lighting.GlobalShadows = true
    Lighting.Ambient = Color3.fromRGB(111, 109, 148)
    Lighting.OutdoorAmbient = Color3.fromRGB(116, 133, 158)
    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Density, atmosphere.Offset = 0.15, 0
    atmosphere.Color, atmosphere.Decay = Color3.fromRGB(170, 213, 233), Color3.fromRGB(89, 74, 130)
    atmosphere.Parent = Lighting
    local glow = Instance.new("BloomEffect")
    glow.Intensity, glow.Size, glow.Threshold, glow.Parent = 0.45, 32, 1.3, Lighting
    buildSprint()
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
    gate = part("Star gate", Vector3.new(1, 16, 16), CFrame.new(-64, 86, 54) * CFrame.Angles(0, math.pi / 2, 0), colors.violet, Enum.Material.Neon)
    gate.Shape, gate.CanCollide, gate.Transparency = Enum.PartType.Cylinder, false, 0.62
    for i = 1, 12 do
        local a = i * math.pi * 2 / 12
        crystal(Vector3.new(-64 + math.sin(a) * 9, 86 + math.cos(a) * 9, 54), 0.45, colors.gold)
    end
    label(gate, "THE STAR GATE  /  ARRIVALS", Vector3.new(0, 13, 0), colors.gold, 340)
    part("Star Gate stage", Vector3.new(34, 2, 28), CFrame.new(-64, 76, 66), colors.stone, Enum.Material.Marble)
    for i = 1, 5 do
        local pad = part("Arrival spotlight " .. i, Vector3.new(4, 0.2, 4), CFrame.new(-64 + (i - 3) * 6, 77.2, 66), colors.mint, Enum.Material.Neon)
        pad.CanCollide = false
    end
    -- Host/player characters belong outside the racing lanes and above the old
    -- island ceiling. The previous spawn at (0,35,22) was underneath Skybridge.
    part("Spectator deck", Vector3.new(22, 2, 26), CFrame.new(48, 82, 58), colors.stone, Enum.Material.Slate)
    for _, x in ipairs({ 37, 59 }) do
        part("Spectator rail", Vector3.new(0.5, 2, 26), CFrame.new(x, 84, 58), colors.gold, Enum.Material.Neon)
    end
    for _, z in ipairs({ 45, 71 }) do
        part("Spectator rail", Vector3.new(22, 2, 0.5), CFrame.new(48, 84, z), colors.gold, Enum.Material.Neon)
    end
    arrival = Instance.new("SpawnLocation")
    arrival.Name, arrival.Size, arrival.CFrame = "Arrival", Vector3.new(7, 0.3, 7), CFrame.new(48, 83.2, 58)
    arrival.Anchored, arrival.Neutral, arrival.Duration = true, true, 0
    arrival.Color, arrival.Material, arrival.Parent = colors.gold, Enum.Material.Neon, root
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

function World.preparePlayer(player)
    player.RespawnLocation = arrival
    local function place(character)
        local main = character:WaitForChild("HumanoidRootPart", 10)
        if not main or not character.Parent then return end
        -- Also rescue the first character, which can spawn before World.build.
        -- This moves only the actual player character, never a racing NPC.
        character:PivotTo(CFrame.lookAt(Vector3.new(48, 87, 58), Vector3.new(0, 72, 0)))
        main.AssemblyLinearVelocity, main.AssemblyAngularVelocity = Vector3.new(), Vector3.new()
    end
    player.CharacterAdded:Connect(function(character) task.spawn(function() place(character) end) end)
    if player.Character then task.spawn(function() place(player.Character) end) end
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
    return prepareRig(model)
end

local function number(value)
    if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
    if value >= 1000 then return string.format("%.1fK", value / 1000) end
    return tostring(math.floor(value))
end

function World.arrive(model, slot, username)
    model.Name = "Traveler_" .. username
    model:PivotTo(CFrame.new(World.entrancePoint(1, 1)))
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
        balance = 0, popText = popText, scale = 1, username = username,
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
    if state.entrance then
        for index, name in ipairs(state.entrance.names) do
            if name == member.username then return World.entrancePoint(index, #state.entrance.names), true end
        end
    end
    if member.entranceDone == false then return Vector3.new(-64 + ((member.slot - 1) % 5 - 2) * 5, 80, 82), false end
    if state.phase == "result" then
        for rank, row in ipairs(state.winners or {}) do
            if row.username == member.username then
                return Vector3.new(({ 0, -10, 10 })[rank], (state.activity.id == "sprint" and 76.5 or 35) + 3 * scale + ({ 4, 2.5, 1.5 })[rank], state.activity.id == "sprint" and -1104 or 14), true
            end
        end
    end
    if state.activity.id == "sprint" then
        if state.phase == "voting" or state.phase == "gathering" then
            for lane, username in ipairs(state.nextCohort or {}) do
                if username == member.username then return World.sprintPoint(((lane + (state.phase == "gathering" and state.round + 1 or state.round) - 2) % 5) + 1, 0), false end
            end
        end
        return World.crewPosition(member.slot).Position, false
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
        local key = string.lower(member.username)
        local record = avatars[key]
        if record and not (state.phase == "storm" and member.activityEntered) and (record.pendingAppearance or not record.model.PrimaryPart
            or not record.model:FindFirstChild("Head") or not record.model:FindFirstChildOfClass("Humanoid") or record.model.Humanoid.Health <= 0) then
            local replacement, old = record.pendingAppearance or World.offlineAvatar(member.username), record.model
            local balance, previousFrame = record.balance, old:GetPivot()
            local queuedGiant, deferredGiantUntil = record.queuedGiant, record.deferredGiantUntil
            World.arrive(replacement, record.slot, member.username)
            old:Destroy()
            record = avatars[key]
            record.frame = previousFrame
            replacement:PivotTo(previousFrame)
            record.balance, record.appearanceAttempted = balance, true
            record.queuedGiant, record.deferredGiantUntil = queuedGiant, deferredGiantUntil
        end
        if record then
            local model = record.model
            if record.physical and not (state.phase == "storm" and state.activity.id == "sprint") then
                record.frame = model.PrimaryPart.CFrame
                physical(record, false)
            end
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
            local racing = state.phase == "storm" and state.activity.id == "sprint"
            if racing and member.effect == "giant" then record.queuedGiant = true end
            if not racing and record.queuedGiant then
                record.deferredGiantUntil, record.queuedGiant = now + 6, false
            end
            local giant = member.effect == "giant" or now < (record.deferredGiantUntil or 0)
            local targetScale = giant and not racing and 1.85 or 1
            if record.scale ~= targetScale then model:ScaleTo(targetScale); record.scale = targetScale end
            model.GiftAura.Enabled = member.effect ~= "" or now < (record.deferredGiantUntil or 0)
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
    World.stepCourse(now)
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
            local radius = celebration and (state.activity.id == "sprint" and 12 or 16) or 25
            local baseY = state.activity.id == "sprint" and 84 or 37
            local baseZ = state.activity.id == "sprint" and (celebration and -1104 or 0) or 10
            p.CFrame = CFrame.new(math.cos(a) * radius, baseY + ((now * (celebration and 8 or 5) + i * 2) % (state.activity.id == "sprint" and 18 or 30)), baseZ + math.sin(a) * radius)
            p.Color = Color3.fromHSV((i / 36 + now * 0.03) % 1, 0.5, 1)
        end
    end
    for _, member in ipairs(state.members) do
        local record = avatars[string.lower(member.username)]
        if record then
            if state.activity.id == "sprint" and state.phase == "storm" and record.race and record.race.round == state.round then
                -- Physics owns the root. Only pose the massless limbs for walking.
                local speed = record.model.PrimaryPart and record.model.PrimaryPart.AssemblyLinearVelocity.Magnitude or 0
                local gait = speed > 1 and math.sin(now * 9) * 0.45 or 0
                for _, joint in ipairs(record.model:GetDescendants()) do
                    if joint:IsA("Motor6D") and (string.find(joint.Name, "Shoulder") or string.find(joint.Name, "Hip")) then
                        if not joint:GetAttribute("SprintBaseC0") then joint:SetAttribute("SprintBaseC0", joint.C0) end
                        joint.C0 = joint:GetAttribute("SprintBaseC0") * CFrame.Angles(gait * (string.find(joint.Name, "Left") and 1 or -1), 0, 0)
                    end
                end
            else
            local target, winner = destination(member, state, now, record.scale)
            local age = now - record.arrivedAt
            local entering = false
            for _, name in ipairs(state.entrance and state.entrance.names or {}) do if name == member.username then entering = true end end
            if entering then
                -- Hold a recognizable celebratory pose at the gate, never a race root.
                record.frame = CFrame.lookAt(target, target + Vector3.new(0, 0, 1))
                record.model.GiftAura.Enabled, record.model.GiftAura.OutlineColor = true, colors.mint
            end
            local current = record.frame.Position
            local position = current:Lerp(target, math.min(1, dt * 7))
            local delta = target - current
            local direction = Vector3.new(delta.X, 0, delta.Z)
            if direction.Magnitude < 0.1 then direction = Vector3.new(0, 0, entering and 1 or -1) end
            local frame = CFrame.lookAt(position, position + direction)
            record.frame = record.frame:Lerp(frame, math.min(1, dt * 9))
            local moving = not entering and Vector3.new(delta.X, 0, delta.Z).Magnitude > 0.2
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
            model["Winner crown"].Transparency = winner and not entering and 0 or 1
            for i = 1, 3 do model["Crown spike " .. i].Transparency = winner and not entering and 0 or 1 end
            model["Relay energy"].Transparency = storm and state.activity.id == "relay" and member.activityEntered and 0 or 1
            model["Relay energy"].CFrame = body * CFrame.new(0, size, -1.5 * size)
            end
        end
    end
end

return World
