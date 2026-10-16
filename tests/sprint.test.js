import test from 'node:test';
import { readFileSync } from 'node:fs';
import { runLua } from './helpers/lua.js';
import { presentationEngine } from './helpers/presentation-engine.js';
const read = name => readFileSync(new URL(`../roblox/ServerScriptService/${name}`, import.meta.url), 'utf8');
const config = read('Config.lua'), domain = read('RealmState.lua'), world = read('World.lua');
const rules = `
local Config=(function() ${config} end)()
local Realm=(function() ${domain} end)()
Config.SprintCompetitors=5
Config.DemoNames={"Demo_Astra","Demo_Lumen","Demo_Nova","Demo_Fern","Demo_Orion"}
local function start(count)
    local state=Realm.new(Config,0)
    for i=1,count do assert(state:addCrew("Racer_"..i,i)) end
    state:advance(12); state:advance(20)
    assert(state.activity.id=="sprint")
    return state
end
local function finish(state,name,step)
    for cp=1,48 do assert(state:recordCheckpoint(name,cp,20+cp*step,state.round)) end
end
`;

test('Sprint never advances or invents winners from elapsed time, names or money', () => runLua(rules + `
local state=start(5)
state:tick(140)
for _,m in pairs(state.crew) do assert(m.score==0 and m.finishedAt==0) end
state:advance(140)
assert(#state.winners==0 and not state:raceComplete())
for _,m in pairs(state.crew) do assert(m.raceStatus=="dnf" and m.roundWins==0) end
`));

test('gate verification rejects skips, duplicates, stale rounds, bad times and late observations', () => runLua(rules + `
local state=start(5)
assert(not state:recordCheckpoint("Racer_1",2,21,state.round))
assert(not state:recordCheckpoint("Racer_1",1,19,state.round))
assert(not state:recordCheckpoint("Racer_1",1,21,state.round-1))
assert(not state:recordCheckpoint("Racer_1",1,0/0,state.round))
assert(not state:recordCheckpoint("Racer_1",1,141,state.round))
assert(state:recordCheckpoint("Racer_1",1,21,state.round))
local balance=state.crew.racer_1.balance
assert(not state:recordCheckpoint("Racer_1",1,22,state.round))
assert(state.crew.racer_1.balance==balance)
assert(not state:recordCheckpoint("Racer_1",2,20.9,state.round))
`));

test('actual observed times rank all five; top three bonuses pay once and ties share placement', () => runLua(rules + `
local state=start(5)
-- Process slow racers first: processing/arrival order cannot select the winner.
finish(state,"Racer_1",1.4); finish(state,"Racer_2",1.3); finish(state,"Racer_3",1.2)
finish(state,"Racer_4",1.1); finish(state,"Racer_5",1.0)
assert(state:raceComplete())
local ranks=state:activityLeaderboard()
assert(ranks[1].username=="Racer_5" and ranks[5].username=="Racer_1")
assert(state.crew.racer_1.placement==5 and state.crew.racer_5.placement==1)
state:advance(90)
assert(#state.winners==3 and state.winners[1].username=="Racer_5")
local balance=state.crew.racer_5.balance
assert(not state:advance(90) and balance==state.crew.racer_5.balance)
local tied=start(2); finish(tied,"Racer_1",1); finish(tied,"Racer_2",1); tied:advance(90)
assert(tied.winners[1].placement==1 and tied.winners[2].placement==1)
assert(tied.winners[1].prize==tied.winners[2].prize)
`));

test('five-entry limit, late viewers, cohort rotation, DNFs and reset work without Keeper actions', () => runLua(rules + `
local state=start(8)
assert(state.activityEntrants==5)
assert(state:addCrew("LateViewer",99)); assert(not state.crew.lateviewer.activityEntered)
finish(state,"Racer_1",1)
state:advance(140)
assert(#state.winners==1 and state.winners[1].username=="Racer_1")
assert(state.crew.racer_2.raceStatus=="dnf")
state:advance(150); state:advance(162); state:advance(170)
assert(state.round==2 and state.activityEntrants==5 and state.crew.lateviewer.activityEntered)
assert(state.crew.racer_1.score==0 and state.crew.racer_1.finishedAt==0)
`));

const scene = presentationEngine + rules + `
Config.LoadAvatarAppearances=false
local World=(function() ${world} end)()
World.build(Config)
local state=start(5)
for i=1,5 do World.arrive(World.offlineAvatar("Racer_"..i),i,"Racer_"..i) end
now=20; World.sprintStep(state,now)
local function rig(i) return workspace.RiftboundRealm["Traveler_Racer_"..i] end
local function move(i,position,time)
    now=time; rig(i).PrimaryPart.CFrame=CFrame.new(position); World.sprintStep(state,now)
end
local function publish(time)
    now=time
    local snapshot=state:snapshot(time)
    snapshot.cameraBounds=World.cameraBounds(snapshot)
    World.render(snapshot,time); World.animate(time)
end
`;

test('actual World builds server-owned unanchored rigs and commands physical checkpoint navigation', () => runLua(scene + `
assert(workspace.RiftboundRealm.ModelStreamingMode==Enum.ModelStreamingMode.Persistent)
assert(workspace.RiftboundRealm.SkybridgeSprint)
for i=1,5 do
    assert(rig(i).PrimaryPart.ServerOwned and not rig(i).PrimaryPart.Anchored)
    assert(rig(i).RaceCollider.CanCollide and not rig(i).Torso.CanCollide)
    assert(rig(i).Humanoid.MoveGoal and rig(i).Humanoid.WalkSpeed==12.5)
end
move(1,World.sprintPoint(1,0)+Vector3.new(0,0,-10),20.8)
assert(not rig(1).Humanoid.Jump,"continuous starting apron requested an unnecessary jump")
move(1,World.sprintPoint(1,1),21.2)
assert(state.crew.racer_1.score==1)
assert(not rig(1).Humanoid.Jump,'continuous road should not trigger an edge jump')
local position=rig(1).PrimaryPart.Position
publish(21.4)
assert((rig(1).PrimaryPart.Position-position).Magnitude<0.0001,"renderer teleported a racing root")
`));

test('physical gates require position/grounding; falls and stalls restore only the last verified pad', () => runLua(scene + `
rig(1).Humanoid.FloorMaterial=Enum.Material.Air
move(1,World.sprintPoint(1,1),21); assert(state.crew.racer_1.score==0)
rig(1).Humanoid.FloorMaterial=Enum.Material.Slate
move(1,World.sprintPoint(1,1),21.2); assert(state.crew.racer_1.score==1)
move(1,Vector3.new(0,40,40),22)
assert(state.crew.racer_1.score==1 and rig(1).PrimaryPart.Position.Y>=68)
local safe=rig(1).PrimaryPart.Position
now=29; World.sprintStep(state,now)
assert(state.crew.racer_1.score==1 and (rig(1).PrimaryPart.Position-safe).Magnitude<0.001)
`));

test('jumping a shared hurdle requires ground, fires once per gate, and recovery retains route progress', () => runLua(scene + `
for cp=1,3 do move(1,World.routePoint(cp,'shared'),20+cp) end
local point=World.routePoint(3.5,'shared')+Vector3.new(0,0,3.5)
rig(1).Humanoid.FloorMaterial=Enum.Material.Air
move(1,point,23.9);assert(not rig(1).Humanoid.Jump)
rig(1).Humanoid.FloorMaterial=Enum.Material.Slate
move(1,point,24);assert(rig(1).Humanoid.Jump,'hurdle takeoff missing')
rig(1).Humanoid.Jump=false
move(1,point,24.5);assert(not rig(1).Humanoid.Jump,'repeated takeoff')
move(1,Vector3.new(0,40,0),25)
assert(state.crew.racer_1.score==3 and state.crew.racer_1.recoveries==1)
assert(math.abs(rig(1).PrimaryPart.Position.Z-World.routePoint(3,'shared').Z)<.001)
`));

test('physical finish crossing interpolates time, freezes finishers and preserves racing gift fairness', () => runLua(scene + `
assert(state:gift("Racer_1","giant",1,20)); publish(20)
assert(rig(1).AppliedScale==nil or rig(1).AppliedScale==1,"giant changed physical size")
for cp=1,47 do
    local route=state.crew.racer_1.route or 'shared'
    move(1,World.routePoint(cp,route),20+cp)
end
local endPoint=World.sprintPoint(1,48)+Vector3.new(0,0,-1)
move(1,endPoint,68)
local m=state.crew.racer_1
assert(m.score==48 and m.finishedAt>67 and m.finishedAt<68 and m.placement==1)
assert(rig(1).PrimaryPart.Anchored and m.balance>=64)
assert(state:raceDNF("Racer_2",state.round)); assert(state:raceDNF("Racer_3",state.round))
assert(state:raceDNF("Racer_4",state.round)); assert(state:raceDNF("Racer_5",state.round))
state:advance(68); publish(68)
assert(#state.winners==1 and rig(1).AppliedScale==1.85)
`));

test('disabled appearance mode makes zero Roblox appearance calls; failure keeps the fallback playable', () => runLua(scene + `
World.loadAppearance("Racer_1",1); assert(#spawnedJobs==0)
Config.LoadAvatarAppearances=true
local warnings={}; warn=function(msg) warnings[#warnings+1]=msg end
local original=rig(1)
players.GetHumanoidDescriptionFromUserIdAsync=function() error("unavailable") end
World.loadAppearance("Racer_1",1); assert(#spawnedJobs==1)
spawnedJobs[1]()
assert(rig(1)==original and #warnings==1 and rig(1).Humanoid.MoveGoal)
World.loadAppearance("Racer_1",1); assert(#spawnedJobs==1,"requests repeated")
`));

test('appearance success is queued until a break; late results are discarded and cleaned up', () => runLua(scene + `
Config.LoadAvatarAppearances=true
local description=instance("HumanoidDescription","Description")
players.GetHumanoidDescriptionFromUserIdAsync=function() return description end
local loaded
local creations=0
players.CreateHumanoidModelFromDescriptionAsync=function()
    creations=creations+1
    loaded=World.offlineAvatar("Appearance")
    return loaded
end
local original=rig(1)
World.loadAppearance("Racer_1",1); spawnedJobs[1](); publish(21)
assert(rig(1)==original and description.Destroyed)
state:advance(140); publish(140)
assert(rig(1)==loaded and original.Destroyed)
-- Simulate an API call taking longer than the configured soft deadline.
local lateDescription
players.GetHumanoidDescriptionFromUserIdAsync=function() now=now+9; lateDescription=instance("HumanoidDescription","Late"); return lateDescription end
World.loadAppearance("Racer_2",2); spawnedJobs[2]()
assert(rig(2)~=loaded and #spawnedJobs==2 and creations==1 and lateDescription.Destroyed)
`));

test('dead racers DNF and get a fresh playable fallback at the next break', () => runLua(scene + `
local old=rig(1)
local broken=rig(2)
broken.Humanoid:Destroy()
old.Humanoid.Health=0
now=21; World.sprintStep(state,now)
assert(state.crew.racer_1.raceStatus=="dnf")
assert(state.crew.racer_2.raceStatus=="dnf")
state:advance(140); publish(140)
assert(old.Destroyed and rig(1)~=old and rig(1).Humanoid.Health==100)
assert(broken.Destroyed and rig(2).Humanoid.Health==100)
`));

test('a queued giant gift still gets its visual celebration after a long timed-out race', () => runLua(scene + `
assert(state:gift("Racer_1","giant",1,20)); publish(20)
assert(rig(1).AppliedScale==nil or rig(1).AppliedScale==1)
state:advance(140); publish(140)
assert(rig(1).AppliedScale==1.85 and rig(1).GiftAura.Enabled)
publish(147); assert(rig(1).AppliedScale==1)
`));

test('server course bounds contain every lane, jump envelope and authored part across all four sections', () => runLua(scene + `
local box=World.cameraBounds(state:snapshot(20))
for lane=1,5 do for cp=0,48 do
    local p=World.sprintPoint(lane,cp)
    assert(p.X-5>=box.minX and p.X+5<=box.maxX and p.Z>=box.minZ and p.Z<=box.maxZ and p.Y+12<=box.maxY)
end end
for _,part in ipairs(workspace.RiftboundRealm.SkybridgeSprint:GetDescendants()) do
    if part:IsA("BasePart") then
        for _,x in ipairs({-0.5,0.5}) do for _,y in ipairs({-0.5,0.5}) do for _,z in ipairs({-0.5,0.5}) do
            local p=part.CFrame:PointToWorldSpace(Vector3.new(x*part.Size.X,y*part.Size.Y,z*part.Size.Z))
            assert(p.X>=box.minX and p.X<=box.maxX and p.Y>=box.minY and p.Y<=box.maxY and p.Z>=box.minZ and p.Z<=box.maxZ,part.Name.." outside bounds")
        end end end
    end
end
`));

test('actual server/World/client repeat physical Sprint rounds with five NPCs under a command-following physics stub', () => {
  const server=read('Realm.server.lua');
  const client=readFileSync(new URL('../roblox/StarterPlayerScripts/Realm.client.lua',import.meta.url),'utf8');
  runLua(presentationEngine + rules + `
Config.LoadAvatarAppearances=false
local World=(function() ${world} end)()
-- Scenery poses are covered separately; this scheduler focuses on physical commands.
World.animate=function() end
runtime.IsStudio=function() return true end
runtime.Heartbeat=signal()
players.GetPlayers=function() return {} end
players.PlayerAdded,players.PlayerRemoving=signal(),signal()
local modules=instance("ServerScriptService","ServerScriptService")
for _,name in ipairs({"Config","RealmState","World"}) do instance("ModuleScript",name,modules) end
script={Parent=modules}
require=function(token)
    if token==modules.Config then return Config end
    if token==modules.RealmState then return Realm end
    if token==modules.World then return World end
    error("wrong dependency")
end
local jobs={}
task.spawn=function(fn,...)
    local args={...}
    jobs[#jobs+1]={co=coroutine.create(function() fn(table.unpack(args)) end),wake=now}
end
task.wait=function(seconds) return coroutine.yield(seconds or 0.03) end
local last,results,previousPhase=nil,0,nil
print=function() end
warn=function(message) error(message.." "..tostring(remotes:GetAttribute("StartupError"))) end
local snapshotConnection=remotes.Snapshot.OnClientEvent:Connect(function(snapshot)
    last=snapshot
    if snapshot.phase=="result" and previousPhase~="result" then
        results=results+1
        assert(#snapshot.winners==3 and snapshot.winners[1].elapsed>=90 and snapshot.winners[1].elapsed<=120, "mock race duration outside target: round="..snapshot.round.." winners="..#snapshot.winners.." first="..(snapshot.winners[1] and snapshot.winners[1].elapsed or -1))
    end
    previousPhase=snapshot.phase
end)
;(function() ${server} end)()
assert(remotes:GetAttribute("Ready"))
;(function() ${client} end)()
for step=1,8800 do
    now=step*0.05
    -- This is explicit mocked movement, not Roblox collision/jump simulation.
    for _,model in ipairs(workspace.RiftboundRealm:GetChildren()) do
        local main=model.PrimaryPart
        local humanoid=model:FindFirstChildOfClass("Humanoid")
        if main and humanoid and not main.Anchored and humanoid.MoveGoal then
            local delta=humanoid.MoveGoal-main.Position
            local amount=math.min(1,Config.SprintWalkSpeed*.05/math.max(0.001,delta.Magnitude))
            model:PivotTo(CFrame.new(main.Position+delta*amount))
            main.AssemblyLinearVelocity=delta*amount*20
        end
    end
    runtime.Heartbeat:Fire(0.05)
    local count=#jobs
    for i=1,count do
        local job=jobs[i]
        if coroutine.status(job.co)~="dead" and job.wake<=now+0.00001 then
            local ok,delay=coroutine.resume(job.co); assert(ok,delay); job.wake=now+(delay or 0)
        end
    end
    if step%8==0 then renderStep(0.4) end
end
assert(results>=3 and #last.crew==5 and last.followers>0,"autonomous Sprint did not repeat")
assert(last.physicalSprint and last.cameraBounds)
assert(playerGui.RiftboundHUD.VerticalStreamCanvas.RoundLeaders.Title.Text=="SPRINT / TIME")
snapshotConnection:Disconnect()
local nofinish=start(5); nofinish:advance(140)
local snapshot=nofinish:snapshot(140); snapshot.demo=true; snapshot.cameraBounds=World.cameraBounds(snapshot)
remotes.Snapshot.OnClientEvent:Fire(snapshot)
assert(string.find(playerGui.RiftboundHUD.VerticalStreamCanvas.RoundDock.Instruction.Text,"NO FINISHERS",1,true),playerGui.RiftboundHUD.VerticalStreamCanvas.RoundDock.Instruction.Text)
assert(playerGui.RiftboundHUD.VerticalStreamCanvas.RoundLeaders.Score1.Text=="DNF",playerGui.RiftboundHUD.VerticalStreamCanvas.RoundLeaders.Score1.Text)
`);
});

test('20 racers enter a shared cohort; route labels, skips and branch shortcuts remain bounded',()=>runLua(rules+`
Config.SprintCompetitors=20
local state=start(24)
assert(state.activityEntrants==20 and #state:nextCohort()==20)
for i=1,20 do assert(state.crew['racer_'..i].gridSlot==i) end
assert(not state.crew.racer_21.activityEntered)
assert(not state:recordCheckpoint('Racer_1',1,21,state.round,'shortcut'))
for cp=1,10 do assert(state:recordCheckpoint('Racer_1',cp,20+cp,state.round,'shared')) end
assert(not state:recordCheckpoint('Racer_1',11,31,state.round,'teleport'))
assert(state:recordCheckpoint('Racer_1',11,31,state.round,'main'))
assert(not state:recordCheckpoint('Racer_1',18,32,state.round,'shortcut'))
assert(state.crew.racer_1.score==11)
`));
