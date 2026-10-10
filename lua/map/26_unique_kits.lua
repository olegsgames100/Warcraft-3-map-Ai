-- Distinct 12-class ability kits. Overrides first-pass generic QWER handlers.
local A=Arena
local function power(rank) return 32+rank*22 end
local function state(pid) return A.role(pid) end
local function resource(pid,key,change)
  local previous=A.resources[pid][key] or 0
  if change=="consume" then A.resources[pid][key]=0;return previous end
  A.resources[pid][key]=math.min(100,previous+change)
  return previous
end
local function targetEnemy(h,target) return A.pickEnemy(h,target,950) end
local function center(h) return GetUnitX(h),GetUnitY(h) end
local function allyHeal(h,radius,base)
  A.forAllies(h,radius,function(u)A.spellHeal(h,u,base)end)
end
local function otherHeroes(h,fn)
  A.forAllies(h,nil,fn)
end
local function enemyIn(c,x,y,r,fn)
  A.withUnits(x,y,r,function(u)if A.isEnemy(c,u) then fn(u) end end)
end
local function killShot(h,target,base,multiplier)
  if target and A.isEnemy(h,target) then
    A.spellDamage(h,target,base*multiplier,"physical")
  end
end
local function cast(h,pid,kind,slot,rank,target,x,y,b)
  local s=state(pid)
  local hx,hy=center(h)
  local fx=A.visual
  if kind==1 then -- Reynar: oath-bonded guardian with stored absorbed damage
    if slot==1 then
      local hits=A.spellCone(h,520,110,b*1.3,"physical")
      A.taunt(h,600)
      resource(pid,"valor",hits>0 and 18 or 7)
      s.resolve=math.min(700,(s.resolve or 0)+hits*b*.15)
    elseif slot==2 then
      otherHeroes(h,function(u)
        if u~=h then
          A.protect(h,u,.32,9)
          A.addShield(u,b*2.2,9)
        else A.addShield(h,b*3.5,9) end
      end)
      A.taunt(h,610)
      fx([[Abilities\Spells\Human\DivineShield\DivineShieldTarget.mdl]],hx,hy,2)
    elseif slot==3 then
      local ally=A.findAlly(h,target,1000)
      if ally~=h then A.moveToward(h,GetUnitX(ally),GetUnitY(ally),550) end
      A.addShield(ally,b*3.8,8)
      if ally~=h then A.protect(h,ally,.42,7) end
      A.spellCone(h,330,150,b*.8,"physical")
      resource(pid,"valor",12)
    else
      local stored=s.resolve or 0
      s.resolve=0
      local valor=resource(pid,"valor","consume")
      for k=0,3 do
        local u=A.heroUnits[k]
        if u and IsUnitAlly(u,GetOwningPlayer(h)) then
          if not A.alive(u) then ReviveHero(u,hx,hy,true) end
          if A.alive(u) then
            A.spellHeal(h,u,b*2+stored*.6+valor)
            A.addShield(u,b*2+stored*.3,10)
          end
        end
      end
      A.spellRing(h,hx,hy,200,710,b*1.5+stored*.35,"magic",
        function(u)A.knockAway(h,u,hx,hy,200)end)
    end
  elseif kind==2 then -- Zarhan: directional bleeding duelist, riposte, finisher
    if slot==1 then
      A.moveToward(h,x,y,410)
      A.spellCone(h,330,95,b*1.5,"physical",function(u)
        A.applyBleed(h,u,1,8)
      end)
      resource(pid,"combo",18)
    elseif slot==2 then
      local enemy=targetEnemy(h,target)
      if enemy then
        A.spellDamage(h,enemy,b*1.1,"physical")
        A.applyBleed(h,enemy,2,8)
        if A.bleedCount(enemy)>=3 then
          A.popBleed(h,enemy,b*.6)
          resource(pid,"combo",18)
        end
      end
    elseif slot==3 then
      s.parry=A.clock+4
      A.haste(h,.16,4)
      A.addShield(h,b*.65,4)
    else
      local combo=resource(pid,"combo","consume")
      local enemy=targetEnemy(h,target)
      if enemy then
        A.moveToward(h,GetUnitX(enemy),GetUnitY(enemy),420)
        A.spellDamage(h,enemy,b*(2+combo*.025),"physical")
        A.popBleed(h,enemy,b*.7+combo*.08)
        A.after(.2,function()if A.alive(h) and A.isEnemy(h,enemy) then
          A.spellDamage(h,enemy,b*(1+combo*.01),"physical") end end)
      end
    end
  elseif kind==3 then -- Mirella: target hopping, planted conductor, overload
    if slot==1 then
      local found={}
      local last=targetEnemy(h,target)
      for k=1,5 do
        if not last then break end
        found[GetHandleId(last)]=true
        A.spellDamage(h,last,b*1.05*(1-(k-1)*.1),"magic")
        fx([[Abilities\Spells\Orc\LightningShield\LightningShieldTarget.mdl]],
           GetUnitX(last),GetUnitY(last),.75)
        last=A.findEnemy(h,GetUnitX(last),GetUnitY(last),475,function(u)
          return not found[GetHandleId(u)]
        end)
      end
      resource(pid,"storm",15+math.min(5,k or 1))
    elseif slot==2 then
      s.storm={x=x,y=y,expires=A.clock+10,next=A.clock,
               power=b*.75}
      fx([[Abilities\Spells\Orc\LightningShield\LightningShieldTarget.mdl]],x,y,2)
    elseif slot==3 then
      local charge=resource(pid,"storm","consume")
      otherHeroes(h,function(u)
        A.mana(u,b*1.7+charge*.9)
        A.buff(u,"spellAmp",.12+charge*.0012,10)
        A.refundCooldown(u,1,1.8)
      end)
    else
      local charge=resource(pid,"storm","consume")
      local points={{x,y}}
      if s.storm and s.storm.expires>A.clock then
        points[#points+1]={s.storm.x,s.storm.y}
        s.storm=nil
      end
      for n=1,4 do
        A.after(n*.55,function()
          if A.alive(h) then
            for _,p in ipairs(points) do
              A.spellRing(h,p[1],p[2],0,450,b*(1.25+charge*.006),"magic",
                function(u)A.stunEnemy(h,u,.4)end)
              A.visualRing([[Abilities\Spells\Orc\LightningShield\LightningShieldTarget.mdl]],
                  p[1],p[2],240,7,.7)
            end
          end
        end)
      end
    end
  elseif kind==4 then -- Morven: death-trigger curse, expendable skeletal screen
    if slot==1 then
      local enemy=targetEnemy(h,target)
      if enemy then
        A.spellDamage(h,enemy,b*.7,"magic")
        A.doomMarks[GetHandleId(enemy)]={caster=h,pid=pid,
                   expires=A.clock+11,power=b}
      end
    elseif slot==2 then
      local enemy=targetEnemy(h,target)
      A.summonGuard(h,"uske",2+math.floor(rank/2),20,enemy)
      A.addShield(h,b*1.4,8)
      A.taunt(h,400)
    elseif slot==3 then
      local victims=0
      enemyIn(h,hx,hy,460,function(u)
        victims=victims+1
        A.spellDamage(h,u,b*1.05,"magic")
        if A.doomMarks[GetHandleId(u)] then resource(pid,"souls",3) end
      end)
      local ally=A.lowestAlly(h,800)
      A.spellHeal(h,ally,b*(.9+math.min(victims,7)*.35))
      resource(pid,"souls",math.min(victims*3,18))
    else
      local souls=resource(pid,"souls","consume")
      local enemy=targetEnemy(h,target)
      A.summonGuard(h,"uske",3+math.floor(souls/15),27,enemy)
      otherHeroes(h,function(u)A.addShield(u,b*.85+souls*1.5,9)end)
      for id,mark in pairs(A.doomMarks) do
        if mark.pid==pid and mark.expires>A.clock then mark.expires=A.clock+18 end
      end
      A.taunt(h,520)
    end
  elseif kind==5 then -- Valtir: spatial rift mines and rage transformation
    if slot==1 then
      local oldX,oldY=hx,hy
      A.moveToward(h,x,y,490)
      A.spellRing(h,oldX,oldY,0,245,b*1.2,"physical")
      A.spellRing(h,GetUnitX(h),GetUnitY(h),0,245,b*1.0,"physical")
      resource(pid,"fury",18)
    elseif slot==2 then
      local enemy=targetEnemy(h,target)
      if enemy then
        A.spellDamage(h,enemy,b*1.45,"magic")
        A.mana(h,b*1.25)
        A.spellHeal(h,h,b*.95)
      end
      resource(pid,"fury",12)
    elseif slot==3 then
      s.mines=s.mines or {}
      if #s.mines>=3 then table.remove(s.mines,1) end
      s.mines[#s.mines+1]={x=x,y=y,power=b*2.0,expires=A.clock+22}
      A.visualRing([[Abilities\Spells\Other\GeneralAuraTarget\GeneralAuraTarget.mdl]],
         x,y,145,6,4)
    else
      local fury=resource(pid,"fury","consume")
      A.buff(h,"felForm",1,11)
      A.buff(h,"physicalAmp",.28+fury*.003,11)
      A.buff(h,"resist",.22,11)
      A.haste(h,.18,11)
      A.spellHeal(h,h,b*.9+fury)
      if s.mines then
        for _,mine in ipairs(s.mines) do
          A.spellArea(h,mine.x,mine.y,290,mine.power*.7,"magic")
        end
        s.mines={}
      end
    end
  elseif kind==6 then -- Selena: direct clutch heals + overheal + anchoring grove
    if slot==1 then
      local friend=A.findAlly(h,target,1050)
      local missing=1-GetWidgetLife(friend)/math.max(1,GetUnitState(friend,UNIT_STATE_MAX_LIFE))
      A.spellHeal(h,friend,b*(2.6+missing*1.4))
      if hpFraction(friend)>.95 then A.addShield(friend,b*1.6,8) end
      resource(pid,"moon",12)
    elseif slot==2 then
      s.bloom={x=x,y=y,radius=570,power=b*.92,expires=A.clock+11,next=A.clock}
      fx([[Abilities\Spells\NightElf\Tranquility\TranquilityTarget.mdl]],x,y,2)
      resource(pid,"moon",14)
    elseif slot==3 then
      local friend=A.findAlly(h,target,900)
      A.addShield(friend,b*4.5,9)
      A.buff(friend,"resist",.24,9)
      A.buff(friend,"healAmp",.12,9)
      A.spellHeal(h,friend,b*.7)
    else
      local moon=resource(pid,"moon","consume")
      for k=0,3 do
        local friend=A.heroUnits[k]
        if friend and IsUnitAlly(friend,GetOwningPlayer(h)) then
          if not A.alive(friend) then ReviveHero(friend,hx,hy,true) end
          if A.alive(friend) then
            A.spellHeal(h,friend,b*2.8+moon*1.4)
            A.addShield(friend,b*1.8,11)
          end
        end
      end
      if s.bloom and s.bloom.expires>A.clock then
        s.bloom.power=s.bloom.power*2
        s.bloom.expires=A.clock+11
      end
    end
  elseif kind==7 then -- Fenn: tactical concoctions, vulnerability and true haste
    if slot==1 then
      otherHeroes(h,function(u)
        A.buff(u,"physicalAmp",.24,11)
        A.haste(u,.23,11)
      end)
    elseif slot==2 then
      s.acid={x=x,y=y,expires=A.clock+9}
      A.visualRing([[Abilities\Spells\Other\AcidBomb\AcidBombTarget.mdl]],
         x,y,340,7,4)
      enemyIn(h,x,y,380,function(u)
        A.spellDamage(h,u,b*.8,"magic")
        A.buff(u,"vulnerable",.24,8)
      end)
      A.after(3,function()
        if A.alive(h) then
          enemyIn(h,x,y,380,function(u)
            A.spellDamage(h,u,b*.65,"magic")
            A.buff(u,"vulnerable",.24,5)
          end)
        end
      end)
    elseif slot==3 then
      otherHeroes(h,function(u)
        A.mana(u,b*1.8)
        A.buff(u,"spellAmp",.24,11)
        A.refundCooldown(u,2,2.0)
      end)
    else
      otherHeroes(h,function(u)
        A.buff(u,"physicalAmp",.24,12)
        A.buff(u,"spellAmp",.24,12)
        A.haste(u,.16,12)
        A.addShield(u,b*2.4,12)
        A.spellHeal(h,u,b*1.3)
        A.refundCooldown(u,3,4)
      end)
    end
  elseif kind==8 then -- Torvin: interruption, enemy displacement, reactive armor
    if slot==1 then
      A.spellCone(h,560,115,b*1.3,"physical",function(u)
        A.stunEnemy(h,u,.85)
      end)
    elseif slot==2 then
      enemyIn(h,hx,hy,580,function(u)
        A.moveToward(u,hx,hy,400)
        A.spellDamage(h,u,b*.75,"physical")
        A.stunEnemy(h,u,.5)
      end)
      A.taunt(h,640)
    elseif slot==3 then
      s.stoneExpires=A.clock+12
      s.stoneCount=0
      A.addShield(h,b*5.5,12)
      A.buff(h,"resist",.32,12)
      A.spellHeal(h,h,b*.9)
    else
      local hits=A.spellRing(h,hx,hy,180,680,b*1.85,"physical",function(u)
        A.knockAway(h,u,hx,hy,180)
        A.stunEnemy(h,u,1.35)
      end)
      A.taunt(h,750)
      A.addShield(h,b*(1+math.min(hits,10)*.3),10)
    end
  elseif kind==9 then -- Lyrisa: backstab execution with target return point
    if slot==1 then
      s.shadowX,s.shadowY=hx,hy
      local enemy=targetEnemy(h,target)
      if enemy then
        local nx,ny=GetUnitX(enemy),GetUnitY(enemy)
        local facing=math.rad(GetUnitFacing(enemy))
        A.moveToward(h,nx-math.cos(facing)*100,ny-math.sin(facing)*100,750)
        A.spellDamage(h,enemy,b*1.7,"physical")
        A.buff(enemy,"vulnerable",.1,5)
      end
    elseif slot==2 then
      local enemy=targetEnemy(h,target)
      if enemy then
        A.spellDamage(h,enemy,b*.85,"physical")
        A.marks[GetHandleId(enemy)]={warden=pid,untilTime=A.clock+11}
        A.buff(enemy,"vulnerable",.22,11)
      end
    elseif slot==3 then
      if s.shadowX then
        A.moveToward(h,s.shadowX,s.shadowY,880)
        s.shadowX=nil
      else A.moveToward(h,x,y,300) end
      A.addShield(h,b*1.3,5)
      s.parry=A.clock+2
      fx([[Abilities\Spells\NightElf\Blink\BlinkTarget.mdl]],GetUnitX(h),GetUnitY(h),1)
    else
      local enemy=targetEnemy(h,target)
      if enemy then
        local data=A.marks[GetHandleId(enemy)]
        local marked=data and data.warden==pid and data.untilTime>A.clock
        local hp=1-hpFraction(enemy)
        A.spellDamage(h,enemy,b*(2.1+hp*2)*(marked and 1.7 or 1),"physical")
        if marked then
          A.marks[GetHandleId(enemy)]=nil
          A.refundCooldown(h,1,5)
        end
      end
    end
  elseif kind==10 then -- Issara: frost stacking, shattering ice barrier
    if slot==1 then
      A.launchShot(h,hx,hy,x,y,880,1400,105,b*1.3,"magic",function(u)
        A.addFrost(h,u,1)
      end)
    elseif slot==2 then
      local enemy=targetEnemy(h,target)
      if enemy then
        A.addFrost(h,enemy,2)
        A.rootEnemy(h,enemy,2.5)
        enemyIn(h,GetUnitX(enemy),GetUnitY(enemy),210,function(other)
          if other~=enemy then A.addFrost(h,other,1) end
        end)
      end
    elseif slot==3 then
      local angle=math.rad(GetUnitFacing(h)+90)
      s.frostWall={x=x,y=y,dx=math.cos(angle),dy=math.sin(angle),
                   expires=A.clock+9,next=A.clock,power=b}
      A.visualRing([[Abilities\Spells\Undead\FrostNova\FrostNovaTarget.mdl]],
          x,y,260,8,2)
    else
      enemyIn(h,hx,hy,880,function(u)
        local id=GetHandleId(u)
        local frost=A.frostStacks[id]
        local stacks=frost and frost.expiry>A.clock and frost.stacks or 0
        A.spellDamage(h,u,b*(1.2+stacks*.6),"magic")
        A.stunEnemy(h,u,.7+stacks*.5)
        A.frostStacks[id]=nil
      end)
      fx([[Abilities\Spells\Undead\FrostNova\FrostNovaTarget.mdl]],hx,hy,1.6)
    end
  elseif kind==11 then -- Avals: controllable ranged marks and precision shot
    local gelo=A.allyOfKind(12,h)
    if slot==1 then
      local blessing=(A.boneBlessing[pid] or 0)>A.clock and 1.75 or 1
      A.boneBlessing[pid]=nil
      local focus=1+math.min(5,s.precision or 0)*.12
      s.precision=0
      A.launchShot(h,hx,hy,x,y,1050,1600,115,b*1.45*blessing*focus,
         "physical",function(u)A.markBone(h,u,9)end)
    elseif slot==2 then
      for i=1,7 do
        local theta=i*2.3999632
        local radius=120+(i%3)*75
        local xx,yy=x+math.cos(theta)*radius,y+math.sin(theta)*radius
        A.after(i*.2,function()
          if A.alive(h) then
            A.spellRing(h,xx,yy,0,170,b*(gelo and .95 or .75),"physical",
              function(u)A.markBone(h,u,9)end)
          end
        end)
      end
    elseif slot==3 then
      A.buff(h,"physicalAmp",.30,11)
      A.haste(h,.22,11)
      if gelo then A.addShield(gelo,b*3.0,9);A.buff(gelo,"physicalAmp",.14,9) end
    else
      local enemy=targetEnemy(h,target)
      local xx,yy=enemy and GetUnitX(enemy) or x,enemy and GetUnitY(enemy) or y
      for i=1,5 do
        A.after(i*.25,function()
          if A.alive(h) then
            A.spellRing(h,xx,yy,0,260,b*1.05,"physical",
              function(u)A.markBone(h,u,9)end)
          end
        end)
      end
      A.recordTwinUltimate(h,11,b)
    end
  elseif kind==12 then -- Gelo: bone-shatter brawler, team-facing shield
    local avals=A.allyOfKind(11,h)
    if slot==1 then
      A.spellCone(h,460,135,b*1.65,"physical",function(u)
        if A.consumeBone(h,u) then
          A.spellDamage(h,u,b*1.5,"physical")
          A.stunEnemy(h,u,.9)
        end
      end)
    elseif slot==2 then
      A.taunt(h,610)
      A.addShield(h,b*5,10)
      if avals then A.addShield(avals,b*4,10);A.protect(h,avals,.30,10) end
      A.buff(h,"resist",.2,10)
    elseif slot==3 then
      A.moveToward(h,x,y,460)
      A.spellCone(h,280,140,b*1.45,"physical",function(u)
        if A.consumeBone(h,u) then
          A.spellDamage(h,u,b*1.2,"physical")
        end
      end)
      if avals then
        local otherPid=GetPlayerId(GetOwningPlayer(avals))
        A.boneBlessing[otherPid]=A.clock+9
      end
    else
      A.spellRing(h,hx,hy,0,560,b*1.4,"physical",function(u)
        A.stunEnemy(h,u,.9)
      end)
      A.summonGuard(h,"uske",2+math.floor(rank/2),20,targetEnemy(h,target))
      A.recordTwinUltimate(h,12,b)
    end
  end
end

function A.castHero(hero,ability)
  local pid=GetPlayerId(GetOwningPlayer(hero))
  if pid<0 or pid>3 or A.heroUnits[pid]~=hero then return false end
  local kind=A.heroKind[pid]
  local slot=nil
  for k,id in ipairs(A.spells[kind]) do
    if A.raw(id)==ability then slot=k;break end
  end
  if not slot then return false end
  local key=GetHandleId(hero)..":"..ability
  local record=A.spellDetails[kind][slot]
  local remaining=(A.cooldowns[key] or 0)-A.clock
  if remaining>0 then
    A.playerText(pid,string.format("Перезарядка: %.1f сек.",remaining))
    return true
  end
  local rank=math.max(1,math.min(5,GetUnitAbilityLevel(hero,ability)))
  A.cooldowns[key]=A.clock+record.cooldown
  if BlzStartUnitAbilityCooldown then
    BlzStartUnitAbilityCooldown(hero,ability,record.cooldown)
  end
  local x,y=GetSpellTargetX(),GetSpellTargetY()
  local target=GetSpellTargetUnit()
  if x==0 and y==0 then
    if target then x,y=GetUnitX(target),GetUnitY(target)
    else x,y=GetUnitX(hero),GetUnitY(hero) end
  end
  cast(hero,pid,kind,slot,rank,target,x,y,power(rank))
  if A.onItemSpell then A.onItemSpell(hero,ability) end
  return true
end
