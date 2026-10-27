-- Regression checks for the user-observed behaviors, beyond source inspection.
local units,timers,tags,effects,damageLog={},{},{},{},{}
function CreateTimer() local t={};table.insert(timers,t);return t end
function TimerStart(t,delay,periodic,callback) t.delay=delay;t.callback=callback end
function DestroyTimer(t) t.destroyed=true end
function CreateTextTag() local t={};table.insert(tags,t);return t end
function SetTextTagPermanent() end
function SetTextTagText(t,text) t.text=text end
function SetTextTagColor(t,r,g,b) t.color={r,g,b} end
function SetTextTagPosUnit(t,u,z) t.unit=u;t.z=z end
function DestroyTextTag(t) t.destroyed=true end
function AddSpecialEffectTarget(path,u) local e={path=path,unit=u};table.insert(effects,e);return e end
function DestroyEffect(e) e.destroyed=true end
function GetUnitMoveSpeed(u) return u.speed or 300 end
function SetUnitMoveSpeed(u,speed) u.speed=speed end
function GetHeroAgi() return 50 end
function SetUnitFlyHeight(u,height) u.height=height end
function CreateUnit(owner,raw,x,y)
    local u={id=raw,owner=owner,x=x,y=y,life=1000,maxHp=1000,mana=0,maxMana=1000,abilities={},speed=300,intelligence=100}
    table.insert(units,u);return u
end
function GroupEnumUnitsInRange(g,x,y,r)
    for _,u in ipairs(units) do
        if u.id~=0 and (u.x-x)^2+(u.y-y)^2<=r*r then table.insert(g,u) end
    end
end
function UnitDamageTarget(caster,u,damage,attack,ranged,attackType,damageType)
    u.life=u.life-damage;table.insert(damageLog,{target=u,kind=damageType,damage=damage})
end
function Arena_ShowProjectile() end
DAMAGE_TYPE_COLD=42
InitGlobals()
local hero=CreateUnit(Player(0),FourCC('E001'),0,0)
local enemy=CreateUnit(Player(1),FourCC('hfoo'),300,0)
Arena_ApplyBleedStack(enemy,hero,3,8)
Arena_ApplyBleedStack(enemy,hero,2,8)
assert(#tags==1 and tags[1].text=='Кровотечение: 5' and not tags[1].destroyed)
Arena_ApplyInductionStack(enemy,hero,2)
assert(#tags==2 and tags[2].text=='Проводимость: 2/5')
local inductionEffect=StackIndicators[enemy].induction.effect
assert(inductionEffect and not inductionEffect.destroyed)
Arena_ClearStackIndicator(enemy,'induction')
assert(inductionEffect.destroyed and tags[2].destroyed)

local enemy2=CreateUnit(Player(1),FourCC('hfoo'),400,0)
Arena_Lich_W(hero,1)
local barge=units[#units]
assert(barge.id==FourCC('uL01') and barge.height==150)
local aura=timers[#timers-1]
assert(aura.delay==2)
aura.callback()
assert(enemy.life==930 and enemy2.life==930)
assert(enemy.speed==210 and enemy2.speed==210)
assert(damageLog[#damageLog].kind==DAMAGE_TYPE_COLD)
MoveSlows[enemy].timer.callback()
assert(enemy.speed==300)

-- Living skeletons at long range must be consumed, not silently skipped.
local skeleton=CreateUnit(Player(0),FourCC('uske'),4000,0)
LichSkeletons[hero]={skeleton}
Arena_Lich_E(hero,1)
assert(skeleton.id==0 and #LichSkeletons[hero]==0)

-- W creates a damage-dealing visible unit, with replacement of the oldest at cap.
for i=1,4 do Arena_Bombardier_W(hero,1) end
assert(#EngineerTurrets[hero]==3)
local turret=EngineerTurrets[hero][3]
assert(turret.id==FourCC('hT01'))
local fire=timers[#timers]
local life=enemy2.life
fire.callback()
assert(enemy2.life==life-90)
KillUnit(turret)
fire.callback()
assert(fire.destroyed)
