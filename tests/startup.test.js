import test from 'node:test';
import { readFileSync } from 'node:fs';
import { runLua } from './helpers/lua.js';
import { instances } from './helpers/instances.js';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const server = read('roblox/ServerScriptService/Realm.server.lua');
const clientBootstrap = read('roblox/StarterPlayerScripts/Realm.client.lua').split('local ink =')[0];
const config = read('roblox/ServerScriptService/Config.lua');
const domain = read('roblox/ServerScriptService/RealmState.lua');
const environment = instances + `
local Config = (function() ${config} end)()
local Realm = (function() ${domain} end)()
local now, jobs, warnings, stages = 0, {}, {}, {}
workspace={StreamingEnabled=false}
local storage = instance("ReplicatedStorage", "ReplicatedStorage")
local modules = instance("ServerScriptService", "ServerScriptService")
for _, name in ipairs({ "Config", "RealmState", "World" }) do instance("ModuleScript", name, modules) end
script = { Parent = modules }
local buildCalls, renderCalls, animationCalls = 0, 0, 0
local world = {
    build = function() buildCalls = buildCalls + 1 end,
    render = function() renderCalls = renderCalls + 1 end,
    animate = function() animationCalls = animationCalls + 1 end,
    offlineAvatar = function() return instance("Model", "StandIn") end,
    arrive = function() end,
    sprintStep = function() end,
    loadAppearance = function() end,
    cameraBounds = function() end,
    courseInfo = function() return {checkpoints=48} end,
    resolveUsername = function() return 123 end,
    validUsername = function(name) return type(name)=="string" and #name>=3 end,
}
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end }
local runtime = { IsStudio = function() return true end, Heartbeat = signal() }
game = { GetService = function(_, name)
    if name == "Players" then return players end
    if name == "ReplicatedStorage" then return storage end
    if name == "RunService" then return runtime end
    error("Unexpected service " .. name)
end }
local function moduleRequire(token)
    local folder = storage.Riftbound
    assert(folder and folder.Snapshot and folder.Action and folder.Notice, "Bootstrap channels must exist before ANY require")
    assert(not folder:GetAttribute("Ready"))
    stages[#stages + 1] = folder:GetAttribute("StartupStage")
    if token == modules.Config then return Config end
    if token == modules.RealmState then return Realm end
    if token == modules.World then return world end
    error("Unexpected dependency")
end
require = moduleRequire
os.clock = function() return now end
warn = function(message) warnings[#warnings + 1] = message end
print = function() end
task = {
    spawn = function(fn, ...) local args = {...}; jobs[#jobs + 1] = function() fn(table.unpack(args)) end end,
    wait = function(seconds) now = now + (seconds or 0.03) end,
}
local function expectFailed(stage, message)
    local folder = storage.Riftbound
    assert(folder and folder.Snapshot and folder.Action and folder.Notice)
    assert(folder:GetAttribute("Ready") == false)
    assert(folder:GetAttribute("StartupState") == "failed")
    assert(folder:GetAttribute("StartupStage") == stage, tostring(folder:GetAttribute("StartupStage")))
    assert(string.find(folder:GetAttribute("StartupError"), message, 1, true), tostring(folder:GetAttribute("StartupError")))
    assert(#warnings == 1 and string.find(warnings[1], message, 1, true))
end
`;
const boot = `\n;(function() ${server} end)()\n`;

test('server publishes channels before requires; readiness follows a successful first render', () => runLua(environment + `
world.build = function()
    assert(storage.Riftbound:GetAttribute("Ready") == false)
    buildCalls = buildCalls + 1
end
world.render = function()
    assert(storage.Riftbound:GetAttribute("Ready") == false)
    renderCalls = renderCalls + 1
end
` + boot + `
assert(storage.Riftbound:GetAttribute("Ready") == true)
assert(storage.Riftbound:GetAttribute("StartupState") == "ready")
assert(buildCalls == 1 and renderCalls == 1 and #warnings == 0 and #stages == 3)
assert(stages[1] == "Requiring Config" and stages[2] == "Requiring RealmState" and stages[3] == "Requiring World")
`));

for (const name of ['Config', 'RealmState', 'World']) {
  test(`missing ${name} produces a bounded, exact dependency error with remotes already present`, () => runLua(environment + `
modules.${name}:Destroy()
` + boot + `expectFailed("Checking ModuleScript ${name}", "Missing ServerScriptService.${name}")
assert(buildCalls == 0 and #jobs == 0)
`));
  test(`an exception requiring ${name} is preserved and attributed to its stage`, () => runLua(environment + `
require = function(token)
    if token == modules.${name} then error("original module failure") end
    return moduleRequire(token)
end
` + boot + `expectFailed("Requiring ${name}", "original module failure")
assert(buildCalls == 0 and #jobs == 0)
`));
}

test('wrong module class and duplicate module names cannot silently select a dependency', () => {
  runLua(environment + `modules.World:Destroy(); instance("Script", "World", modules)` + boot + `
expectFailed("Checking ModuleScript World", "must be a ModuleScript, not Script")`);
  runLua(environment + `instance("ModuleScript", "Config", modules)` + boot + `
expectFailed("Checking ModuleScript Config", "Duplicate ModuleScripts named Config")`);
});

test('Phase 1 Config missing new settings gets safe defaults, while invalid explicit settings fail clearly', () => {
  runLua(environment + `Config.SceneUpdatesPerSecond = nil; Config.SnapshotSeconds = nil; Config.AutoActivities = nil` + boot + `
assert(storage.Riftbound:GetAttribute("Ready") and Config.SceneUpdatesPerSecond == 12 and Config.AutoActivities)`);
  for (const [field, value] of [['GatheringSeconds', '0'], ['SceneUpdatesPerSecond', '"12"'], ['PersistenceEnabled', 'true']]) {
    runLua(environment + `Config.${field} = ${value}` + boot + `
expectFailed("Validating Config", "${field}"); assert(buildCalls == 0 and #jobs == 0)`);
  }
});

test('incompatible Phase 1 module exports fail with an exact replacement message', () => {
  runLua(environment + `world.animate = nil` + boot + `expectFailed("Requiring World", "World is missing animate()")`);
  runLua(environment + `Realm.new = function() return { tick = function() end } end` + boot + `
expectFailed("Creating RealmState", "RealmState is missing advance()")`);
});

for (const [method, stage] of [['build', 'Building World'], ['render', 'Rendering first World snapshot']]) {
  test(`World.${method} failure never advertises readiness or starts background tasks`, () => runLua(environment + `
world.${method} = function() error("engine error") end
` + boot + `expectFailed("${stage}", "engine error"); assert(#jobs == 0)`));
}

test('runtime animation failure publishes the error once and disconnects the frame loop', () => runLua(environment + `
world.animate = function() animationCalls = animationCalls + 1; error("animation failure") end
` + boot + `
runtime.Heartbeat:Fire(0.1)
expectFailed("Animating World", "animation failure")
for i = 1, 20 do runtime.Heartbeat:Fire(0.1) end
assert(animationCalls == 1 and #warnings == 1)
`));

test('runtime snapshot failure stops the automatic round task and publishes its cause', () => runLua(environment + boot + `
world.render = function() error("snapshot render failure") end
now = 1
jobs[#jobs]()
expectFailed("Advancing rounds / rendering snapshot", "snapshot render failure")
`));

const clientEnvironment = `
Vector2 = { new = function(...) return {...} end }
UDim2 = { fromScale = function(...) return {...} end }
Color3 = { fromRGB = function(...) return {...} end }
Enum = { Font = { Gotham = "Gotham" }, CameraType = { Custom = "Custom" } }
workspace = { CurrentCamera = { CameraType = "Scriptable", FieldOfView = 58 } }
local player = instance("Player", "Tester")
local playerGui = instance("PlayerGui", "PlayerGui", player)
players.LocalPlayer = player
-- Check that even the missing-server case has a visible GUI before waiting.
local originalWait = methods.WaitForChild
function methods:WaitForChild(name, timeout)
    if self == storage then assert(playerGui.RiftboundStartup) end
    return originalWait(self, name, timeout)
end
local function expectClientError(message)
    assert(playerGui.RiftboundStartup.Enabled == true)
    local text = playerGui.RiftboundStartup:GetChildren()[1].Text
    assert(string.find(text, message, 1, true), text)
    assert(workspace.CurrentCamera.CameraType == "Custom")
    assert(#warnings >= 1)
end
`;
const startClient = `\n;(function() ${clientBootstrap} end)()\n`;
test('client with no server shows an installation error instead of waiting indefinitely', () => runLua(environment + clientEnvironment + startClient + `
expectClientError("server did not publish ReplicatedStorage.Riftbound")
`));
test('client displays the original module error and failing startup stage', () => runLua(environment + `
require = function() error("bad Config source") end
` + boot + clientEnvironment + startClient + `
expectClientError("Requiring Config"); expectClientError("bad Config source")
`));
test('client bounds old-server readiness waits and identifies the last stage', () => runLua(environment + `
local folder = instance("Folder", "Riftbound", storage)
folder:SetAttribute("StartupStage", "Requiring World")
` + clientEnvironment + startClient + `
expectClientError("Last stage: Requiring World"); assert(now >= 25 and now < 26)
`));
test('client refuses wrong remote classes even after a server claims readiness', () => runLua(environment + boot + `
storage.Riftbound.Snapshot:Destroy(); instance("Folder", "Snapshot", storage.Riftbound)
` + clientEnvironment + startClient + `expectClientError("Snapshot is missing or is not a RemoteEvent")`));

test('client accepts a ready server and observes a subsequent runtime failure', () => runLua(environment + boot + clientEnvironment + startClient + `
assert(#warnings == 0 and now == 0)
storage.Riftbound:SetAttribute("StartupStage", "Animating World")
storage.Riftbound:SetAttribute("StartupError", "runtime example\\nfull traceback")
storage.Riftbound:SetAttribute("Ready", false)
storage.Riftbound:SetAttribute("StartupState", "failed")
expectClientError("Animating World"); expectClientError("runtime example")
assert(not string.find(playerGui.RiftboundStartup:GetChildren()[1].Text, "full traceback", 1, true))
`));
