-- Active combat feedback: bleed armor reduction, a clear Valor-only guardian resource.
local A=Arena
A.bleedArmor={}
function A.removeBleed(unit)
  if not unit then return end
  local id=GetHandleId(unit)
  local armor=A.bleedArmor[id] or 0
  if armor>0 and GetUnitTypeId(unit)~=0 then
    BlzSetUnitArmor(unit,BlzGetUnitArmor(unit)+armor)
  end
  A.bleedArmor[id]=nil
  A.bleeds[id]=nil
end
local oldBleed=A.applyBleed
function A.applyBleed(caster,unit,count,duration)
  if not A.isEnemy(caster,unit) then return end
  oldBleed(caster,unit,count,duration)
  local id=GetHandleId(unit)
  local status=A.bleeds[id]
  if not status then return end
  status.rank=math.max(1,GetUnitAbilityLevel(caster,A.raw("A104")))
  status.nextDisplay=A.clock
  local desired=status.stacks
  local old=A.bleedArmor[id] or 0
  if desired~=old then
    BlzSetUnitArmor(unit,BlzGetUnitArmor(unit)-(desired-old))
    A.bleedArmor[id]=desired
  end
  A.text(GetUnitX(unit),GetUnitY(unit),"|cffff4455КРОВЬ "..desired.."/6  БРОНЯ -"..desired.."|r",.024,1.6)
  A.visual([[Abilities\Spells\Other\Stampede\StampedeMissileDeath.mdl]],GetUnitX(unit),GetUnitY(unit),.55)
end
local oldPop=A.popBleed
function A.popBleed(caster,unit,base)
  local amount=A.bleedCount(unit)
  if amount>0 then
    A.removeBleed(unit)
    A.spellDamage(caster,unit,base*amount,"physical")
    A.text(GetUnitX(unit),GetUnitY(unit),"|cffff7777РАЗРЫВ "..amount.." МЕТОК!|r",.027,1.8)
  end
  return amount
end
local previousIncoming=A.modifyIncoming
function A.modifyIncoming(unit,damage)
  local attacker=GetEventDamageSource and GetEventDamageSource() or nil
  local normal=A.scriptDepth==0 and (not BlzGetEventIsAttack or BlzGetEventIsAttack())
  if normal and A.alive(attacker) and A.isEnemy(attacker,unit) then
    local pid=GetPlayerId(GetOwningPlayer(attacker))
    if pid>=0 and pid<=3 and A.heroUnits[pid]==attacker and A.heroKind[pid]==2 then
      if GetUnitAbilityLevel(attacker,A.raw("A104"))>0 then A.applyBleed(attacker,unit,1,8) end
    end
  end
  local output=previousIncoming(unit,damage)
  if A.alive(unit) then
    local pid=GetPlayerId(GetOwningPlayer(unit))
    if pid>=0 and pid<=3 and A.heroKind[pid]==1 and A.heroUnits[pid]==unit then
      local valor=(A.resources[pid] and A.resources[pid].valor or 0)
      output=output*(1-.001*valor)
    end
  end
  return output
end
local oldDamage=A.spellDamage
function A.spellDamage(caster,victim,base,school)
  local pid=GetPlayerId(GetOwningPlayer(caster))
  if school=="physical" and pid>=0 and pid<=3 and A.heroUnits[pid]==caster and A.heroKind[pid]==1 then
    base=base*(1+.003*(A.resources[pid].valor or 0))
  end
  return oldDamage(caster,victim,base,school)
end
local prevTick=A.tickCombat
function A.tickCombat()
  prevTick()
  for id,data in pairs(A.bleeds) do
    if not A.alive(data.unit) or not A.alive(data.caster) or data.expiry<=A.clock then
      A.removeBleed(data.unit)
    else
      if (data.nextDisplay or 0)<=A.clock then
        data.nextDisplay=A.clock+1.4
        A.text(GetUnitX(data.unit),GetUnitY(data.unit),"|cffff5555КРОВОТЕЧЕНИЕ "..data.stacks.."/6, -"..data.stacks.." брони|r",.019,1.6)
      end
    end
  end
end
