-- Advanced party combat systems: active counters, tactical projectiles, status combos.
-- Loaded after 15_combat and before the 48 spell handlers.
local A=Arena
A.roleState={}
A.bleeds={}
A.frostStacks={}
A.doomMarks={}
A.protectionLinks={}
A.staggered={}
A.attackHaste={}
A.lastRolePulse=0
A.scriptDepth=0

local function key(unit) return GetHandleId(unit) end
local function dist(x,y,xx,yy) return (x-xx)^2+(y-yy)^2 end
local function alive(unit) return A.alive(unit) end
local function clamp(n,minimum,maximum) return math.max(minimum,math.min(maximum,n)) end
local function hpFraction(u)
  return GetWidgetLife(u)/math.max(1,GetUnitState(u,UNIT_STATE_MAX_LIFE))
end

function A.role(pid)
  local state=A.roleState[pid]
  if not state then
    state={slashes=0,precision=0,revenge=0,alchemy=0,energy=0}
    A.roleState[pid]=state
  end
  return state
end

function A.findEnemy(caster,x,y,radius,predicate)
  local found=nil
  local best=radius*radius
  A.withUnits(x,y,radius,function(u)
    if A.isEnemy(caster,u) and (not predicate or predicate(u)) then
      local d=dist(x,y,GetUnitX(u),GetUnitY(u))
      if d<best then best=d;found=u end
    end
  end)
  return found
end

function A.findAlly(caster,target,reach)
  if alive(target) and IsUnitAlly(target,GetOwningPlayer(caster))
     and IsUnitType(target,UNIT_TYPE_HERO) then return target end
  return A.lowestAlly(caster,reach or 1100)
end

function A.pickEnemy(caster,target,reach)
  if A.isEnemy(caster,target) then return target end
  return A.closestEnemy(caster,reach or 850)
end

function A.spellCone(caster,reach,degrees,base,school,onHit)
  local x,y=GetUnitX(caster),GetUnitY(caster)
  local facing=math.rad(GetUnitFacing(caster))
  local hits=0
  A.withUnits(x,y,reach,function(u)
    if A.isEnemy(caster,u) then
      local dx,dy=GetUnitX(u)-x,GetUnitY(u)-y
      local angle=math.atan(dy,dx)
      local difference=math.atan(math.sin(angle-facing),math.cos(angle-facing))
      if math.abs(difference)<=math.rad(degrees*.5) then
        A.spellDamage(caster,u,base,school)
        hits=hits+1
        if onHit then onHit(u) end
      end
    end
  end)
  return hits
end

function A.spellRing(caster,x,y,inner,outer,base,school,onHit)
  local hits=0
  A.withUnits(x,y,outer,function(u)
    local d=dist(x,y,GetUnitX(u),GetUnitY(u))
    if A.isEnemy(caster,u) and d>=inner*inner then
      A.spellDamage(caster,u,base,school)
      hits=hits+1
      if onHit then onHit(u) end
    end
  end)
  return hits
end

-- A projectile is resolved at discrete positions; targets are hit only once.
-- It travels in the cast direction instead of doing an instant invisible line AoE.
function A.launchShot(caster,x,y,goalX,goalY,range,speed,width,base,school,onHit,finish)
  local dx,dy=goalX-x,goalY-y
  local length=math.sqrt(dx*dx+dy*dy)
  if length<1 then
    local radians=math.rad(GetUnitFacing(caster))
    dx,dy=math.cos(radians),math.sin(radians)
  else dx,dy=dx/length,dy/length end
  local duration=.10
  local step=speed*duration
  local distance=0
  local seen={}
  local function move()
    if not alive(caster) or distance>=range then
      if finish then finish(x+dx*distance,y+dy*distance) end
      return
    end
    distance=math.min(range,distance+step)
    local xx,yy=x+dx*distance,y+dy*distance
    A.visual([[Abilities\Weapons\Arrow\ArrowMissile.mdl]],xx,yy,.22,.9)
    A.withUnits(xx,yy,width,function(enemy)
      local id=key(enemy)
      if A.isEnemy(caster,enemy) and not seen[id] then
        seen[id]=true
        A.spellDamage(caster,enemy,base,school)
        if onHit then onHit(enemy) end
      end
    end)
    if distance<range then A.after(duration,move)
    elseif finish then finish(xx,yy) end
  end
  move()
end

function A.moveToward(unit,x,y,distance)
  if not alive(unit) then return end
  local ux,uy=GetUnitX(unit),GetUnitY(unit)
  local dx,dy=x-ux,y-uy
  local length=math.sqrt(dx*dx+dy*dy)
  if length<1 then return end
  local move=math.min(length,distance)
  SetUnitPosition(unit,clamp(ux+move*dx/length,-1880,1880),
                       clamp(uy+move*dy/length,-1880,1880))
end

function A.knockAway(caster,target,fromX,fromY,amount)
  if not A.isEnemy(caster,target) or target==A.boss then return end
  local x,y=GetUnitX(target),GetUnitY(target)
  local dx,dy=x-fromX,y-fromY
  local length=math.max(1,math.sqrt(dx*dx+dy*dy))
  SetUnitPosition(target,clamp(x+dx/length*amount,-1880,1880),
                         clamp(y+dy/length*amount,-1880,1880))
end

function A.stunEnemy(caster,target,duration)
  if not A.isEnemy(caster,target) or target==A.boss
     or IsUnitType(target,UNIT_TYPE_HERO) then
    if A.isEnemy(caster,target) then A.slowEnemy(caster,target,.55,duration) end
    return
  end
  local id=key(target)
  local expiry=math.max(A.staggered[id] or 0,A.clock+duration)
  A.staggered[id]=expiry
  PauseUnit(target,true)
  A.visual([[Abilities\Spells\Human\ThunderClap\ThunderClapCaster.mdl]],
       GetUnitX(target),GetUnitY(target),.65)
  A.after(duration,function()
    if A.staggered[id]==expiry and A.clock>=expiry-.04 then
      A.staggered[id]=nil
      if GetUnitTypeId(target)~=0 then PauseUnit(target,false) end
    end
  end)
end

function A.applyBleed(caster,target,count,seconds)
  if not A.isEnemy(caster,target) then return end
  local id=key(target)
  local current=A.bleeds[id]
  local stacks=current and current.expiry>A.clock and current.stacks or 0
  A.bleeds[id]={unit=target,caster=caster,stacks=math.min(6,stacks+(count or 1)),
                expiry=A.clock+(seconds or 7),nextPulse=A.clock+1}
end

function A.bleedCount(target)
  if not target then return 0 end
  local data=A.bleeds[key(target)]
  if not data or data.expiry<=A.clock then return 0 end
  return data.stacks
end

function A.popBleed(caster,target,base)
  local stacks=A.bleedCount(target)
  if stacks>0 then
    if A.removeBleed then A.removeBleed(target) else A.bleeds[key(target)]=nil end
    A.spellDamage(caster,target,base*stacks,"physical")
    A.visual([[Abilities\Spells\Other\Stampede\StampedeMissileDeath.mdl]],
        GetUnitX(target),GetUnitY(target),.6)
  end
  return stacks
end

function A.addFrost(caster,target,stacks)
  if not A.isEnemy(caster,target) then return 0 end
  local id=key(target)
  local previous=A.frostStacks[id]
  local old=previous and previous.expiry>A.clock and previous.stacks or 0
  local amount=old+(stacks or 1)
  if amount>=3 then
    A.frostStacks[id]=nil
    A.stunEnemy(caster,target,1.5)
    A.spellDamage(caster,target,36+GetHeroInt(caster,true)*.4,"magic")
    A.visual([[Abilities\Spells\Undead\FrostNova\FrostNovaTarget.mdl]],
       GetUnitX(target),GetUnitY(target),.9)
    return 3
  end
  A.frostStacks[id]={unit=target,caster=caster,stacks=amount,expiry=A.clock+8}
  A.slowEnemy(caster,target,.28,3)
  return amount
end

function A.haste(unit,amount,duration)
  if not alive(unit) then return end
  local id=key(unit)
  A.buff(unit,"haste",amount,duration)
  if not A.attackHaste[id] then
    A.attackHaste[id]={
      unit=unit,
      move=GetUnitMoveSpeed(unit),
      attack=BlzGetUnitAttackCooldown and BlzGetUnitAttackCooldown(unit,0) or nil
    }
  end
end

function A.protect(protector,ally,portion,duration)
  if not alive(protector) or not alive(ally) or protector==ally then return end
  A.protectionLinks[key(ally)]={protector=protector,ally=ally,
                                portion=math.min(.5,portion),
                                expires=A.clock+duration}
  A.visual([[Abilities\Spells\Human\InnerFire\InnerFireTarget.mdl]],
    GetUnitX(ally),GetUnitY(ally),1.5)
end

function A.refundCooldown(hero,slot,seconds)
  if not alive(hero) then return end
  local pid=GetPlayerId(GetOwningPlayer(hero))
  if pid<0 or pid>3 or A.heroUnits[pid]~=hero then return end
  local ident=A.raw(A.spells[A.heroKind[pid]][slot])
  local keyName=GetHandleId(hero)..":"..ident
  local left=math.max(0,(A.cooldowns[keyName] or 0)-A.clock-seconds)
  A.cooldowns[keyName]=A.clock+left
  if left<=0 then
    if BlzEndUnitAbilityCooldown then BlzEndUnitAbilityCooldown(hero,ident) end
  elseif BlzStartUnitAbilityCooldown then
    BlzStartUnitAbilityCooldown(hero,ident,left)
  end
end

function A.summonGuard(caster,typeId,count,duration,focus)
  for i=1,count do
    local dx,dy=GetRandomReal(-130,130),GetRandomReal(-130,130)
    local u=CreateUnit(GetOwningPlayer(caster),A.raw(typeId),
      GetUnitX(caster)+dx,GetUnitY(caster)+dy,GetUnitFacing(caster))
    if u then
      UnitApplyTimedLife(u,A.raw("BTLF"),duration)
      if focus and alive(focus) then IssueTargetOrder(u,"attack",focus)
      else IssuePointOrder(u,"attack",0,0) end
    end
  end
end

-- Damage event integration: attack modifiers are real, tanks intercept incoming
-- hits and Riposte works on a successful enemy attack. Script spells never
-- trigger the native attack proc a second time.
local oldDamage=A.spellDamage
function A.spellDamage(caster,victim,base,school)
  A.scriptDepth=A.scriptDepth+1
  local ok,result=pcall(oldDamage,caster,victim,base,school)
  A.scriptDepth=A.scriptDepth-1
  if not ok then error(result) end
  return result
end

local oldIncoming=A.modifyIncoming
function A.modifyIncoming(victim,amount)
  local attacker=GetEventDamageSource and GetEventDamageSource() or nil
  local normalAttack=A.scriptDepth==0
    and (not BlzGetEventIsAttack or BlzGetEventIsAttack())
    and (not BlzGetEventDamageType or BlzGetEventDamageType()~=DAMAGE_TYPE_MAGIC)
  if normalAttack and alive(attacker) then
    amount=amount*(1+A.statusValue(attacker,"physicalAmp"))
    local pid=GetPlayerId(GetOwningPlayer(attacker))
    local state=pid>=0 and pid<=3 and A.roleState[pid] or nil
    if state and A.heroUnits[pid]==attacker then
      if A.heroKind[pid]==5 and A.statusValue(attacker,"felForm")>0 then
        local life=amount*.14
        A.after(.02,function()if alive(attacker) then A.heal(attacker,life) end end)
      elseif A.heroKind[pid]==11 then
        state.precision=math.min(5,(state.precision or 0)+1)
      end
    end
  end
  local output=oldIncoming(victim,amount)
  local id=key(victim)
  local link=A.protectionLinks[id]
  if link and link.expires>A.clock and alive(link.protector)
     and dist(GetUnitX(victim),GetUnitY(victim),
              GetUnitX(link.protector),GetUnitY(link.protector))<850^2 then
    local absorbed=math.max(0,output)*link.portion
    local protector=link.protector
    output=output-absorbed
    A.after(.03,function()
      if alive(protector) then
        SetWidgetLife(protector,math.max(1,GetWidgetLife(protector)-absorbed))
        local playerId=GetPlayerId(GetOwningPlayer(protector))
        if playerId>=0 and playerId<=3 and A.heroKind[playerId]==1 then
          local state=A.role(playerId)
          A.resources[playerId].valor=math.min(100,(A.resources[playerId].valor or 0)+3)
        end
      end
    end)
  end
  local attackedHero=GetPlayerId(GetOwningPlayer(victim))
  if attackedHero>=0 and attackedHero<=3 and A.heroUnits[attackedHero]==victim then
    local state=A.role(attackedHero)
    local parry=state.parry
    if parry and parry>A.clock and alive(attacker) and A.isEnemy(victim,attacker)
       and normalAttack then
      output=output*.15
      state.parry=0
      A.after(.04,function()
        if alive(victim) and alive(attacker) then
          A.spellDamage(victim,attacker,35+GetHeroStr(victim,true)*1.0,"physical")
          if A.heroKind[attackedHero]==2 then
            A.resources[attackedHero].combo=math.min(100,
              (A.resources[attackedHero].combo or 0)+25)
            A.refundCooldown(victim,4,6+2*math.max(1,GetUnitAbilityLevel(victim,A.raw("A10F"))))
            A.playerText(attackedHero,"|cffffaa55Парирование! Танец барханов: -"..(6+2*math.max(1,GetUnitAbilityLevel(victim,A.raw("A10F")))).." сек.|r")
          end
        end
      end)
    end
    if state.stoneExpires and state.stoneExpires>A.clock and output>0 then
      state.stoneCount=(state.stoneCount or 0)+1
      if state.stoneCount>=3 then
        state.stoneCount=0
        A.after(.04,function()
          if alive(victim) then
            A.spellArea(victim,GetUnitX(victim),GetUnitY(victim),320,
              40+GetHeroStr(victim,true)*.45,"physical",
              function(u) A.stunEnemy(victim,u,.65) end)
          end
        end)
      end
    end
    if A.heroKind[attackedHero]==1 and output>0 then
    end
  end
  return output
end

function A.onRoleEnemyDeath(unit,killer,elite)
  local id=key(unit)
  local x,y=GetUnitX(unit),GetUnitY(unit)
  local curse=A.doomMarks[id]
  if curse and curse.expires>A.clock and alive(curse.caster) then
    local pid=curse.pid
    A.resources[pid].souls=math.min(100,(A.resources[pid].souls or 0)+(elite and 23 or 13))
    A.visual([[Abilities\Spells\Undead\AnimateDead\AnimateDeadTarget.mdl]],x,y,1.2)
    A.spellArea(curse.caster,x,y,270,curse.power*.8,"magic")
    A.doomMarks[id]=nil
  end
  local bleed=A.bleeds[id]
  if bleed and bleed.expiry>A.clock and alive(bleed.caster) then
    local pid=GetPlayerId(GetOwningPlayer(bleed.caster))
    if pid>=0 and pid<=3 and A.heroKind[pid]==2 then
      A.resources[pid].combo=math.min(100,(A.resources[pid].combo or 0)+10)
      A.refundCooldown(bleed.caster,1,2)
    end
  end
  if A.removeBleed then A.removeBleed(unit) else A.bleeds[id]=nil end
  A.frostStacks[id]=nil
  A.boneMarks[id]=nil
  A.fractures[id]=nil
end

local function roleTick()
  if A.clock-A.lastRolePulse<.24 then return end
  A.lastRolePulse=A.clock
  for id,haste in pairs(A.attackHaste) do
    if not alive(haste.unit) then A.attackHaste[id]=nil
    else
      local strength=A.statusValue(haste.unit,"haste")
      if strength==0 then
        SetUnitMoveSpeed(haste.unit,haste.move)
        if haste.attack and BlzSetUnitAttackCooldown then
          BlzSetUnitAttackCooldown(haste.unit,haste.attack,0)
        end
        A.attackHaste[id]=nil
      else
        SetUnitMoveSpeed(haste.unit,math.min(522,haste.move*(1+strength)))
        if haste.attack and BlzSetUnitAttackCooldown then
          BlzSetUnitAttackCooldown(haste.unit,haste.attack/(1+strength),0)
        end
      end
    end
  end
  for id,bleed in pairs(A.bleeds) do
    if not alive(bleed.unit) or not alive(bleed.caster) or bleed.expiry<=A.clock then
      if A.removeBleed then A.removeBleed(bleed.unit) else A.bleeds[id]=nil end
    elseif bleed.nextPulse<=A.clock then
      bleed.nextPulse=A.clock+1
      A.spellDamage(bleed.caster,bleed.unit,(12+5*(bleed.rank or 1))*bleed.stacks,"physical")
    end
  end
  for id,frost in pairs(A.frostStacks) do
    if not alive(frost.unit) or frost.expiry<=A.clock then A.frostStacks[id]=nil end
  end
  for id,link in pairs(A.protectionLinks) do
    if link.expires<=A.clock or not alive(link.ally) or not alive(link.protector) then
      A.protectionLinks[id]=nil
    end
  end
  for id,mark in pairs(A.doomMarks) do
    if mark.expires<=A.clock or not alive(mark.caster) then A.doomMarks[id]=nil end
  end
  -- Force temporary walls to stay tactical even when enemies enter their segment.
  for pid=0,3 do
    local state=A.roleState[pid]
    local caster=A.heroUnits[pid]
    if state and alive(caster) then
      if state.rift and state.rift.expires>A.clock
         and state.rift.next<=A.clock then
        state.rift.next=A.clock+.6
        local r=state.rift
        A.spellArea(caster,r.x,r.y,210,r.power,"magic",
          function(enemy)A.slowEnemy(caster,enemy,.32,1.2)end)
      end
      if state.storm and state.storm.expires>A.clock
         and state.storm.next<=A.clock then
        state.storm.next=A.clock+.75
        local s=state.storm
        local enemy=A.findEnemy(caster,s.x,s.y,600)
        if enemy then
          A.spellDamage(caster,enemy,s.power,"magic")
          A.visual([[Abilities\Spells\Orc\LightningShield\LightningShieldTarget.mdl]],
            GetUnitX(enemy),GetUnitY(enemy),.8)
          A.resources[pid].storm=math.min(100,(A.resources[pid].storm or 0)+3)
        end
      end
      if state.bloom and state.bloom.expires>A.clock
         and state.bloom.next<=A.clock then
        state.bloom.next=A.clock+.95
        local s=state.bloom
        A.forAllies(caster,nil,function(ally)
          if dist(s.x,s.y,GetUnitX(ally),GetUnitY(ally))<s.radius^2 then
            A.spellHeal(caster,ally,s.power)
          end
        end)
        A.visual([[Abilities\Spells\NightElf\Tranquility\TranquilityTarget.mdl]],
           s.x,s.y,1.0)
      end
      if state.frostWall and state.frostWall.expires>A.clock
         and state.frostWall.next<=A.clock then
        state.frostWall.next=A.clock+.5
        local wall=state.frostWall
        local vx,vy=wall.dx,wall.dy
        local x,y=wall.x,wall.y
        A.withUnits(x,y,630,function(enemy)
          if A.isEnemy(caster,enemy) then
            local px,py=GetUnitX(enemy)-x,GetUnitY(enemy)-y
            local along=math.abs(px*vx+py*vy)
            local across=math.abs(px*vy-py*vx)
            if along<=420 and across<90 then
              A.addFrost(caster,enemy,1)
              A.knockAway(caster,enemy,x,y,80)
            end
          end
        end)
      end
      if state.mines then
        for index=#state.mines,1,-1 do
          local mine=state.mines[index]
          if mine.expires<=A.clock then
            table.remove(state.mines,index)
          else
            local trigger=A.findEnemy(caster,mine.x,mine.y,135)
            if trigger then
              A.visualRing([[Abilities\Spells\Other\Doom\DoomDeath.mdl]],
                 mine.x,mine.y,200,5,1)
              A.spellArea(caster,mine.x,mine.y,290,mine.power,"magic",
                 function(u)A.slowEnemy(caster,u,.40,3)end)
              table.remove(state.mines,index)
            end
          end
        end
      end
    end
  end
end

local previous=A.tickCombat
function A.tickCombat()
  previous()
  roleTick()
end
