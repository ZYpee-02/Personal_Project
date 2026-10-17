import test from 'node:test';
import {readFileSync} from 'node:fs';
import {runLua} from './helpers/lua.js';
import {instances} from './helpers/instances.js';
const read=n=>readFileSync(new URL(`../roblox/ServerScriptService/${n}`,import.meta.url),'utf8');
const scene=instances+`
local Config=(function() ${read('Config.lua')} end)()
Config.LoadAvatarAppearances=false;Config.SprintCompetitors=3
Config.DemoNames={'Demo_Astra','Demo_Lumen','Demo_Nova'}
Config.DemoAppearanceUserIds={}
local Realm=(function() ${read('RealmState.lua')} end)()
local now,jobs,latest,actualState=0,{},nil,nil
local arrivals,lookups,slowLookup,finishRaces=0,0,false,false
local captured,answers={},{}
local players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return {} end}
local runtime={IsStudio=function() return true end,Heartbeat=signal()}
local storage=instance('ReplicatedStorage','ReplicatedStorage')
local modules=instance('ServerScriptService','ServerScriptService')
for _,name in ipairs({'Config','RealmState','World'}) do instance('ModuleScript',name,modules) end
script={Parent=modules};workspace={StreamingEnabled=false}
game={GetService=function(_,name)
    if name=='Players' then return players elseif name=='ReplicatedStorage' then return storage elseif name=='RunService' then return runtime end
    error('unexpected service '..name)
end}
os.clock=function() return now end
print=function() end
warn=function(message) error(message) end
task={spawn=function(fn,...)
    local args={...};jobs[#jobs+1]={co=coroutine.create(function() fn(table.unpack(args)) end),wake=now}
end,wait=function(seconds) return coroutine.yield(seconds or .03) end}
local world={
 build=function() end,animate=function() end,
 preparationStep=function(state,time)
    if state.entrance and state.entrance.stage=='walking' then state:gridArrived(state.entrance.names[1],state.round,state.entrance.sequence,time,0) end
 end,
 render=function(s) latest=s;captured[#captured+1]=s end,
 offlineAvatar=function() return {Destroy=function() end} end,
 arrive=function() arrivals=arrivals+1 end,
 loadAppearance=function() end,cameraBounds=function() end,courseInfo=function() return {} end,
 validUsername=function(name) return type(name)=='string' and #name>=3 and name:match('^[%w_]+$') end,
 resolveUsername=function() lookups=lookups+1;if slowLookup then task.wait(2) end;return 123 end,
 sprintStep=function(state,time)
    actualState=state
    if finishRaces and state.phase=='storm' then for _,key in ipairs(state.crewOrder) do
        if state.crew[key].activityEntered then state:raceDNF(state.crew[key].username,state.round) end
    end end
 end,
}
require=function(token) if token==modules.Config then return Config elseif token==modules.RealmState then return Realm elseif token==modules.World then return world end;error('wrong module') end
;(function() ${read('Realm.server.lua')} end)()
assert(storage.Riftbound:GetAttribute('Ready'))
local function advanceTo(time)
    while now<time-.00001 do
        now=math.min(time,now+.05);runtime.Heartbeat:Fire(.05)
        local count=#jobs
        for i=1,count do local job=jobs[i]
            if coroutine.status(job.co)~='dead' and job.wake<=now+.00001 then
                local ok,delay=coroutine.resume(job.co);assert(ok,delay);job.wake=now+(delay or 0)
            end
        end
    end
end
local hook=modules.RiftboundEvent
local function submit(event,label)
    task.spawn(function() local ok,message=hook.OnInvoke(event);answers[label or event.eventId or 'missing']={ok=ok,message=message} end)
end
local function event(name,id,round)
    return {type='register',username=name,roundId=round or actualState.round,eventId=id,submittedAt=now,offline=true}
end
local host={UserId=123,Parent=true}
`;

test('normal server stays empty indefinitely; only explicitly scoped registration events enter the roster',()=>runLua(scene+`
advanceTo(300)
assert(latest.phase=='registration' and latest.registration.count==0 and arrivals==0 and #actualState.crewOrder==0)
submit({type='register',username='Viewer_One'},'missing')
advanceTo(301);assert(not answers.missing.ok and arrivals==0)
submit(event('Viewer_One','register:1'));advanceTo(302)
assert(answers['register:1'].ok and arrivals==1 and latest.registration.count==1)
advanceTo(500);assert(latest.phase=='registration' and actualState.deadline==0)
submit(event('Viewer_Two','register:2'));advanceTo(501)
assert(answers['register:2'].ok and actualState.deadline>now)
`));

test('queue copies envelopes, deduplicates IDs and rejects late verified lookups rather than carrying them forward',()=>runLua(scene+`
advanceTo(.1)
local first=event('Viewer_One','event:1')
submit(first);advanceTo(.2);first.username='Mutated_Name'
submit(event('Viewer_Two','event:2'));advanceTo(2)
assert(actualState.crew.viewer_one and not actualState.crew.mutated_name)
submit(event('Viewer_Three','event:1'),'replay');advanceTo(3);assert(not answers.replay.ok)
local close=actualState.deadline
advanceTo(close-1)
slowLookup=true
local late=event('Late_Viewer','lookup:late');late.offline=false
submit(late);advanceTo(close+3)
assert(lookups==1 and answers['lookup:late'] and not answers['lookup:late'].ok)
assert(not actualState.crew.late_viewer and #actualState.lockedRoster==2)
submit(event('Closed_Viewer','closed:entry'));advanceTo(close+4.5)
assert(not answers['closed:entry'].ok and not actualState.crew.closed_viewer)
local oldRound=actualState.round;finishRaces=true
advanceTo(now+12)
assert(actualState.phase=='registration' and actualState.round==oldRound+1 and #actualState.roster==0)
submit(event('Late_Viewer','lookup:late',oldRound),'old:window');advanceTo(now+1)
assert(not answers['old:window'].ok and #actualState.roster==0 and arrivals==2)
`));

test('explicit demo testing creates fresh registration events each round; disabling it returns to an empty unattended lobby',()=>runLua(scene+`
advanceTo(10);assert(arrivals==0)
storage.Riftbound.Action.OnServerEvent:Fire(host,'demoToggle','')
advanceTo(20);assert(actualState.phase=='registration' and #actualState.roster==3 and arrivals==3)
finishRaces=true
advanceTo(65)
assert(actualState.round>=2 and arrivals>=6 and #actualState.crewOrder==3)
for _,m in pairs(actualState.crew) do assert(m.races>=1) end
storage.Riftbound.Action.OnServerEvent:Fire(host,'demoToggle','')
advanceTo(150)
assert(actualState.phase=='registration' and #actualState.roster==0 and actualState.deadline==0)
local prior=arrivals;advanceTo(500);assert(arrivals==prior)
`));

for (const count of [2,5,10,20]) test(`host offline batch ${count} reserves only this round, respects capacity and rejects batches after closure`,()=>runLua(scene.replace('Config.SprintCompetitors=3','Config.SprintCompetitors=20')+`
advanceTo(.1)
storage.Riftbound.Action.OnServerEvent:Fire(host,'batchJoin','${count}',actualState.round)
advanceTo(10)
assert(#actualState.roster==${count} and arrivals==${count} and lookups==0)
for i=1,${count} do assert(actualState.crew['test_racer'..i].registeredRound==actualState.round) end
local deadline=actualState.deadline;advanceTo(deadline+.3)
assert(latest.registration.locked and #actualState.lockedRoster==${count})
storage.Riftbound.Action.OnServerEvent:Fire(host,'batchJoin','20',actualState.round)
advanceTo(now+2)
assert(arrivals==${count} and #actualState.roster==${count})
`));

test('real registration entrypoint derives canonical identity from verification and rejects alias IDs supplied through another username',()=>runLua(scene+`
advanceTo(.1)
local first=event('Verified_One','verify:1');first.offline=false;first.appearanceUserId=999
submit(first);advanceTo(2)
assert(answers['verify:1'].ok and actualState.crew.verified_one.userId==123)
local alias=event('Verified_Alias','verify:2');alias.offline=false
submit(alias);advanceTo(3)
assert(not answers['verify:2'].ok and #actualState.roster==1 and not actualState.crew.verified_alias)
assert(lookups==2 and arrivals==1)
`));
