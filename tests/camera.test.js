import test from 'node:test';
import { readFileSync } from 'node:fs';
import { runLua } from './helpers/lua.js';
import { presentationEngine } from './helpers/presentation-engine.js';

const read = name => readFileSync(new URL(`../${name}`, import.meta.url), 'utf8');
const client = read('roblox/StarterPlayerScripts/Realm.client.lua');
const config = read('roblox/ServerScriptService/Config.lua');
const domain = read('roblox/ServerScriptService/RealmState.lua');
const world = read('roblox/ServerScriptService/World.lua');
const mathSource = client.split('-- BEGIN PRESENTATION MATH')[1].split('\n').slice(1).join('\n').split('-- END PRESENTATION MATH')[0];
const resolutions = [[320,568],[390,844],[720,1280],[1080,1920],[1920,1080],[844,390],[1200,1920],[2160,3840],[250,1000],[1000,250]];
const sizes = resolutions.map(([w,h]) => `{${w},${h}}`).join(',');
const modules = `
local Config=(function() ${config} end)()
Config.LoadAvatarAppearances=false
local Realm=(function() ${domain} end)()
local World=(function() ${world} end)()
`;
const geometryAssertions = `
local courseBox={minX=-26,maxX=26,minY=54,maxY=88,minZ=-82,maxZ=76,yaw=60}
local function assertFraming(w,h)
    local s,ox,oy=viewportLayout(w,h)
    local area=screenRect(Layout.arena,s,ox,oy)
    local p=camera.CFrame.Position
    assert(finite(p.X) and finite(p.Y) and finite(p.Z),"nonfinite camera")
    assert(p.Y>=112 and p.Y<=900 and math.abs(p.X)<700 and math.abs(p.Z)<700,"unsafe camera position")
    assert((p-Vector3.new(0,71,-3)).Magnitude<950,"runaway camera")
    local toCenter=Vector3.new(0,71,-3)-p
    assert(camera.CFrame.LookVector:Dot(toCenter)*(1/toCenter.Magnitude)>0.97,"camera faces away from the course")
    for _,x in ipairs({-26,26}) do for _,y in ipairs({54,88}) do for _,z in ipairs({-82,76}) do
        local point,onScreen=camera:WorldToViewportPoint(Vector3.new(x,y,z))
        assert(onScreen and point.Z>1 and point.X>=area.x and point.X<=area.x+area.w
            and point.Y>=area.y and point.Y<=area.y+area.h,"course escaped the unobstructed arena rectangle")
    end end end
end
`;

for (const [w,h] of resolutions) {
  test(`fixed camera contains the entire course and rejects corrupt bounds at ${w}x${h}`, () => runLua(presentationEngine + mathSource + geometryAssertions + `
setViewport(${w},${h}); camera.FieldOfView=50
local cases={
    {"missing"},{"empty",{}},{"wrong type","bad"},{"boolean",false},
    {"NaN",{minX=0/0,maxX=26,minY=54,maxY=88,minZ=-82,maxZ=76,yaw=60}},
    {"infinity",{minX=-26,maxX=math.huge,minY=54,maxY=88,minZ=-82,maxZ=76,yaw=60}},
    {"missing field",{minX=-26,maxX=26,minY=54,maxY=88,minZ=-82,yaw=60}},
    {"inverted",{minX=26,maxX=-26,minY=54,maxY=88,minZ=-82,maxZ=76,yaw=60}},
    {"undersized",{minX=-1,maxX=1,minY=54,maxY=88,minZ=-1,maxZ=1,yaw=60}},
    {"runaway",{minX=-10000,maxX=10000,minY=54,maxY=88,minZ=-82,maxZ=76,yaw=60}},
    {"below map",{minX=-26,maxX=26,minY=-900,maxY=-800,minZ=-82,maxZ=76,yaw=60}},
    {"bad heading",{minX=-26,maxX=26,minY=54,maxY=88,minZ=-82,maxZ=76,yaw=0/0}},
    {"behind course",{minX=-26,maxX=26,minY=54,maxY=88,minZ=-82,maxZ=76,yaw=240}},
    {"correct",courseBox}
}
for _,item in ipairs(cases) do
    local d,shift,up,back,cy,cx,cz,yaw,box,reason,fitted=arenaCamera(${w},${h},item[2],true)
    assert(d>=120 and d<=850 and fitted,item[1].." failed bounded fit")
    assert(cy==71 and cx==0 and cz==-3 and yaw==math.rad(60),"fixed course center/heading changed")
    if item[1]~="correct" then assert(string.find(reason,"fallback",1,true),"bad bounds not identified") end
    local focus=Vector3.new(cx,cy,cz)
    camera.CFrame=CFrame.lookAt(focus+Vector3.new(math.sin(yaw)*back*d,up*d,math.cos(yaw)*back*d),focus)*CFrame.new(0,-shift,0)
    assertFraming(${w},${h})
end
`));
}

test('zero, nonfinite, tiny and extreme viewports yield a bounded fallback instead of an exponential zoom', () => runLua(presentationEngine + mathSource + `
for _,size in ipairs({{0,0},{0,844},{390,0},{0/0,844},{math.huge,844},{1,1},{1,10000},{10000,1},{40000,40000}}) do
    local d,shift,up,back,cy,cx,cz,yaw,box,reason,fitted=arenaCamera(size[1],size[2],nil,true)
    assert(finite(d) and finite(shift) and d<850 and cy==71 and cx==0 and cz==-3 and not fitted)
end
`));

test('actual server bounds stay identical in every phase and enclose built course geometry and racing envelopes', () => runLua(presentationEngine + modules + `
World.build(Config)
local state=Realm.new(Config,0)
for i=1,5 do assert(state:addCrew("Racer_"..i,i)) end
local reference
for _,time in ipairs({0,12,20,100,110,122,130}) do
    now=time
    if time>0 then state:tick(time); state:advance(time) end
    local snapshot=state:snapshot(time)
    assert(snapshot.physicalSprint,"Sprint bounds disappeared during "..snapshot.phase)
    local box=World.cameraBounds(snapshot)
    if not reference then reference=box else
        for key,value in pairs(reference) do assert(box[key]==value,"bounds changed with round phase") end
    end
end
local parts=0
for _,object in ipairs(workspace.RiftboundRealm.SkybridgeSprint:GetDescendants()) do
    if object:IsA("BasePart") then
        parts=parts+1
        for _,x in ipairs({-0.5,0.5}) do for _,y in ipairs({-0.5,0.5}) do for _,z in ipairs({-0.5,0.5}) do
            local p=object.CFrame:PointToWorldSpace(Vector3.new(x*object.Size.X,y*object.Size.Y,z*object.Size.Z))
            assert(p.X>=reference.minX and p.X<=reference.maxX and p.Y>=reference.minY and p.Y<=reference.maxY
                and p.Z>=reference.minZ and p.Z<=reference.maxZ,object.Name.." outside server box")
        end end end
    end
end
assert(parts==155,"update readiness diagnostic if authored course geometry changes")
for lane=1,5 do for cp=0,12 do
    local p=World.sprintPoint(lane,cp)
    assert(p.Y+10<=reference.maxY and p.X-3>=reference.minX and p.X+3<=reference.maxX)
end end
`));

const clientScene = presentationEngine + modules + mathSource + geometryAssertions + `
local logs={}
print=function(...) local args={...}; for i,v in ipairs(args) do args[i]=tostring(v) end; logs[#logs+1]=table.concat(args," ") end
World.build(Config)
local state=Realm.new(Config,0)
for i=1,5 do assert(state:addCrew("Racer_"..i,i)) end
;(function() ${client} end)()
local canvas=playerGui.RiftboundHUD.VerticalStreamCanvas
local function publish(box)
    local snapshot=state:snapshot(now)
    snapshot.cameraBounds=box
    remotes.Snapshot.OnClientEvent:Fire(snapshot)
    renderStep(0.13)
end
local function logged(fragment)
    for _,line in ipairs(logs) do if string.find(line,fragment,1,true) then return true end end
    return false
end
`;

test('full client repairs same-activity bounds, camera overrides, Focus and FOV mode on every phase', () => runLua(clientScene + `
assertFraming(390,844) -- before the first snapshot, already aiming at the raised Sprint course
local baseline=camera.CFrame.Position
publish(courseBox)
assert((camera.CFrame.Position-baseline).Magnitude<0.00001)
local padded={minX=-32,maxX=32,minY=50,maxY=92,minZ=-86,maxZ=80,yaw=60}
publish(padded)
assert((camera.CFrame.Position-baseline).Magnitude>1,"new bounds ignored within the same activity")
publish({minX=-10000,maxX=10000,minY=-1000,maxY=-900,minZ=-82,maxZ=76,yaw=60})
assert((camera.CFrame.Position-baseline).Magnitude<0.00001,"invalid box retained the last bad view")
assert(logged("outside course envelope; fallback"))
for _,time in ipairs({12,20,100,110}) do
    now=time; state:tick(time); state:advance(time)
    publish(courseBox)
    camera.CFrame=CFrame.new(0,-1000,0)
    camera.Focus=CFrame.new(0,-1000,0)
    camera.FieldOfViewMode=Enum.FieldOfViewMode.Diagonal; camera.FieldOfView=120
    camera.CameraType=Enum.CameraType.Custom
    renderStep(0.13)
    assertFraming(390,844)
    assert(camera.CameraType==Enum.CameraType.Scriptable and camera.FieldOfView==50
        and camera.FieldOfViewMode==Enum.FieldOfViewMode.Vertical)
    assert((camera.Focus.Position-Vector3.new(0,71,-3)).Magnitude<0.00001)
    assert((camera.CFrame.Position-baseline).Magnitude<0.00001,"phase moved the fixed spectator view")
end
assert(logged("phase=voting") and logged("phase=storm") and logged("phase=result"))
assert(logged("parts=155 opaque=155 anchors=6/6 projected=6 geometry=present"))
`));

test('full client handles portrait/landscape resizing, zero viewport recovery, camera replacement and Roam toggles', () => runLua(clientScene + `
publish(courseBox)
for _,size in ipairs({${sizes}}) do
    setViewport(size[1],size[2]); renderStep(0.13); assertFraming(size[1],size[2])
end
setViewport(0,0); renderStep(0.13)
assert(finite(camera.CFrame.Position.Y) and camera.CFrame.Position.Y>112)
-- Recover even when the viewport property signal is missed.
viewport=Vector2.new(1080,1920); camera.ViewportSize=viewport
renderStep(0.13); assertFraming(1080,1920)
workspace.CurrentCamera=nil; workspace:GetPropertyChangedSignal("CurrentCamera"):Fire(); renderStep(0.13)
local replacement=instance("Camera","Replacement",workspace)
replacement.CameraType=Enum.CameraType.Custom; replacement.FieldOfView=73
replacement.FieldOfViewMode=Enum.FieldOfViewMode.Diagonal; replacement.ViewportSize=viewport
replacement.CFrame=CFrame.new(0,-500,0)
camera=replacement; workspace.CurrentCamera=replacement
workspace:GetPropertyChangedSignal("CurrentCamera"):Fire(); renderStep(0.13)
assertFraming(1080,1920)
canvas.CameraToggle.Activated:Fire()
assert(camera.CameraType==Enum.CameraType.Custom and camera.FieldOfView==73 and camera.FieldOfViewMode==Enum.FieldOfViewMode.Diagonal)
camera.CFrame=CFrame.new(0,90,0); renderStep(0.13)
assert(camera.CFrame.Position.X==0,"stream camera still controls Roam")
canvas.CameraToggle.Activated:Fire(); assertFraming(1080,1920)
`));

test('Persistent alone does not pass readiness; native streaming requests are limited and do not fabricate geometry', () => runLua(clientScene + `
workspace.StreamingEnabled=true
local course=workspace.RiftboundRealm.SkybridgeSprint
course.Parent=nil -- model policy still Persistent, but geometry missing on this mock client
local requests=0
function methods:RequestStreamAroundAsync(focus,timeout)
    assert(self==player and focus.X==0 and focus.Y==71 and focus.Z==-3 and timeout==5)
    requests=requests+1
end
for _,time in ipairs({0,10,20,30,40,50,60,70}) do
    now=time; renderStep(0.13)
    local jobs=spawnedJobs; spawnedJobs={}; for _,job in ipairs(jobs) do job() end
    assertFraming(390,844)
end
assert(requests==3,"stream requests flooded or never attempted")
assert(logged("policy=ModelStreamingMode.Persistent parts=0 opaque=0") and logged("geometry=MISSING/PARTIAL"))
assert(logged("returned; rechecking geometry"))
course.Parent=workspace.RiftboundRealm
now=80; renderStep(0.13)
assert(logged("parts=155 opaque=155 anchors=6/6 projected=6 geometry=present"))
assert(requests==3,"loaded geometry triggered another request")
`));

test('streaming disabled or already present makes no native request; request failures leave the camera safe', () => runLua(clientScene + `
local requests=0
function methods:RequestStreamAroundAsync() requests=requests+1; error("mock streaming failure") end
workspace.StreamingEnabled=true
publish(courseBox)
assert(requests==0 and #spawnedJobs==0,"loaded persistent course requested streaming")
local course=workspace.RiftboundRealm.SkybridgeSprint
course.Parent=nil; workspace.StreamingEnabled=false
now=10; renderStep(0.13)
assert(requests==0 and #spawnedJobs==0,"disabled streaming made a request")
workspace.StreamingEnabled=true
now=20; renderStep(0.13)
assert(#spawnedJobs==1)
spawnedJobs[1](); spawnedJobs={}
assert(requests==1 and logged("failed: ") and logged("mock streaming failure"))
now=30; renderStep(0.13); assert(#spawnedJobs==0,"failure retried without cooldown")
assertFraming(390,844)
`));

test('diagnostics identify transparent geometry and a foreground ray hit without moving the fixed camera', () => runLua(clientScene + `
for _,object in ipairs(workspace.RiftboundRealm.SkybridgeSprint:GetDescendants()) do
    if object:IsA("BasePart") then object.LocalTransparencyModifier=1 end
end
local blocker=instance("Part","Foreground blocker")
function methods:Raycast(origin,direction)
    return {Instance=blocker,Position=origin+direction*(1/direction.Magnitude)}
end
publish(courseBox)
assert(logged("parts=155 opaque=0") and logged("geometry=MISSING/PARTIAL"))
assert(logged("ray=Foreground blocker at 1.0 studs"))
assertFraming(390,844)
`));
