import test from 'node:test';
import {readFileSync} from 'node:fs';
import {runLua} from './helpers/lua.js';
import {presentationEngine} from './helpers/presentation-engine.js';
const read=p=>readFileSync(new URL('../roblox/'+p,import.meta.url),'utf8');
const client=read('StarterPlayerScripts/Realm.client.lua');
const base=presentationEngine+`
local Config=(function() ${read('ServerScriptService/Config.lua')} end)()
Config.SoloEntrances=false -- v11 isolated-domain/shot regression; production requires the v13 preparation gate
Config.LoadAvatarAppearances=false
local Realm=(function() ${read('ServerScriptService/RealmState.lua')} end)()
local World=(function() ${read('ServerScriptService/World.lua')} end)()
World.build(Config)
local state=Realm.new(Config,0)
local logs={};print=function(line) logs[#logs+1]=line end
local function join(i)
 local name='Viewer_'..i
 assert(state:register(name,0,state.round,now,now,'register:'..state.round..':'..i))
 World.arrive(World.offlineAvatar(name),i,name)
end
local scene
local function publish(time)
 now=time
 local s=state:snapshot(time);s.cameraBounds=World.cameraBounds(s);s.course=World.courseInfo()
 World.render(s,time);World.animate(time)
 if scene then scene() end
 remotes.Snapshot.OnClientEvent:Fire(s);renderStep(.1)
 return s
end
;(function() ${client} end)()
local hud=playerGui.RiftboundHUD
local function start(count)
 for i=1,count do join(i) end
 state:advance(30);publish(30);state:advance(34);World.sprintStep(state,34);publish(34)
end
local function pack(checkpoint)
 scene=function()
  for i=1,#state.roster do
   local rig=workspace.RiftboundRealm['Traveler_Viewer_'..i]
   local p=World.routePoint(checkpoint,'shared',(i-1)%5*6-12)+Vector3.new(0,0,math.floor((i-1)/5)*5)
   rig:PivotTo(CFrame.new(p));rig.PrimaryPart.CFrame=CFrame.lookAt(p,p+Vector3.new(0,0,-1))
  end
 end
end
`;

test('pre-race groups fairly introduce all 20 staggered arrivals before registration closes without mutating participation',()=>runLua(base+`
local seen,solo,group={},false,false
for step=0,56 do
 now=step*.5
 if step<20 then join(step+1) end
 state:advanceEntrances(now);publish(now)
 local names=hud:GetAttribute('BroadcastSubjects') or ''
 for name in names:gmatch('[^,]+') do seen[name]=true end
 if hud:GetAttribute('BroadcastShot')=='racer introduction / CLOSE-UP' then solo=solo or not names:find(',',1,true) end
 if names:find(',',1,true) then group=true end
 assert(state.phase=='registration' and #state.lockedRoster==0)
end
for i=1,20 do assert(seen['Viewer_'..i],'unseen competitor '..i) end
assert(solo and group,'busy registration lost individual close-ups or groups')
assert(#state.roster==20 and state.deadline==30.5)
assert(hud.VerticalStreamCanvas.EventStrip.Message.Text~='COMMENT YOUR ROBLOX USERNAME TO JOIN!')
-- Registration closes independently of whichever shot was playing.
state:advance(30.5);publish(30.5)
assert(state.phase=='countdown' and #state.lockedRoster==20)
assert(not state:register('Too_Late',0,state.round,31,31,'late'))
`));

for (const count of [5,10,15,20]) test(`broadcast rotates angles and competitors with ${count} physical actor mocks, preserving roots and race values`,()=>runLua(base+`
start(${count});pack(20)
for _,m in pairs(state.crew) do m.distance=20;m.score=20 end
local modes,seen,previous,lastChange={}, {}, nil, nil
for step=0,102 do
 local time=36+step*.5
 publish(time)
 local shot=hud:GetAttribute('BroadcastShot')
 modes[shot]=true
 if previous~=shot then
  if lastChange then assert(time-lastChange>=4 and time-lastChange<=8,'normal shot cadence') end
  previous,lastChange=shot,time
 end
 for name in hud:GetAttribute('BroadcastSubjects'):gmatch('[^,]+') do
  seen[name]=true
  local rig=workspace.RiftboundRealm['Traveler_'..name]
  local screen,on=camera:WorldToViewportPoint(rig.PrimaryPart.Position)
  assert(on and screen.Z>1,'offscreen actual subject')
 end
 assert(camera.CFrame.Position.Y>=92 and camera.CFrame.Position.Y<=220)
 assert((camera.CFrame.Position-workspace.RiftboundRealm.Traveler_Viewer_1.PrimaryPart.Position).Magnitude<210,'extreme zoom-out')
 assert(state.deadline==154 and state.phase=='storm' and state.activityEntrants==${count})
 for _,m in pairs(state.crew) do assert(m.distance==20 and m.score==20 and m.finishedAt==0) end
end
for _,mode in ipairs({'FRONT','REAR','SIDE','WIDE','LOW ANGLE','LEADER','MID-PACK'}) do assert(modes[mode],'missing angle '..mode) end
local n=0;for _ in pairs(seen) do n=n+1 end
assert(n>=math.min(${count},12),'lower-ranked racers ignored: '..n)
`));

test('front/rear/side views use actual root facing; starting shots and manual Roam remain usable',()=>runLua(base+`
for i=1,5 do join(i) end
state:advance(30)
local starting={}
for _,t in ipairs({30,31.5,33}) do publish(t);starting[hud:GetAttribute('BroadcastShot')]=true end
for _,mode in ipairs({'FRONT','SIDE','REAR'}) do assert(starting['starting grid / '..mode]) end
state:advance(34);World.sprintStep(state,34);pack(24)
for _,m in pairs(state.crew) do m.distance=24;m.score=24 end
publish(36)
local root=workspace.RiftboundRealm.Traveler_Viewer_1.PrimaryPart
local p=root.Position
local before=camera.CFrame.Position
scene=function() for i=1,5 do local r=workspace.RiftboundRealm['Traveler_Viewer_'..i].PrimaryPart;r.CFrame=CFrame.lookAt(r.Position,r.Position+Vector3.new(1,0,0)) end end
publish(36.5)
assert((camera.CFrame.Position-before).Magnitude>5,'actual facing ignored')
hud.VerticalStreamCanvas.CameraToggle.Activated:Fire();assert(camera.CameraType==Enum.CameraType.Custom)
local actionsBefore=#actions;publish(37);assert(camera.CameraType==Enum.CameraType.Custom and #actions==actionsBefore)
hud.VerticalStreamCanvas.CameraToggle.Activated:Fire();publish(37.5);assert(camera.CameraType==Enum.CameraType.Scriptable)
`));

test('native-query contract rejects a blocked front angle and never hides the road or frames a remote grid',()=>runLua(base+`
start(5);pack(24)
for _,m in pairs(state.crew) do m.distance=24;m.score=24 end
RaycastParams={new=function() return {} end};OverlapParams={new=function() return {} end}
local queried,blocked,boxes=0,0,0
workspace.Raycast=function(_,origin,direction,params)
 queried=queried+1
 assert(params.FilterType==Enum.RaycastFilterType.Exclude)
 for _,obj in ipairs(params.FilterDescendantsInstances) do assert(obj~=workspace.RiftboundRealm.SkybridgeSprint,'course excluded from obstruction checks') end
 if origin.Z<World.routePoint(24,'shared',0).Z-10 then blocked=blocked+1;return {Instance=workspace.RiftboundRealm.SkybridgeSprint['START platform']} end
end
workspace.GetPartBoundsInBox=function(_,cf,size,params) boxes=boxes+1;assert(size.X>=3);return {} end
workspace.Blockcast=function() return nil end
publish(36)
assert(queried>0 and blocked>0 and boxes>0,'query counts '..queried..'/'..blocked..'/'..boxes)
assert(camera.CFrame.Position.Z>World.routePoint(24,'shared',0).Z-10,'blocked requested angle used: '..camera.CFrame.Position.Z)
local _,on=camera:WorldToViewportPoint(workspace.RiftboundRealm.Traveler_Viewer_1.PrimaryPart.Position);assert(on,'obstruction fallback lost subject, lens='..camera.CFrame.Position.Z)
assert(workspace.RiftboundRealm.SkybridgeSprint['START platform'].LocalTransparencyModifier~=1)
local safe=camera.CFrame.Position
local caption=hud.VerticalStreamCanvas.EventStrip.Message.Text
local shown=hud:GetAttribute('BroadcastSubjects')
workspace.Raycast=function() error('query unavailable') end
assert(state:activatePowerup('Viewer_5','trail',37,state.round,'blocked-fx'));state:advanceEntrances(37)
publish(37)
assert((camera.CFrame.Position-safe).Magnitude<.001,'query failure authorized unvalidated shot')
assert(hud:GetAttribute('BroadcastSubjects')==shown and hud.VerticalStreamCanvas.EventStrip.Message.Text==caption,'held view announced an unframed racer')
`));

test('bounded event queue handles overtakes, route changes, power-ups and measured crossings; finish preempts cosmetics',()=>runLua(base+`
start(20);pack(20)
for i=1,20 do local m=state.crew['viewer_'..i];m.distance=21-i*.5;m.score=math.floor(m.distance) end
publish(36)
state.crew.viewer_2.distance=21;state.crew.viewer_2.score=21
publish(36.5);assert(hud:GetAttribute('BroadcastShot')=='overtake close-up')
for i=3,20 do state.crew['viewer_'..i].route='shortcut' end
publish(37);assert(hud:GetAttribute('BroadcastQueue')<=8 and hud:GetAttribute('BroadcastShot')=='overtake close-up')
assert(state:activatePowerup('Viewer_3','trail',37,state.round,'fx'));state:advanceEntrances(37);publish(37.5)
state.crew.viewer_1.distance=45;publish(38)
assert(hud:GetAttribute('BroadcastShot')=='finish line','finish did not preempt lower priority highlight')
local m=state.crew.viewer_1;m.raceStatus='finished';m.finishedAt=38.5;m.elapsed=4.5;m.placement=1;m.distance=48;m.score=48
publish(38.5);assert(hud:GetAttribute('BroadcastShot')=='finish crossing')
assert(state.deadline==154 and state.crew.viewer_2.raceStatus=='racing')
`));

test('montage coverage and queued highlights reset with the fresh round; history stays in the ledger',()=>runLua(base+`
start(5);pack(20);publish(36)
scene=nil;state:advance(154);publish(154);state:advance(164);publish(164)
assert(#state.roster==0 and #state.crewOrder==5 and state.round==2)
assert(hud:GetAttribute('BroadcastShot')=='waiting lobby' and hud:GetAttribute('BroadcastSubjects')=='')
now=165;join(5);publish(165)
assert(hud:GetAttribute('BroadcastSubjects')=='Viewer_5' and #state.roster==1 and state.deadline==0)
assert(#state.raceHistory==1 and state.crew.viewer_1.races==1)
`));

test('airborne motion and a moving close duel trigger short highlights; shortcut changes wait for a normal-view gap',()=>runLua(base+`
start(5);pack(15)
for i=1,5 do local m=state.crew['viewer_'..i];m.distance=15-i;m.score=math.floor(m.distance) end
publish(36)
local root=workspace.RiftboundRealm.Traveler_Viewer_1.PrimaryPart
root.AssemblyLinearVelocity=Vector3.new(0,12,0)
root.Parent.Humanoid.FloorMaterial=Enum.Material.Air
publish(36.5);assert(hud:GetAttribute('BroadcastShot')=='jump highlight')
root.AssemblyLinearVelocity=Vector3.new();root.Parent.Humanoid.FloorMaterial=Enum.Material.Slate
state.crew.viewer_3.route='shortcut';publish(37.5)
publish(38);assert(hud:GetAttribute('BroadcastShot')~='jump highlight' and hud:GetAttribute('BroadcastShot')~='shortcut highlight')
publish(42);assert(hud:GetAttribute('BroadcastShot')=='shortcut highlight','queued shortcut missing: '..hud:GetAttribute('BroadcastShot'))
publish(44)
state.crew.viewer_1.distance=14;state.crew.viewer_2.distance=13.9
root.AssemblyLinearVelocity=Vector3.new(0,0,-12)
publish(47.5);publish(48.5)
assert(hud:GetAttribute('BroadcastShot')=='close battle','moving duel missing: '..hud:GetAttribute('BroadcastShot'))
assert(state.deadline==154 and state.crew.viewer_1.finishedAt==0)
`));

const mathSource=client.split('-- BEGIN PRESENTATION MATH')[1].split('\n').slice(1).join('\n').split('-- END PRESENTATION MATH')[0];
test('portrait and landscape broadcast fitting contains full avatar/jump margins for every facing and low-angle profile',()=>runLua(presentationEngine+mathSource+`
for _,size in ipairs({{390,844},{1080,1920},{1158,536}}) do
 local w,h=size[1],size[2];setViewport(w,h)
 local scale,ox,oy=viewportLayout(w,h);local area=screenRect(Layout.arena,scale,ox,oy)
 for _,yaw in ipairs({0,45,90,135,180,225,270,315}) do
  for _,elevation in ipairs({24,36,42}) do
   local p=Vector3.new(20,76,-420)
   local cf,focus,distance,fov=cinematicCamera(w,h,{p},yaw,elevation,false,false,{floor=elevation==24 and 92 or 100})
   assert(cf and distance<=150 and cf.Position.Y>=92,'profile failed to fit')
   camera.CFrame,camera.FieldOfView=cf,fov
   for _,x in ipairs({-5,5}) do for _,y in ipairs({-5,12}) do for _,z in ipairs({-5,5}) do
    local screen,on=camera:WorldToViewportPoint(p+Vector3.new(x,y,z))
    assert(on and screen.X>=area.x and screen.X<=area.x+area.w and screen.Y>=area.y and screen.Y<=area.y+area.h,'body escaped action rectangle')
   end end end
  end
 end
end
`));
