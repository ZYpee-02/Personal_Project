import test from 'node:test';
import { readFileSync } from 'node:fs';
import { performance } from 'node:perf_hooks';
import { runLua } from './helpers/lua.js';
import { presentationEngine } from './helpers/presentation-engine.js';
const read = name => readFileSync(new URL(`../roblox/ServerScriptService/${name}`, import.meta.url), 'utf8');
const scene = presentationEngine + `
local Config=(function() ${read('Config.lua')} end)()
Config.LoadAvatarAppearances=false
local Realm=(function() ${read('RealmState.lua')} end)()
local World=(function() ${read('World.lua')} end)()
World.build(Config)
local course=workspace.RiftboundRealm.SkybridgeSprint
local function surfaceY(triangle,p)
    local a,b,c=triangle:GetAttribute('SurfaceA'),triangle:GetAttribute('SurfaceB'),triangle:GetAttribute('SurfaceC')
    local v,w,q=b-a,c-a,p-a
    local denominator=v.X*w.Z-w.X*v.Z
    if math.abs(denominator)<.000001 then return nil end
    local u=(q.X*w.Z-w.X*q.Z)/denominator
    local t=(v.X*q.Z-q.X*v.Z)/denominator
    if u>=-.00001 and t>=-.00001 and u+t<=1.00001 then return a.Y+u*v.Y+t*w.Y end
end
local triangles,obstacles={},{}
for _,p in ipairs(course:GetChildren()) do
    if p.Name:find('Moving wind gate',1,true) or p.Name:find('Jump hurdle',1,true) then obstacles[#obstacles+1]=p end
    if p:GetAttribute('SurfaceA') then
        local cp=p:GetAttribute('Checkpoint');triangles[cp]=triangles[cp] or {};table.insert(triangles[cp],p)
    end
end
local function floorAt(p)
    if p.Z>=60 and p.Z<=102 and math.abs(p.X)<=48 then return 65 end
    if p.Z<=-1092 and p.Z>=-1128 and math.abs(p.X)<=48 then return 77 end
    local cp=math.max(1,math.min(48,math.ceil((60-p.Z)/24)))
    for _,triangle in ipairs(triangles[cp]) do local y=surfaceY(triangle,p);if y then return y end end
end
local function simulate(count)
    Config.SprintCompetitors=count
    local state=Realm.new(Config,0)
    local bodies={}
    for i=1,count do
        assert(state:register('Contact_'..i,0,state.round,0,0,'entry:'..i))
        World.arrive(World.offlineAvatar('Contact_'..i),i,'Contact_'..i)
        bodies[i]={vy=0,grounded=false}
    end
    state:advance(30); state:advance(34);now=34;World.sprintStep(state,now)
    local seenRoutes,rankChanges,previousLeader={},0,nil
    local dt=.05
    for step=1,2400 do
        now=34+step*dt
        World.sprintStep(state,now)
        for i=1,count do
            local m=state.crew['contact_'..i]
            local model=workspace.RiftboundRealm['Traveler_Contact_'..i]
            local h,p,b=model.Humanoid,model.PrimaryPart,bodies[i]
            if m.raceStatus=='racing' then
                if b.position and (p.Position-b.position).Magnitude>.1 then b.vy,b.grounded,b.jumpAt=0,false,nil end
                if m.route~='shared' then seenRoutes[m.route]=true end
                if h.Jump then
                    if b.grounded and not b.jumpAt then b.jumpAt=now+.05 end
                    h.Jump=false
                end
                if b.jumpAt and now>=b.jumpAt then
                    if b.grounded then b.vy,b.grounded=h.JumpPower,false end
                    b.jumpAt=nil
                end
                local old=p.Position
                local d=h.MoveGoal-old;d=Vector3.new(d.X,0,d.Z)
                local next=old+d*math.min(1,h.WalkSpeed*dt/math.max(.001,d.Magnitude))
                -- Native ground collision, friction, Humanoid step-up and crowd
                -- contacts are NOT available. Approximate only triangle contact,
                -- vertical obstacle faces, gravity and 50ms jump response.
                for _,o in ipairs(obstacles) do
                    if o.Name:find('Moving wind gate',1,true) or o.Name:find('Jump hurdle',1,true) then
                        local q=o.CFrame:PointToObjectSpace(next)
                        if math.abs(q.X)<=o.Size.X/2+1 and math.abs(q.Z)<=o.Size.Z/2+1
                            and old.Y-3<o.Position.Y+o.Size.Y/2 and old.Y+2>o.Position.Y-o.Size.Y/2 then next=old;break end
                    end
                end
                b.vy=b.vy-196.2*dt
                next=Vector3.new(next.X,old.Y+b.vy*dt,next.Z)
                local y=floorAt(next)
                local wasGrounded=b.grounded;b.grounded=false
                if y and b.vy<=0 and old.Y>=y+3-(wasGrounded and .5 or .08) and next.Y<=y+3 then
                    next=Vector3.new(next.X,y+3,next.Z);b.vy,b.grounded=0,true
                end
                h.FloorMaterial=b.grounded and Enum.Material.Slate or Enum.Material.Air
                model:PivotTo(CFrame.new(next));p.AssemblyLinearVelocity=Vector3.new(0,b.vy,0);b.position=next
            end
        end
        if step%10==0 then
            local leader=state:activityLeaderboard()[1].username
            if previousLeader and previousLeader~=leader then rankChanges=rankChanges+1 end
            previousLeader=leader
        end
        if state:raceComplete() then break end
    end
    state:advance(154) -- unfinished bodies must become real DNFs at the deadline
    local minTime,maxTime,recoveries,finished,dnfs=math.huge,0,0,0,0
    for _,m in pairs(state.crew) do
        recoveries=recoveries+m.recoveries
        assert(m.score>=44,'failed to physically traverse all four sections: '..m.username..' cp='..m.score)
        if m.finishedAt>0 then
            assert(m.score==48 and m.raceStatus=='finished','invalid finisher')
            local elapsed=m.finishedAt-m.enteredAt
            assert(elapsed>=90 and elapsed<=120,'duration outside target '..elapsed)
            minTime,maxTime=math.min(minTime,elapsed),math.max(maxTime,elapsed);finished=finished+1
        else
            assert(m.raceStatus=='dnf' and m.placement==0 and m.score<48,'deadline fabricated a finisher')
            dnfs=dnfs+1
        end
    end
    assert(finished>=math.ceil(count*.85),'fewer than 85% of the field finished the 120s contact approximation')
    assert(recoveries==0,'avoidable contact-model fall/stall: '..recoveries)
    assert(seenRoutes.main and seenRoutes.shortcut,'route choice did not exercise both paths')
    assert(rankChanges>0,'no observed changes of lead')
    print(string.format('CONTACT count=%d finished=%d DNF=%d time=%.2f..%.2f recoveries=%d leadChanges=%d',count,finished,dnfs,minTime,maxTime,recoveries,rankChanges))
end
`;
for (const count of [5,10,15,20]) {
    test(`${count} NPCs race the shared road and both forks with measured results and deadline DNFs`, () => {
        const started=performance.now();
        runLua(scene+`simulate(${count})`);
        console.log(`CONTACT ${count} NPCs cloud interpreter wall time ${((performance.now()-started)/1000).toFixed(2)}s; not Roblox FPS`);
    });
}
