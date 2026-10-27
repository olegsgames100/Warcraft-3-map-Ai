-- Functional checks with positions, corpses, timer ticks and real stat changes.
local world, timers = {}, {}
local function unit(owner, x, hp)
    local u = {owner=owner, x=x, y=0, life=hp or 1000, maxHp=1000, mana=0, maxMana=1000,
        armor=4, abilities={}, id=1, intelligence=100}
    table.insert(world,u)
    return u
end
UNIT_STATE_LIFE, UNIT_STATE_MAX_LIFE = 'life','maxHp'
UNIT_STATE_MANA, UNIT_STATE_MAX_MANA = 'mana','maxMana'
UNIT_TYPE_HERO, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS = 'hero',1,1,1
function GetHandleId(u) return u end
function GetUnitX(u) return u.x end
function GetUnitY(u) return u.y end
function GetUnitTypeId(u) return u.id end
function IsUnitType(u,t) return u.hero == true end
function IsUnitEnemy(u,p) return u.owner ~= p end
function GetHeroInt(u) return u.intelligence end
function GetUnitState(u,field) return u[field] end
function SetUnitState(u,field,v) u[field]=v end
function GetSpellTargetX() return 0 end
function GetSpellTargetY() return 0 end
function GetSpellTargetUnit() return nil end
function SetWidgetLife(u,hp) u.life=math.min(hp,u.maxHp) end
function BlzGetUnitMaxHP(u) return u.maxHp end
function BlzSetUnitMaxHP(u,hp) u.maxHp=hp; u.life=math.min(u.life,hp) end
function BlzGetUnitArmor(u) return u.armor end
function BlzSetUnitArmor(u,v) u.armor=v end
function KillUnit(u) u.life=0 end
function RemoveUnit(u) u.id=0 end
function CreateTimer() local t={}; table.insert(timers,t); return t end
function DestroyTimer(t) t.destroyed=true end
function TimerStart(t,interval,periodic,callback) t.interval=interval; t.callback=callback end
function CreateGroup() return {} end
function GroupEnumUnitsInRange(g,x,y,r)
    for _,u in ipairs(world) do
        if u.id~=0 and (u.x-x)^2+(u.y-y)^2<=r*r then table.insert(g,u) end
    end
end
function FirstOfGroup(g) return g[1] end
function GroupRemoveUnit(g,u)
    for i,v in ipairs(g) do if v==u then table.remove(g,i); return end end
end
function DestroyGroup(g) end
function UnitDamageTarget(caster,target,damage) target.life=target.life-damage end
function AddSpecialEffect() return {} end
function SetUnitPosition(u,x,y) u.x=x;u.y=y end
function Arena_ApplyInductionStack() end -- isolate field damage from the detonation mechanic

InitGlobals()
local hero=unit(Player(0),0,500)
Arena_ShieldOfTorment(hero,210,15,8)
assert(hero.maxHp==1210 and hero.armor==19 and hero.abilities[FourCC('AS01')])
assert(not hero.abilities[FourCC('Adev')] and not hero.abilities[FourCC('AImx')])
local oldTimer=timers[#timers]
Arena_ShieldOfTorment(hero,210,15,8)
assert(oldTimer.destroyed and hero.maxHp==1210 and hero.armor==19, 'refresh must not stack')
timers[#timers].callback()
assert(hero.maxHp==1000 and hero.armor==4 and not hero.abilities[FourCC('AS01')])

world={hero}
hero.life=1000
local target=unit(Player(1),400)
local outside=unit(Player(1),451)
Arena_Storm_W(hero,1)
local fieldTimer=timers[#timers]
assert(fieldTimer.interval==1)
for i=1,6 do fieldTimer.callback() end
assert(target.life==760 and outside.life==1000 and fieldTimer.destroyed)

world={hero}
hero.life=500; hero.mana=0
local corpse=unit(Player(1),100,0)
local enemy=unit(Player(1),120)
local skeleton=unit(Player(0),150)
local heroCorpse=unit(Player(1),200,0);heroCorpse.hero=true
LichSkeletons[hero]={skeleton}
Arena_Lich_E(hero,1)
assert(corpse.id==0 and skeleton.life==0 and heroCorpse.id~=0)
assert(enemy.life==700 and hero.life==580 and hero.mana==100)
assert(#LichSkeletons[hero]==0)
-- No second damage/healing from already consumed corpses or dead tracked summons.
Arena_Lich_E(hero,1)
assert(enemy.life==700 and hero.life==580 and hero.mana==100)
