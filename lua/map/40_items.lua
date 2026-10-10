-- Hero Arena v2: item effects. Every unique item ID has a separate mechanic.
local A=Arena
A.itemList={
"I001","I002","I003","I004","I005","I006","I007","I008","I009",
"I00A","I00B","I00C","I00D","I00E","I00F","I00G","I00H","I00I",
"I00J","I00K","I00L","I00M","I00N","I00O"}
A.itemData={}
local defs={
 {"Разящая комета","uncommon","Каждая четвёртая атака наносит взрывной урон.",1,270,"combo"},
 {"Зимний укус","uncommon","Удар создаёт ледяной импульс на цели.",1,390,"frost"},
 {"Клятвенный клинок","rare","Добивания возвращают владельцу здоровье.",1,530,"execute"},
 {"Стражевые руны","uncommon","Укрепляют героя и лечат после тяжёлого удара.",2,300,"barrier"},
 {"Шлем выжившего","rare","Периодическое восстановление здоровья в бою.",2,500,"regen"},
 {"Покров мага","rare","Снижает магический урон и питает маной.",2,580,"spellguard"},
 {"Настой первоцвета","common","При использовании лечит ближайших героев.",3,180,"heal"},
 {"Флакон ясности","common","Восстанавливает ману команде.",3,200,"mana"},
 {"Пыль неуязвимости","rare","При использовании создаёт защитный купол.",3,480,"shield"},
 {"Сердце метеора","epic","Заклинания вызывают дополнительный метеор.",4,1100,"meteor"},
 {"Часы течений","epic","Периодически сокращают остаток перезарядки.",4,1320,"haste"},
 {"Лунная печать","legendary","Ультимейт исцеляет союзников поблизости.",4,1700,"moon"},
 {"Раскалыватель комет","rare","Каждая третья атака выпускает ударную волну.",1,720,"cleave"},
 {"Ледяное око","rare","Враги получают морозные вспышки от ударов.",1,780,"iceblast"},
 {"Бальзам хранителя","uncommon","Мощное групповое лечение при применении.",3,350,"greaterheal"},
 {"Каменная пластина","rare","Временная броня после получения урона.",2,730,"stone"},
 {"Доспех бессмертия","epic","Срабатывает спасительное лечение на низком HP.",2,1250,"laststand"},
 {"Колпак предвидения","epic","Возвращает часть маны за использование умений.",2,1450,"focus"},
 {"Нектар астрала","rare","Переливает ману ближайшим союзникам.",3,440,"greatermana"},
 {"Печать очищения","epic","При использовании исцеляет и защищает отряды.",3,660,"purify"},
 {"Жезл оракула","epic","За каждое заклинание поддерживает случайного союзника.",4,1850,"oracle"},
 {"Корона созвездий","legendary","Каждое третье умение вызывает звёздный удар.",4,2350,"stars"},
 {"Маска пустоты","legendary","Урон способностей восстанавливает здоровье владельца.",4,2650,"vampire"},
 {"Клинок последней войны","legendary","Атаки усиливаются за каждое добивание.",1,1850,"war"}
}
for i,id in ipairs(A.itemList) do
 local d=defs[i]
 A.itemData[A.raw(id)]={id=id,name=d[1],tier=d[2],desc=d[3],shop=d[4],price=d[5],effect=d[6]}
end
A.equipped={}
A.itemProc={}
A.itemStacks={}
A.lastItemHeal={}

function A.itemHero(unit)
 local pid=GetPlayerId(GetOwningPlayer(unit))
 return pid>=0 and pid<=3 and A.heroUnits[pid]==unit
end
function A.itemEffects(unit)
 local set={}
 if not A.itemHero(unit) then return set end
 for slot=0,5 do
    local item=UnitItemInSlot(unit,slot)
    if item~=nil then
       local data=A.itemData[GetItemTypeId(item)]
       if data then set[data.effect]=true end
    end
 end
 return set
end
function A.teamHeal(caster,amount,radius)
 A.area(caster,GetUnitX(caster),GetUnitY(caster),radius,0,amount)
 A.visualRing([[Abilities\Spells\Human\HolyBolt\HolyBoltSpecialArt.mdl]],
 GetUnitX(caster),GetUnitY(caster),math.min(radius*.55,250),5,1)
end
function A.teamMana(caster,amount,radius)
 A.withUnits(GetUnitX(caster),GetUnitY(caster),radius,function(target)
    if IsUnitType(target,UNIT_TYPE_HERO) and IsUnitAlly(target,GetOwningPlayer(caster)) then
       A.mana(target,amount)
    end
 end)
 A.visual([[Abilities\Spells\Human\Brilliance\Brilliance.mdl]],GetUnitX(caster),GetUnitY(caster),1.3)
end
function A.activeItem(caster,item)
 local data=A.itemData[GetItemTypeId(item)]
 if not data or not A.itemHero(caster) then return end
 if data.effect=="heal" then A.teamHeal(caster,125,550)
 elseif data.effect=="greaterheal" then A.teamHeal(caster,330,650)
 elseif data.effect=="mana" then A.teamMana(caster,105,600)
 elseif data.effect=="greatermana" then A.teamMana(caster,210,680)
 elseif data.effect=="shield" then A.guard(caster,6);A.teamHeal(caster,80,550)
 elseif data.effect=="purify" then A.guard(caster,7);A.teamHeal(caster,200,650)
 end
end
function A.onItemSpell(caster,ability)
 if not A.itemHero(caster) then return end
 local effects=A.itemEffects(caster)
 local pid=GetPlayerId(GetOwningPlayer(caster))
 A.itemProc[pid]=A.itemProc[pid] or {}
 local proc=A.itemProc[pid]
 proc.spells=(proc.spells or 0)+1
 if effects.focus then A.mana(caster,8) end
 if effects.oracle then A.teamHeal(caster,20,520) end
 if effects.moon then A.teamHeal(caster,52,540) end
 if effects.vampire then A.heal(caster,30) end
 if effects.meteor then
    A.after(.45,function()
        if A.alive(caster) then
          A.visual([[Abilities\Spells\Other\Meteor\MeteorImpact.mdl]],GetUnitX(caster),GetUnitY(caster),1.1)
          A.area(caster,GetUnitX(caster),GetUnitY(caster),300,90)
        end
    end)
 end
 if effects.stars and proc.spells%3==0 then
    local x,y=GetUnitX(caster),GetUnitY(caster)
    A.visualRing([[Abilities\Spells\NightElf\Starfall\StarfallTarget.mdl]],x,y,260,7,1.4)
    A.area(caster,x,y,460,150)
 end
 if effects.haste then
    -- The native cooldown is adjusted per ability, not removed wholesale.
    if BlzGetUnitAbilityCooldownRemaining and BlzStartUnitAbilityCooldown then
       local left=BlzGetUnitAbilityCooldownRemaining(caster,ability)
       if left>2 then BlzStartUnitAbilityCooldown(caster,ability,math.max(1,left*.9)) end
    end
 end
end
function A.onEnemyKill(enemy,elite)
 local killer=GetKillingUnit()
 if not killer then return end
 local pid=GetPlayerId(GetOwningPlayer(killer))
 local hero=A.heroUnits[pid]
 if pid<0 or pid>3 or not hero or not A.alive(hero) then return end
 local effects=A.itemEffects(hero)
 if effects.execute then A.heal(hero,35) end
 if effects.war then A.itemStacks[pid]=math.min(30,(A.itemStacks[pid] or 0)+1) end
end
function A.onAttacked()
 local victim=GetTriggerUnit()
 local attacker=GetAttacker()
 if not A.alive(victim) or not A.alive(attacker) then return end
 if A.itemHero(attacker) then
    local pid=GetPlayerId(GetOwningPlayer(attacker))
    A.itemProc[pid]=A.itemProc[pid] or {}
    local proc=A.itemProc[pid]
    proc.hits=(proc.hits or 0)+1
    local effects=A.itemEffects(attacker)
    if effects.combo and proc.hits%4==0 then A.area(attacker,GetUnitX(victim),GetUnitY(victim),180,45) end
    if effects.cleave and proc.hits%3==0 then A.area(attacker,GetUnitX(attacker),GetUnitY(attacker),280,75) end
    if effects.frost or effects.iceblast then
       if proc.hits%3==0 then
          A.damage(attacker,victim,effects.iceblast and 85 or 35)
          A.visual([[Abilities\Spells\Undead\FrostNova\FrostNovaTarget.mdl]],GetUnitX(victim),GetUnitY(victim),1.0)
       end
    end
    if effects.war then A.damage(attacker,victim,(A.itemStacks[pid] or 0)*2) end
 end
end
function A.onItemDamage()
 local victim=GetTriggerUnit()
 if not A.itemHero(victim) then return end
 local effects=A.itemEffects(victim)
 local pid=GetPlayerId(GetOwningPlayer(victim))
 local now=A.clock
 if effects.spellguard then
    if BlzGetEventDamageType and BlzGetEventDamageType()==DAMAGE_TYPE_MAGIC then
       BlzSetEventDamage(GetEventDamage()*.82)
    end
 end
 if effects.stone or effects.barrier then
    if (A.lastItemHeal[pid] or -100)+11<now then
       A.guard(victim,effects.stone and 3.0 or 1.7)
       A.lastItemHeal[pid]=now
    end
 end
 if effects.laststand then
    if GetWidgetLife(victim)<GetUnitState(victim,UNIT_STATE_MAX_LIFE)*.28
       and (A.lastItemHeal[pid] or -100)+35<now then
       A.heal(victim,260)
       A.guard(victim,4.0)
       A.lastItemHeal[pid]=now
    end
 end
end
function A.tickItems()
 if math.floor(A.clock*4)%12~=0 then return end
 for pid=0,3 do
    local hero=A.heroUnits[pid]
    if A.alive(hero) then
       local fx=A.itemEffects(hero)
       if fx.regen then A.heal(hero,12) end
       if fx.focus then A.mana(hero,8) end
       if fx.oracle then A.teamHeal(hero,18,480) end
    end
 end
end
function A.initItems()
 local t=CreateTrigger()
 TriggerRegisterAnyUnitEventBJ(t,EVENT_PLAYER_UNIT_USE_ITEM)
 TriggerAddAction(t,function()A.activeItem(GetTriggerUnit(),GetManipulatedItem())end)
 local hits=CreateTrigger()
 TriggerRegisterAnyUnitEventBJ(hits,EVENT_PLAYER_UNIT_ATTACKED)
 TriggerAddAction(hits,A.onAttacked)
 local damage=CreateTrigger()
 for pid=0,3 do TriggerRegisterPlayerUnitEvent(damage,Player(pid),EVENT_PLAYER_UNIT_DAMAGING,nil) end
 TriggerAddAction(damage,A.onItemDamage)
end
function A.initExperience()
 -- XP is granted in Arena.enemyDied *before* tracked enemies are removed.
 -- war3mapMisc.txt disables regular neutral-creep experience.
end
