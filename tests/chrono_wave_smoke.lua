local world,timers={},{}
function CreateTimer() local t={};table.insert(timers,t);return t end
function TimerStart(t,delay,periodic,callback) t.delay=delay;t.callback=callback end
function CreateUnit(owner,raw,x,y)
    local u={owner=owner,id=raw,x=x,y=y,life=1000,maxHp=1000,abilities={},speed=300,intelligence=100}
    table.insert(world,u);return u
end
function GroupEnumUnitsInRange(g,x,y,r)
    for _,u in ipairs(world) do
        if u.id~=0 and (u.x-x)^2+(u.y-y)^2<=r*r then table.insert(g,u) end
    end
end
function PauseUnit(u,flag) u.paused=flag end
function GetSpellTargetUnit() return nil end
function BlzGetUnitAbilityCooldownRemaining(u,spell) return u.cooldowns[spell] or 0 end
function BlzStartUnitAbilityCooldown(u,spell,remaining) u.cooldowns[spell]=remaining end
DAMAGE_TYPE_UNIVERSAL=43
InitGlobals()
local hero=CreateUnit(Player(0),FourCC('U002'),0,0)
Heroes[0]=hero;HeroKind[0]=10
hero.cooldowns={}
Arena_Chrono_E(hero,1)
assert(world[#world].id==FourCC('eC01'))
local cooldown=timers[#timers-1]
assert(cooldown.delay==0)
cooldown.callback()
assert(hero.cooldowns[FourCC('A11F')]==16)
hero.cooldowns[FourCC('A11G')]=30
Arena_AccelerateCooldowns(hero,5)
local acceleration=timers[#timers]
acceleration.callback()
assert(hero.cooldowns[FourCC('A11F')]==15.5 and hero.cooldowns[FourCC('A11G')]==30)

hero.x,hero.y=0,0
local near=CreateUnit(Player(1),FourCC('hfoo'),100,0)
local late=CreateUnit(Player(1),FourCC('hfoo'),900,0)
Arena_Chrono_R(hero,1)
local first=timers[#timers]
assert(first.delay==0.1 and near.paused and not late.paused)
late.x=300
first.callback()
assert(late.paused, 'late entrant must receive the same stasis')
late.x=800
first.callback()
assert(not late.paused and ChronoFreeze[late]==nil, 'leaving releases stasis')
late.x=250
first.callback()
Arena_Chrono_R(hero,1)
local second=timers[#timers]
for i=1,50 do if not first.destroyed then first.callback() end end
assert(first.destroyed and late.paused and ChronoFreeze[late].count==1)
for i=1,50 do if not second.destroyed then second.callback() end end
assert(second.destroyed and not late.paused and ChronoFreeze[late]==nil)
assert(hero.speed==300 and ChronoHaste[hero]==nil)

udg_WavesStarted=true;udg_Wave=1;udg_EnemiesAlive=0;udg_WaveCleared=false;udg_Boss=nil
udg_WaveTimer=CreateTimer()
Arena_CheckWaveClear()
assert(udg_WaveTimer.delay==7)
