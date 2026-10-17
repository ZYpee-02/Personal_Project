import test from 'node:test';
import {readFileSync} from 'node:fs';
import {runLua} from './helpers/lua.js';
const read=n=>readFileSync(new URL(`../roblox/ServerScriptService/${n}`,import.meta.url),'utf8');
const setup=`
local Config=(function() ${read('Config.lua')} end)()
Config.SoloEntrances=false -- v11 isolated-domain/shot regression; production requires the v13 preparation gate
local Realm=(function() ${read('RealmState.lua')} end)()
local function fresh() return Realm.new(Config,0) end
local function join(s,name,at,id,round)
    return s:register(name,0,round or s.round,at,at,id or 'entry:'..name)
end
local function race(s)
    s:advance(30);assert(s.phase=='countdown')
    s:advance(34);assert(s.phase=='storm' and s.deadline==154)
end
`;

test('default unattended mode waits indefinitely and never auto-seeds, counts down or races with zero/one entrant',()=>runLua(setup+`
assert(Config.OfflineDemoEnabled==false and Config.AutoJoinPlayers==false)
local s=fresh()
for _,time in ipairs({0,10,100,10000}) do assert(not s:advance(time)) end
assert(s.phase=='registration' and s.round==1 and s.deadline==0 and #s.roster==0)
assert(join(s,'Viewer_One',10000))
s:advance(100000);assert(s.phase=='registration' and s.deadline==0)
assert(s:snapshot(100000).registration.count==1 and #s:nextCohort()==1)
`));

test('second competitor starts a 30s open registration timer; withdrawal below two cancels and restarts fairly',()=>runLua(setup+`
local s=fresh()
assert(join(s,'Viewer_One',0));assert(join(s,'Viewer_Two',4));assert(s.deadline==34)
assert(join(s,'Viewer_Three',5));assert(s.deadline==34)
assert(s:unregister('Viewer_Two',1,8,'withdraw:2'));assert(s.deadline==34)
assert(s:unregister('Viewer_Three',1,9,'withdraw:3'));assert(s.deadline==0)
assert(not s:advance(100))
assert(join(s,'Viewer_Two',101,'retry:2'));assert(s.deadline==131)
assert(s:advance(131) and s.phase=='countdown' and #s.lockedRoster==2)
assert(not s:unregister('Viewer_One',1,132,'late:withdraw'))
`));

test('case-insensitive duplicate names, duplicate event IDs, wrong/stale round IDs and delayed verification are rejected',()=>runLua(setup+`
local s=fresh()
assert(join(s,'Viewer_One',0));assert(join(s,'Viewer_Two',0))
assert(not join(s,'viewer_one',1,'duplicate:name'))
assert(not join(s,'Viewer_Three',1,'entry:Viewer_One'))
assert(not join(s,'Viewer_Three',1,'wrong:round',2))
assert(not s:register('Viewer_Three',0,1,-1,1,'old:time'))
assert(not s:register('Viewer_Three',0,1,2,1,'future:time'))
assert(s:registrationCheck('Viewer_Three',1,29,29,'lookup:late'))
assert(not s:register('Viewer_Three',0,1,29,30,'lookup:late'),'verification completed at close was admitted')
assert(not s:register('Viewer_Three',0,1,30,30,'exact:boundary'))
s:advance(30);assert(not join(s,'Viewer_Three',31,'closed:countdown'))
s:advance(34);assert(not join(s,'Viewer_Three',40,'closed:race'))
assert(#s.lockedRoster==2 and s.activityEntrants==2 and not s.crew.viewer_three)
`));

test('roster capacity is separate from the session ledger and empty races cannot be forced',()=>runLua(setup+`
local s=fresh()
for i=1,20 do assert(join(s,'Viewer_'..i,0,'entry:'..i)) end
assert(not join(s,'Viewer_21',0,'full:entry'))
s:advance(30);assert(s.phase=='countdown' and #s:nextCohort()==20)
s:advance(34);assert(s.activityEntrants==20)
local empty=fresh();empty.deadline=1
empty:advance(10);assert(empty.phase=='registration' and empty.deadline==0)
`));

test('measured winners/earnings/history survive roster reset; everyone needs a NEW event in the next window',()=>runLua(setup+`
local s=fresh();join(s,'Viewer_One',0);join(s,'Viewer_Two',0);race(s)
for cp=1,48 do assert(s:recordCheckpoint('Viewer_One',cp,34+cp*2,s.round)) end
assert(s:raceDNF('Viewer_Two',s.round))
assert(s:advance(131) and s.phase=='result' and #s.roster==0 and #s.lockedRoster==0 and #s.entranceQueue==0 and not s.entrance)
assert(#s.winners==1 and s.winners[1].elapsed==96 and s.winners[1].prize==120)
local money=s.crew.viewer_one.balance;local races=s.crew.viewer_one.races
assert(s:advance(141) and s.phase=='registration' and s.round==2 and s.deadline==0)
assert(s.crew.viewer_one.balance==money and s.crew.viewer_one.races==races and s.crew.viewer_one.finishes==1)
assert(s.crew.viewer_two.dnfs==1 and s.raceHistory[1].roundId==1)
local copy=s:snapshot(141);copy.lastRace.finishers[1].elapsed=0
assert(s.raceHistory[1].finishers[1].elapsed==96,'snapshot leaked mutable history')
assert(not s.crew.viewer_one.activityEntered and #s:nextCohort()==0 and s:rate(s.crew.viewer_one)==0)
assert(not s:register('Viewer_One',0,1,0,142,'entry:Viewer_One'))
assert(not s:register('Viewer_One',0,2,140,142,'wrong:window:time'))
assert(join(s,'Viewer_One',142,'fresh:round:2'))
s:advance(10000);assert(s.phase=='registration' and s.deadline==0 and #s.roster==1)
assert(s.crew.viewer_one.balance==money,'inactive waiting mode earned race income')
`));

test('power-up highlights are cosmetic, round-bound, cooldown-limited, queued for 1.5s and yield to finishes',()=>runLua(setup+`
local s=fresh();join(s,'Viewer_One',0);join(s,'Viewer_Two',0);race(s)
local m=s.crew.viewer_one;local score,money,deadline=m.score,m.balance,s.deadline
assert(s:activatePowerup('Viewer_One','trail',40,1,'power:1'))
assert(not s:activatePowerup('Viewer_One','shield',40,1,'power:1'))
assert(not s:activatePowerup('Viewer_One','shield',41,1,'power:2'))
assert(not s:activatePowerup('Viewer_One','trail',52,2,'wrong:power:round'))
assert(s:activatePowerup('Viewer_Two','shield',40,1,'power:3'))
s:advanceHighlights(40);assert(s.highlight.username=='Viewer_One' and s.highlight.endsAt==41.5)
s:advanceHighlights(41.5);assert(s.highlight.username=='Viewer_Two')
assert(m.score==score and m.balance==money and s.deadline==deadline and Config.SprintWalkSpeed==12.5)
m.distance=45;s:advanceHighlights(42);assert(not s.highlight)
assert(s:activatePowerup('Viewer_One','starburst',52,1,'power:4'))
s:advanceHighlights(60);assert(not s.highlight,'expired queued highlight survived')
s:advance(154);assert(#s.highlightQueue==0 and not s.highlight)
`));
