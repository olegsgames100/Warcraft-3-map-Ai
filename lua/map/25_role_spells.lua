-- Reforged role kits: 12 heroes, four actions each. All offensive casts use typed scaling.
local A=Arena
local function base(rank) return 26+rank*21 end
local function add(pid,key,amount) A.resources[pid][key]=math.min(100,(A.resources[pid][key] or 0)+amount) end
local function take(pid,key) local n=A.resources[pid][key] or 0; A.resources[pid][key]=0;return n end
local function hit(h,r,b,s) return A.spellArea(h,GetUnitX(h),GetUnitY(h),r,b,s) end
local function nuke(h,t,b,s)
  if A.isEnemy(h,t) then A.spellDamage(h,t,b,s);return t end
  local enemy=A.closestEnemy(h,850)
  if enemy then A.spellDamage(h,enemy,b,s) end
  return enemy
end
local function healTeam(h,r,b)
  A.forAllies(h,r,function(u) A.spellHeal(h,u,b) end)
end
local function shieldTeam(h,r,b,d)
  A.forAllies(h,r,function(u) A.addShield(u,b,d) end)
end
local function pulse(h,x,y,r,d,i,b,s,onHit) A.spellZone(h,x,y,r,d,i,b,s,onHit) end
local function visual(h,x,y,slot,kind)
  local style=A.visualCatalog and A.visualCatalog[kind]
  local fx=style and style[slot==4 and 2 or 1] or [[Abilities\Spells\Human\ThunderClap\ThunderClapCaster.mdl]]
  A.visual(fx,x,y,1.5)
  if slot==4 then A.visualRing(fx,x,y,340,10,2) end
end
function A.castHero(hero,ability)
  local pid=GetPlayerId(GetOwningPlayer(hero))
  if pid<0 or pid>3 or A.heroUnits[pid]~=hero then return false end
  local kind=A.heroKind[pid]
  local slot
  for k,id in ipairs(A.spells[kind]) do if A.raw(id)==ability then slot=k;break end end
  if not slot then return false end
  local rank=math.max(1,math.min(5,GetUnitAbilityLevel(hero,ability)))
  local key=GetHandleId(hero)..":"..ability
  local spell=A.spellDetails[kind][slot]
  local cooldown=spell.cooldown
  local untilTime=A.cooldowns[key] or 0
  if untilTime>A.clock then
    A.playerText(pid,string.format("Перезарядка: %.1f сек.",untilTime-A.clock))
    return true
  end
  A.cooldowns[key]=A.clock+cooldown
  if BlzStartUnitAbilityCooldown then BlzStartUnitAbilityCooldown(hero,ability,cooldown) end
  local b=base(rank)
  local hx,hy=GetUnitX(hero),GetUnitY(hero)
  local target=GetSpellTargetUnit()
  local x,y=GetSpellTargetX(),GetSpellTargetY()
  if x==0 and y==0 then x,y=hx,hy end
  visual(hero,x,y,slot,kind)
  if kind==1 then -- dedicated main tank
    if slot==1 then A.spellLine(hero,530,165,b*1.15,"physical");A.taunt(hero,580);add(pid,"valor",16)
    elseif slot==2 then
      shieldTeam(hero,650,b*3.5,9)
      A.forAllies(hero,650,function(u) A.buff(u,"resist",.2,9) end)
      A.taunt(hero,660)
    elseif slot==3 then
      A.spellDash(hero,350,170,b*1.2,"physical")
      A.addShield(A.lowestAlly(hero,750),b*4,7)
      add(pid,"valor",12)
    else
      local valor=take(pid,"valor")
      for k=0,3 do
        local u=A.heroUnits[k]
        if u and IsUnitAlly(u,GetOwningPlayer(hero)) then
          if not A.alive(u) then ReviveHero(u,hx,hy,true) end
          A.spellHeal(hero,u,b*3+valor*2)
          A.addShield(u,b*2,8)
        end
      end
      hit(hero,620,b*1.3,"magic")
    end
  elseif kind==2 then -- melee damage assassin, combo
    if slot==1 then A.spellDash(hero,360,130,b*1.5,"physical");add(pid,"combo",18)
    elseif slot==2 then pulse(hero,hx,hy,350,4,.5,b*.65+(A.resources[pid].combo or 0)*.3,"physical");add(pid,"combo",13)
    elseif slot==3 then
      for i=1,3 do A.after(i*.22,function()if A.alive(hero) then nuke(hero,target,b*.9,"physical") end end) end
      A.buff(hero,"resist",.25,3);add(pid,"combo",12)
    else pulse(hero,hx,hy,460,5,.35,b*.8+take(pid,"combo")*1.8,"physical") end
  elseif kind==3 then -- ranged wizard
    if slot==1 then
      local seen={}
      for i=1,4 do
        local best,dist=nil,1e12
        A.withUnits(x,y,620,function(u)
          if A.isEnemy(hero,u) and not seen[GetHandleId(u)] then
            local d=(GetUnitX(u)-x)^2+(GetUnitY(u)-y)^2
            if d<dist then best,dist=u,d end
          end
        end)
        if best then seen[GetHandleId(best)]=true;A.spellDamage(hero,best,b*.9,"magic");x,y=GetUnitX(best),GetUnitY(best) end
      end
      add(pid,"storm",16)
    elseif slot==2 then pulse(hero,x,y,365,6,.6,b*.5,"magic");add(pid,"storm",16)
    elseif slot==3 then
      local charges=take(pid,"storm")
      A.forAllies(hero,nil,function(u)
        A.mana(u,b*1.5+charges)
        A.buff(u,"spellAmp",.15,9)
      end)
    else
      local charges=take(pid,"storm")
      for i=1,3 do
        A.after(i*.7,function()if A.alive(hero) then
          A.spellArea(hero,x,y,620,b*1.6+charges*.7,"magic")
          A.visualRing([[Abilities\Spells\Orc\LightningShield\LightningShieldTarget.mdl]],x,y,250,8,1)
        end end)
      end
    end
  elseif kind==4 then -- necromantic off tank
    if slot==1 then
      local enemy=nuke(hero,target,b*1.4,"magic")
      if enemy then A.marks[GetHandleId(enemy)]={soulOwner=pid,untilTime=A.clock+10} end
    elseif slot==2 then A.summon(hero,"uske",3+math.floor(rank/2),18+rank);A.taunt(hero,450);A.addShield(hero,b*2,8)
    elseif slot==3 then
      hit(hero,380,b*1.25,"magic");A.spellHeal(hero,A.lowestAlly(hero,700),b*2.6);add(pid,"souls",12)
    else
      local souls=take(pid,"souls")
      A.summon(hero,"uske",4+math.floor(souls/18),27)
      hit(hero,500,b*1.1+souls*.5,"magic")
      shieldTeam(hero,620,b*1.5,8)
    end
  elseif kind==5 then -- mobile bruiser
    if slot==1 then A.spellDash(hero,350,165,b*1.6,"physical");add(pid,"fury",18)
    elseif slot==2 then hit(hero,430,b*1.2,"magic");A.mana(hero,b*2);A.spellHeal(hero,hero,b*.9);add(pid,"fury",12)
    elseif slot==3 then A.spellTrap(hero,x,y,2.0,340,b*1.8,"magic",function(u)A.slowEnemy(hero,u,.35,4)end);add(pid,"fury",12)
    else
      local fury=take(pid,"fury")
      A.buff(hero,"physicalAmp",.25+fury*.003,10)
      A.buff(hero,"resist",.24,10)
      pulse(hero,hx,hy,420,8,.8,b*.75+fury*.4,"physical")
      A.spellHeal(hero,hero,b*2)
    end
  elseif kind==6 then -- heal, don't try to deal damage
    if slot==1 then A.spellHeal(hero,A.lowestAlly(hero,1000),b*3.2)
    elseif slot==2 then A.healZone(hero,x,y,545,9,.75,b*.9)
    elseif slot==3 then
      local weak=A.lowestAlly(hero,750)
      A.addShield(weak,b*5,9)
      A.buff(weak,"resist",.3,9)
      A.spellHeal(hero,weak,b*.8)
    else
      for k=0,3 do
        local ally=A.heroUnits[k]
        if ally and IsUnitAlly(ally,GetOwningPlayer(hero)) then
          if not A.alive(ally) then ReviveHero(ally,hx,hy,true) end
          A.spellHeal(hero,ally,b*4)
          A.buff(ally,"spellAmp",.25,12)
        end
      end
    end
  elseif kind==7 then -- team buffer
    if slot==1 then A.forAllies(hero,nil,function(u)A.buff(u,"physicalAmp",.22,11);A.buff(u,"haste",.2,11) end)
    elseif slot==2 then pulse(hero,x,y,355,7,.7,b*.52,"magic",function(u)A.buff(u,"vulnerable",.2,5)end)
    elseif slot==3 then A.forAllies(hero,nil,function(u)A.mana(u,b*2.2);A.buff(u,"spellAmp",.23,10)end)
    else
      A.forAllies(hero,nil,function(u)
        A.buff(u,"physicalAmp",.32,12);A.buff(u,"spellAmp",.32,12)
        A.addShield(u,b*3,12);A.spellHeal(hero,u,b*1.8)
      end)
    end
  elseif kind==8 then -- mountain king battlefield control
    if slot==1 then A.spellLine(hero,580,200,b*1.45,"physical",function(u)A.slowEnemy(hero,u,.35,3)end)
    elseif slot==2 then
      A.withUnits(hx,hy,590,function(u)if A.isEnemy(hero,u) then
        SetUnitPosition(u,hx+GetRandomReal(-110,110),hy+GetRandomReal(-110,110))
        A.spellDamage(hero,u,b*.7,"physical")
      end end)
      A.taunt(hero,600)
    elseif slot==3 then A.addShield(hero,b*6,10);A.buff(hero,"resist",.35,10);A.spellHeal(hero,hero,b*1.3)
    else
      pulse(hero,hx,hy,600,6,.6,b*1.0,"physical",function(u)A.slowEnemy(hero,u,.45,2)end)
      A.taunt(hero,660)
    end
  elseif kind==9 then -- single target execution
    if slot==1 then A.spellDash(hero,400,140,b*1.55,"physical")
    elseif slot==2 then
      local enemy=nuke(hero,target,b*.7,"physical")
      if enemy then A.marks[GetHandleId(enemy)]={warden=pid,untilTime=A.clock+9};A.buff(enemy,"vulnerable",.2,9) end
    elseif slot==3 then A.addShield(hero,b*2.4,5);A.buff(hero,"resist",.4,5);hit(hero,340,b*.8,"physical")
    else
      local enemy=A.isEnemy(hero,target) and target or A.closestEnemy(hero,660)
      if enemy then
        local mark=A.marks[GetHandleId(enemy)]
        local missing=1-GetWidgetLife(enemy)/math.max(1,GetUnitState(enemy,UNIT_STATE_MAX_LIFE))
        local bonus=mark and mark.warden==pid and mark.untilTime>A.clock and 1.7 or 1.0
        A.spellDamage(hero,enemy,b*(2+missing*3)*bonus,"physical")
      end
    end
  elseif kind==10 then -- frost control ranged wizard
    if slot==1 then A.spellLine(hero,760,130,b*1.55,"magic",function(u)A.slowEnemy(hero,u,.3,3)end)
    elseif slot==2 then A.spellArea(hero,hx,hy,460,b*.85,"magic",function(u)A.rootEnemy(hero,u,2.2)end)
    elseif slot==3 then pulse(hero,x,y,480,7,.7,b*.52,"magic",function(u)A.slowEnemy(hero,u,.3,2)end)
    else pulse(hero,hx,hy,750,9,.5,b*.8,"magic",function(u)A.rootEnemy(hero,u,1.2)end)
    end
  elseif kind==11 then -- AVАLS: bone archer who supports Gelo
    local gelo=A.allyOfKind(12,hero)
    if slot==1 then
      local resonance=(A.boneBlessing[pid] or 0)>A.clock and 1.75 or 1
      A.boneBlessing[pid]=nil
      A.spellLine(hero,900,110,b*1.6*resonance,"physical",function(u)A.markBone(hero,u,9)end)
    elseif slot==2 then
      pulse(hero,x,y,480,6,.5,b*(gelo and 1.0 or .75),"physical",function(u)A.markBone(hero,u,9)end)
    elseif slot==3 then
      A.buff(hero,"physicalAmp",.32,10)
      if gelo then A.addShield(gelo,b*3,9);A.buff(gelo,"physicalAmp",.12,9) end
    else
      pulse(hero,hx,hy,690,6,.45,b*1.0,"physical",function(u)A.markBone(hero,u,9)end)
      A.recordTwinUltimate(hero,11,b)
    end
  elseif kind==12 then -- GELO: melee skeleton who detonates Avals's marks
    local avals=A.allyOfKind(11,hero)
    if slot==1 then
      A.spellLine(hero,480,185,b*1.4,"physical",function(u)
        if A.consumeBone(hero,u) then A.spellDamage(hero,u,b*2.0,"physical") end
      end)
    elseif slot==2 then
      A.taunt(hero,550);A.addShield(hero,b*5,9)
      if avals then A.addShield(avals,b*4.5,9);A.buff(avals,"resist",.3,9) end
    elseif slot==3 then
      A.spellDash(hero,390,185,b*1.5,"physical",function(u)
        if A.consumeBone(hero,u) then A.spellDamage(hero,u,b*1.6,"physical") end
      end)
      if avals then A.boneBlessing[GetPlayerId(GetOwningPlayer(avals))]=A.clock+9 end
    else
      pulse(hero,hx,hy,550,6,.6,b*1.0,"physical",function(u)A.slowEnemy(hero,u,.4,3)end)
      A.summon(hero,"uske",3+math.floor(rank/2),20)
      A.recordTwinUltimate(hero,12,b)
    end
  end
  return true
end

-- Spell metadata used by runtime cooldowns; generated in the same sequence as war3map.w3a.
A.spellDetails={
  {{cooldown=7,mana=28,school="physical"},{cooldown=18,mana=44,school="magic"},{cooldown=13,mana=36,school="physical"},{cooldown=60,mana=115,school="magic"}},
  {{cooldown=6,mana=22,school="physical"},{cooldown=12,mana=32,school="physical"},{cooldown=16,mana=38,school="physical"},{cooldown=46,mana=105,school="physical"}},
  {{cooldown=7,mana=28,school="magic"},{cooldown=15,mana=42,school="magic"},{cooldown=17,mana=36,school="magic"},{cooldown=50,mana=120,school="magic"}},
  {{cooldown=8,mana=25,school="magic"},{cooldown=19,mana=42,school="magic"},{cooldown=13,mana=38,school="magic"},{cooldown=52,mana=110,school="magic"}},
  {{cooldown=6,mana=24,school="physical"},{cooldown=12,mana=34,school="magic"},{cooldown=16,mana=40,school="magic"},{cooldown=49,mana=105,school="physical"}},
  {{cooldown=5,mana=24,school="heal"},{cooldown=17,mana=44,school="heal"},{cooldown=16,mana=39,school="heal"},{cooldown=60,mana=120,school="heal"}},
  {{cooldown=12,mana=28,school="buff"},{cooldown=15,mana=39,school="magic"},{cooldown=18,mana=36,school="buff"},{cooldown=54,mana=110,school="buff"}},
  {{cooldown=7,mana=26,school="physical"},{cooldown=17,mana=36,school="physical"},{cooldown=22,mana=38,school="buff"},{cooldown=55,mana=115,school="physical"}},
  {{cooldown=6,mana=24,school="physical"},{cooldown=11,mana=31,school="physical"},{cooldown=18,mana=35,school="physical"},{cooldown=42,mana=110,school="physical"}},
  {{cooldown=7,mana=26,school="magic"},{cooldown=17,mana=40,school="magic"},{cooldown=18,mana=40,school="magic"},{cooldown=53,mana=125,school="magic"}},
  {{cooldown=6,mana=25,school="physical"},{cooldown=15,mana=40,school="physical"},{cooldown=18,mana=32,school="buff"},{cooldown=49,mana=115,school="physical"}},
  {{cooldown=7,mana=25,school="physical"},{cooldown=18,mana=42,school="buff"},{cooldown=13,mana=35,school="physical"},{cooldown=52,mana=115,school="physical"}}
}
