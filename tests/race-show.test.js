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
Config.RegistrationSeconds=nil -- legacy-domain regression fixture; production server always supplies 30s
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

test('shared skyway retains four sections, banked turns, moving gates and the physical 120s deadline',()=>runLua(base+`
assert(Config.SprintCompetitors==20 and Config.MaxCrew==40 and #Config.DemoNames==20)
assert(Config.SprintRaceSeconds==120 and Config.SprintWalkSpeed==12.5)
local info=World.courseInfo()
assert(info.length>1270 and info.length<1290 and #info.sections==4 and info.roadWidth==64)
assert(#info.headings==48 and info.headings[1]<-30 and info.headings[12]>30)
local course=workspace.RiftboundRealm.SkybridgeSprint
assert(course:GetAttribute('CourseRevision')=='show-v10-shared-road')
local p=course['Moving wind gate 1'];local original=p.Position
World.stepCourse(0);World.stepCourse(2)
assert((p.Position-original).Magnitude>1 and (p.Position-original).Magnitude<22)
local left,right=World.routePoint(6,'shared',-32),World.routePoint(6,'shared',32)
assert(right.Y-left.Y>3,'turns have no physical bank')
for i=1,20 do assert(course['Grid '..i]) end
for i=1,5 do add('Runner_'..i) end
state:advance(12);state:advance(20);now=20;World.sprintStep(state,20)
assert(state.deadline==140)
for i=1,5 do
    local rig=workspace.RiftboundRealm['Traveler_Runner_'..i]
    assert(rig.RaceCollider.CollisionGroup=='RiftboundRacers' and not rig.PrimaryPart.Anchored)
end
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

test('director keeps the lead and two neighboring racers close on both outside bends in portrait and landscape',()=>runLua(cameras+`
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
        for i=1,3 do framed('Runner_'..i) end
        local root=workspace.RiftboundRealm.Traveler_Runner_1.PrimaryPart.Position
        local bottom=camera:WorldToViewportPoint(root)
        local top=camera:WorldToViewportPoint(root+Vector3.new(0,5.5,0))
        assert(math.abs(top.Y-bottom.Y)>camera.ViewportSize.Y*.025,'pack shot made the lead avatar too small')
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

test('20-racer director frames a fork pack and follows an actual new leader within the same camera beat',()=>runLua(base+mathSource+`
Config.SprintCompetitors=20
print=function() end
for i=1,20 do add('Crowd_'..i) end
;(function() ${client} end)()
state:advance(12);state:advance(20);now=20;World.sprintStep(state,20)
for i=1,20 do
    local member=state.crew['crowd_'..i]
    member.score,member.distance=15,15+(20-i)*.01
    member.route=i%2==0 and 'shortcut' or 'main'
    workspace.RiftboundRealm['Traveler_Crowd_'..i]:PivotTo(CFrame.new(World.routePoint(15,member.route,(i%3-1)*3)))
end
local function assertLead(name)
    local main=workspace.RiftboundRealm['Traveler_'..name].PrimaryPart
    local p,on=camera:WorldToViewportPoint(main.Position)
    local scale,ox,oy=viewportLayout(camera.ViewportSize.X,camera.ViewportSize.Y)
    local rect=screenRect(Layout.arena,scale,ox,oy)
    assert(on and p.X>=rect.x and p.X<=rect.x+rect.w and p.Y>=rect.y and p.Y<=rect.y+rect.h,'fork leader outside HUD safe area')
    assert(camera.CFrame.Position.Y>=112 and camera.FieldOfView==55)
end
for _,size in ipairs({{390,844},{1080,1920},{1158,536}}) do
    setViewport(size[1],size[2]);state.crew.crowd_1.distance=15.9;state.crew.crowd_2.distance=15.8
    publish(60);assertLead('Crowd_1')
    state.crew.crowd_2.distance=15.95
    publish(60.1);assertLead('Crowd_2')
end
`));
