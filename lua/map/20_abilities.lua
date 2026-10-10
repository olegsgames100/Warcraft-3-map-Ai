-- 40 custom ability mechanics, 10 truly different class kits.
local A=Arena

local VFX={
    {[[Abilities\Spells\Human\HolyBolt\HolyBoltSpecialArt.mdl]],[[Abilities\Spells\Human\Resurrect\ResurrectTarget.mdl]]},
    {[[Abilities\Spells\Orc\MirrorImage\MirrorImageCaster.mdl]],[[Abilities\Spells\Orc\Bladestorm\BladestormTarget.mdl]]},
    {[[Abilities\Spells\Orc\LightningShield\LightningShieldTarget.mdl]],[[Abilities\Spells\Orc\Farseer\FarSeerMissile.mdl]]},
    {[[Abilities\Spells\Undead\DeathCoil\DeathCoilSpecialArt.mdl]],[[Abilities\Spells\Undead\AnimateDead\AnimateDeadTarget.mdl]]},
    {[[Abilities\Spells\NightElf\Blink\BlinkTarget.mdl]],[[Abilities\Spells\Other\Doom\DoomDeath.mdl]]},
    {[[Abilities\Spells\NightElf\Starfall\StarfallTarget.mdl]],[[Abilities\Spells\NightElf\Tranquility\TranquilityTarget.mdl]]},
    {[[Abilities\Spells\Other\AcidBomb\BottleMissile.mdl]],[[Abilities\Spells\Other\AcidBomb\AcidBombTarget.mdl]]},
    {[[Abilities\Spells\Human\ThunderClap\ThunderClapCaster.mdl]],[[Abilities\Spells\Human\Avatar\AvatarCaster.mdl]]},
    {[[Abilities\Spells\NightElf\Blink\BlinkTarget.mdl]],[[Abilities\Spells\NightElf\FanOfKnives\FanOfKnivesCaster.mdl]]},
    {[[Abilities\Spells\Undead\FrostNova\FrostNovaTarget.mdl]],[[Abilities\Spells\Undead\FreezingBreath\FreezingBreathMissile.mdl]]}
}
A.visualCatalog=VFX
function A.cooldownSeconds(kind,slot,rank)
    local base=({7,14,17,52})[slot]
    if slot==4 and kind==1 then base=64 end
    if slot==4 and kind==9 then base=56 end
    if slot==2 and (kind==3 or kind==7 or kind==10) then base=16 end
    return math.max(3,base-(rank-1)*(slot==4 and .7 or .35))
end
function A.castVFX(kind,slot,caster,x,y)
    local style=VFX[kind]
    A.visual(style[1],GetUnitX(caster),GetUnitY(caster),1.25)
    local visual=style[slot==4 and 2 or 1]
    if slot==2 or slot==4 then
        A.visualRing(visual,x,y,slot==4 and 380 or 200,slot==4 and 10 or 6,slot==4 and 2.4 or 1.5)
    else
        A.visual(visual,x,y,1.4)
    end
    if slot==4 then A.text(x,y,"|cffffcc33УЛЬТИМЕЙТ!|r",.026,2.3) end
end
local function spend(pid,key,amount)
    local r=A.resources[pid]
    if (r[key] or 0)<amount then return false end
    r[key]=r[key]-amount
    return true
end
local function gain(pid,key,amount)
    A.resources[pid][key]=math.min(100,(A.resources[pid][key] or 0)+amount)
end
local function rank(hero,id)
    return math.max(1,math.min(5,GetUnitAbilityLevel(hero,id)))
end
local function power(level)
    return 45+24*level
end
local function sayResource(pid,key)
    A.playerText(pid,"Энергия "..key..": "..math.floor(A.resources[pid][key] or 0).."/100")
end
function A.castHero(hero,ability)
    local pid=GetPlayerId(GetOwningPlayer(hero))
    if pid<0 or pid>3 or A.heroUnits[pid]~=hero then return false end
    local kind=A.heroKind[pid]
    local slot
    for k,id in ipairs(A.spells[kind]) do
        if A.raw(id)==ability then slot=k;break end
    end
    if not slot then return false end
    local level=rank(hero,ability)
    local key=GetHandleId(hero)..":"..ability
    local untilTime=A.cooldowns[key] or 0
    if untilTime>A.clock then
        A.playerText(pid,"Перезарядка: "..string.format("%.1f",untilTime-A.clock).." сек.")
        if BlzEndUnitAbilityCooldown then BlzEndUnitAbilityCooldown(hero,ability) end
        return true
    end
    A.cooldowns[key]=A.clock+A.cooldownSeconds(kind,slot,level)
    if BlzStartUnitAbilityCooldown then BlzStartUnitAbilityCooldown(hero,ability,A.cooldownSeconds(kind,slot,level)) end
    local p=power(level)
    local hx,hy=GetUnitX(hero),GetUnitY(hero)
    local target=GetSpellTargetUnit()
    local x,y=GetSpellTargetX(),GetSpellTargetY()
    if x==0 and y==0 then x,y=hx,hy end
    A.castVFX(kind,slot,hero,x,y)
    local vfx=[[Abilities\Spells\Human\ThunderClap\ThunderClapCaster.mdl]]
    if kind==1 then -- PALADIN: valor drives defensive ultimates
        if slot==1 then
            A.line(hero,520,110,p*1.55);gain(pid,"valor",16)
        elseif slot==2 then
            A.zone(hero,hx,hy,560,7,0.7,16+p*.27,true,
                [[Abilities\Spells\Human\Resurrect\ResurrectTarget.mdl]])
            A.guard(hero,7)
        elseif slot==3 then
            A.dash(hero,250+25*level,200,p)
            A.guard(hero,3)
        else
            for other=0,3 do
                local friend=A.heroUnits[other]
                if friend and IsUnitAlly(friend,GetOwningPlayer(hero)) then
                    if not A.alive(friend) then ReviveHero(friend,hx,hy,true) end
                    A.heal(friend,p*2.1)
                end
            end
            local bonus=(A.resources[pid].valor or 0)*1.4
            A.area(hero,hx,hy,650,p*2+bonus)
            A.resources[pid].valor=0
        end
    elseif kind==2 then -- BLADEMASTER: combo chain to blade-storm
        if slot==1 then
            A.dash(hero,290+level*20,135,p*1.5);gain(pid,"combo",15)
        elseif slot==2 then
            A.zone(hero,hx,hy,370,4,.5,p*.5,nil,vfx);gain(pid,"combo",12)
        elseif slot==3 then
            A.summon(hero,"uske",2+math.floor(level/3),12+level);gain(pid,"combo",8)
        else
            local combo=A.resources[pid].combo or 0
            A.zone(hero,hx,hy,470,5,.35,p*.42+combo*.75,nil,vfx)
            A.resources[pid].combo=0
        end
    elseif kind==3 then -- ARCHMAGE: charges amplify storm
        if slot==1 then
            for i=1,3 do A.area(hero,hx,hy,380+i*100,p*.65) end
            gain(pid,"storm",19)
        elseif slot==2 then
            A.zone(hero,x,y,370,6,.6,p*.6,nil,vfx);gain(pid,"storm",14)
        elseif slot==3 then
            local charges=A.resources[pid].storm or 0
            for other=0,3 do
                local ally=A.heroUnits[other]
                if A.alive(ally) and IsUnitAlly(ally,GetOwningPlayer(hero)) then
                    A.mana(ally,p*.6+charges)
                end
            end
            A.resources[pid].storm=0
        else
            local bonus=(A.resources[pid].storm or 0)*1.0
            A.zone(hero,hx,hy,750,7,.45,p*.55+bonus,nil,vfx)
            A.resources[pid].storm=0
        end
    elseif kind==4 then -- NECROMANCER: soul harvesting
        if slot==1 then
            if A.alive(target) then
                A.marks[GetHandleId(target)]={caster=hero,untilTime=A.clock+8,soulOwner=pid}
                A.damage(hero,target,p*1.3)
            else A.area(hero,hx,hy,340,p*.8) end
        elseif slot==2 then
            A.summon(hero,"uske",2+math.floor(level/2),16+level)
        elseif slot==3 then
            A.area(hero,hx,hy,390,p*1.35)
            A.heal(hero,p*1.15)
            gain(pid,"souls",10)
        else
            local souls=A.resources[pid].souls or 0
            A.summon(hero,"uske",3+math.min(6,math.floor(souls/12)),28)
            A.area(hero,hx,hy,440,p+souls*.65)
            A.resources[pid].souls=0
        end
    elseif kind==5 then -- DEMON HUNTER: fury and infernal traps
        if slot==1 then
            A.dash(hero,280+20*level,170,p*1.4);gain(pid,"fury",20)
        elseif slot==2 then
            A.area(hero,hx,hy,480,p*1.4)
            A.mana(hero,p*.7);gain(pid,"fury",12)
        elseif slot==3 then
            A.trap(hero,x,y,2.0,330,p*2.4);gain(pid,"fury",8)
        else
            local fury=A.resources[pid].fury or 0
            A.zone(hero,hx,hy,550,9,.5,p*.5+fury*.35,nil,vfx)
            A.heal(hero,p+fury)
            A.resources[pid].fury=0
        end
    elseif kind==6 then -- MOON PRIESTESS: allied blessing and arrows
        if slot==1 then A.line(hero,780,95,p*2.0);gain(pid,"moon",12)
        elseif slot==2 then
            A.zone(hero,x,y,590,8,.8,20+p*.25,true,
                [[Abilities\Spells\NightElf\Tranquility\TranquilityTarget.mdl]])
            gain(pid,"moon",12)
        elseif slot==3 then
            A.guard(hero,5)
            A.area(hero,hx,hy,380,p*.6)
        else
            local buff=A.resources[pid].moon or 0
            A.zone(hero,hx,hy,730,7,.45,p*.43+buff*.55,nil,vfx)
            A.resources[pid].moon=0
        end
    elseif kind==7 then -- ALCHEMIST: delayed reagents and economy
        if slot==1 then A.trap(hero,x,y,1.2,360,p*2.1);gain(pid,"reagent",18)
        elseif slot==2 then
            A.zone(hero,x,y,350,7,.7,p*.65,nil,
                [[Abilities\Spells\Other\AcidBomb\BottleMissile.mdl]])
            gain(pid,"reagent",16)
        elseif slot==3 then
            local enemy=A.closestEnemy(hero,600)
            if enemy then A.damage(hero,enemy,p*1.8) end
            local gold=20+level*9
            SetPlayerState(Player(pid),PLAYER_STATE_RESOURCE_GOLD,
                GetPlayerState(Player(pid),PLAYER_STATE_RESOURCE_GOLD)+gold)
            gain(pid,"reagent",10)
        else
            local reagent=A.resources[pid].reagent or 0
            A.zone(hero,hx,hy,680,10,.7,20+p*.28,true,
                [[Abilities\Spells\Human\Resurrect\ResurrectTarget.mdl]])
            A.zone(hero,hx,hy,510,7,.7,p*.40+reagent*.3,nil,vfx)
            A.resources[pid].reagent=0
        end
    elseif kind==8 then -- MOUNTAIN KING: fortitude and control
        if slot==1 then A.line(hero,550,230,p*1.7);gain(pid,"fortitude",16)
        elseif slot==2 then
            local enemies={}
            A.withUnits(hx,hy,580,function(u)if A.isEnemy(hero,u) then enemies[#enemies+1]=u end end)
            for _,enemy in ipairs(enemies) do
                SetUnitPosition(enemy,hx+GetRandomReal(-110,110),hy+GetRandomReal(-110,110))
                A.damage(hero,enemy,p*.9)
            end
            gain(pid,"fortitude",15)
        elseif slot==3 then A.guard(hero,8+level);A.heal(hero,p*1.5)
        else
            local bonus=(A.resources[pid].fortitude or 0)*1.2
            A.zone(hero,hx,hy,700,6,.5,p*.65+bonus*.3,nil,vfx)
            A.summon(hero,"hfoo",2+math.floor(level/2),20)
            A.resources[pid].fortitude=0
        end
    elseif kind==9 then -- WARDEN: marked target execution
        if slot==1 then A.dash(hero,325,160,p*1.6)
        elseif slot==2 then
            local enemy=A.alive(target) and target or A.closestEnemy(hero,540)
            if enemy then
                A.marks[GetHandleId(enemy)]={caster=hero,untilTime=A.clock+9,warden=pid}
                A.damage(hero,enemy,p*.7)
            end
        elseif slot==3 then
            A.guard(hero,4)
            A.trap(hero,hx,hy,1.5,370,p*1.55)
        else
            local enemy=A.alive(target) and target or A.closestEnemy(hero,600)
            if enemy and A.isEnemy(hero,enemy) then
                local mark=A.marks[GetHandleId(enemy)]
                local bonus=mark and mark.warden==pid and mark.untilTime>A.clock and 2.5 or 1.0
                local missing=1-GetWidgetLife(enemy)/math.max(1,GetUnitState(enemy,UNIT_STATE_MAX_LIFE))
                A.damage(hero,enemy,p*(2+missing*3)*bonus)
            end
        end
    else -- LICH: frost, immobilization and winter
        if slot==1 then A.line(hero,690,125,p*1.8);gain(pid,"frost",14)
        elseif slot==2 then
            A.withUnits(hx,hy,430,function(enemy)
                if A.isEnemy(hero,enemy) then
                    local id=GetHandleId(enemy)
                    A.guards[id]=A.guards[id] or 0
                    A.damage(hero,enemy,p*.7)
                    IssueImmediateOrder(enemy,"stop")
                end
            end)
            gain(pid,"frost",12)
        elseif slot==3 then A.zone(hero,hx,hy,460,6,.6,p*.52,nil,vfx)
        else
            local frost=A.resources[pid].frost or 0
            A.zone(hero,hx,hy,760,9,.5,p*.52+frost*.36,nil,vfx)
            A.heal(hero,p+frost)
            A.resources[pid].frost=0
        end
    end
    return true
end

-- Spell runtime diagnostics. Channel sometimes supplies CAST but not EFFECT
-- when data fields or native target modes are inconsistent.
function A.initAbilities()
    local trigger=CreateTrigger()
    A.spellEvents={}
    A.spellDebug=false
    local function identity(hero,ability)
        return tostring(GetHandleId(hero))..":"..tostring(ability)
    end
    local function execute(hero,ability,snapshot,eventType)
        local pid=GetPlayerId(GetOwningPlayer(hero))
        local ok,result=xpcall(function()
            return A.castHero(hero,ability,snapshot)
        end,function(err)
            return tostring(err)..(debug and debug.traceback and debug.traceback("",2) or "")
        end)
        if not ok then
            if pid>=0 and pid<=3 then
                A.playerText(pid,"|cffff3333[LUA SPELL ERROR] "..tostring(result):sub(1,350).."|r")
            end
            A.say("|cffff3333Ошибка Lua способности: "..tostring(result):sub(1,140).."|r")
        elseif A.spellDebug and pid>=0 and pid<=3 then
            A.playerText(pid,"|cff66ff66"..eventType.." "..tostring(ability).." "..(result and "OK" or "SKIP").."|r")
        end
        return ok and result
    end
    for pid=0,3 do
        TriggerRegisterPlayerUnitEvent(trigger,Player(pid),EVENT_PLAYER_UNIT_SPELL_CAST,nil)
        TriggerRegisterPlayerUnitEvent(trigger,Player(pid),EVENT_PLAYER_UNIT_SPELL_EFFECT,nil)
    end
    TriggerAddAction(trigger,function()
        local hero=GetTriggerUnit()
        local ability=GetSpellAbilityId()
        local pid=GetPlayerId(GetOwningPlayer(hero))
        if pid<0 or pid>3 or A.heroUnits[pid]~=hero then return end
        local index
        for slot,id in ipairs(A.spells[A.heroKind[pid]]) do
            if A.raw(id)==ability then index=slot;break end
        end
        if not index then return end
        local which=GetTriggerEventId()
        local k=identity(hero,ability)
        if which==EVENT_PLAYER_UNIT_SPELL_CAST then
            local marker={x=GetSpellTargetX(),y=GetSpellTargetY(),
                target=GetSpellTargetUnit(),hero=hero,ability=ability,
                processed=false}
            A.spellEvents[k]=marker
            if A.spellDebug then A.playerText(pid,"|cffffff66CAST "..index.."|r") end
            A.after(.35,function()
                if A.spellEvents[k]==marker and not marker.processed and A.alive(hero) then
                    marker.processed=true
                    execute(hero,ability,marker,"FALLBACK")
                end
                if A.spellEvents[k]==marker then A.spellEvents[k]=nil end
            end)
        elseif which==EVENT_PLAYER_UNIT_SPELL_EFFECT then
            local marker=A.spellEvents[k]
            if marker then
                if marker.processed then return end
                marker.processed=true
            end
            execute(hero,ability,nil,"EFFECT")
        end
    end)
end
