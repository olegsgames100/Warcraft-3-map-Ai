-- Isolated behavioral checks for the new balancing request.
local world, timers, damageLog = {}, {}, {}
UNIT_STATE_LIFE,UNIT_STATE_MAX_LIFE,UNIT_STATE_MANA,UNIT_STATE_MAX_MANA='life','maxHp','mana','maxMana'
UNIT_TYPE_HERO='hero'
PATHING_TYPE_WALKABILITY='walk'
ATTACK_TYPE_MAGIC,DAMAGE_TYPE_FIRE,DAMAGE_TYPE_LIGHTNING,DAMAGE_TYPE_NORMAL,ATTACK_TYPE_HERO,WEAPON_TYPE_WHOKNOWS=1,2,3,4,5,6
function CreateTimer() local t={};timers[#timers+1]=t;return t end
function TimerStart(t,delay,periodic,callback) t.delay=delay;t.callback=callback end
function DestroyTimer(t) t.destroyed=true end
function CreateUnit(owner,id,x,y)
    local u={owner=owner,id=id,x=x,y=y,life=5000,maxHp=1000,mana=200,maxMana=1000,
        intelligence=100,strength=50,speed=300,abilities={},heroLevel=1}
    world[#world+1]=u;return u
end

function GetUnitTypeId(u) return u.id end
function GetUnitX(u) return u.x end
function GetUnitY(u) return u.y end
function SetUnitX(u,x) u.x=x end
function SetUnitPosition(u,x,y) u.x=x;u.y=y end
function SetUnitY(u,y) u.y=y end
function GetUnitFacing() return 0 end
function GetHandleId(u) return u end
function GetHeroInt(u) return u.intelligence end
function GetHeroStr(u) return u.strength end
function GetUnitState(u,f) return u[f] end
function SetUnitState(u,f,v) u[f]=v end
function GetUnitMoveSpeed(u) return u.speed end
function SetUnitMoveSpeed(u,v) u.speed=v end
function BlzSetUnitMaxHP(u,v) assert(math.type(v)=='integer');u.maxHp=v end
function BlzSetUnitBaseDamage(u,v) u.baseDamage=v end
function KillUnit(u) u.life=0 end
function RemoveUnit(u) u.id=0 end
function IsUnitType(u) return u.hero or false end
function IsUnitEnemy(u,p) return u.owner~=p end
function IsUnitPaused(u) return u.paused or false end
function PauseUnit(u,v) u.paused=v end
function IsTerrainPathable() return false end
function UnitApplyTimedLife() end
function AddSpecialEffect() return {} end
function AddSpecialEffectTarget() return {} end
function DestroyEffect(e) e.destroyed=true end
function CreateGroup() return {} end
function FirstOfGroup(g) return g[1] end
function GroupRemoveUnit(g,u) for i,v in ipairs(g) do if v==u then table.remove(g,i);return end end end
function DestroyGroup() end
function GroupEnumUnitsInRange(g,x,y,r)
    for _,u in ipairs(world) do
        if u.id~=0 and (u.x-x)^2+(u.y-y)^2<=r*r then g[#g+1]=u end
    end
end
function UnitDamageTarget(caster,u,damage,a,b,attackType,damageType)
    u.life=u.life-damage;damageLog[#damageLog+1]={unit=u,damage=damage,kind=damageType}
end
function GetSpellTargetUnit() return nil end
local aimX,aimY=0,0
function GetSpellTargetX() return aimX end
function GetSpellTargetY() return aimY end
function MoveLightningEx() end
function CreateTextTag() return {} end
function SetTextTagPermanent() end
function SetTextTagText() end
function SetTextTagColor() end
function SetTextTagPosUnit() end
function DestroyTextTag() end

InitGlobals()
-- Ultimate button remains visible but disabled until exactly level five, for all classes.
for role=1,10 do
    local hero=CreateUnit(Player(0),HeroClasses[role].id,0,0)
    for _,id in ipairs(HeroClasses[role].spells) do UnitAddAbility(hero,id) end
    local ult=HeroClasses[role].spells[4]
    for level=1,4 do
        hero.heroLevel=level;Arena_UpdateUltimate(hero,role)
        assert(hero.disabled[ult])
    end
    hero.heroLevel=5;Arena_UpdateUltimate(hero,role)
    assert(not hero.disabled[ult])
end

-- All nearby enemies are chained, dragged, damaged every second and released.
InitGlobals();world={};timers={}
local knight=CreateUnit(Player(0),FourCC('H001'),0,0)
local a=CreateUnit(Player(1),FourCC('hfoo'),300,0)
local b=CreateUnit(Player(1),FourCC('hfoo'),-300,0)
local outside=CreateUnit(Player(1),FourCC('hfoo'),501,0)
local ally=CreateUnit(Player(0),FourCC('hfoo'),200,0)
Arena_DoomChains(knight,500,4,110)
local chainTimer=timers[#timers]
assert(a.paused and b.paused and not outside.paused and not ally.paused)
knight.x=700
for i=1,20 do chainTimer.callback() end
assert(a.x>300 and b.x>-300 and a.life==4890 and b.life==4890)
assert(damageLog[#damageLog].kind==DAMAGE_TYPE_FIRE)
for i=21,80 do chainTimer.callback() end
assert(a.life==4560 and b.life==4560 and not a.paused and not b.paused and chainTimer.destroyed)
assert(outside.life==5000 and ally.life==5000 and next(ChronoFreeze)==nil)
-- Early caster death releases every victim too.
knight.x=0;a.x=100;b.x=-100
Arena_DoomChains(knight,500,4,110)
local early=timers[#timers];knight.life=0;early.callback()
assert(early.destroyed and not a.paused and not b.paused)

-- Guardian cap, dynamic damage scaling, and re-summoning after its death.
InitGlobals();world={};timers={}
local druid=CreateUnit(Player(0),FourCC('U001'),0,0)
UnitAddAbility(druid,FourCC('A107'))
Arena_Druid_Q(druid,1)
local guardian=DruidGuardians[druid]
local guardianTimer=timers[#timers]
assert(guardian.maxHp==900 and guardian.baseDamage==74 and druid.disabled[FourCC('A107')])
Arena_Druid_Q(druid,1)
assert(#world==2 and DruidGuardians[druid]==guardian)
druid.strength=100;guardianTimer.callback()
assert(guardian.baseDamage==104)
KillUnit(guardian);guardianTimer.callback()
assert(DruidGuardians[druid]==nil and not druid.disabled[FourCC('A107')])
Arena_Druid_Q(druid,1)
assert(DruidGuardians[druid]~=guardian and #world==3)

-- E applies real hit stacks; the fifth stack emits a small wave without instant kills.
InitGlobals();world={};timers={}
local mage=CreateUnit(Player(0),FourCC('H002'),0,0)
Heroes[0]=mage;HeroKind[0]=3
local marked=CreateUnit(Player(1),FourCC('hfoo'),300,0)
local near=CreateUnit(Player(1),FourCC('hfoo'),500,0)
local far=CreateUnit(Player(1),FourCC('hfoo'),650,0)
Arena_Storm_E(mage,1)
assert(mage.mana==200, 'overcharge no longer refunds mana')
Arena_Storm_OnAttackHit(mage,marked)
assert(InductionStacks[marked].count==2 and marked.life==4880)
Arena_Storm_OnAttackHit(mage,marked)
assert(InductionStacks[marked].count==4)
Arena_Storm_OnAttackHit(mage,marked)
assert(InductionStacks[marked]==nil and marked.life==4480 and near.life==5000 and far.life==5000)
assert(mage.mana==210)
mage.life=500
Arena_Storm_R(mage,1)
assert(mage.life==500, 'storm must not heal the caster')

-- Each rank caps the cast; selection center rather than caster controls consumption.
for rank=1,5 do
    InitGlobals();world={};timers={}
    local lich=CreateUnit(Player(0),FourCC('E001'),0,0)
    lich.life=500;lich.mana=0
    aimX,aimY=3000,0
    local limit=3+2*rank
    local bodies={}
    for i=1,limit+2 do
        local body=CreateUnit(Player(1),FourCC('hfoo'),3000+i*2,0);body.life=0
        bodies[#bodies+1]=body
    end
    local skeleton=CreateUnit(Player(0),FourCC('uske'),3100,0)
    local outsideSkeleton=CreateUnit(Player(0),FourCC('uske'),0,0)
    LichSkeletons[lich]={skeleton,outsideSkeleton}
    Arena_Lich_E(lich,rank)
    local consumed=0
    for _,body in ipairs(bodies) do if body.id==0 then consumed=consumed+1 end end
    assert(consumed==limit and skeleton.id~=0 and outsideSkeleton.id~=0)
    assert(lich.mana==10*limit, 'only 1% max mana is restored per consumed body')
    -- No corpses left: the living owned skeleton in the selected area can be consumed.
    for _,body in ipairs(bodies) do body.id=0 end
    Arena_Lich_E(lich,rank)
    assert(skeleton.id==0 and outsideSkeleton.id~=0 and #LichSkeletons[lich]==1)
end

-- Rank progression is automatic, including the separate ultimate progression.
InitGlobals()
local ranked=CreateUnit(Player(0),FourCC('O001'),0,0)
for _,spell in ipairs(HeroClasses[2].spells) do UnitAddAbility(ranked,spell) end
for _,level in ipairs({1,4,5,9,13,17,21}) do
    ranked.heroLevel=level;Arena_UpdateRanks(ranked,2)
    assert(ranked.levels[FourCC('A103')]==math.min(5,1+math.floor((level-1)/4)))
    assert(ranked.levels[FourCC('A10G')]==math.min(5,1+math.floor(math.max(0,level-5)/4)))
end

-- Q splits one fixed budget; E stacks only on hits and ranks extend duration.
InitGlobals();world={};timers={};aimX,aimY=0,0
local hunter=CreateUnit(Player(0),FourCC('O001'),0,0)
function GetHeroAgi() return 50 end
Heroes[0]=hunter;HeroKind[0]=2
local first=CreateUnit(Player(1),FourCC('hfoo'),100,0)
Arena_ShadowThrow(hunter,1)
assert(first.life==4818 and BleedStacks[first].count==2)
first.life=5000
local second=CreateUnit(Player(1),FourCC('hfoo'),150,0)
Arena_ShadowThrow(hunter,1)
assert(first.life==4909 and second.life==4909)
SetUnitAbilityLevel(hunter,FourCC('A10F'),3)
Arena_HeroHitPassives(hunter,first)
assert(BleedStacks[first].count==5 and BleedStacks[first].duration==10)
Arena_InitBleedSystem()
timers[#timers].callback()
assert(first.life==4884, 'five stacks deal 25 per second')

-- Stance preserves received damage, reflects a bounded fraction and rewards completion only.
function BlzGetUnitArmor(u) return u.armor or 4 end
function BlzSetUnitArmor(u,v) u.armor=v end
InitGlobals();world={};timers={}
local ronin=CreateUnit(Player(0),FourCC('H003'),0,0)
local attacker=CreateUnit(Player(1),FourCC('hfoo'),100,0)
Arena_Ronin_E(ronin,3)
assert(RoninResolve[ronin].timer.delay==4)
Arena_ResolveReflect(ronin,attacker,100)
assert(attacker.life==4940 and attacker.speed==210 and ronin.life==5000)
Arena_EndResolve(ronin,false)
assert(not RoninResolve[ronin] and not RoninRewards[ronin] and ronin.speed==300)
Arena_Ronin_E(ronin,3)
RoninResolve[ronin].timer.callback()
assert(RoninRewards[ronin] and ronin.armor==13 and ronin.speed==360)
RoninRewards[ronin].timer.callback()
assert(ronin.armor==4 and ronin.speed==300 and not RoninRewards[ronin])


-- Sequential bolts: no damage to the next unit until its scheduled jump.
InitGlobals();world={};timers={}
local storm=CreateUnit(Player(0),FourCC('H002'),0,0)
local bolt1=CreateUnit(Player(1),FourCC('hfoo'),200,0)
local bolt2=CreateUnit(Player(1),FourCC('hfoo'),450,0)
local bolt3=CreateUnit(Player(1),FourCC('hfoo'),700,0)
local chain=Arena_ChainLightning(storm,bolt1,100,3,false)
assert(bolt1.life==4900 and bolt2.life==5000 and bolt3.life==5000 and chain.delay==0.15)
chain.callback()
assert(bolt2.life==4920 and bolt3.life==5000)
chain.callback()
assert(bolt3.life==4936 and chain.destroyed)

-- Saplings decay by exactly 10 HP, and E heals instead of extending a deadline.
function IsUnitAlly(u,p) return u.owner==p end
InitGlobals();world={};timers={}
local keeper=CreateUnit(Player(0),FourCC('U001'),0,0)
local sapling=CreateUnit(Player(0),FourCC('eD03'),100,0)
sapling.life=500
Arena_StartSaplingLife(sapling,keeper)
local decay=SaplingLife[sapling]
for i=1,2 do decay.timer.callback() end
assert(sapling.life==480 and decay.remaining==nil)
Arena_Druid_E(keeper,3)
assert(sapling.life==880, '30% extra plus 10% ordinary healing')
for i=1,40 do decay.timer.callback() end
assert(sapling.life==480 and SaplingLife[sapling], 'no timed expiry')
sapling.life=10;decay.timer.callback()
assert(sapling.life==0 and SaplingLife[sapling]==nil)

-- E survives automatic/attack orders, and Stop deliberately cancels it.
function OrderId(order) return order end
InitGlobals();world={};timers={}
local blade=CreateUnit(Player(0),FourCC('H003'),0,0)
Arena_Ronin_E(blade,2)
Arena_ResolveOrder(blade,OrderId('attack'))
assert(RoninResolve[blade])
Arena_ResolveOrder(blade,OrderId('stop'))
assert(not RoninResolve[blade] and not RoninRewards[blade])

-- W marks a directional strip, then cuts without moving or dealing early damage.
local victim=CreateUnit(Player(1),FourCC('hfoo'),100,0)
local following=CreateUnit(Player(1),FourCC('hfoo'),300,0)
local side=CreateUnit(Player(1),FourCC('hfoo'),300,160)
local friend=CreateUnit(Player(0),FourCC('hfoo'),200,0)
local bx,by=blade.x,blade.y
aimX,aimY=900,0
Arena_Ronin_W(blade,1)
local delayed=timers[#timers]
assert(delayed.delay==0.8 and victim.life==5000 and following.life==5000)
assert(blade.x==bx and blade.y==by and not RoninResolve[blade])
following.x=4000
delayed.callback()
assert(victim.life==4860 and following.life==4860 and side.life==5000 and friend.life==5000)
assert(victim.armor==2 and RoninIaiCuts[victim].timer.delay==4)
RoninIaiCuts[victim].timer.callback()
assert(victim.armor==4 and not RoninIaiCuts[victim])
Arena_IaiArmorCut(victim,2)
local stale=RoninIaiCuts[victim]
Arena_IaiArmorCut(victim,4)
assert(stale.timer.destroyed and victim.armor==0)
stale.timer.callback()
assert(victim.armor==0)
RoninIaiCuts[victim].timer.callback()
assert(victim.armor==4)
-- A successful full stance empowers the delayed W hit by 25%.
Arena_Ronin_E(blade,1)
assert(RoninResolve[blade].timer.delay==2)
for i=1,10 do RoninResolve[blade].progress.callback() end
assert(not RoninRewards[blade])
RoninResolve[blade].timer.callback()
Arena_Ronin_W(blade,1)
local combo=timers[#timers]
local life=victim.life
combo.callback()
assert(victim.life==life-175)
for rank=1,5 do
    Arena_Ronin_E(blade,rank)
    assert(RoninResolve[blade].timer.delay==rank+1)
    Arena_EndResolve(blade,false)
end
-- Model the engine behavior that made SetUnitPosition cancel E.
local position=SetUnitPosition
function SetUnitPosition(u,x,y)
    position(u,x,y);Arena_ResolveOrder(u,OrderId('stop'))
end
Arena_Ronin_E(blade,2)
RoninResolve[blade].progress.callback()
assert(RoninResolve[blade], 'position anchoring must not issue Stop')
SetUnitPosition=position

-- Priest beam has a separate, reduced damage value rather than full healing damage.
InitGlobals();world={};timers={}
local priest=CreateUnit(Player(0),FourCC('E002'),0,0)
priest.life=500
local beamTarget=CreateUnit(Player(1),FourCC('hfoo'),400,0)
aimX,aimY=800,0
Arena_Priestess_Q(priest,1)
assert(math.abs(beamTarget.life-4849.5)<0.001 and priest.life==715)


-- Killing several creeps with Q must still start the full eight-second cooldown.
InitGlobals();world={};timers={}
local dashHero=CreateUnit(Player(0),FourCC('H003'),0,0)
dashHero.life=500
local fodder1=CreateUnit(Player(1),FourCC('hfoo'),200,0);fodder1.life=50
local fodder2=CreateUnit(Player(1),FourCC('hfoo'),400,0);fodder2.life=50
function SetUnitPathing() end
local actualCooldown
function BlzStartUnitAbilityCooldown(u,id,remaining)
    assert(u==dashHero and id==FourCC('A115'));actualCooldown=remaining
end
function BlzEndUnitAbilityCooldown() error('Q must not reset its cooldown on a kill') end
aimX,aimY=650,0
Arena_Ronin_Q(dashHero,1)
assert(fodder1.life<=0 and fodder2.life<=0 and dashHero.life==530)
local startCooldown=timers[#timers]
assert(startCooldown.delay==0 and not actualCooldown)
startCooldown.callback()
assert(actualCooldown==8)
