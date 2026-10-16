import test from 'node:test';
import { readFileSync } from 'node:fs';
import { runLua } from './helpers/lua.js';
import { presentationEngine } from './helpers/presentation-engine.js';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const client = read('roblox/StarterPlayerScripts/Realm.client.lua');
const world = read('roblox/ServerScriptService/World.lua');
const domain = read('roblox/ServerScriptService/RealmState.lua');
const config = read('roblox/ServerScriptService/Config.lua');
const math = client.split('-- BEGIN PRESENTATION MATH')[1].split('\n').slice(1).join('\n').split('-- END PRESENTATION MATH')[0];
const resolutions = [[320, 568], [390, 844], [720, 1280], [1080, 1920], [1920, 1080], [844, 390], [1200, 1920]];

for (const [w, h] of resolutions) {
  test(`actual layout and fitted camera keep panels apart and arena corners inside at ${w}x${h}`, () => runLua(math + `
local s,ox,oy=viewportLayout(${w},${h})
local bounds={x=0,y=0,w=${w},h=${h}}
local occupied={}
for _,name in ipairs({"toolbar","header","notice","arena","earners","competitors","round","footer"}) do
    local rect=screenRect(Layout[name],s,ox,oy)
    assert(fits(rect,occupied,bounds),name.." overlaps another zone or exits viewport")
    occupied[#occupied+1]=rect
    assert(Layout[name].y+Layout[name].h<=718,"reserved lower LIVE area")
end
local d,shift,up,back,cy=arenaCamera(${w},${h})
assert(d<1500,"camera fitting did not converge")
local area=screenRect(Layout.arena,s,ox,oy)
local tanV=math.tan(math.rad(50)/2)
for _,x in ipairs({-54,0,54}) do
    for _,y in ipairs({-10,26,60}) do
        for _,z in ipairs({-54,0,54}) do
            local depth=d-up*(y-cy)-back*z
            local px=${w}/2+x*${h}/(2*tanV*depth)
            local py=${h}/2-(back*(y-cy)-up*z+shift)*${h}/(2*tanV*depth)
            assert(depth>0 and px>=area.x and px<=area.x+area.w and py>=area.y and py<=area.y+area.h,"clipped arena bounds")
        end
    end
end
`));
}

const setup = presentationEngine + `
local Config=(function() ${config} end)()
Config.SprintOnly=false -- exercise the preserved original presentation/variety mode
Config.SprintRaceSeconds=30
local Realm=(function() ${domain} end)()
local World=(function() ${world} end)()
World.build(Config)
local realm=Realm.new(Config,0)
for i=1,18 do
    local name="Viewer_"..string.rep("W",11)..i
    local ok,member=realm:addCrew(name,i); assert(ok)
    World.arrive(World.offlineAvatar(name),member.slot,name)
end
;(function() ${client} end)()
local canvas=playerGui.RiftboundHUD.VerticalStreamCanvas
local function snapshot(time)
    now=time
    realm:tick(time)
    local state=realm:snapshot(time)
    state.demo=true
    World.render(state,time); World.animate(time)
    remotes.Snapshot.OnClientEvent:Fire(state)
    renderStep(0.13)
    return state
end
local function visible(node)
    while node do
        if node.Visible==false or node.Enabled==false then return false end
        node=node.Parent
    end
    return true
end
local function checkHud()
    local panels={}
    for _,child in ipairs(canvas:GetChildren()) do
        if (child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel")) and visible(child) then
            local r=uiRect(child)
            assert(r.x>=-0.01 and r.y>=-0.01 and r.x+r.w<=viewport.X+0.01 and r.y+r.h<=viewport.Y+0.01,child.Name.." outside viewport")
            for _,other in ipairs(panels) do
                assert(r.x>=other.x+other.w-0.01 or r.x+r.w<=other.x+0.01 or r.y>=other.y+other.h-0.01 or r.y+r.h<=other.y+0.01,child.Name.." overlaps another panel")
            end
            panels[#panels+1]=r
        end
    end
    for _,node in ipairs(canvas:GetDescendants()) do
        if node:IsA("TextLabel") or node:IsA("TextButton") then
            assert(node.TextWrapped==false and node.TextTruncate==Enum.TextTruncate.AtEnd,node.Name.." can spill text")
            assert(node.TextSize<=node.Size.Y.Offset,node.Name.." text is taller than its logical row")
        end
    end
end
local function checkLabels()
    local accepted,names,earnings={},0,0
    for _,node in ipairs(workspace:GetDescendants()) do
        if node:IsA("BillboardGui") and node.Enabled then
            assert(node:GetAttribute("RiftboundLabelKind")=="avatar","world board/scenery duplicated in stream")
            local p=camera:WorldToViewportPoint(node.Parent.Position+camera.CFrame.UpVector*node.StudsOffset.Y)
            local r={x=p.X-node.Size.X.Offset/2,y=p.Y-node.Size.Y.Offset/2,w=node.Size.X.Offset,h=node.Size.Y.Offset}
            for _,other in ipairs(accepted) do
                assert(r.x>=other.x+other.w or r.x+r.w<=other.x or r.y>=other.y+other.h or r.y+r.h<=other.y,"avatar label collision")
            end
            accepted[#accepted+1]=r
            names=names+1
            if node.Earned.Visible then earnings=earnings+1 end
        end
    end
    assert(names>0 and names<=4,"stream label budget or visibility failure")
    assert(earnings<=2)
end
`;

test('full client + actual World construct and render 18 viewers across all phases and screen sizes', () => runLua(setup + `
for _,size in ipairs({${resolutions.map(([w,h]) => `{${w},${h}}`).join(',')}}) do
    setViewport(size[1],size[2]); snapshot(0); checkHud(); checkLabels()
end
realm:advance(12); snapshot(12); checkHud(); checkLabels()
assert(canvas.RoundDock.Ward.Visible and canvas.RoundDock.Sail.Visible and not canvas.RoundDock.Status.Visible)
realm:advance(20); snapshot(30); checkHud(); checkLabels()
local position=camera.CFrame.Position
realm:tick(50); realm:advance(50); snapshot(50); checkHud(); checkLabels()
assert(string.find(canvas.RoundDock.Instruction.Text,"WINNER:",1,true))
assert((camera.CFrame.Position-position).Magnitude<0.001,"results should not zoom into a crowd")
assert(not canvas.RoundDock.Ward.Visible and canvas.RoundDock.Status.Visible)
`));

test('testing drawer hides the leaderboards, restores them on close, and preserves all event actions', () => runLua(setup + `
snapshot(0)
canvas.KeeperToggle.Activated:Fire()
assert(canvas.TestTools.Visible and not canvas.TopEarners.Visible and not canvas.RoundLeaders.Visible)
checkHud()
for _,name in ipairs({"Join","StartEarly","Follow","Sky1","Sky2","Sky3","Gift1","Gift2","Gift3","VoteWard","VoteSail"}) do
    canvas.TestTools[name].Activated:Fire()
end
assert(#actions==11 and actions[1][1]=="join" and actions[7][1]=="giftBloom")
canvas.TestTools.Close.Activated:Fire()
assert(not canvas.TestTools.Visible and canvas.TopEarners.Visible and canvas.RoundLeaders.Visible)
checkHud()
`));

test('gift money pops use separate non-overlapping rows; giant effects and income keep working', () => runLua(setup + `
realm:advance(12); realm:advance(20); snapshot(25)
local first=realm.crew[realm.crewOrder[1]]
local balance=first.balance
local model=workspace.RiftboundRealm["Traveler_"..first.username]
local label=model.Head.Caption
assert(label.NameLabel.Text==first.username and label.Earned.Text~="")
assert(label.Earned.Position.Y.Scale+label.Earned.Size.Y.Scale<=label.NameLabel.Position.Y.Scale)
assert(realm:gift(first.username,"giant",1,25))
snapshot(26); assert(model.AppliedScale==1.85 and first.balance>balance)
snapshot(45); assert(model.AppliedScale==1)
checkLabels()
assert(#realm.crewOrder==18 and #workspace.RiftboundRealm:GetChildren()>18)
`));

test('roam restores native player labels and stream view suppresses them locally', () => runLua(setup + `
local humanoid=instance("Humanoid","Humanoid",workspace)
-- Assign before parenting to match actual replicated creation.
humanoid.Parent=nil; humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.Viewer; humanoid.Parent=workspace
snapshot(0)
assert(humanoid.DisplayDistanceType==Enum.HumanoidDisplayDistanceType.None)
canvas.CameraToggle.Activated:Fire(); renderStep(0.13)
assert(camera.CameraType==Enum.CameraType.Custom and humanoid.DisplayDistanceType==Enum.HumanoidDisplayDistanceType.Viewer)
canvas.CameraToggle.Activated:Fire(); renderStep(0.13)
assert(camera.CameraType==Enum.CameraType.Scriptable and humanoid.DisplayDistanceType==Enum.HumanoidDisplayDistanceType.None)
`));

test('world leaderboards are nearby roam displays and remain hidden in the stream', () => runLua(setup + `
snapshot(0)
canvas.CameraToggle.Activated:Fire()
camera.CFrame=CFrame.lookAt(Vector3.new(87,48,65),Vector3.new(87,48,21))
renderStep(0.13)
local found=0
for _,node in ipairs(workspace:GetDescendants()) do
    if node:IsA("BillboardGui") and node:GetAttribute("RiftboundLabelKind")=="worldBoard" and node.Enabled then
        found=found+1; assert(node.Name=="SessionBoard" and node.MaxDistance==95 and not node.AlwaysOnTop)
    end
end
assert(found==1,"nearby side-island board should be available in roam")
canvas.CameraToggle.Activated:Fire(); renderStep(0.13); checkLabels()
`));

test('a label whose replicated attributes arrive late is still managed', () => runLua(setup + `
snapshot(0)
local head=instance("Part","LateHead",workspace)
head.CFrame=CFrame.new(10,44,0)
local caption=instance("BillboardGui","LateCaption",head)
caption.Enabled=true; caption.MaxDistance=1200
caption:SetAttribute("ViewerUsername","LateViewer")
caption:SetAttribute("RiftboundLabelKind","avatar")
assert(caption.Enabled==false,"late label was not registered")
renderStep(0.13)
assert(caption.Size.X.Offset>0)
`));
