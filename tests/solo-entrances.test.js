import test from 'node:test';
import {readFileSync} from 'node:fs';
import {runLua} from './helpers/lua.js';
import {presentationEngine} from './helpers/presentation-engine.js';
const read=n=>readFileSync(new URL('../roblox/'+n,import.meta.url),'utf8');
const config=read('ServerScriptService/Config.lua');
const domain=read('ServerScriptService/RealmState.lua');
const world=read('ServerScriptService/World.lua');
const client=read('StarterPlayerScripts/Realm.client.lua');
const base=presentationEngine+`
local Config=(function() ${config} end)()
Config.LoadAvatarAppearances=false
local Realm=(function() ${domain} end)()
local World=(function() ${world} end)()
World.build(Config)
local state=Realm.new(Config,0)
local function join(i,at,id)
 now=at or now
 local name='Viewer_'..i
 local ok,m=state:register(name,id or 0,state.round,now,now,'entry:'..state.round..':'..i)
 assert(ok,m)
 World.arrive(World.offlineAvatar(name),m.slot,m.username,state.round,m.reservedGrid)
 return m
end
local function scene(time)
 now=time;local s=state:snapshot(time);s.course=World.courseInfo();s.cameraBounds=World.cameraBounds(s)
 World.render(s,time);World.animate(time)
 return s
end
local function publish(time)
 local s=scene(time);remotes.Snapshot.OnClientEvent:Fire(s);if renderStep then renderStep(.1) end;return s
end
local function step(time)
 now=time;state:advanceEntrances(now);World.preparationStep(state,now);state:advance(now)
end
`;

test('twenty simultaneous acceptances reserve unique slots and remain FIFO for full 4.5s solos plus physical readiness',()=>runLua(base+`
for i=1,20 do join(i) end
assert(#state.roster==20 and #state.entranceQueue==20 and state.deadline==30)
assert(not state:register('Extra_Racer',0,1,1,1,'full'))
local slots={};for _,m in pairs(state.crew) do assert(not slots[m.reservedGrid]);slots[m.reservedGrid]=true end
local time=0
for i=1,20 do
 state:advanceEntrances(time)
 local entry=state.entrance
 assert(entry and #entry.names==1 and entry.names[1]=='Viewer_'..i and entry.stage=='intro')
 assert(entry.endsAt-entry.startedAt==4.5)
 state:advanceEntrances(time+4.49);assert(state.entrance.stage=='intro')
 state:advanceEntrances(time+4.5);assert(state.entrance.stage=='walking')
 state:advanceEntrances(time+5.5);assert(state.entrance.names[1]=='Viewer_'..i,'next introduction began before grid arrival')
 assert(not state:gridArrived('Viewer_'..i,2,entry.sequence,time+5.5,0))
 assert(not state:gridArrived('Viewer_'..i,1,entry.sequence+1,time+5.5,0))
 assert(state:gridArrived('Viewer_'..i,1,entry.sequence,time+5.5,0))
 assert(not state:gridArrived('Viewer_'..i,1,entry.sequence,time+5.5,0),'acknowledgement replay accepted')
 time=time+5.6
 if time>=30 then state:advance(time);assert(state.phase=='preparing' or i==20 and state.phase=='countdown') end
end
assert(state.phase=='countdown' and state.deadline>time)
assert(not state:register('Late_Racer',0,1,time,time,'late'))
state:advance(state.deadline);assert(state.phase=='storm' and state.deadline==state.activityStarted+120)
for _,m in pairs(state.crew) do assert(m.introductionCount==1 and m.preparationStatus=='ready' and m.activityEntered and m.score==0) end
`));

test('registration closes at 30s, preserves pending introductions, rejects new entries and starts promptly only after everyone is ready',()=>runLua(base+`
join(1);join(2)
state:advanceEntrances(0);state:advanceEntrances(4.5)
assert(state:gridArrived('Viewer_1',1,1,6,0))
state:advanceEntrances(6);assert(state.entrance.names[1]=='Viewer_2')
state:advance(30);assert(state.phase=='preparing' and #state.lockedRoster==2 and state.entrance.names[1]=='Viewer_2')
assert(not state:register('Late_Racer',0,1,29,31,'late-verified'))
state:advanceEntrances(30);assert(state.entrance.stage=='walking')
assert(not state:advance(300),'elapsed time alone must never launch unready racers')
assert(state:gridArrived('Viewer_2',1,2,301,1))
state:advance(301);assert(state.phase=='countdown' and state.deadline==305)
state:advance(305);assert(state.phase=='storm' and state.activityStarted==305 and state.deadline==425)
`));

test('canonical user IDs deduplicate aliases and preserve ledger statistics after a username change in a fresh round',()=>runLua(base+`
assert(state:register('Original_Name',123,1,0,0,'original'))
state.crew.original_name.balance=500;state.crew.original_name.roundWins=3
assert(not state:register('Alias_Name',123,1,1,1,'alias'))
assert(not state:register('_Invalid',0,1,1,1,'bad'))
assert(not state:register('Bad__Name',0,1,1,1,'bad2'))
assert(state:unregister('Original_Name',1,2,'withdraw'))
assert(not state:register('Original_Name',123,1,3,3,'retry'),'same-window reentry must not duplicate the introduction')
-- Exercise the real completed-round reset using a second registered pair.
join(1,3);join(2,3)
for _,name in ipairs({'Viewer_1','Viewer_2'}) do state:advanceEntrances(now);local e=state.entrance;now=e.endsAt;state:advanceEntrances(now);assert(state:gridArrived(name,1,e.sequence,now,0));now=now+.1 end
state:advance(33);state:advance(37);state:advance(157);state:advance(167)
assert(state.round==2 and #state.roster==0 and #state.entranceQueue==0)
for _,m in pairs(state.crew) do assert(m.preparationStatus==nil and m.reservedGrid==nil and m.introductionCount==0) end
assert(state:register('Renamed_User',123,2,168,168,'new-window'))
assert(state.crew.renamed_user.balance==500 and state.crew.renamed_user.roundWins==3)
assert(not state.crew.original_name and state.userKeys[123]=='renamed_user')
assert(state.crew.renamed_user.introductionCount==0 and state.crew.renamed_user.preparationStatus=='queued')
assert(not state:avatarPrepared('Renamed_User',1) and not state:gridArrived('Renamed_User',1,1,168,0))
`));

for (const count of [2,5,10,20]) test(`${count} registered actors physically follow pre-grid MoveTo commands; next solo waits for arrival and no normal grid warp occurs`,()=>runLua(base+`
for i=1,${count} do join(i) end
local seen,done,physicalSteps={}, {}, 0
local lastEntry,lastStage
local originalPivot=methods.PivotTo
local forbiddenWarps=0
methods.PivotTo=function(model,cf)
 local root=model.PrimaryPart
 if root and root.Anchored==false and (cf.Position-root.Position).Magnitude>3 and not model:GetAttribute('PreparationRecovery') then forbiddenWarps=forbiddenWarps+1 end
 return originalPivot(model,cf)
end
for tick=0,4000 do
 now=tick*.1
 -- Explicit command-following mock: it has no native contacts, gravity or slope solver.
 for i=1,${count} do
  local model=workspace.RiftboundRealm['Traveler_Viewer_'..i]
  local h,root=model.Humanoid,model.PrimaryPart
  if not root.Anchored and h.MoveGoal then
   local delta=h.MoveGoal-root.Position
   local movement=delta*math.min(1,h.WalkSpeed*.1/math.max(.001,delta.Magnitude))
   originalPivot(model,CFrame.new(root.Position+movement));root.AssemblyLinearVelocity=movement*10;physicalSteps=physicalSteps+1
  end
 end
 step(now)
 local e=state.entrance
 if e and e.stage=='intro' and not seen[e.names[1]] then
  local index=tonumber(e.names[1]:match('%d+$'));assert(index==1 or done['Viewer_'..(index-1)],'FIFO started before prior grid readiness')
  seen[e.names[1]]=true
 end
 for _,m in pairs(state.crew) do if m.preparationStatus=='ready' then
  local model=workspace.RiftboundRealm['Traveler_'..m.username]
  assert(model.PrimaryPart.Anchored and (model.PrimaryPart.Position-World.sprintPoint(m.reservedGrid,0)).Magnitude<1.6)
  done[m.username]=true
 end end
 local signature=e and (e.sequence..'/'..e.stage) or ''
 if tick%5==0 or signature~=lastEntry then scene(now);lastEntry=signature end
 assert(state.phase~='storm','test should stop at the countdown')
 if state.phase=='countdown' then break end
 assert(tick<4000,'preparation stalled')
end
assert(physicalSteps>0 and forbiddenWarps==0,'normal preparation warped a physical racer')
print(string.format('PREPARATION count=%d soloSeconds=%.1f countdownAt=%.1f physicalSteps=%d',${count}, ${count}*Config.EntranceSeconds,now,physicalSteps))
for i=1,${count} do assert(seen['Viewer_'..i] and done['Viewer_'..i] and state.crew['viewer_'..i].introductionCount==1 and state.crew['viewer_'..i].preparationRecoveries==0) end
local start=state.deadline
state:advance(start);World.sprintStep(state,start)
assert(state.phase=='storm' and state.deadline==start+120 and state.activityEntrants==${count})
for i=1,${count} do assert((workspace.RiftboundRealm['Traveler_Viewer_'..i].PrimaryPart.Position-World.sprintPoint(state.crew['viewer_'..i].reservedGrid,0)).Magnitude<1.6);assert(workspace.RiftboundRealm['Traveler_Viewer_'..i].Humanoid.WalkSpeed==Config.SprintWalkSpeed) end
`));

test('stalled and fallen pre-grid actors recover visibly, while a timer cannot itself mark them ready',()=>runLua(base+`
join(1);join(2);step(0);scene(0)
step(4.5);scene(4.5)
local rig=workspace.RiftboundRealm.Traveler_Viewer_1
assert(not rig.PrimaryPart.Anchored)
step(8);assert(rig:GetAttribute('PreparationRecovery')==1 and state.entrance.stage=='walking')
rig:PivotTo(CFrame.new(-60,40,70));step(8.1)
assert(rig:GetAttribute('PreparationRecovery')==2 and state.entrance.stage=='walking')
step(8.5);assert(state.crew.viewer_1.preparationStatus=='ready' and state.crew.viewer_1.preparationRecoveries==2)
assert(rig.PrimaryPart.Anchored and (rig.PrimaryPart.Position-World.sprintPoint(1,0)).Magnitude<1)
`));

test('native appearance failure and hung loading use bounded fallback readiness; stale models cannot replace a later round',()=>runLua(base+`
Config.LoadAvatarAppearances=true
local warnings=0;warn=function() warnings=warnings+1 end
players.GetHumanoidDescriptionFromUserIdAsync=function() error('account outfit unavailable') end
join(1,0,123);join(2,0,456)
World.loadAppearance('Viewer_1',123);World.loadAppearance('Viewer_2',456)
state:advanceEntrances(0);assert(not state.entrance,'avatar not yet ready')
local first=table.remove(spawnedJobs,1);first()
step(.1);state:advanceEntrances(.1)
assert(state.entrance and state.entrance.names[1]=='Viewer_1' and warnings==1)
-- The second job is never resumed. Its timeout must still release the FIFO head.
state:advanceEntrances(4.6);assert(state:gridArrived('Viewer_1',1,1,5,0))
step(8.1);state:advanceEntrances(8.1)
assert(state.entrance and state.entrance.names[1]=='Viewer_2' and state.crew.viewer_2.avatarReady)
local old=workspace.RiftboundRealm.Traveler_Viewer_2
state:advanceEntrances(12.6);assert(state:gridArrived('Viewer_2',1,2,13,0))
state:advance(30);state:advance(34);state:advance(154);state:advance(164);scene(164)
assert(not old.Parent)
join(2,165,456)
local stale=table.remove(spawnedJobs,1);stale()
assert(workspace.RiftboundRealm.Traveler_Viewer_2~=old and state.round==2 and state.crew.viewer_2.preparationStatus=='queued')
`));

test('solo camera owns every full entrance, exposes queue/preparation progress and preserves Roam plus batch controls',()=>runLua(base+`
print=function() end
;(function() ${client} end)()
join(1);join(2)
step(0);publish(0)
local hud=playerGui.RiftboundHUD;local canvas=hud.VerticalStreamCanvas
assert(canvas.EventStrip.Message.Text=='NEW CHALLENGER!')
for _,t in ipairs({1.2,2.8,4.4}) do
 step(t)
 for _,size in ipairs({{390,844},{1080,1920},{1158,536}}) do
  setViewport(size[1],size[2]);publish(t)
  assert(canvas.EventStrip.Message.Text=='Viewer_1')
  assert(hud:GetAttribute('BroadcastSubjects')=='Viewer_1')
  local p,on=camera:WorldToViewportPoint(workspace.RiftboundRealm.Traveler_Viewer_1.PrimaryPart.Position);assert(on)
 end
end
assert(hud:GetAttribute('BroadcastShot')=='solo entrance / CLOSE-UP')
step(4.5);publish(4.5);assert(hud:GetAttribute('BroadcastShot')=='walking to starting grid')
assert(canvas.EventStrip.Message.Text=='Viewer_1 / TO THE GRID')
state:advance(30);publish(30);assert(state.phase=='preparing' and canvas.Header.Countdown.Text=='—')
assert(canvas.RoundDock.Status.Text:find('PENDING',1,true))
canvas.CameraToggle.Activated:Fire();assert(camera.CameraType==Enum.CameraType.Custom)
canvas.CameraToggle.Activated:Fire();renderStep(.1);assert(camera.CameraType==Enum.CameraType.Scriptable)
canvas.KeeperToggle.Activated:Fire()
for _,count in ipairs({2,5,10,20}) do canvas.TestTools['Batch'..count].Activated:Fire();local a=actions[#actions];assert(a[1]=='batchJoin' and a[2]==tostring(count) and a[3]==state.round) end
`));

test('verified/offline alias mixing cannot rekey an active registration or duplicate a canonical identity',()=>runLua(base+`
assert(state:register('Known_User',123,1,0,0,'known'))
assert(state:unregister('Known_User',1,1,'withdraw'))
-- Fresh window retains the canonical ledger identity, not active participation.
state.round,state.registrationOpenedAt=2,2
state.registrationNames,state.registrationIdentities,state.registrationEvents={},{},{}
assert(state:register('Known_User',0,2,2,2,'offline'))
assert(not state:register('Alias_User',123,2,3,3,'alias'))
assert(state.crew.known_user and not state.crew.alias_user and state.roster[1]=='known_user' and #state.roster==1)
`));

test('cosmetic giant gifts defer until after preparation and racing, preserving collider scale and equal race speeds',()=>runLua(base+`
join(1);join(2);step(0);scene(0)
assert(state:gift('Viewer_1','giant',1,1));scene(1)
assert(workspace.RiftboundRealm.Traveler_Viewer_1.AppliedScale~=1.85)
step(4.5);scene(4.5)
assert(workspace.RiftboundRealm.Traveler_Viewer_1.Humanoid.WalkSpeed==Config.PreparationWalkSpeed)
scene(5);assert(workspace.RiftboundRealm.Traveler_Viewer_1.AppliedScale~=1.85)
`));

test('every approach centerline has continuous supporting floor at the expected foot height; no flat terrace covers a descending ramp',()=>runLua(base+`
local floors={workspace.RiftboundRealm.SkybridgeSprint['START platform']}
for _,p in ipairs(workspace.RiftboundRealm.ChallengerLobby:GetDescendants()) do if p:IsA('BasePart') and p.CanCollide then floors[#floors+1]=p end end
local function floorAt(point)
 local highest
 for _,p in ipairs(floors) do
  local up=p.CFrame.UpVector
  local top=p.Position+up*(p.Size.Y*.5)
  local y=top.Y-(up.X*(point.X-top.X)+up.Z*(point.Z-top.Z))/up.Y
  local q=p.CFrame:PointToObjectSpace(Vector3.new(point.X,y,point.Z))
  if math.abs(q.X)<=p.Size.X*.5+.001 and math.abs(q.Z)<=p.Size.Z*.5+.001 then highest=math.max(highest or -10000,y) end
 end
 return highest
end
for slot=1,20 do
 local grid=World.sprintPoint(slot,0)
 local route={World.entrancePoint(1,1),Vector3.new(-64,80,86),Vector3.new(-44,74,94),Vector3.new(-28,68,94),Vector3.new(grid.X,68,94),grid}
 for i=1,#route-1 do
  local a,b=route[i],route[i+1]
  local delta=b-a
  assert(math.abs(delta.Y)/math.max(.001,Vector3.new(delta.X,0,delta.Z).Magnitude)<math.tan(math.rad(25)),'approach slope too steep')
  for sample=0,25 do
   local point=a:Lerp(b,sample/25);local floor=floorAt(point)
   assert(floor and math.abs(floor-(point.Y-3))<.2,'unsupported/clipped approach at slot '..slot..' segment '..i..' sample '..sample)
  end
 end
end
`));
