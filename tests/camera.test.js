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
const resolutions = [[320,568],[390,844],[720,1280],[1080,1920],[1920,1080],[844,390],[1200,1920],[2160,3840],[250,1000],[1000,250],[923.2,427.2],[1158,536]];
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
    assert(p.Y>=112 and p.Y<=200 and math.abs(p.X)<700 and math.abs(p.Z)<700,"unsafe camera position")
    assert((p-Vector3.new(0,71,-3)).Magnitude<230,"runaway camera")
    local toCenter=Vector3.new(0,71,-3)-p
    assert(camera.CFrame.LookVector:Dot(toCenter)*(1/toCenter.Magnitude)>0.97,"camera faces away from the course")
    for _,volume in ipairs(SprintVolumes) do
    for _,x in ipairs({volume.minX,volume.maxX}) do for _,y in ipairs({volume.minY,volume.maxY}) do for _,z in ipairs({volume.minZ,volume.maxZ}) do
        local corner=Vector3.new(x,y,z)
        assert((corner-p).Magnitude<=290,"overview exceeds near-course distance budget")
        local point,onScreen=camera:WorldToViewportPoint(corner)
        assert(onScreen and point.Z>1 and point.X>=area.x and point.X<=area.x+area.w
            and point.Y>=area.y and point.Y<=area.y+area.h,"course escaped the unobstructed arena rectangle")
    end end end
    end
end
`;

for (const [w,h] of resolutions) {
  test(`near overview contains the entire course within 290 studs and rejects corrupt bounds at ${w}x${h}`, () => runLua(presentationEngine + mathSource + geometryAssertions + `
setViewport(${w},${h}); camera.FieldOfView=55
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
    local d,shift,up,back,cy,cx,cz,yaw,box,reason,fitted,fov=arenaCamera(${w},${h},item[2],true)
    assert(d>=100 and d<=210 and fitted and fov>=85 and fov<=120,item[1].." failed bounded fit")
    assert(cx==0 and yaw==0 and shift==0,"overview must keep its optical-axis Focus")
    if item[1]~="correct" then assert(string.find(reason,"fallback",1,true),"bad bounds not identified") end
    local focus=Vector3.new(cx,cy,cz)
    camera.FieldOfView=fov
    camera.CFrame=CFrame.lookAt(focus+Vector3.new(math.sin(yaw)*back*d,up*d,math.cos(yaw)*back*d),focus)*CFrame.new(0,-shift,0)
    assertFraming(${w},${h})
end
`));
}

test('zero, nonfinite, tiny and extreme viewports yield a bounded fallback instead of an exponential zoom', () => runLua(presentationEngine + mathSource + `
for _,size in ipairs({{0,0},{0,844},{390,0},{0/0,844},{math.huge,844},{1,1},{1,10000},{10000,1},{40000,40000}}) do
    local d,shift,up,back,cy,cx,cz,yaw,box,reason,fitted,fov=arenaCamera(size[1],size[2],nil,true)
    assert(finite(d) and finite(shift) and d<=210 and finite(cy) and cx==0 and finite(cz) and not fitted)
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
local baselineFocus,baselineFov=camera.Focus.Position,camera.FieldOfView
publish(courseBox)
assert((camera.CFrame.Position-baseline).Magnitude<0.00001)
local padded={minX=-32,maxX=32,minY=50,maxY=92,minZ=-86,maxZ=80,yaw=60}
publish(padded)
assert((camera.CFrame.Position-baseline).Magnitude<0.00001,"padding moved a fixed authored course")
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
    assert(camera.CameraType==Enum.CameraType.Scriptable and camera.FieldOfView==baselineFov
        and camera.FieldOfViewMode==Enum.FieldOfViewMode.Vertical)
    assert((camera.Focus.Position-baselineFocus).Magnitude<0.00001)
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
    assert(self==player and focus.X==0 and focus.Y>=40 and focus.Y<=88 and math.abs(focus.Z)<=82 and timeout==5)
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

test('close Sprint overview keeps Focus on its optical axis and stays outside native realm geometry', () => runLua(clientScene + `
publish(courseBox)
for _,size in ipairs({${sizes}}) do
    setViewport(size[1],size[2]); renderStep(0.13)
    local d,shift,up,back,cy,cx,cz,yaw=arenaCamera(size[1],size[2],courseBox,true)
    assert(shift==0,"Sprint retained a local CFrame offset")
    local aim=Vector3.new(cx,cy,cz)
    local expected=CFrame.lookAt(aim+Vector3.new(math.sin(yaw)*back*d,up*d,math.cos(yaw)*back*d),aim)
    assert((camera.CFrame.Position-expected.Position).Magnitude<0.0001)
    assert(camera.CFrame.LookVector:Dot((aim-camera.CFrame.Position)*(1/d))>0.99999,"actual CFrame misses actual Focus")
    assert((camera.Focus.Position-aim).Magnitude<0.0001)
    assertFraming(size[1],size[2])
    for _,object in ipairs(workspace.RiftboundRealm:GetDescendants()) do
        if object:IsA("BasePart") and object.Size.Magnitude>=20 then
            assert(not containsPartBounds(object,camera.CFrame.Position),"lens inside "..object.Name)
        end
    end
end
setViewport(1080,1920)
local a=camera:WorldToViewportPoint(Vector3.new(0,64,63)) -- actual start
local b=camera:WorldToViewportPoint(Vector3.new(0,80,-60)) -- actual finish arch
local scale=viewportLayout(1080,1920)
assert(math.abs(a.Y-b.Y)/scale>190,"start-to-arch route became too small in the close overview")
assert(logged("aimDot=1.000000 focusError=0.000"))
`));

test('ward masking is local, survives replicated phase changes, and restores the original modifier in Roam', () => runLua(clientScene + `
local ward=workspace.RiftboundRealm["Starlight ward"]
assert(ward.LocalTransparencyModifier==1,"Stream View did not mask ward")
assert(containsPartBounds(ward,Vector3.new(0,71,-3)),"old focus was not inside the ward shell")
assert(not containsPartBounds(ward,Vector3.new(223.2,342,125.8)),"reported old camera was inside the ward")
assert(not containsPartBounds(ward,camera.CFrame.Position))
canvas.CameraToggle.Activated:Fire()
assert(ward.LocalTransparencyModifier==0 and camera.CameraType==Enum.CameraType.Custom)
ward.LocalTransparencyModifier=0.25 -- preserve an existing local presentation setting
canvas.CameraToggle.Activated:Fire()
assert(ward.LocalTransparencyModifier==1)
for _,time in ipairs({0,12,20,100,110}) do
    now=time; state:tick(time); state:advance(time)
    local snapshot=state:snapshot(time)
    World.render(snapshot,time); World.animate(time)
    local transparency,position=ward.Transparency,ward.CFrame.Position
    publish(courseBox)
    assert(ward.LocalTransparencyModifier==1)
    assert(ward.Transparency==transparency and (ward.CFrame.Position-position).Magnitude==0,"client changed server ward presentation/state")
end
canvas.CameraToggle.Activated:Fire()
assert(ward.LocalTransparencyModifier==0.25,"Roam failed to restore prior local modifier")
canvas.CameraToggle.Activated:Fire()
playerGui.RiftboundHUD.Enabled=false
renderStep(0.13)
assert(ward.LocalTransparencyModifier==0.25,"disabled HUD retained the Stream View mask")
`));

test('late or replaced ward geometry is masked without affecting other scenery or the saved Roam setting', () => runLua(clientScene + `
local old=workspace.RiftboundRealm["Starlight ward"]
local other=workspace.RiftboundRealm.SkybridgeSprint["START platform"]
local initialOtherModifier=other.LocalTransparencyModifier
old.Parent=nil
renderStep(0.13)
assert(old.LocalTransparencyModifier==0,"detached ward retained a stale local mask")
local ward=instance("Part","Starlight ward")
ward.Size=Vector3.new(110,110,110); ward.CFrame=CFrame.new(0,35,0)
ward.Shape=Enum.PartType.Ball; ward.Transparency=0.88; ward.LocalTransparencyModifier=0.35
ward.Parent=workspace.RiftboundRealm
renderStep(0.13)
assert(ward.LocalTransparencyModifier==1 and other.LocalTransparencyModifier==initialOtherModifier)
canvas.CameraToggle.Activated:Fire()
assert(ward.LocalTransparencyModifier==0.35 and ward.Transparency==0.88)
`));

test('camera diagnostics distinguish raw ward hits, excluded-shell rays, lens enclosures and external camera drift', () => runLua(clientScene + `
RaycastParams={new=function() return {} end}
local ward=workspace.RiftboundRealm["Starlight ward"]
local start=workspace.RiftboundRealm.SkybridgeSprint["START platform"]
function methods:Raycast(origin,direction,params)
    if params then
        assert(params.FilterType==Enum.RaycastFilterType.Exclude and params.FilterDescendantsInstances[1]==ward)
        return {Instance=start,Position=origin+direction*0.95}
    end
    return {Instance=ward,Position=origin+direction*0.9}
end
local blocker=instance("Part","Lens enclosure",workspace.RiftboundRealm)
blocker.Size=Vector3.new(30,30,30); blocker.CFrame=CFrame.new(camera.CFrame.Position)
blocker.Transparency,blocker.LocalTransparencyModifier=0,0
camera.CFrame=CFrame.lookAt(Vector3.new(0,-100,0),Vector3.new(0,-100,1))
publish(courseBox) -- resize reapplies before render; inject a later competing controller next
now=10
camera.CFrame=CFrame.lookAt(Vector3.new(0,-100,0),Vector3.new(0,-100,1))
renderStep(0.13)
assert(logged("ray=Starlight ward at ") and logged("filteredRay=START platform at "))
assert(logged("locally masking camera-enclosing geometry: Lens enclosure"))
assert(blocker.LocalTransparencyModifier==1)
local driftFound=false
for _,line in ipairs(logs) do
    local drift=string.match(line,"preApplyPositionDrift=([%d%.]+)")
    if drift and tonumber(drift)>100 then driftFound=true end
end
assert(driftFound,"another controller's camera movement was not reported")
assertFraming(390,844)
ward.Parent=nil; now=20; renderStep(0.13)
assert(logged("ward=absent riftLocalMask=true largeGeometryAtLens=none"))
canvas.CameraToggle.Activated:Fire()
assert(blocker.LocalTransparencyModifier==0,"lens enclosure mask was not restored in Roam")
`));

test('ward hypothesis can be isolated by disabling only the local mask while retaining the direct camera', () => {
  const unmaskedClient = client.replace('local STREAM_HIDE_WARD = true', 'local STREAM_HIDE_WARD = false');
  runLua(presentationEngine + modules + mathSource + geometryAssertions + `
print=function() end
World.build(Config)
local ward=workspace.RiftboundRealm["Starlight ward"]
ward.LocalTransparencyModifier=0.4
;(function() ${unmaskedClient} end)()
renderStep(0.13)
assert(ward.LocalTransparencyModifier==0.4,"ward test toggle still modifies ward")
assertFraming(390,844)
local aim=camera.Focus.Position-camera.CFrame.Position
assert(camera.CFrame.LookVector:Dot(aim*(1/aim.Magnitude))>0.99999)
`);
});

test('display volumes enclose actual authored geometry and all five racing/jump envelopes', () => runLua(presentationEngine + modules + mathSource + `
World.build(Config)
local function covered(p)
    for _,v in ipairs(SprintVolumes) do
        if p.X>=v.minX and p.X<=v.maxX and p.Y>=v.minY and p.Y<=v.maxY and p.Z>=v.minZ and p.Z<=v.maxZ then return true end
    end
    return false
end
for _,object in ipairs(workspace.RiftboundRealm.SkybridgeSprint:GetDescendants()) do
    if object:IsA("BasePart") then
        for _,x in ipairs({-0.5,0.5}) do for _,y in ipairs({-0.5,0.5}) do for _,z in ipairs({-0.5,0.5}) do
            assert(covered(object.CFrame:PointToWorldSpace(Vector3.new(x*object.Size.X,y*object.Size.Y,z*object.Size.Z))),"authored part outside display volumes: "..object.Name)
        end end end
    end
end
for lane=1,5 do for cp=0,12 do
    local root=World.sprintPoint(lane,cp)
    for _,x in ipairs({-3,3}) do for _,z in ipairs({-3,3}) do
        assert(covered(root+Vector3.new(x,10,z)),"racer jump envelope clipped")
    end end
end end
`));

test('Storm rift intersects the authored finish sightline; local masks restore in Roam without changing server opacity', () => runLua(clientScene + `
local rift=workspace.RiftboundRealm["Storm rift"]
local gate=workspace.RiftboundRealm.SkybridgeSprint["Finish arch"]
local origin=camera.CFrame.Position
local segment=gate.Position-origin
local t=(rift.Position-origin):Dot(segment)/segment:Dot(segment)
local closest=origin+segment*math.max(0,math.min(1,t))
assert(t>0 and t<1 and (closest-rift.Position).Magnitude<rift.Size.X/2,"finish sightline no longer crosses sphere; review local mask")
assert(rift.LocalTransparencyModifier==1)
local opacity=rift.Transparency
canvas.CameraToggle.Activated:Fire()
assert(rift.LocalTransparencyModifier==0 and rift.Transparency==opacity)
rift.LocalTransparencyModifier=0.2
canvas.CameraToggle.Activated:Fire()
for _,time in ipairs({0,12,20,100}) do
    now=time; state:tick(time); state:advance(time)
    World.render(state:snapshot(time),time); World.animate(time)
    local alpha=rift.Transparency
    publish(courseBox)
    assert(rift.LocalTransparencyModifier==1 and rift.Transparency==alpha)
end
canvas.CameraToggle.Activated:Fire()
assert(rift.LocalTransparencyModifier==0.2)
`));

test('Stream daylight restores on Roam and leaves animated gift ambient color unchanged', () => runLua(clientScene + `
assert(lighting.ClockTime==14 and lighting.Brightness==3 and lighting.ExposureCompensation==0.25)
assert(lighting.GlobalShadows==false and lighting.EnvironmentDiffuseScale==1)
local ambient=Color3.fromRGB(100,70,160)
lighting.Ambient=ambient
lighting.ClockTime=0; lighting.ExposureCompensation=-5
renderStep(0.13)
assert(lighting.ClockTime==14 and lighting.ExposureCompensation==0.25 and lighting.Ambient==ambient)
canvas.CameraToggle.Activated:Fire()
assert(lighting.ClockTime==18.3 and lighting.Brightness==2 and lighting.ExposureCompensation==0)
assert(lighting.GlobalShadows==true and lighting.EnvironmentDiffuseScale==0 and lighting.EnvironmentSpecularScale==1)
assert(lighting.Ambient==ambient)
canvas.CameraToggle.Activated:Fire()
assert(lighting.ClockTime==14)
playerGui.RiftboundHUD.Enabled=false; renderStep(0.13)
assert(lighting.ClockTime==18.3 and lighting.GlobalShadows==true)
`));

test('lighting hypothesis can be isolated with the local daylight flag disabled', () => {
  const noDaylight = client.replace('local STREAM_DAYLIGHT = true','local STREAM_DAYLIGHT = false');
  runLua(presentationEngine + modules + `
print=function() end
World.build(Config)
lighting.ExposureCompensation=-0.4
;(function() ${noDaylight} end)()
renderStep(0.13)
assert(lighting.ClockTime==18.3 and lighting.Brightness==2 and lighting.ExposureCompensation==-0.4)
`);
});

test('all key-anchor sightlines reveal an accessory obstruction beyond the optical focus', () => runLua(clientScene + `
RaycastParams={new=function() return {} end}
local avatar=instance("Model","Traveler_ObstructingOutfit",workspace.RiftboundRealm)
local outfit=instance("Accessory","OversizedHat",avatar)
local handle=instance("Part","Handle",outfit)
function methods:GetFullName()
    local names,node={},self
    while node do table.insert(names,1,node.Name); node=node.Parent end
    return table.concat(names,".")
end
function methods:Raycast(origin,direction,params)
    if origin.Z+direction.Z < -55 then return {Instance=handle,Position=origin+direction*0.8} end
end
publish(courseBox)
assert(logged("anchor=START platform world=(0.0,64.0,63.0)"))
assert(logged("anchor=Finish arch world=(0.0,80.0,-60.0)"))
assert(logged("sightline=Workspace.RiftboundRealm.Traveler_ObstructingOutfit.OversizedHat.Handle"))
assert(logged("anchor=Sprint podium 3"))
assert(logged("filteredRay=clear"),"test did not demonstrate the old focus-ray blind spot")
`));

test('render probes are opt-in local geometry, follow the current camera and clean up in Roam/disabled HUD', () => runLua(clientScene + `
publish(courseBox)
assert(not workspace:FindFirstChild("RiftboundLocalRenderCheck"))
local baseline=camera.CFrame.Position
local cash=state:snapshot(now).leaderboard[1].money
local actionCount=#actions
canvas.KeeperToggle.Activated:Fire()
canvas.TestTools.RenderCheck.Activated:Fire(); renderStep(0.13)
assert(not canvas.TestTools.Visible,"drawer covers the diagnostic view")
local folder=workspace.RiftboundLocalRenderCheck
local pink=folder.Near_PINK_12_studs
local green=folder.Course_GREEN
assert(#folder:GetChildren()==2)
assert((pink.Position-camera.CFrame:PointToWorldSpace(Vector3.new(-1.2,0,-12))).Magnitude<0.0001)
assert((green.Position-Vector3.new(0,104,0)).Magnitude<0.0001)
for _,part in ipairs({pink,green}) do
    assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery)
    assert(part.Transparency==0 and part.LocalTransparencyModifier==0)
    local point,visible=camera:WorldToViewportPoint(part.Position)
    assert(visible and point.Z>0,"probe offscreen")
end
assert((camera.CFrame.Position-baseline).Magnitude<0.0001)
setViewport(1080,1920); renderStep(0.13)
assert((pink.Position-camera.CFrame:PointToWorldSpace(Vector3.new(-1.2,0,-12))).Magnitude<0.0001)
canvas.CameraToggle.Activated:Fire()
assert(not workspace:FindFirstChild("RiftboundLocalRenderCheck"))
canvas.CameraToggle.Activated:Fire(); renderStep(0.13)
assert(workspace:FindFirstChild("RiftboundLocalRenderCheck"))
playerGui.RiftboundHUD.Enabled=false; renderStep(0.13)
assert(not workspace:FindFirstChild("RiftboundLocalRenderCheck"))
playerGui.RiftboundHUD.Enabled=true; renderStep(0.13)
canvas.TestTools.RenderCheck.Activated:Fire(); renderStep(0.13)
assert(not workspace:FindFirstChild("RiftboundLocalRenderCheck"))
assert(#actions==actionCount and state:snapshot(now).leaderboard[1].money==cash,"diagnostic altered gameplay")
`));

test('render diagnostics report composed opacity, rendered camera offset and drift between log frames', () => runLua(clientScene + `
local start=workspace.RiftboundRealm.SkybridgeSprint["START platform"]
start.Transparency=0.9; start.LocalTransparencyModifier=0.9
function methods:GetRenderCFrame() return self.CFrame*CFrame.new(0,2,0) end
publish(courseBox)
assert(logged("anchor=START platform Transparency=0.900 LocalTransparencyModifier=0.900 effectiveOpacity=0.010"))
assert(logged("renderedPositionDelta=2.000 renderedAimDelta=0.000000"))
assert(logged("parts=155 opaque=154"))
camera.CFrame=CFrame.new(0,-500,0)
renderStep(0.13) -- no log due yet: drift must survive to the next reporting frame
now=11; renderStep(0.13)
local found=false
for _,line in ipairs(logs) do
    local drift=string.match(line,"intervalPositionDrift=([%d%.]+)")
    if drift and tonumber(drift)>100 then found=true end
end
assert(found,"inter-frame camera conflict was lost before diagnostics")
assertFraming(390,844)
`));

test('overview refits keep ten-second logging and quarter-second scene-scan limits across snapshots', () => runLua(clientScene + `
local sceneScans=0
local originalDescendants=methods.GetDescendants
function methods:GetDescendants()
    if self==workspace then sceneScans=sceneScans+1 end
    return originalDescendants(self)
end
publish(courseBox)
for step=1,660 do
    now=step/60
    if step%30==0 then publish(courseBox) else renderStep(1/60) end
end
local blocks=0
for _,line in ipairs(logs) do if string.find(line,"[Riftbound camera] presentation=",1,true) then blocks=blocks+1 end end
assert(blocks==2,"overview reset diagnostic throttle: "..blocks.." blocks in 11 seconds")
assert(sceneScans<=46,"overview reset lens-scan throttle: "..sceneScans.." full scene scans")
assertFraming(390,844)
`));

test('held camera survives phase/round/viewport changes and camera replacement without stopping the game', () => runLua(clientScene + `
publish(courseBox)
local heldFrame,heldFocus,heldFov=camera.CFrame,camera.Focus.Position,camera.FieldOfView
local actionCount=#actions
canvas.TestTools.HoldCamera.Activated:Fire()
assert(not canvas.TestTools.Visible and canvas.TestTools.HoldCamera.Text=="HOLD CAMERA: ON")
local function sameView()
    assert((camera.CFrame.Position-heldFrame.Position).Magnitude<0.0001)
    assert(camera.CFrame.LookVector:Dot(heldFrame.LookVector)>0.99999)
    assert((camera.Focus.Position-heldFocus).Magnitude<0.0001 and camera.FieldOfView==heldFov)
end
for _,time in ipairs({12,20,100,110,122}) do
    state:tick(time); state:advance(time); now=time
    local snapshot=state:snapshot(now); snapshot.cameraBounds=courseBox
    remotes.Snapshot.OnClientEvent:Fire(snapshot)
    sameView() -- snapshot resize must not apply another view between frames
    renderStep(0.13); sameView()
end
setViewport(1080,1920); sameView(); renderStep(0.13); sameView()
local replacement=instance("Camera","Replacement",workspace)
replacement.CFrame=CFrame.new(0,-500,0); replacement.ViewportSize=viewport
replacement.CameraType=Enum.CameraType.Custom; replacement.FieldOfView=70
replacement.FieldOfViewMode=Enum.FieldOfViewMode.Vertical
camera=replacement; workspace.CurrentCamera=replacement
workspace:GetPropertyChangedSignal("CurrentCamera"):Fire(); sameView()
renderStep(0.13); sameView()
assert(logged("shot=held camera") and logged("round=2"))
assert(#actions==actionCount and state:snapshot(now).round==2,"holding stopped or changed server rounds")
canvas.TestTools.HoldCamera.Activated:Fire(); renderStep(0.13)
assert(canvas.TestTools.HoldCamera.Text=="HOLD CAMERA: OFF")
assert((camera.CFrame.Position-heldFrame.Position).Magnitude>1,"release did not restore viewport fitting")
canvas.TestTools.HoldCamera.Activated:Fire(); renderStep(0.13)
canvas.CameraToggle.Activated:Fire()
assert(camera.CameraType==Enum.CameraType.Custom and canvas.TestTools.HoldCamera.Text=="HOLD CAMERA: OFF")
`));

test('spectator deck rescues existing player characters and handles later respawns outside the race lanes', () => runLua(presentationEngine + modules + `
World.build(Config)
player.CharacterAdded=signal()
local function character(name)
    local model=instance("Model",name,workspace)
    local main=instance("Part","HumanoidRootPart",model)
    model.PrimaryPart=main
    main.CFrame=CFrame.new(0,35,22)
    main.AssemblyLinearVelocity=Vector3.new(2,-100,3)
    return model
end
player.Character=character("Host")
World.preparePlayer(player)
assert(player.RespawnLocation==workspace.RiftboundRealm.Arrival)
assert(player.RespawnLocation.Position.X>26 and player.RespawnLocation.Position.Y>83)
spawnedJobs[#spawnedJobs]()
assert((player.Character:GetPivot().Position-Vector3.new(48,87,58)).Magnitude<0.0001)
assert(player.Character.PrimaryPart.AssemblyLinearVelocity.Magnitude==0)
local nextCharacter=character("RespawnedHost")
player.CharacterAdded:Fire(nextCharacter)
spawnedJobs[#spawnedJobs]()
assert((nextCharacter:GetPivot().Position-Vector3.new(48,87,58)).Magnitude<0.0001)
local deck=workspace.RiftboundRealm["Spectator deck"]
assert(deck.Position.X-deck.Size.X/2>26,"spectator platform obstructs the physical race")
`));

test('Stream effect isolation includes late and camera effects and restores exact Roam states', () => runLua(clientScene + `
local atmosphere=instance("Atmosphere","CustomFog",lighting)
local blur=instance("BlurEffect","Blur",lighting)
local disabled=instance("ColorCorrectionEffect","AlreadyOff",camera); disabled.Enabled=false
now=1; renderStep(0.13)
assert(atmosphere.Parent==nil and blur.Enabled==false and disabled.Enabled==false)
assert(lighting.FogStart==10000 and lighting.FogEnd==100000)
canvas.CameraToggle.Activated:Fire()
assert(atmosphere.Parent==lighting and blur.Enabled==true and disabled.Enabled==false)
assert(lighting.FogStart==1000 and lighting.FogEnd==5000)
canvas.CameraToggle.Activated:Fire()
assert(atmosphere.Parent==nil and blur.Enabled==false)
local late=instance("DepthOfFieldEffect","LateDepth",camera)
now=2; renderStep(0.13)
assert(late.Enabled==false)
playerGui.RiftboundHUD.Enabled=false; renderStep(0.13)
assert(atmosphere.Parent==lighting and blur.Enabled==true and late.Enabled==true and disabled.Enabled==false)
assert(not atmosphere.Destroyed,"Atmosphere was permanently removed")
`));

test('Roam camera starts outside the safe deck with the actual character as subject', () => runLua(clientScene + `
local character=instance("Model","Host",workspace)
local main=instance("Part","HumanoidRootPart",character); main.CFrame=CFrame.new(48,87,58)
local humanoid=instance("Humanoid","Humanoid",character)
player.Character=character
canvas.CameraToggle.Activated:Fire()
assert(camera.CameraType==Enum.CameraType.Custom and camera.CameraSubject==humanoid)
assert((camera.Focus.Position-Vector3.new(48,89,58)).Magnitude<0.0001)
assert((camera.CFrame.Position-Vector3.new(70,105,82)).Magnitude<0.0001)
canvas.CameraToggle.Activated:Fire(); renderStep(0.13)
assert(camera.CameraType==Enum.CameraType.Scriptable)
`));

test('Stream masks enclosing geometry outside the generated realm and restores it without touching physics', () => runLua(clientScene + `
publish(courseBox)
-- Terrain inherits BasePart but does not support ordinary part opacity masking.
local terrain=instance("Terrain","Terrain",workspace)
local object=instance("Part","UserSceneryOutsideRealm",workspace)
object.Size=Vector3.new(50,50,50); object.CFrame=CFrame.new(camera.CFrame.Position)
object.Transparency,object.LocalTransparencyModifier,object.CanCollide=0,0.25,true
local rig=instance("Model","ProtectedRacer",workspace)
instance("Humanoid","Humanoid",rig)
local body=instance("Part","LargeCostume",rig)
body.Size=Vector3.new(50,50,50); body.CFrame=CFrame.new(camera.CFrame.Position)
body.Transparency,body.LocalTransparencyModifier=0,0.1
now=1; renderStep(0.13)
assert(object.LocalTransparencyModifier==1)
assert(terrain.LocalTransparencyModifier==nil,"Terrain was treated as an ordinary maskable part")
assert(body.LocalTransparencyModifier==0.1,"camera masking hid a Humanoid model")
assert(object.Transparency==0 and object.CanCollide==true)
assert(logged("locally masking camera-enclosing geometry: UserSceneryOutsideRealm"))
canvas.CameraToggle.Activated:Fire()
assert(object.LocalTransparencyModifier==0.25)
canvas.CameraToggle.Activated:Fire(); now=2; renderStep(0.13)
assert(object.LocalTransparencyModifier==1)
object.CFrame=CFrame.new(1000,1000,1000); now=3; renderStep(0.13)
assert(object.LocalTransparencyModifier==0.25)
`));

test('automatic cinematic shots follow observed racers, frame actual podium winners and return to the overview', () => runLua(clientScene + `
local models={}
for i=1,5 do
    local name="Racer_"..i
    local model=World.offlineAvatar(name); World.arrive(model,i,name)
    model:PivotTo(CFrame.new((i-3)*6,68,50))
    models[i]=model
end
state:advance(12); state:advance(20)
now=20; publish(courseBox)
local overview=camera.CFrame.Position
assertFraming(390,844)
now=23; publish(courseBox)
assert(logged("shot=racing pack") and (camera.CFrame.Position-overview).Magnitude>50)
assert(logged("revision=near-course-v6") and logged("presentation=near-course-v6"))
local trackingFrame,trackingFov=camera.CFrame,camera.FieldOfView
local refreshed=state:snapshot(now); refreshed.cameraBounds=courseBox
remotes.Snapshot.OnClientEvent:Fire(refreshed)
assert(camera.FieldOfView==trackingFov and (camera.CFrame.Position-trackingFrame.Position).Magnitude<0.0001,
    "snapshot applied the wider overview lens to a close tracking shot")
local function racerFramed(model)
    local point,visible=camera:WorldToViewportPoint(model.PrimaryPart.Position)
    local s,ox,oy=viewportLayout(camera.ViewportSize.X,camera.ViewportSize.Y)
    local area=screenRect(Layout.arena,s,ox,oy)
    assert(visible and point.X>area.x and point.X<area.x+area.w and point.Y>area.y and point.Y<area.y+area.h,"racer not in clear frame")
end
for _,model in ipairs(models) do racerFramed(model) end
now=26; publish(courseBox)
assert(logged("shot=racer close-up"))
local before=camera.CFrame.Position
models[1]:PivotTo(CFrame.new(-12,68,30))
now=27; renderStep(0.2)
assert((camera.CFrame.Position-before).Magnitude>1,"close-up did not follow physical root movement")
racerFramed(models[1])
for i=1,3 do for cp=1,12 do assert(state:recordCheckpoint("Racer_"..i,cp,20+cp*(0.5+i*0.1),state.round)) end end
state:advance(100)
local winners=state:snapshot(100).winners
assert(#winners==3)
for rank,row in ipairs(winners) do
    workspace.RiftboundRealm["Traveler_"..row.username]:PivotTo(CFrame.new(({0,-9,9})[rank],72,-70))
end
now=100; publish(courseBox)
assert(logged("shot=podium celebration"))
for _,row in ipairs(winners) do racerFramed(workspace.RiftboundRealm["Traveler_"..row.username]) end
now=105; publish(courseBox)
assert(logged("shot=winner close-up"))
racerFramed(workspace.RiftboundRealm["Traveler_"..winners[1].username])
local cash=state:snapshot(now).leaderboard[1].money
renderStep(0.13)
assert(state:snapshot(now).leaderboard[1].money==cash,"camera awarded money")
canvas.CameraToggle.Activated:Fire(); assert(camera.CameraType==Enum.CameraType.Custom)
canvas.CameraToggle.Activated:Fire(); renderStep(0.13)
assert(camera.CameraType==Enum.CameraType.Scriptable)
state:advance(110); now=110; publish(courseBox)
assert((camera.CFrame.Position-overview).Magnitude<0.001,"next gathering did not restore the safe overview")
`));

for (const [w,h] of [[320,568],[390,844],[1080,1920],[1920,1080]]) {
  test(`cinematic portrait fitting encloses racer bodies and safely rejects invalid points at ${w}x${h}`, () => runLua(presentationEngine + mathSource + `
setViewport(${w},${h})
local points={Vector3.new(-12,68,40),Vector3.new(12,68,25)}
local cf,focus,d,fov=cinematicCamera(${w},${h},points,35,40)
assert(cf and d>=65 and d<=220)
camera.CFrame,camera.Focus,camera.FieldOfView=cf,CFrame.new(focus),fov
local s,ox,oy=viewportLayout(${w},${h}); local area=screenRect(Layout.arena,s,ox,oy)
for _,p in ipairs(points) do
    for _,x in ipairs({-5,5}) do for _,y in ipairs({-5,12}) do for _,z in ipairs({-5,5}) do
        local point,visible=camera:WorldToViewportPoint(p+Vector3.new(x,y,z))
        assert(visible and point.X>=area.x and point.X<=area.x+area.w and point.Y>=area.y and point.Y<=area.y+area.h)
    end end end
end
assert(not cinematicCamera(0,0,points,35,40))
assert(not cinematicCamera(${w},${h},{Vector3.new(0/0,68,0)},35,40))
assert(not cinematicCamera(${w},${h},{Vector3.new(0,68,-1000),Vector3.new(0,68,1000)},35,40))
`));
}
