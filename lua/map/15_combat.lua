-- Shared spell engine for the 12-role party overhaul.
-- Physical SPELL damage scales with hero Strength. Magical damage and healing
-- scale with Intelligence. Agility continues to benefit native attacks/defence.
local A=Arena
A.statuses={}
A.boneMarks={}
A.fractures={}
A.twinUlt={}
A.boneBlessing={}
A.lastCleanup=0

local function ident(unit)
    return GetHandleId(unit)
end

function A.statMultiplier(caster,school)
    if school=="physical" then
        return 1+math.max(0,GetHeroStr(caster,true))*.015
    end
    return 1+math.max(0,GetHeroInt(caster,true))*.02
end

function A.statusValue(unit,key)
    if not A.alive(unit) then return 0 end
    local b=A.statuses[ident(unit)]
    local current=b and b[key]
    if current and current.expires>A.clock then return current.value end
    return 0
end

function A.buff(unit,key,value,duration)
    if not A.alive(unit) then return end
    local id=ident(unit)
    local effects=A.statuses[id] or {}
    A.statuses[id]=effects
    local old=effects[key]
    effects[key]={
        value=math.max(value,old and old.expires>A.clock and old.value or 0),
        expires=A.clock+duration
    }
end

function A.addShield(unit,amount,duration)
    if not A.alive(unit) then return end
    local id=ident(unit)
    local effects=A.statuses[id] or {}
    A.statuses[id]=effects
    local prev=effects.shield
    local remaining=prev and prev.expires>A.clock and prev.value or 0
    effects.shield={value=math.min(18000,remaining+math.max(0,amount)),expires=A.clock+duration}
    A.visual([[Abilities\Spells\Human\DivineShield\DivineShieldTarget.mdl]],
        GetUnitX(unit),GetUnitY(unit),.8)
end

function A.modifyIncoming(victim,amount)
    local dealt=amount
    local guard=A.guards[ident(victim)] or 0
    if guard>A.clock then dealt=dealt*.35 end
    dealt=dealt*(1-math.min(.65,A.statusValue(victim,"resist")))
    local states=A.statuses[ident(victim)]
    local shield=states and states.shield
    if shield and shield.expires>A.clock and shield.value>0 then
        local prevented=math.min(math.max(0,dealt),shield.value)
        dealt=dealt-prevented
        shield.value=shield.value-prevented
    end
    return dealt
end

function A.spellDamage(caster,victim,base,school)
    if not A.isEnemy(caster,victim) then return 0 end
    local amp=school=="physical" and A.statusValue(caster,"physicalAmp")
                                   or A.statusValue(caster,"spellAmp")
    local weakness=A.statusValue(victim,"vulnerable")
    local amount=math.max(1,base*A.statMultiplier(caster,school)
                        *(1+amp)*(1+weakness))
    if school=="physical" and (A.fractures[ident(victim)] or 0)>A.clock then
        amount=amount*1.25
    end
    local physical=school=="physical"
    UnitDamageTarget(caster,victim,amount,physical,false,
        physical and ATTACK_TYPE_NORMAL or ATTACK_TYPE_MAGIC,
        physical and DAMAGE_TYPE_NORMAL or DAMAGE_TYPE_MAGIC,
        WEAPON_TYPE_WHOKNOWS)
    return amount
end

function A.spellHeal(caster,ally,base)
    if not A.alive(ally) then return 0 end
    local amount=base*A.statMultiplier(caster,"magic")
                    *(1+A.statusValue(caster,"healAmp"))
    A.heal(ally,amount)
    return amount
end

function A.forAllies(caster,radius,callback)
    local x,y=GetUnitX(caster),GetUnitY(caster)
    for pid=0,3 do
        local ally=A.heroUnits[pid]
        if A.alive(ally) and IsUnitAlly(ally,GetOwningPlayer(caster)) then
            local dx,dy=GetUnitX(ally)-x,GetUnitY(ally)-y
            if radius==nil or dx*dx+dy*dy<=radius*radius then
                callback(ally,pid)
            end
        end
    end
end

function A.lowestAlly(caster,radius)
    local selected,best=nil,2
    A.forAllies(caster,radius,function(ally)
        local ratio=GetWidgetLife(ally)/math.max(1,GetUnitState(ally,UNIT_STATE_MAX_LIFE))
        if ratio<best then best=ratio;selected=ally end
    end)
    return selected or caster
end

function A.allyOfKind(kind,caster)
    for pid=0,3 do
        local u=A.heroUnits[pid]
        if A.heroKind[pid]==kind and A.alive(u)
           and IsUnitAlly(u,GetOwningPlayer(caster)) then return u,pid end
    end
    return nil,nil
end

function A.spellArea(caster,x,y,radius,base,school,onHit)
    local hits=0
    A.withUnits(x,y,radius,function(unit)
        if A.isEnemy(caster,unit) then
            A.spellDamage(caster,unit,base,school)
            hits=hits+1
            if onHit then onHit(unit) end
        end
    end)
    return hits
end

function A.spellLine(caster,range,width,base,school,onHit)
    local x,y=GetUnitX(caster),GetUnitY(caster)
    local angle=math.rad(GetUnitFacing(caster))
    local dx,dy=math.cos(angle),math.sin(angle)
    local hits=0
    A.withUnits(x+dx*range*.5,y+dy*range*.5,range,function(unit)
        if A.isEnemy(caster,unit) then
            local ux,uy=GetUnitX(unit)-x,GetUnitY(unit)-y
            local forward=ux*dx+uy*dy
            local across=math.abs(ux*dy-uy*dx)
            if forward>=0 and forward<=range and across<=width then
                A.spellDamage(caster,unit,base,school)
                hits=hits+1
                if onHit then onHit(unit) end
            end
        end
    end)
    return hits
end

function A.spellZone(caster,x,y,radius,duration,interval,base,school,onHit)
    local repeats=math.max(1,math.floor(duration/interval))
    local count=0
    A.visualRing(
      school=="physical"
        and [[Abilities\Spells\Human\ThunderClap\ThunderClapCaster.mdl]]
        or [[Abilities\Spells\Undead\FrostNova\FrostNovaTarget.mdl]],
      x,y,math.min(radius*.75,400),7,math.min(duration,3.0))
    local function pulse()
        if not A.alive(caster) or count>=repeats then return end
        count=count+1
        A.spellArea(caster,x,y,radius,base,school,onHit)
        if count<repeats then A.after(interval,pulse) end
    end
    A.after(interval,pulse)
end

function A.healZone(caster,x,y,radius,duration,interval,base)
    local repeats=math.max(1,math.floor(duration/interval))
    local count=0
    A.visualRing([[Abilities\Spells\NightElf\Tranquility\TranquilityTarget.mdl]],
       x,y,radius*.75,7,duration)
    local function pulse()
        if not A.alive(caster) or count>=repeats then return end
        count=count+1
        A.forAllies(caster,nil,function(ally)
            local dx,dy=GetUnitX(ally)-x,GetUnitY(ally)-y
            if dx*dx+dy*dy<=radius*radius then A.spellHeal(caster,ally,base) end
        end)
        if count<repeats then A.after(interval,pulse) end
    end
    A.after(interval,pulse)
end

function A.spellTrap(caster,x,y,delay,radius,base,school,onHit)
    A.visualRing([[Abilities\Spells\Other\GeneralAuraTarget\GeneralAuraTarget.mdl]],
       x,y,radius*.7,6,delay)
    A.after(delay,function()
        if A.alive(caster) then
            A.visual([[Abilities\Spells\Human\ThunderClap\ThunderClapCaster.mdl]],x,y,1.2)
            A.spellArea(caster,x,y,radius,base,school,onHit)
        end
    end)
end

function A.spellDash(caster,distance,width,base,school,onHit)
    A.spellLine(caster,distance,width,base,school,onHit)
    local radians=math.rad(GetUnitFacing(caster))
    local x=math.max(-1900,math.min(1900,GetUnitX(caster)+distance*math.cos(radians)))
    local y=math.max(-1900,math.min(1900,GetUnitY(caster)+distance*math.sin(radians)))
    SetUnitPosition(caster,x,y)
    A.visual([[Abilities\Spells\NightElf\Blink\BlinkTarget.mdl]],x,y,1.1)
end

function A.slowEnemy(caster,enemy,percent,seconds)
    if not A.isEnemy(caster,enemy) then return end
    local base=GetUnitMoveSpeed(enemy)
    local old=A.statuses[ident(enemy)] or {}
    -- Capture the pre-slow speed once, not a progressively reduced value.
    local prior=old.speedBase or base
    local expiry=A.clock+seconds
    old.speedBase=prior
    old.speedExpiry=math.max(old.speedExpiry or 0,expiry)
    A.statuses[ident(enemy)]=old
    SetUnitMoveSpeed(enemy,math.max(1,prior*(1-percent)))
    A.after(seconds,function()
        if A.alive(enemy) and old.speedExpiry<=A.clock+.01 then
            SetUnitMoveSpeed(enemy,prior)
            old.speedBase=nil
            old.speedExpiry=nil
        end
    end)
end

function A.rootEnemy(caster,enemy,seconds)
    if not A.isEnemy(caster,enemy) then return end
    IssueImmediateOrder(enemy,"stop")
    A.slowEnemy(caster,enemy,.98,seconds)
end

function A.taunt(caster,radius)
    local x,y=GetUnitX(caster),GetUnitY(caster)
    A.withUnits(x,y,radius,function(enemy)
        if A.isEnemy(caster,enemy) then IssueTargetOrder(enemy,"attack",caster) end
    end)
end

function A.markBone(caster,enemy,seconds)
    if not A.isEnemy(caster,enemy) then return end
    local pid=GetPlayerId(GetOwningPlayer(caster))
    A.boneMarks[ident(enemy)]={untilTime=A.clock+seconds,by=pid}
    A.visual([[Abilities\Spells\Undead\DeathCoil\DeathCoilSpecialArt.mdl]],
       GetUnitX(enemy),GetUnitY(enemy),1)
end

function A.consumeBone(caster,enemy)
    if not A.isEnemy(caster,enemy) then return false end
    local id=ident(enemy)
    local mark=A.boneMarks[id]
    if not mark or mark.untilTime<=A.clock then return false end
    local archer=A.heroUnits[mark.by]
    if not A.alive(archer) or A.heroKind[mark.by]~=11
        or not IsUnitAlly(archer,GetOwningPlayer(caster)) then return false end
    A.boneMarks[id]=nil
    A.fractures[id]=A.clock+9
    A.boneBlessing[mark.by]=A.clock+8
    A.visual([[Abilities\Spells\Undead\FrostNova\FrostNovaTarget.mdl]],
       GetUnitX(enemy),GetUnitY(enemy),1.0)
    return true
end

function A.recordTwinUltimate(caster,kind,base)
    local other=kind==11 and 12 or 11
    local peer=A.allyOfKind(other,caster)
    local previous=A.twinUlt[other]
    A.twinUlt[kind]={unit=caster,when=A.clock}
    if not peer or not previous or previous.unit~=peer
       or A.clock-previous.when>12 then return end
    A.twinUlt[other]=nil
    A.twinUlt[kind]=nil
    local x=(GetUnitX(peer)+GetUnitX(caster))*.5
    local y=(GetUnitY(peer)+GetUnitY(caster))*.5
    A.say("|cffffcc66АВАЛС + ГЕЛО: СМЕРТЕЛЬНЫЙ СОЮЗ!|r")
    A.visualRing([[Abilities\Spells\Undead\AnimateDead\AnimateDeadTarget.mdl]],
       x,y,560,12,2.5)
    -- Mixed attacks: the archer's volley and the warrior's impact both matter.
    A.spellArea(caster,x,y,620,base*1.8,"physical")
    A.spellArea(peer,x,y,620,base*1.1,"physical")
    A.forAllies(caster,nil,function(ally)
        A.addShield(ally,220+base*2,10)
        A.buff(ally,"physicalAmp",.22,10)
    end)
end

function A.tickCombat()
    if A.clock-A.lastCleanup<1 then return end
    A.lastCleanup=A.clock
    for id,v in pairs(A.boneMarks) do
        if v.untilTime<=A.clock then A.boneMarks[id]=nil end
    end
    for id,expiry in pairs(A.fractures) do
        if expiry<=A.clock then A.fractures[id]=nil end
    end
    for id,states in pairs(A.statuses) do
        for key,entry in pairs(states) do
            if type(entry)=="table" and entry.expires<=A.clock then states[key]=nil end
        end
        if next(states)==nil then A.statuses[id]=nil end
    end
    for kind,data in pairs(A.twinUlt) do
        if A.clock-data.when>12 then A.twinUlt[kind]=nil end
    end
end
