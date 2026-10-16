import test from 'node:test';
import { readFileSync } from 'node:fs';
import { runLua } from './helpers/lua.js';
import { presentationEngine } from './helpers/presentation-engine.js';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const config=read('roblox/ServerScriptService/Config.lua');
const domain=read('roblox/ServerScriptService/RealmState.lua');
const world=read('roblox/ServerScriptService/World.lua');
const client=read('roblox/StarterPlayerScripts/Realm.client.lua');
const mathSource=client.split('-- BEGIN PRESENTATION MATH')[1].split('\n').slice(1).join('\n').split('-- END PRESENTATION MATH')[0];
const base=presentationEngine+`
local Config=(function() ${config} end)()
Config.LoadAvatarAppearances=false
local Realm=(function() ${domain} end)()
local World=(function() ${world} end)()
World.build(Config)
local state=Realm.new(Config,0)
local function add(name)
    local ok,member=state:addCrew(name,0); assert(ok)
    World.arrive(World.offlineAvatar(name),member.slot,name)
    return member
end
local function publish(time)
    now=time
    local s=state:snapshot(time); s.course=World.courseInfo(); s.cameraBounds=World.cameraBounds(s)
    World.render(s,time); World.animate(time)
    remotes.Snapshot.OnClientEvent:Fire(s)
    if renderStep then renderStep(0.1) end
    return s
end
`;

test('four winding sections have all 240 rotated lane pads, feasible supports and a 120s deadline',()=>runLua(base+`
assert(Config.SprintRaceSeconds==120 and Config.SprintWalkSpeed==12)
assert(World.courseInfo().length>1270 and World.courseInfo().length<1290 and #World.courseInfo().sections==4)
local course=workspace.RiftboundRealm.SkybridgeSprint
local moving,seen=0,{}
for lane=1,5 do
    for cp=1,48 do
        local pad=course['Lane '..lane..' checkpoint '..cp]
        assert(pad and pad.CanCollide and pad:GetAttribute('Section')==math.floor((cp-1)/12)+1)
        local from,to=World.sprintPoint(lane,cp-1),World.sprintPoint(lane,cp)
        local prev=cp>1 and course['Lane '..lane..' checkpoint '..(cp-1)] or course['START platform']
        local delta=to-from
        local direction=Vector3.new(delta.X,0,delta.Z); direction=direction*(1/direction.Magnitude)
        local function interval(part)
            local p=part.CFrame:PointToObjectSpace(Vector3.new(from.X,part.Position.Y,from.Z))
            local d=part.CFrame:VectorToObjectSpace(direction)
            local lo,hi=-math.huge,math.huge
            for _,axis in ipairs({'X','Z'}) do
                if math.abs(d[axis])>0.00001 then
                    local a,b=(-part.Size[axis]/2-p[axis])/d[axis],(part.Size[axis]/2-p[axis])/d[axis]
                    lo,hi=math.max(lo,math.min(a,b)),math.min(hi,math.max(a,b))
                else assert(math.abs(p[axis])<=part.Size[axis]/2,'route misses support width') end
            end
            assert(lo<=hi,'route misses rotated support')
            return lo,hi
        end
        local _,exit=interval(prev); local entry=interval(pad)
        local gap=math.max(0,entry-exit)
        local rise=to.Y-from.Y
        -- Ballistic feasibility only: gravity/jump velocity and measured pad edges,
        -- not a replacement for Roblox collision/contact testing.
        assert(gap<=4.01 and rise<=3 and rise>=-1,'unreachable authored step')
        local flight=(50+math.sqrt(50*50-2*196.2*math.max(0,rise)))/196.2
        assert(flight*12>=gap+1,'jump cannot cover the gap with landing margin')
        assert(pad.Size.X/2-1.25>=1.5,'moving bridge loses the static route center')
        seen[pad:GetAttribute('Section')]=true
    end
end
for i=1,4 do assert(seen[i]) end
local bridge=course['Lane 3 checkpoint 14']; local original=bridge.CFrame.Position
publish(0); publish(2)
assert((bridge.Position-original).Magnitude>0.1 and (bridge.Position-original).Magnitude<1.3,'bridge is not bounded moving geometry')
for i=1,5 do add('Runner_'..i) end
state:advance(12); state:advance(20); now=20; World.sprintStep(state,20)
assert(state.deadline==140)
`));

test('all five NPCs navigate every section under speed-limited command following; native contacts are unmocked',()=>runLua(base+`
print=function() end
for i=1,5 do add('Runner_'..i) end
state:advance(12); state:advance(20); now=20; World.sprintStep(state,20)
local sections,jumps,previousScores={},0,{}
for step=0,600 do
    now=20+step*0.2
    World.sprintStep(state,now)
    for i=1,5 do
        local model=workspace.RiftboundRealm['Traveler_Runner_'..i]
        local h=model.Humanoid; local p=model.PrimaryPart
        if not p.Anchored and h.MoveGoal then
            local delta=h.MoveGoal-p.Position
            local amount=math.min(1,h.WalkSpeed*0.2/math.max(0.001,delta.Magnitude))
            -- Explicit root integration follows only authored MoveTo goals. No
            -- gravity, collision, jumping or moving-support solver is supplied.
            model:PivotTo(CFrame.new(p.Position+delta*amount))
            p.AssemblyLinearVelocity=delta*amount*5
            if h.Jump then jumps=jumps+1 end
        end
        local m=state.crew['runner_'..i]
        assert(m.score>=(previousScores[i] or 0))
        previousScores[i]=m.score
        sections[math.min(4,math.floor(m.score/12)+1)]=true
    end
    if state:raceComplete() then break end
end
assert(state:raceComplete() and jumps>0,'physical command controller stalled before finishing: '..state.crew.runner_1.score..'/'..state.crew.runner_2.score..'/'..state.crew.runner_3.score..'/'..state.crew.runner_4.score..'/'..state.crew.runner_5.score)
for _,m in pairs(state.crew) do
    assert(m.score==48 and m.finishedAt-m.enteredAt>=90 and m.finishedAt-m.enteredAt<=120,'duration outside target: '..(m.finishedAt-m.enteredAt))
end
for i=1,4 do assert(sections[i]) end
`));

test('S-shaped trail changes direction and support shape, with hurdles aligned independently to every lane',()=>runLua(base+`
local course=workspace.RiftboundRealm.SkybridgeSprint
assert(course:GetAttribute('CourseRevision')=='show-v8-winding')
assert(math.abs(World.sprintPoint(3,6).X-64)<0.001 and math.abs(World.sprintPoint(3,18).X+64)<0.001)
assert(math.abs(World.sprintPoint(3,30).X-64)<0.001 and math.abs(World.sprintPoint(3,42).X+64)<0.001)
assert(course['Lane 3 checkpoint 3'].Size.X~=course['Lane 3 checkpoint 14'].Size.X)
assert(course['Lane 3 checkpoint 6'].Size.Y>course['Lane 3 checkpoint 14'].Size.Y)
for _,cp in ipairs({4,8,16,20,28,32,36,40,44}) do
    for lane=1,5 do
        local name=lane==3 and 'Jump hurdle '..cp or 'Lane '..lane..' hurdle '..cp
        local hurdle=course[name]
        local from,to=World.sprintPoint(lane,cp-1),World.sprintPoint(lane,cp)
        local midpoint=(from+to)*0.5
        local localPoint=hurdle.CFrame:PointToObjectSpace(midpoint)
        assert(math.abs(localPoint.X)<0.001 and math.abs(localPoint.Z)<0.001,'hurdle not on lane takeoff path')
        assert(hurdle.CanCollide and hurdle.Size.X<7,'lane hurdle became a shared diagonal crossbar')
    end
end
local info=World.courseInfo()
assert(#info.headings==48 and info.headings[1]<-30 and info.headings[12]>30,'missing turn directions for the camera')
`));

test('entrances queue/group without changing race clocks or money; newcomers get the next eligible cohort',()=>runLua(base+`
for i=1,5 do add('Runner_'..i) end
state:advance(12); state:advance(20); now=20; World.sprintStep(state,20)
local deadline=state.deadline
for i=1,7 do add('Viewer_'..i); assert(state:queueEntrance('Viewer_'..i)) end
state:advanceEntrances(21)
local entry=state:snapshot(21).entrance
assert(#entry.names==3 and entry.endsAt-entry.startedAt==2.5)
assert(state.deadline==deadline and state.activityEntrants==5)
assert(not state.crew.viewer_1.activityEntered and not state.crew.viewer_1.entranceDone)
publish(21)
for i=1,3 do
    local p=workspace.RiftboundRealm['Traveler_Viewer_'..i].PrimaryPart.Position
    assert((p-World.entrancePoint(i,3)).Magnitude<0.8,'entrant not held at gate')
end
state:advanceEntrances(23.5); state:advanceEntrances(26); state:advanceEntrances(30)
assert(state.crew.viewer_1.entranceDone)
state:tick(140); state:advance(140); state:advance(150); state:advance(162); state:advance(170)
assert(state.crew.viewer_1.activityEntered and state.crew.viewer_2.activityEntered,'newcomer lost next cohort priority')
assert(state.crew.runner_1.score==0 and state.crew.runner_1.finishedAt==0)
`));

test('normal entrance lasts four seconds, rejects duplicates, and new montages defer during a contested finish',()=>runLua(base+`
add('LeadRunner'); state:advance(12); state:advance(20); now=20; World.sprintStep(state,20)
add('NewViewer'); assert(state:queueEntrance('NewViewer')); assert(not state:queueEntrance('NewViewer'))
state.crew.leadrunner.distance=44
state:advanceEntrances(100); assert(not state.entrance and #state.entranceQueue==1)
state.crew.leadrunner.distance=10
state:advanceEntrances(101); assert(state.entrance.endsAt==105)
state:advanceEntrances(105); assert(state.crew.newviewer.entranceDone and not state.entrance)
`));

test('native username validation is bounded/cached, rejects invalid/nonexistent accounts, and offline rigs need no APIs',()=>runLua(base+`
assert(World.validUsername('Real_Viewer') and not World.validUsername('_bad') and not World.validUsername('two__underscores') and not World.validUsername('display name'))
local calls=0
players.GetUserIdFromNameAsync=function(_,name) calls=calls+1; assert(name=='RealViewer'); return 123 end
task.spawn=function(fn) fn() end
local id=World.resolveUsername('RealViewer'); assert(id==123)
assert(World.resolveUsername('realviewer')==123 and calls==1)
assert(not World.resolveUsername('bad name') and calls==1)
players.GetUserIdFromNameAsync=function() error('no such account') end
assert(not World.resolveUsername('DoesNotExist'))
players.GetUserIdFromNameAsync=function() now=now+9; return 99 end
assert(not World.resolveUsername('TooSlow'))
Config.ResolveViewerUsernames=false
assert(not World.resolveUsername('RealViewer'),'disabled verification made a request')
Config.LoadAvatarAppearances=false
players.GetHumanoidDescriptionFromUserIdAsync=function() error('offline appearance request') end
add('OfflineViewer'); World.loadAppearance('OfflineViewer',0)
`));

const cameras=base+mathSource+`
local logs={}; print=function(line) logs[#logs+1]=line end
for i=1,5 do add('Runner_'..i) end
;(function() ${client} end)()
local canvas=playerGui.RiftboundHUD.VerticalStreamCanvas
local function logged(fragment)
    for _,line in ipairs(logs) do if string.find(line,fragment,1,true) then return true end end
    return false
end
local function framed(name)
    local main=workspace.RiftboundRealm['Traveler_'..name].PrimaryPart
    local point,visible=camera:WorldToViewportPoint(main.Position)
    local s,ox,oy=viewportLayout(camera.ViewportSize.X,camera.ViewportSize.Y)
    local area=screenRect(Layout.arena,s,ox,oy)
    assert(visible and point.X>=area.x and point.X<=area.x+area.w and point.Y>=area.y and point.Y<=area.y+area.h,'target outside clear HUD: '..name)
    assert(camera.CFrame.Position.Y>=112 and camera.CFrame.Position.Y<=220)
    assert((camera.CFrame.Position-main.Position).Magnitude<240,'distant camera regression')
end
`;

test('director keeps all five racers framed on both outside bends in portrait and landscape',()=>runLua(cameras+`
state:advance(12); state:advance(20); now=20; World.sprintStep(state,20)
for _,size in ipairs({{390,844},{1080,1920},{1158,536}}) do
    setViewport(size[1],size[2])
    for _,cp in ipairs({6,18,30,42}) do
        for i=1,5 do
            local member=state.crew['runner_'..i]
            member.score,member.distance=cp,cp+(5-i)*0.02
            workspace.RiftboundRealm['Traveler_Runner_'..i]:PivotTo(CFrame.new(World.sprintPoint(i,cp)))
        end
        publish(20+cp*1.8)
        for i=1,5 do framed('Runner_'..i) end
        assert(camera.FieldOfView==55,'bend fell back to a distant starting-grid shot')
    end
end
`));
for (const [w,h] of [[390,844],[1080,1920],[1158,536]]) {
 test(`director follows real section roots, spotlights other racers and frames the finish at ${w}x${h}`,()=>runLua(cameras+`
setViewport(${w},${h})
state:advance(12); state:advance(20); now=20; World.sprintStep(state,20)
for _,cp in ipairs({2,14,27,39,45,47}) do
    for i=1,5 do
        local m=state.crew['runner_'..i]
        m.score,m.distance=cp,cp+(5-i)*0.02
        local model=workspace.RiftboundRealm['Traveler_Runner_'..i]
        model:PivotTo(CFrame.new(World.sprintPoint(i,cp)))
    end
    publish(20+cp*1.8)
    framed('Runner_1')
    assert(camera.FieldOfView==55,'race zoomed out to fit whole course')
end
assert(logged('shot=finish line'))
-- Test a slower competitor far behind the leaders on the periodic spotlight beat.
state.crew.runner_1.score,state.crew.runner_1.distance=25,25
state.crew.runner_2.score,state.crew.runner_2.distance=5,5
workspace.RiftboundRealm.Traveler_Runner_1:PivotTo(CFrame.new(World.sprintPoint(1,25)))
workspace.RiftboundRealm.Traveler_Runner_2:PivotTo(CFrame.new(World.sprintPoint(2,5)))
for i=3,5 do state.crew['runner_'..i].raceStatus='dnf' end
publish(44); framed('Runner_2'); assert(logged('shot=competitor spotlight'))
`));
}

test('entrance camera announces actual usernames and resumes section tracking with scoring untouched',()=>runLua(cameras+`
state:advance(12); state:advance(20); now=20; World.sprintStep(state,20)
for i=1,5 do
 state.crew['runner_'..i].score,state.crew['runner_'..i].distance=15,15
 workspace.RiftboundRealm['Traveler_Runner_'..i]:PivotTo(CFrame.new(World.sprintPoint(i,15)))
end
add('NewViewer'); state:queueEntrance('NewViewer'); state:advanceEntrances(50)
local deadline=state.deadline; publish(50)
framed('NewViewer')
for i=1,3 do now=50+i*0.2; renderStep(0.2) end -- controlled entrance ease-in
assert(camera.FieldOfView==35,'entrance reused the medium race lens')
local main=workspace.RiftboundRealm.Traveler_NewViewer.PrimaryPart
local base=camera:WorldToViewportPoint(main.Position)
local top=camera:WorldToViewportPoint(main.Position+Vector3.new(0,5.5,0))
assert(math.abs(top.Y-base.Y)>camera.ViewportSize.Y*0.08,'newcomer is too small for the entrance close-up: pixels='..math.abs(top.Y-base.Y)..' distance='..(camera.CFrame.Position-main.Position).Magnitude)
assert(logged('shot=Star Gate entrance') and canvas.EventStrip.Visible)
assert(string.find(canvas.EventStrip.Message.Text,'NewViewer',1,true))
assert(state.crew.runner_1.score==15 and state.deadline==deadline)
state:advanceEntrances(54); publish(54); framed('Runner_1')
assert(not canvas.EventStrip.Visible)
canvas.CameraToggle.Activated:Fire(); assert(camera.CameraType==Enum.CameraType.Custom)
canvas.CameraToggle.Activated:Fire(); renderStep(0.1); framed('Runner_1')
`));

test('hung native account requests cannot accumulate beyond two in flight',()=>runLua(base+`
local jobs={}; task.spawn=function(fn) jobs[#jobs+1]=fn end
assert(not World.resolveUsername('FirstHang'))
assert(not World.resolveUsername('SecondHang'))
local before=now
assert(not World.resolveUsername('ThirdHang'))
assert(#jobs==2 and now==before,'resolver accumulated more hanging requests')
`));

test('DNFs sort behind active competitors and never acquire a finisher placement',()=>runLua(base+`
add('ActiveRunner'); add('FallenRunner'); state:advance(12); state:advance(20)
state.crew.fallenrunner.score,state.crew.fallenrunner.distance=30,30
state:raceDNF('FallenRunner',state.round)
local rows=state:activityLeaderboard()
assert(rows[1].username=='ActiveRunner' and rows[2].placement==0)
`));

test('the named Studio baseplate is hidden locally for Stream and restored exactly in Roam',()=>runLua(cameras+`
local floor=instance('Part','Baseplate',workspace)
floor.LocalTransparencyModifier=0.3; floor.Transparency=0
renderStep(0.1)
assert(floor.LocalTransparencyModifier==1 and floor.Transparency==0)
canvas.CameraToggle.Activated:Fire()
assert(floor.LocalTransparencyModifier==0.3 and floor.Transparency==0)
canvas.CameraToggle.Activated:Fire(); renderStep(0.1)
playerGui.RiftboundHUD.Enabled=false; renderStep(0.1)
assert(floor.LocalTransparencyModifier==0.3)
`));

test('burst entrance shots frame every announced member at portrait and Studio sizes',()=>runLua(cameras+`
for i=1,7 do add('Viewer_'..i); assert(state:queueEntrance('Viewer_'..i)) end
state:advanceEntrances(30)
assert(#state.entrance.names==3)
for _,size in ipairs({{390,844},{1080,1920},{1158,536}}) do
    setViewport(size[1],size[2]); publish(30)
    for _,name in ipairs(state.entrance.names) do framed(name) end
    assert(camera.FieldOfView==35 and string.find(canvas.EventStrip.Message.Text,'+2 ARRIVALS',1,true))
end
`));
