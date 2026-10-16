import test from 'node:test';
import { readFileSync } from 'node:fs';
import { runLua } from './helpers/lua.js';
import { presentationEngine } from './helpers/presentation-engine.js';

const read = name => readFileSync(new URL(`../roblox/ServerScriptService/${name}`, import.meta.url), 'utf8');
const scene = presentationEngine + `
local Config=(function() ${read('Config.lua')} end)()
Config.LoadAvatarAppearances=false
local Realm=(function() ${read('RealmState.lua')} end)()
local World=(function() ${read('World.lua')} end)()
World.build(Config)
local state=Realm.new(Config,0)
for i=1,5 do
    assert(state:addCrew('Contact_'..i,0))
    World.arrive(World.offlineAvatar('Contact_'..i),i,'Contact_'..i)
end
state:advance(12); state:advance(20)
now=20; World.sprintStep(state,now)
local course=workspace.RiftboundRealm.SkybridgeSprint
print=function() end

-- Simplified axis-aligned contact approximation, NOT Roblox physics. It uses
-- actual pad bounds, horizontal MoveTo speed, gravity, vertical jump velocity,
-- a 50ms jump response and 20Hz controller samples. FloorMaterial is Air after
-- leaving support: unlike the older command-only stub it cannot walk on air.
local bodies={}
for i=1,5 do bodies[i]={vy=0,grounded=false,position=workspace.RiftboundRealm['Traveler_Contact_'..i].PrimaryPart.Position} end
local function overlaps(pad,p)
    return math.abs(p.X-pad.Position.X)<=pad.Size.X/2 and math.abs(p.Z-pad.Position.Z)<=pad.Size.Z/2
end
local function simulate(seconds)
    local dt=0.025
    for step=1,seconds/dt do
        now=20+step*dt
        if step%2==0 then World.sprintStep(state,now) end
        for i=1,5 do
            local member=state.crew['contact_'..i]
            local model=workspace.RiftboundRealm['Traveler_Contact_'..i]
            local h,p,b=model.Humanoid,model.PrimaryPart,bodies[i]
            if member.raceStatus=='racing' then
                if (p.Position-b.position).Magnitude>0.1 then b.vy,b.grounded,b.jumpAt=0,false,nil end -- recovery
                if h.Jump then
                    if b.grounded and not b.jumpAt then b.jumpAt=now+0.05 end
                    h.Jump=false
                end
                if b.jumpAt and now>=b.jumpAt then
                    if b.grounded then b.vy,b.grounded=h.JumpPower,false end
                    b.jumpAt=nil
                end
                local old=p.Position
                local d=h.MoveGoal-old; d=Vector3.new(d.X,0,d.Z)
                local next=old+d*math.min(1,h.WalkSpeed*dt/math.max(0.001,d.Magnitude))
                if b.checkpoint~=member.score then
                    b.checkpoint=member.score
                    b.pads={course['START platform']}
                    local lane=((member.raceLane+state.round-2)%5)+1
                    for cp=math.max(1,member.score),math.min(48,member.score+2) do
                        b.pads[#b.pads+1]=course['Lane '..lane..' checkpoint '..cp]
                    end
                    b.obstacles={}
                    local hurdle=course['Jump hurdle '..(member.score+1)]
                    if hurdle then b.obstacles[#b.obstacles+1]=hurdle end
                    for index,cp in ipairs({26,30,34}) do
                        if cp==member.score+1 then b.obstacles[#b.obstacles+1]=course['Moving wind gate '..index] end
                    end
                end
                local pads=b.pads
                -- A vertical pad face above the feet blocks walking; it cannot
                -- silently lift the root toward a three-dimensional MoveTo goal.
                for _,pad in ipairs(pads) do
                    local top=pad.Position.Y+pad.Size.Y/2
                    if overlaps(pad,next) and old.Y-3<top-0.5 and old.Y+2>top-pad.Size.Y then next=old; break end
                end
                for _,obstacle in ipairs(b.obstacles) do
                    local top=obstacle.Position.Y+obstacle.Size.Y/2
                    if overlaps(obstacle,next) and old.Y-3<top and old.Y+2>top-obstacle.Size.Y then next=old; break end
                end
                b.vy=b.vy-196.2*dt
                next=Vector3.new(next.X,old.Y+b.vy*dt,next.Z)
                b.grounded=false
                if b.vy<=0 then
                    for _,pad in ipairs(pads) do
                        local y=pad.Position.Y+pad.Size.Y/2+3
                        if overlaps(pad,next) and old.Y>=y-0.08 and next.Y<=y then
                            next=Vector3.new(next.X,y,next.Z); b.vy,b.grounded=0,true; break
                        end
                    end
                end
                h.FloorMaterial=b.grounded and Enum.Material.Slate or Enum.Material.Air
                model:PivotTo(CFrame.new(next)); p.AssemblyLinearVelocity=Vector3.new(0,b.vy,0)
                b.position=next
            end
        end
        if state:raceComplete() then break end
    end
end
`;

test('all lanes leave the start and cross Starting Dash with gravity and loss of ground support', () => runLua(scene + `
simulate(30)
for _,m in pairs(state.crew) do
    assert(m.score>=12,'start/contact loop: '..m.username..' cp='..m.score..' recoveries='..m.recoveries)
    assert(m.recoveries==0,'avoidable fall in Starting Dash: '..m.username..' cp='..m.score..' recoveries='..m.recoveries)
end
`));

test('edge-triggered jumps traverse all four sections with simplified gravity, hurdle faces and moving supports', () => runLua(scene + `
simulate(120)
for _,m in pairs(state.crew) do
    assert(m.score==48,'contact model did not finish: '..m.username..' cp='..m.score..' recoveries='..m.recoveries)
    assert(m.recoveries==0,'contact model fell: '..m.username..' recoveries='..m.recoveries)
    assert(m.finishedAt-m.enteredAt>=90 and m.finishedAt-m.enteredAt<=120,'contact model duration outside target')
end
`));
