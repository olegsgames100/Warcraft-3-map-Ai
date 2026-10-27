-- Functional regression checks for the reported direction/parry/summon bugs.
local aimX, aimY, targetUnit = 0,0,nil
function GetSpellTargetX() return aimX end
function GetSpellTargetY() return aimY end
function GetSpellTargetUnit() return targetUnit end
local hero = {x=500,y=500,life=1000,maxHp=1000,owner=Player(0),abilities={},id=1,armor=4}
local x,y = Arena_GetAimPoint(hero)
assert(x==0 and y==0, 'world origin must remain a valid aim point')
targetUnit={x=200,y=300}
x,y=Arena_GetAimPoint(hero)
assert(x==200 and y==300)
targetUnit=nil
assert(Arena_UnitInLine({x=300,y=0},0,0,700,0,100))
assert(not Arena_UnitInLine({x=300,y=250},0,0,700,0,100))
assert(not Arena_UnitInLine({x=-1,y=0},0,0,700,0,100))
assert(not Arena_UnitInLine({x=701,y=0},0,0,700,0,100))

local timers, invulnerabilityCalls, damage = {},0,0
function CreateTimer() local t={};table.insert(timers,t);return t end
function TimerStart(t,delay,periodic,callback) t.delay=delay;t.callback=callback end
function SetUnitInvulnerable() invulnerabilityCalls=invulnerabilityCalls+1 end
function BlzSetEventDamage(v) damage=v end
Arena_Ronin_W(hero,1)
local stanceTimer=timers[#timers]
local counterCount=0
local originalCounter=Arena_Ronin_CounterAttack
function Arena_Ronin_CounterAttack(caster,absorbed)
    counterCount=counterCount+1
    assert(absorbed==83)
end
Arena_ParryDamage(hero,83)
assert(damage==0 and invulnerabilityCalls==0)
local queued=timers[#timers]
damage=50
Arena_ParryDamage(hero,50)
assert(damage==0 and timers[#timers]==queued)
queued.callback()
assert(counterCount==1)
stanceTimer.callback()
damage=50
Arena_ParryDamage(hero,50)
assert(damage==50, 'block expires after the stance')
Arena_Ronin_CounterAttack=originalCounter

local created={}
function GetUnitFacing() return 0 end
function GetHeroStr() return 26 end
function UnitApplyTimedLife(u) assert(u~=nil) end
function CreateUnit(owner,raw,x,y)
    assert(raw==FourCC('eD01') or raw==FourCC('eD02'), 'unregistered druid summon')
    local u={owner=owner,id=raw,x=x,y=y,life=100,maxHp=100,abilities={}}
    table.insert(created,u)
    return u
end
Arena_Druid_Q(hero,1)
assert(#created==1 and created[1].id==FourCC('eD01') and created[1].maxHp==2300)
Arena_Druid_R(hero,1)
assert(#created==2 and created[2].id==FourCC('eD02') and DruidDeepwoodColossus[hero]==created[2])

-- A side target must not steal the aimed shot; choose the closest target on its line.
hero.x,hero.y=0,0
aimX,aimY=700,0
local near={x=200,y=0,life=1000,owner=Player(1),id=1}
local far={x=600,y=0,life=1000,owner=Player(1),id=1}
local side={x=300,y=250,life=1000,owner=Player(1),id=1}
function GroupEnumUnitsInRange(g,x,y,r)
    for _,u in ipairs({far,side,near}) do
        if (u.x-x)^2+(u.y-y)^2<=r*r then table.insert(g,u) end
    end
end
function PauseUnit() end
function SetUnitPathing() end
local originalProjectile=Arena_ShowProjectile
local endpoint
function Arena_ShowProjectile(sx,sy,ex,ey) endpoint={ex,ey} end
Arena_Colossus_Q(hero,1)
assert(near.life==834 and far.life==1000 and side.life==1000)
assert(endpoint[1]==200 and endpoint[2]==0)
Arena_ShowProjectile=originalProjectile
