-- 40 custom ability mechanics, 10 truly different class kits.
local A=Arena
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
    local p=power(level)
    local hx,hy=GetUnitX(hero),GetUnitY(hero)
    local target=GetSpellTargetUnit()
    local x,y=GetSpellTargetX(),GetSpellTargetY()
    if x==0 and y==0 then x,y=hx,hy end
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

function A.initAbilities()
    local spellTrigger=CreateTrigger()
    for pid=0,3 do
        TriggerRegisterPlayerUnitEvent(spellTrigger,Player(pid),EVENT_PLAYER_UNIT_SPELL_EFFECT,nil)
    end
    TriggerAddAction(spellTrigger,function()
        A.castHero(GetTriggerUnit(),GetSpellAbilityId())
    end)
end
