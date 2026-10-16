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
Config.RegistrationSeconds=nil -- legacy-domain regression fixture; production server always supplies 30s
Config.LoadAvatarAppearances=false
local World=(function() ${world} end)()
World.build(Config)
local course=workspace.RiftboundRealm.SkybridgeSprint
`;

test('shared road collision faces have no interior overlaps; forks partition and reconnect without isolated lanes',()=>runLua(scene+`
local faces={}
for _,p in ipairs(course:GetChildren()) do
    if p:GetAttribute('SurfaceA') then
        local a,b,c=p:GetAttribute('SurfaceA'),p:GetAttribute('SurfaceB'),p:GetAttribute('SurfaceC')
        local face={a,b,c,part=p};faces[#faces+1]=face
        -- Check real WedgePart transforms against the declared collision face.
        for _,v in ipairs({a,b,c}) do
            local q=p.CFrame:PointToObjectSpace(v)
            assert(math.abs(math.abs(q.X)-.5)<.00001,'surface not on native wedge face')
            assert(math.abs(q.Y)<=p.Size.Y/2+.00001 and math.abs(q.Z)<=p.Size.Z/2+.00001,'triangle exceeds physical wedge')
        end
    end
    assert(not p.Name:find('Lane ',1,true),'isolated lane survived')
end
local function overlaps(a,b)
    for _,face in ipairs({a,b}) do for i=1,3 do
        local v=face[i]-face[i%3+1];local axis=Vector3.new(-v.Z,0,v.X)
        local function interval(f)
            local lo,hi=math.huge,-math.huge
            for j=1,3 do local d=f[j]:Dot(axis);lo,hi=math.min(lo,d),math.max(hi,d) end
            return lo,hi
        end
        local a0,a1=interval(a);local b0,b1=interval(b)
        if a1<=b0+.00001 or b1<=a0+.00001 then return false end
    end end
    return true
end
for i,a in ipairs(faces) do for j=i+1,#faces do
    local b=faces[j]
    if a.part:GetAttribute('Checkpoint')==b.part:GetAttribute('Checkpoint') then
        assert(not overlaps(a,b),'intersecting road collision faces')
    end
end end
assert(World.courseInfo().roadWidth==64 and #World.courseInfo().forks==2 and #faces>190)
for _,fork in ipairs(World.courseInfo().forks) do
    for _,cp in ipairs({fork.first,fork.last}) do
        local center,width=World.roadSection(cp,'shared')
        local left,lw=World.roadSection(cp,'main');local right,rw=World.roadSection(cp,'shortcut')
        assert(lw==16 and rw==16 and math.abs(left-right)==32,'junction does not partition the shared road')
        assert(math.abs(math.min(left-lw,right-rw)-(center-width))<.00001 and math.abs(math.max(left+lw,right+rw)-(center+width))<.00001)
    end
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
assert(count>=350 and count<600,'unexpected unbounded scenery count: '..count)
for _,name in ipairs({'Sky island meadow','Hanging island stone','Elderwood canopy','Aether crystal','Island portal veil','Waterfall curtain','Waterfall flow','Trail cloud'}) do
    assert(names[name],'missing fantasy feature '..name)
end
assert(materials[Enum.Material.Grass] and materials[Enum.Material.Wood] and materials[Enum.Material.Marble] and materials[Enum.Material.Rock])
local materialsBySection={}
for _,p in ipairs(course:GetChildren()) do
    if p:GetAttribute('SurfaceA') then materialsBySection[math.floor((p:GetAttribute('Checkpoint')-1)/12)+1]=p.Material end
end
assert(materialsBySection[2]==Enum.Material.WoodPlanks and materialsBySection[1]==Enum.Material.Slate and materialsBySection[4]==Enum.Material.Marble)
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
local track=course:FindFirstChild('Road 1 shared triangle')
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

test('the shared main road has continuous support; only two advertised shortcut jump openings have no deck',()=>runLua(scene+`
local byGate={}
for _,p in ipairs(course:GetChildren()) do
    local cp=p:GetAttribute('Checkpoint')
    if p:GetAttribute('SurfaceA') then byGate[cp]=byGate[cp] or {};table.insert(byGate[cp],p) end
end
local function supports(cp,route,progress)
    local p=World.routePoint(cp-1+progress,route)
    for _,triangle in ipairs(byGate[cp]) do
        if triangle:GetAttribute('Route')==route then
            local a,b,c=triangle:GetAttribute('SurfaceA'),triangle:GetAttribute('SurfaceB'),triangle:GetAttribute('SurfaceC')
            local v,w,q=b-a,c-a,p-a
            local denominator=v.X*w.Z-w.X*v.Z
            local u=(q.X*w.Z-w.X*q.Z)/denominator
            local t=(v.X*q.Z-q.X*v.Z)/denominator
            if u>=-.00001 and t>=-.00001 and u+t<=1.00001 then return true end
        end
    end
    return false
end
for cp=1,48 do
    local branched=(cp>12 and cp<=18) or (cp>30 and cp<=36)
    for _,route in ipairs(branched and {'main','shortcut'} or {'shared'}) do
        for _,t in ipairs({.01,.25,.5,.75,.99}) do
            local gap=route=='shortcut' and (cp==15 or cp==33) and t==.5
            assert(supports(cp,route,t)~=gap,'unexpected road gap or hidden jump bridge: '..cp..' '..route..' '..t)
        end
    end
end
`));
