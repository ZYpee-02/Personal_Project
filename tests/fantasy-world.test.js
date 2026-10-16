import test from 'node:test';
import { readFileSync } from 'node:fs';
import { runLua } from './helpers/lua.js';
import { presentationEngine } from './helpers/presentation-engine.js';
const read = name => readFileSync(new URL(`../roblox/${name}`, import.meta.url), 'utf8');
const config=read('ServerScriptService/Config.lua');
const world=read('ServerScriptService/World.lua');
const client=read('StarterPlayerScripts/Realm.client.lua');
const domain=read('ServerScriptService/RealmState.lua');
const scene=presentationEngine+`
local Config=(function() ${config} end)()
Config.LoadAvatarAppearances=false
local World=(function() ${world} end)()
World.build(Config)
local course=workspace.RiftboundRealm.SkybridgeSprint
`;

test('all race supports have disjoint footprints, including complete moving-span envelopes',()=>runLua(scene+`
local pads={}
for lane=1,5 do for cp=1,48 do
    local p=course['Lane '..lane..' checkpoint '..cp]
    local moving=cp>=13 and cp<=24 and cp%2==0
    pads[#pads+1]={part=p,width=p.Size.X+(moving and 2.5 or 0),length=p.Size.Z,lane=lane,cp=cp}
end end
local function intersects(a,b)
    local delta=a.part.Position-b.part.Position
    if math.abs(delta.Z)>45 then return false end
    local axes={a.part.CFrame.RightVector,a.part.CFrame.LookVector,b.part.CFrame.RightVector,b.part.CFrame.LookVector}
    for _,axis in ipairs(axes) do
        local function radius(p)
            return math.abs(axis:Dot(p.part.CFrame.RightVector))*p.width/2+math.abs(axis:Dot(p.part.CFrame.LookVector))*p.length/2
        end
        if math.abs(delta:Dot(axis))>=radius(a)+radius(b)+.05 then return false end
    end
    return true
end
for i,a in ipairs(pads) do for j=i+1,#pads do
    local b=pads[j]
    assert(not intersects(a,b),'overlap: '..a.part.Name..' / '..b.part.Name)
end end
assert(World.courseInfo().lanePitch==16 and #pads==240)
-- Shared staging hubs are intentional; the five independent course lanes are
-- the supports checked above. Finish celebration ground is beyond race pads.
for lane=1,5 do
    local final=course['Lane '..lane..' checkpoint 48']
    local stage=course['FINISH island']
    assert(not intersects({part=final,width=final.Size.X,length=final.Size.Z},{part=stage,width=stage.Size.X,length=stage.Size.Z}),'finish stage clips racing surface')
end
`));

test('fantasy decoration is bounded, non-colliding, below the camera and uses native natural materials',()=>runLua(scene+`
local folder=workspace.RiftboundRealm.FantasyScenery
local names,materials,count={},{},0
for _,p in ipairs(folder:GetDescendants()) do
    if p:IsA('BasePart') then
        count=count+1; names[p.Name]=true; materials[p.Material]=true
        assert(p.CanCollide==false and p.CanTouch==false and p:GetAttribute('RiftboundScenery')==true,'unsafe scenery collider')
        for _,x in ipairs({-.5,.5}) do for _,y in ipairs({-.5,.5}) do for _,z in ipairs({-.5,.5}) do
            local corner=p.CFrame:PointToWorldSpace(Vector3.new(x*p.Size.X,y*p.Size.Y,z*p.Size.Z))
            assert(corner.Y<105,'scenery enters the camera height: '..p.Name)
        end end end
    end
end
assert(count>400 and count<900,'unexpected unbounded scenery count: '..count)
for _,name in ipairs({'Sky island meadow','Hanging island stone','Elderwood canopy','Aether crystal','Island portal veil','Waterfall curtain','Waterfall flow','Trail cloud'}) do
    assert(names[name],'missing fantasy feature '..name)
end
assert(materials[Enum.Material.Grass] and materials[Enum.Material.Wood] and materials[Enum.Material.Marble] and materials[Enum.Material.Rock])
assert(course['Lane 3 checkpoint 14'].Material==Enum.Material.WoodPlanks)
assert(course['Lane 3 checkpoint 3'].Material==Enum.Material.Slate)
assert(course['Lane 3 checkpoint 40'].Material==Enum.Material.Marble)
`));

test('scenery visibility masks restore exact opacity and never hide course or racers',()=>runLua(scene+`
local Realm=(function() ${domain} end)()
local state=Realm.new(Config,0)
for i=1,5 do
    state:addCrew('Viewer_'..i,0)
    World.arrive(World.offlineAvatar('Viewer_'..i),i,'Viewer_'..i)
end
local logs={}; print=function() end
;(function() ${client} end)()
state:advance(12); state:advance(20); now=20; World.sprintStep(state,now)
local snapshot=state:snapshot(now); snapshot.course=World.courseInfo(); snapshot.cameraBounds=World.cameraBounds(snapshot)
local leaf=workspace.RiftboundRealm.FantasyScenery:FindFirstChild('Elderwood canopy')
leaf.LocalTransparencyModifier=.27
local track=course['Lane 1 checkpoint 1']
local body=workspace.RiftboundRealm.Traveler_Viewer_1.Torso
local calls=0
camera.GetPartsObscuringTarget=function(_,points,ignore)
    calls=calls+1; assert(#points<=8 and #ignore==5)
    return {leaf,track,body}
end
remotes.Snapshot.OnClientEvent:Fire(snapshot); renderStep(.1)
assert(leaf.LocalTransparencyModifier==1 and (track.LocalTransparencyModifier or 0)==0 and (body.LocalTransparencyModifier or 0)==0)
for i=1,12 do renderStep(.01) end
assert(calls==1,'scenery scans ran every frame')
local canvas=playerGui.RiftboundHUD.VerticalStreamCanvas
canvas.CameraToggle.Activated:Fire(); renderStep(.1)
assert(leaf.LocalTransparencyModifier==.27,'Roam did not restore scenery')
canvas.CameraToggle.Activated:Fire(); now=21; renderStep(.1)
assert(leaf.LocalTransparencyModifier==1)
playerGui.RiftboundHUD.Enabled=false; renderStep(.1)
assert(leaf.LocalTransparencyModifier==.27,'disabled HUD kept local scenery mask')
`));
