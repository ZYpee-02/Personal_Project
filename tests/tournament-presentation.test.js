import test from 'node:test';
import {readFileSync} from 'node:fs';
import {runLua} from './helpers/lua.js';
import {presentationEngine} from './helpers/presentation-engine.js';
const read=n=>readFileSync(new URL(`../roblox/${n}`,import.meta.url),'utf8');
const base=presentationEngine+`
local Config=(function() ${read('ServerScriptService/Config.lua')} end)()
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
local function publish(time)
    now=time
    local snapshot=state:snapshot(time);snapshot.cameraBounds=World.cameraBounds(snapshot);snapshot.course=World.courseInfo()
    World.render(snapshot,time);World.animate(time)
    remotes.Snapshot.OnClientEvent:Fire(snapshot)
    if renderStep then renderStep(.1) end
    return snapshot
end
`;
const client=read('StarterPlayerScripts/Realm.client.lua');

test('empty lobby shows waiting instructions indefinitely; current registration and withdrawal update the HUD',()=>runLua(base+`
;(function() ${client} end)()
local canvas=playerGui.RiftboundHUD.VerticalStreamCanvas
publish(0);publish(200)
assert(canvas.Header.Activity.Text=='WAITING FOR CHALLENGERS' and canvas.Header.Countdown.Text=='—')
assert(canvas.RoundDock.Instruction.Text=='COMMENT YOUR ROBLOX USERNAME TO JOIN!')
assert(camera.CFrame.Position.Y>=112 and camera.FieldOfView>=55)
now=200;join(1);publish(200)
assert(canvas.RoundLeaders.Title.Text=='REGISTERED / 1' and canvas.Header.Countdown.Text=='—')
now=201;join(2);publish(201)
assert(canvas.Header.Countdown.Text=='30' and canvas.Header.Activity.Text=='REGISTRATION OPEN')
assert(state:unregister('Viewer_2',state.round,202,'withdraw:2'));publish(202)
assert(canvas.Header.Countdown.Text=='—' and state.phase=='registration')
canvas.KeeperToggle.Activated:Fire();canvas.TestTools.Join.Activated:Fire()
assert(actions[#actions][3]==state.round,'registration control omitted round ID')
canvas.TestTools.TestStale.Activated:Fire();assert(actions[#actions][3]==state.round-1)
`));

test('all 20 competitors fit the tournament grid shot in portrait/landscape; READY 3 2 1 GO and fire never start physics early',()=>runLua(base+`
;(function() ${client} end)()
for i=1,20 do join(i) end
state:advance(30)
local canvas=playerGui.RiftboundHUD.VerticalStreamCanvas
for _,time in ipairs({30,31,32,33}) do
    for _,size in ipairs({{390,844},{1080,1920},{1158,536}}) do
        setViewport(size[1],size[2]);publish(time)
        for i=1,20 do
            local rig=workspace.RiftboundRealm['Traveler_Viewer_'..i]
            local p,on=camera:WorldToViewportPoint(rig.PrimaryPart.Position)
            assert(on,'grid shot lost competitor '..i)
            assert(rig.PrimaryPart.Anchored,'physics began before GO')
        end
    end
    assert(canvas.Header.Stats.Text:find('REGISTRATION CLOSED',1,true),'locked roster advertised open slots')
    assert(canvas.EventStrip.Message.Text==({[30]='READY',[31]='3',[32]='2',[33]='1'})[time])
end
local folder=workspace.RiftboundRealm.TournamentPresentation
local flames=0
for _,p in ipairs(folder:GetDescendants()) do
    if p:IsA('BasePart') then assert(p.CanCollide==false and p.CanTouch==false and p.CanQuery==false) end
    if p:IsA('Fire') then flames=flames+1;assert(p.Enabled) end
end
assert(flames==2)
state:advance(34);World.sprintStep(state,34);publish(34)
assert(canvas.EventStrip.Message.Text=='GO!')
for i=1,20 do local rig=workspace.RiftboundRealm['Traveler_Viewer_'..i];assert(not rig.PrimaryPart.Anchored and rig.PrimaryPart.RootJoint.Enabled) end
canvas.CameraToggle.Activated:Fire();assert(camera.CameraType==Enum.CameraType.Custom)
canvas.CameraToggle.Activated:Fire();renderStep(.1);assert(camera.CameraType==Enum.CameraType.Scriptable)
`));

test('waiting emotes vary and all current actors are removed at the next registration without deleting money/history',()=>runLua(base+`
join(1);join(2)
assert(workspace.RiftboundRealm.Traveler_Viewer_1.PrimaryPart.RootJoint.Enabled==false)
local poses={}
for step=0,250 do
    now=step*.1;World.render(state:snapshot(now),now);World.animate(now)
    local name=workspace.RiftboundRealm.Traveler_Viewer_1:GetAttribute('RiftboundPose')
    if name then poses[name]=true end
end
for _,pose in ipairs({'wave','stretch','cheer','look around','celebrate'}) do assert(poses[pose],'missing idle '..pose) end
state:advance(30);state:advance(34);World.sprintStep(state,34)
state:advance(154);World.render(state:snapshot(154),154)
state:advance(164);World.render(state:snapshot(164),164)
assert(not workspace.RiftboundRealm:FindFirstChild('Traveler_Viewer_1') and not workspace.RiftboundRealm:FindFirstChild('Traveler_Viewer_2'))
assert(#state.crewOrder==2 and #state.roster==0 and #state.raceHistory==1)
`));

test('power-up visuals alter only non-colliding cosmetics and limbs; queued close-ups yield to a finish contest',()=>runLua(base+`
;(function() ${client} end)()
join(1);join(2);state:advance(30);state:advance(34);World.sprintStep(state,34)
local rig=workspace.RiftboundRealm.Traveler_Viewer_1
local root=rig.PrimaryPart;local before=root.Position
local speed,jump,deadline=rig.Humanoid.WalkSpeed,rig.Humanoid.JumpPower,state.deadline
assert(state:activatePowerup('Viewer_1','trail',40,1,'power:trail'));state:advanceEntrances(40);publish(40)
assert(root.PowerTrail.Enabled and (root.Position-before).Magnitude<.00001)
assert(rig.Humanoid.WalkSpeed==speed and rig.Humanoid.JumpPower==jump and state.deadline==deadline and state.crew.viewer_1.score==0)
assert(playerGui.RiftboundHUD.VerticalStreamCanvas.EventStrip.Message.Text=='Viewer_1 / TRAIL')
assert(state:activatePowerup('Viewer_2','shield',40,1,'power:shield'));state:advanceEntrances(41.5);publish(41.5)
local bubble=workspace.RiftboundRealm.Traveler_Viewer_2.PowerShield
assert(bubble.Transparency<1 and not bubble.CanCollide and bubble.Massless)
state.crew.viewer_1.distance=45;state:advanceEntrances(42);assert(not state.highlight)
publish(42)
local finish=false;for _,line in ipairs(logs) do if line:find('shot=finish line',1,true) then finish=true end end
assert(finish,'finish contest lost priority')
assert(root.Position.Y>54 and not root.Anchored)
`));
