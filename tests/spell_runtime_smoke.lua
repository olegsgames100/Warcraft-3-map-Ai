-- Runtime smoke test for role abilities without Warcraft III client.
local units={}
local function unit(pid,x,y,hero) local v={pid=pid,x=x,y=y,hp=4000,mana=5000,level=5,hero=hero~=false,alive=true};units[#units+1]=v;return v end
function Player(i)return i end
function FourCC(s)return s end
function GetPlayerId(i)return i end
PLAYER_STATE_RESOURCE_GOLD="gold"
function GetPlayerState(p,stat)return 500 end
function SetPlayerState(p,stat,amount)assert(amount>=0)end
function GetOwningPlayer(u)return u.pid end
function GetHandleId(u)return type(u)=="table" and tostring(u) or tostring(u) end
function GetUnitTypeId(u)return u and u.alive and 1 or 0 end
function GetWidgetLife(u)return u.hp end
function SetWidgetLife(u,n)u.hp=n end
function GetUnitState(u,s)if s=="hp" then return 4000 elseif s=="mp" then return 5000 else return u.mana end end
function SetUnitState(u,s,val)u.mana=val end
function GetHeroStr(u)return u.str or 40 end
function GetHeroInt(u)return u.int or 40 end
function GetHeroLevel(u)return u.level end
function GetUnitAbilityLevel(u,id)return 1 end
function GetUnitX(u)return u.x end
function GetUnitY(u)return u.y end
function GetUnitFacing(u)return 0 end
function GetUnitMoveSpeed(u)return 300 end
function SetUnitMoveSpeed(u,speed)u.speed=speed end
function BlzGetUnitArmor(u)return u.armor or 5 end
function BlzSetUnitArmor(u,v)u.armor=v end
function SetUnitPosition(u,x,y)u.x=x;u.y=y end
function GetRandomReal(a,b)return (a+b)*.5 end
function GetSpellTargetX()return 320 end
function GetSpellTargetY()return 0 end
function GetSpellTargetUnit()return nil end
function IsUnitEnemy(u,pid)return u.pid~=pid end
function IsUnitAlly(u,pid)return u.pid==pid end
function IsUnitType(u,t)return u.hero end
function IssueImmediateOrder()end
function IssueTargetOrder()end
function IssuePointOrder()end
function PauseUnit()end
function CreateUnit(pid,id,x,y)return unit(pid,x,y,false) end
function UnitApplyTimedLife()end
function ReviveHero(u,x,y)u.alive=true;u.hp=2200;u.x=x;u.y=y end
function GetUnitState(u,s)if s=="hp" then return 4000 elseif s=="mp" then return 5000 end return 5000 end
UNIT_STATE_MAX_LIFE="hp"
UNIT_STATE_MAX_MANA="mp"
UNIT_STATE_MANA="mana"
UNIT_TYPE_STRUCTURE="structure"
UNIT_TYPE_HERO="hero"
ATTACK_TYPE_NORMAL=1
ATTACK_TYPE_MAGIC=2
DAMAGE_TYPE_NORMAL=1
DAMAGE_TYPE_MAGIC=2
WEAPON_TYPE_WHOKNOWS=0
function UnitDamageTarget(c,t,amount)assert(amount>0 and amount<1e8);t.hp=t.hp-amount;_G.damageCount=_G.damageCount+1 end
function CreateGroup()return {} end
function GroupEnumUnitsInRange(g,x,y,r)for _,u in ipairs(units)do if u.alive and (u.x-x)^2+(u.y-y)^2<=r*r then g[#g+1]=u end end end
function FirstOfGroup(g)return g[1] end
function GroupRemoveUnit(g,u)for i,v in ipairs(g)do if v==u then table.remove(g,i);return end end end
function DestroyGroup()end
function AddSpecialEffect()return {} end
function BlzSetSpecialEffectScale()end
function DestroyEffect()end
function BlzStartUnitAbilityCooldown()end
function DisplayTimedTextToPlayer()end
function GetPlayerName(p)return tostring(p) end
function CreateTextTag()return {} end
function SetTextTagText()end
function SetTextTagPos()end
function SetTextTagColor()end
function SetTextTagPermanent()end
function SetTextTagLifespan()end
function SetTextTagFadepoint()end
local now=0
local pending={}
function CreateTimer()return {} end
function TimerStart(t,delay,repeatFlag,callback)pending[#pending+1]={due=now+delay,fn=callback} end
function DestroyTimer()end
local function advance(t)
  while true do
    local earliest=nil;local index=nil
    for k,v in ipairs(pending)do if v.due<=t and (not earliest or v.due<earliest.due) then earliest=v;index=k end end
    if not earliest then break end
    table.remove(pending,index)
    now=earliest.due
    Arena.clock=now
    earliest.fn()
  end
  now=t;Arena.clock=t
end
dofile("lua/map/00_core.lua")
dofile("lua/map/10_heroes.lua")
dofile("lua/map/15_combat.lua")
dofile("lua/map/16_role_mechanics.lua")
dofile("lua/map/17_arbiter.lua")
dofile("lua/map/18_blood_valor.lua")
dofile("lua/map/21_spell_meta.lua")
dofile("lua/map/22_spell_events.lua")
dofile("lua/map/27_rebuilt_spells.lua")
damageCount=0
for kind=1,12 do
  units={}
  pending={}
  local hero=unit(0,0,0);hero.str=42;hero.int=42
  local enemy=unit(5,310,0,false)
  local friend=unit(0,90,10);friend.hp=1700
  Arena.heroUnits={[0]=hero,[1]=friend}
  Arena.heroKind={[0]=kind,[1]=6}
  Arena.resources={[0]={valor=40,combo=50,storm=45,souls=30,fury=45,moon=40},
                     [1]={}}
  Arena.cooldowns={}
  Arena.roleState={}
  Arena.statuses={}
  Arena.clock=0
  now=0
  for slot,id in ipairs(Arena.spells[kind]) do
    local before=damageCount
    local ok,err=pcall(Arena.castHero,hero,id,{x=kind==1 and slot==3 and 90 or 310,y=0,target=kind==1 and slot==3 and friend or enemy})
    assert(ok,"hero "..kind.." slot "..slot.." broke: "..tostring(err))
    advance(now+2)
    assert(Arena.cooldowns[GetHandleId(hero)..":"..id],"missing cooldown "..kind.."/"..slot)
    print("OK HERO",kind,"SLOT",slot,"damage",damageCount-before)
  end
end
print("48 role abilities executed successfully in mocked Lua runtime")
