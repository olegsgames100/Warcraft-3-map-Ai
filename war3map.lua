gg_trg_Untitled_Trigger_001 = nil
function InitGlobals()
end

-- ===========================================================================
-- Map Script: Warcraft III Reforged (Lua Mode) — FULL COMPLETE VERSION
-- Вставлять целиком в Trigger Editor (F4) -> Custom Script Code
-- ===========================================================================

Arena_Initialized = false
Arena_Started = false
Arena_Countdown = 0
CastSpamGuard = {}
LuaCallbacks = {}
LuaCallbackId = 0
DummyHeroes = {}

function IsModZero(val, div)
    if div == 0 then return false end
    return (val - math.floor(val / div) * div) == 0
end

function IsDivBy5(n)
    return (n - math.floor(n / 5) * 5) == 0
end

function KeepAlive(fn)
    LuaCallbackId = LuaCallbackId + 1
    local wrapped = function()
        local status, err = xpcall(fn, debug.traceback)
        if not status then
            DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 60.0, "|cffff0000[LUA ERROR]:|r " .. tostring(err))
        end
    end
    LuaCallbacks[LuaCallbackId] = wrapped
    return wrapped
end

function SafeTimerStart(whichTimer, timeout, periodic, handlerFunc)
    if handlerFunc == nil then
        TimerStart(whichTimer, timeout, periodic, nil)
    else
        TimerStart(whichTimer, timeout, periodic, KeepAlive(handlerFunc))
    end
end

function ID(code)
    if type(code) ~= "string" or #code ~= 4 then
        return 0
    end
    local b1, b2, b3, b4 = string.byte(code, 1, 4)
    return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
end

function SafeRun(fn)
    return KeepAlive(fn)
end

function NativeRegisterAnyUnitEvent(trig, whichEvent)
    for i = 0, 15 do
        TriggerRegisterPlayerUnitEvent(trig, Player(i), whichEvent, nil)
    end
end

function Arena_Msg(text)
    DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 10.0, text)
end

function Arena_FloatingCastText(unit, text)
    local tt = CreateTextTag()
    if tt ~= nil then
        SetTextTagText(tt, "|cffffcc00" .. text .. "!|r", 0.024)
        SetTextTagPosUnit(tt, unit, 40.0)
        SetTextTagVelocity(tt, 0.0, 0.03)
        SetTextTagPermanent(tt, false)
        SetTextTagLifespan(tt, 2.0)
        SetTextTagFadepoint(tt, 1.2)
    end
end

-- ===========================================================================
-- 1. ИНИЦИАЛИЗАЦИЯ ДАННЫХ, КЛАССОВ И РЕЦЕПТОВ
-- ===========================================================================

function Arena_InitData()
    Heroes = {}
    HeroKind = {}
    BleedStacks = {}
    BombardierTraps = {}
    BombardierRocketState = {}
    ShrapnelDebuffs = {}
    RoninDeepCut = {}
    RoninParryState = {}
    RoninCleaveTimer = {}
    ColossusDamageTaken = {}
    PriestessCoronaShield = {}
    PriestessSunState = {}
    DruidSummons = {}
    DruidDeepwoodColossus = {}
    LichSkeletons = {}
    LichRevenant = {}
    LichWyrm = {}
    ChronoParadoxSaved = {}
    InductionStacks = {}
    StormSupercharge = {}
    GrandChronosphereActive = {}

    udg_Wave = 0
    udg_HumanCount = 1
    udg_EnemiesAlive = 0
    udg_TotalKills = 0
    udg_BossPhase = 0
    udg_WavesStarted = false
    udg_GameOver = false
    udg_WaveCleared = false
    udg_Boss = nil
    udg_WaveTimer = nil
    udg_WaveTD = nil
    udg_WaveExpireTrig = nil
    udg_ReviveTimer = {}
    udg_PlayerKills = {0, 0, 0, 0}

    HeroClasses = {
        { id = ID('Hpal'), name = "1. Тёмный Рыцарь (Сила / Танк)", role = "tank", spells = {ID('A101'), ID('A102'), ID('A10D'), ID('A10E')} },
        { id = ID('Obla'), name = "2. Призрачный Ловчий (Ловкость / Ассасин)", role = "assassin", spells = {ID('A103'), ID('A104'), ID('A10F'), ID('A10G')} },
        { id = ID('Hamg'), name = "3. Элементалист Бури (Интеллект / АоЕ-Маг)", role = "mage", spells = {ID('A105'), ID('A106'), ID('A10H'), ID('A10I')} },
        { id = ID('Udea'), name = "4. Хранитель Древней (Сила / Саммонер)", role = "summoner", spells = {ID('A107'), ID('A108'), ID('A10J'), ID('A10K')} },
        { id = ID('Edem'), name = "5. Архилич Чумы (Интеллект / Некромант)", role = "dot_control", spells = {ID('A109'), ID('A10A'), ID('A10L'), ID('A10M')} },
        { id = ID('Hmkg'), name = "6. Мастер Клинка-Ронин (Ловкость / Керри)", role = "carry", spells = {ID('A115'), ID('A116'), ID('A117'), ID('A118')} },
        { id = ID('Emoo'), name = "7. Жрица Рассвета (Интеллект / Саппорт)", role = "healer", spells = {ID('A10B'), ID('A10C'), ID('A10N'), ID('A10O')} },
        { id = ID('Nalc'), name = "8. Инженер-Бомбардир (Ловкость / Осада)", role = "siege", spells = {ID('A111'), ID('A112'), ID('A113'), ID('A114')} },
        { id = ID('Ewar'), name = "9. Железный Исполин (Сила / Инициатор)", role = "initiator", spells = {ID('A119'), ID('A11A'), ID('A11B'), ID('A11C')} },
        { id = ID('Ulic'), name = "10. Хрономант (Интеллект / Контроль Времени)", role = "control", spells = {ID('A11D'), ID('A11E'), ID('A11F'), ID('A11G')} }
    }

    ItemCraftRecipes = {
        { result = ID('I001'), components = { ID('boot'), ID('glov') }, name = "Сапоги Скитальца" },
        { result = ID('I002'), components = { ID('rng1'), ID('prt5') }, name = "Каменный Бастион" },
        { result = ID('I003'), components = { ID('rat6'), ID('glov') }, name = "Жало Пустоты" },
        { result = ID('I004'), components = { ID('I000'), ID('pman') }, name = "Кодекс Тайной Магии" },
        { result = ID('I005'), components = { ID('I002'), ID('I00G') }, name = "Эгида Несокрушимости" },
        { result = ID('I006'), components = { ID('I003'), ID('I00V') }, name = "Погибель Миров: Клык Королевы" },
        { result = ID('I007'), components = { ID('rat6'), ID('belv'), ID('I00F') }, name = "Секира Пекла" },
        { result = ID('I008'), components = { ID('I004'), ID('I00E') }, name = "Астральный Скипетр Времени" },
        { result = ID('I009'), components = { ID('I001'), ID('I00C') }, name = "Призрачные Поступи" }
    }

    HeroDialog = nil
    HeroDialogButtons = {}
    HeroButtonTriggers = {}
end

function Arena_CheckItemCrafting(hero)
    if hero == nil or GetWidgetLife(hero) <= 0.405 then return end

    for _, recipe in ipairs(ItemCraftRecipes) do
        local hasAll = true
        local matchedSlots = {}

        for _, reqComp in ipairs(recipe.components) do
            local found = false
            for slot = 0, 5 do
                local it = UnitItemInSlot(hero, slot)
                if it ~= nil and GetItemTypeId(it) == reqComp and not matchedSlots[slot] then
                    matchedSlots[slot] = it
                    found = true
                    break
                end
            end
            if not found then
                hasAll = false
                break
            end
        end

        if hasAll then
            for _, it in pairs(matchedSlots) do
                RemoveItem(it)
            end
            UnitAddItemById(hero, recipe.result)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIam\\AIamTarget.mdl", hero, "origin"))
            DisplayTimedTextToPlayer(GetOwningPlayer(hero), 0, 0, 8.0, "|cffffcc00[АРТЕФАКТ СОБРАН]:|r " .. recipe.name)
            break
        end
    end
end

-- ===========================================================================
-- 2. СПОСОБНОСТИ ГЕРОЕВ
-- ===========================================================================

function Arena_CustomCast_Lua(caster, pid, spellId)
    if caster == nil then return end

    local cid = GetHandleId(caster)
    local guardKey = tostring(cid) .. "_" .. tostring(spellId)
    if CastSpamGuard[guardKey] then return end
    CastSpamGuard[guardKey] = true
    local guardTimer = CreateTimer()
    SafeTimerStart(guardTimer, 0.20, false, function()
        CastSpamGuard[guardKey] = nil
        DestroyTimer(guardTimer)
    end)

    local role = HeroKind[cid] or HeroKind[pid]
    if not role then
        for k, h in pairs(Heroes) do
            if h == caster then
                role = HeroKind[k]
                break
            end
        end
    end
    if not role then return end

    local rank = GetUnitAbilityLevel(caster, spellId)
    if rank < 1 then rank = 1 end

    local amount = 35.0 + 25.0 * rank

    if role == 1 then
        if spellId == ID('A101') then
            Arena_FloatingCastText(caster, "Хватка Смерти")
            Arena_PullArea(caster, 500.0, 0.5, amount * 2.0)
        elseif spellId == ID('A102') then
            Arena_FloatingCastText(caster, "Кровавая Жатва")
            Arena_BloodHarvestActive(caster, amount * 0.08)
        elseif spellId == ID('A10D') then
            Arena_FloatingCastText(caster, "Щит Мучений")
            Arena_ShieldOfTorment(caster, amount * 3.5, 10 + rank * 5, 8.0)
            Arena_CustomArea(caster, 350.0, amount * 1.2, false)
        elseif spellId == ID('A10E') then
            Arena_FloatingCastText(caster, "Цепи Рока")
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\DarkRitual\\DarkRitualCaster.mdl", GetUnitX(caster), GetUnitY(caster)))
            Arena_DoomChains(caster, 500.0, 4.0)
            Arena_CustomFinisher(caster, amount * 5.0)
        end
    elseif role == 4 then
        if spellId == ID('A107') then
            Arena_FloatingCastText(caster, "Призыв Древня")
            Arena_Druid_Q(caster, rank)
        elseif spellId == ID('A108') then
            Arena_FloatingCastText(caster, "Ядовитые Споры")
            Arena_Druid_W(caster, rank)
        elseif spellId == ID('A10J') then
            Arena_FloatingCastText(caster, "Дар Природы")
            Arena_Druid_E(caster, rank)
        elseif spellId == ID('A10K') then
            Arena_FloatingCastText(caster, "Колосс Дремучего Леса")
            Arena_Druid_R(caster, rank)
        end
    elseif role == 6 then
        if spellId == ID('A115') then
            Arena_FloatingCastText(caster, "Поток Клинка")
            Arena_Ronin_Q(caster, rank)
        elseif spellId == ID('A116') then
            Arena_FloatingCastText(caster, "Стойка Парирования")
            Arena_Ronin_W(caster, rank)
        elseif spellId == ID('A117') then
            Arena_FloatingCastText(caster, "Глубокий Разрез")
            Arena_Ronin_E(caster, rank)
        elseif spellId == ID('A118') then
            Arena_FloatingCastText(caster, "Разрез Измерений")
            Arena_Ronin_R(caster, rank)
        end
    elseif role == 9 then
        if spellId == ID('A119') then
            Arena_FloatingCastText(caster, "Ракетный Захват")
            Arena_Colossus_Q(caster, rank)
        elseif spellId == ID('A11A') then
            Arena_FloatingCastText(caster, "Выброс Пара")
            Arena_Colossus_W(caster, rank)
        elseif spellId == ID('A11B') then
            Arena_FloatingCastText(caster, "Литая Броня")
            Arena_Colossus_E(caster, rank)
        elseif spellId == ID('A11C') then
            Arena_FloatingCastText(caster, "Гравитационный Молот")
            Arena_Colossus_R(caster, rank)
        end
    elseif role == 2 then
        if spellId == ID('A103') then
            Arena_FloatingCastText(caster, "Теневой Рывок")
            Arena_CustomFinisher(caster, amount * 2.2)
            Arena_CustomMove(caster, 250.0)
            local g = CreateGroup()
            GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), 350.0, nil)
            local u = FirstOfGroup(g)
            while u ~= nil do
                GroupRemoveUnit(g, u)
                if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
                    Arena_ApplyBleedStack(u, caster, 2, 8.0)
                end
                u = FirstOfGroup(g)
            end
            DestroyGroup(g)
        elseif spellId == ID('A104') then
            Arena_FloatingCastText(caster, "Уход в Тень")
            Arena_DivineShield(caster, 2.0 + rank * 0.5)
        elseif spellId == ID('A10F') then
            Arena_FloatingCastText(caster, "Веер Клинков")
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\Blink\\BlinkCaster.mdl", caster, "origin"))
            Arena_CustomFinisher(caster, amount * 3.5)
            local g = CreateGroup()
            GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), 300.0, nil)
            local u = FirstOfGroup(g)
            while u ~= nil do
                GroupRemoveUnit(g, u)
                if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
                    Arena_ApplyBleedStack(u, caster, 3, 10.0)
                end
                u = FirstOfGroup(g)
            end
            DestroyGroup(g)
        elseif spellId == ID('A10G') then
            Arena_FloatingCastText(caster, "Танец Теней")
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\Blink\\BlinkTarget.mdl", caster, "origin"))
            Arena_Omnislash(caster, 5, amount * 1.8)
            local g = CreateGroup()
            GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), 450.0, nil)
            local u = FirstOfGroup(g)
            while u ~= nil do
                GroupRemoveUnit(g, u)
                if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
                    Arena_ApplyBleedStack(u, caster, 5, 12.0)
                end
                u = FirstOfGroup(g)
            end
            DestroyGroup(g)
        end
    elseif role == 3 then
        if spellId == ID('A105') then
            Arena_FloatingCastText(caster, "Цепная Молния")
            Arena_Storm_Q(caster, rank)
        elseif spellId == ID('A106') then
            Arena_FloatingCastText(caster, "Грозовой Фронт")
            Arena_Storm_W(caster, rank)
        elseif spellId == ID('A10H') then
            Arena_FloatingCastText(caster, "Сверхпроводимость")
            Arena_Storm_E(caster, rank)
        elseif spellId == ID('A10I') then
            Arena_FloatingCastText(caster, "Око Бури")
            Arena_Storm_R(caster, rank)
        end
    elseif role == 5 then
        if spellId == ID('A109') then
            Arena_FloatingCastText(caster, "Жатва Костей")
            Arena_Lich_Q(caster, rank)
        elseif spellId == ID('A10A') then
            Arena_FloatingCastText(caster, "Ледяной Ревенант")
            Arena_Lich_W(caster, rank)
        elseif spellId == ID('A10L') then
            Arena_FloatingCastText(caster, "Чумная Детонация")
            Arena_Lich_E(caster, rank)
        elseif spellId == ID('A10M') then
            Arena_FloatingCastText(caster, "Ледяной Змей")
            Arena_Lich_R(caster, rank)
        end
    elseif role == 7 then
        if spellId == ID('A10B') then
            Arena_FloatingCastText(caster, "Луч Рассвета")
            Arena_Priestess_Q(caster, rank)
        elseif spellId == ID('A10C') then
            Arena_FloatingCastText(caster, "Солнечная Корона")
            Arena_Priestess_W(caster, rank)
        elseif spellId == ID('A10N') then
            Arena_FloatingCastText(caster, "Сияние Зари")
            Arena_Priestess_E(caster, rank)
        elseif spellId == ID('A10O') then
            Arena_FloatingCastText(caster, "Восход Солнца")
            Arena_Priestess_R(caster, rank)
        end
    elseif role == 8 then
        if spellId == ID('A111') then
            Arena_FloatingCastText(caster, "Кассетный Заряд")
            Arena_Bombardier_Q(caster, rank)
        elseif spellId == ID('A112') then
            Arena_FloatingCastText(caster, "Капкан-Растяжка")
            Arena_Bombardier_W(caster, rank)
        elseif spellId == ID('A113') then
            Arena_FloatingCastText(caster, "Залп Шрапнели")
            Arena_Bombardier_E(caster, rank)
        elseif spellId == ID('A114') then
            Arena_FloatingCastText(caster, "Ракетная Батарея")
            Arena_Bombardier_R(caster, rank)
        end
    elseif role == 10 then
        if spellId == ID('A11D') then
            Arena_FloatingCastText(caster, "Временной Парадокс")
            Arena_Chrono_Q(caster, rank)
        elseif spellId == ID('A11E') then
            Arena_FloatingCastText(caster, "Ускорение Эпох")
            Arena_Chrono_W(caster, rank)
        elseif spellId == ID('A11F') then
            Arena_FloatingCastText(caster, "Прыжок во Времени")
            Arena_Chrono_E(caster, rank)
        elseif spellId == ID('A11G') then
            Arena_FloatingCastText(caster, "Великая Хроносфера")
            Arena_Chrono_R(caster, rank)
        end
    end
end

function Arena_PullArea(caster, radius, delay, damageAmount)
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\DarkRitual\\DarkRitualCaster.mdl", cx, cy))
    local t = CreateTimer()
    SafeTimerStart(t, delay, false, function()
        local ncx, ncy = GetUnitX(caster), GetUnitY(caster)
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, ncx, ncy, radius, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
                SetUnitPosition(u, ncx + GetRandomReal(-40.0, 40.0), ncy + GetRandomReal(-40.0, 40.0))
                IssueTargetOrder(u, "attack", caster)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\HowlOfTerror\\HowlTarget.mdl", u, "overhead"))
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
        Arena_CustomArea(caster, radius, damageAmount, false)
        DestroyTimer(t)
    end)
end

function Arena_BloodHarvestActive(caster, amountPerMissingPercent)
    local totalMissingPercent = 0.0
    local heroCount = 0
    for i = 0, 15 do
        local h = Heroes[i]
        if h ~= nil and GetWidgetLife(h) > 0.405 then
            local maxHp = GetUnitState(h, UNIT_STATE_MAX_LIFE)
            local curHp = GetUnitState(h, UNIT_STATE_LIFE)
            if maxHp > 0 then
                local missingPct = (maxHp - curHp) / maxHp * 100.0
                totalMissingPercent = totalMissingPercent + missingPct
            end
            heroCount = heroCount + 1
        end
    end
    if heroCount < 1 then heroCount = 1 end
    local avgMissingPercent = totalMissingPercent / heroCount
    local healAmount = avgMissingPercent * amountPerMissingPercent
    if healAmount < 50.0 then healAmount = 50.0 end
    SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + healAmount)
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl", caster, "origin"))
end

function Arena_ShieldOfTorment(caster, shieldHp, armorBonus, duration)
    UnitAddAbility(caster, ID('Adev'))
    SetUnitAbilityLevel(caster, ID('Adev'), math.min(10, math.max(1, math.floor(armorBonus / 5))))
    UnitAddAbility(caster, ID('AImx'))
    SetUnitAbilityLevel(caster, ID('AImx'), 1)
    local curHp = GetUnitState(caster, UNIT_STATE_LIFE)
    SetUnitState(caster, UNIT_STATE_LIFE, curHp + shieldHp)
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\DivineShield\\DivineShieldTarget.mdl", caster, "origin"))
    local t = CreateTimer()
    SafeTimerStart(t, duration, false, function()
        UnitRemoveAbility(caster, ID('Adev'))
        UnitRemoveAbility(caster, ID('AImx'))
        DestroyTimer(t)
    end)
end

function Arena_ApplyBleedStack(target, caster, stacksToAdd, duration)
    if target == nil or GetWidgetLife(target) <= 0.405 then return end
    local id = GetHandleId(target)
    if not BleedStacks[id] then
        BleedStacks[id] = { count = 0, duration = duration, caster = caster, target = target }
    end
    BleedStacks[id].count = BleedStacks[id].count + stacksToAdd
    BleedStacks[id].duration = duration
    UnitAddAbility(target, ID('Ashs'))
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Blood\\BloodImpact.mdl", target, "origin"))
end

function Arena_InitBleedSystem()
    local t = CreateTimer()
    SafeTimerStart(t, 1.0, true, function()
        for id, data in pairs(BleedStacks) do
            local target = data.target
            if target ~= nil and GetWidgetLife(target) > 0.405 and data.count > 0 and data.duration > 0 then
                data.duration = data.duration - 1.0
                local dmg = data.count * 1.0
                UnitDamageTarget(data.caster, target, dmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Blood\\BloodImpact.mdl", target, "overhead"))
            else
                if target ~= nil then
                    UnitRemoveAbility(target, ID('Ashs'))
                end
                BleedStacks[id] = nil
            end
        end
    end)
end

function Arena_KnockbackArea(caster, radius, dist)
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, radius, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            local ux, uy = GetUnitX(u), GetUnitY(u)
            local angle = math.atan(uy - cy, ux - cx)
            local nx = ux + math.cos(angle) * dist
            local ny = uy + math.sin(angle) * dist
            SetUnitPosition(u, nx, ny)
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\WarStomp\\WarStompCaster.mdl", nx, ny))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_DivineShield(caster, duration)
    SetUnitInvulnerable(caster, true)
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\DivineShield\\DivineShieldTarget.mdl", caster, "origin"))
    local t = CreateTimer()
    SafeTimerStart(t, duration, false, function()
        SetUnitInvulnerable(caster, false)
        DestroyTimer(t)
    end)
end

function Arena_DoomChains(caster, radius, duration)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), radius, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, 120.0, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            PauseUnit(u, true)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\EntanglingRoots\\EntanglingRootsTarget.mdl", u, "origin"))
            local victim = u
            local t = CreateTimer()
            SafeTimerStart(t, duration, false, function()
                if GetWidgetLife(victim) > 0.405 then
                    PauseUnit(victim, false)
                end
                DestroyTimer(t)
            end)
            break
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Omnislash(caster, count, damage)
    SetUnitInvulnerable(caster, true)
    local i = 0
    local t = CreateTimer()
    SafeTimerStart(t, 0.25, true, function()
        i = i + 1
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), 450.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
                SetUnitPosition(caster, GetUnitX(u), GetUnitY(u))
                UnitDamageTarget(caster, u, damage, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\Blink\\BlinkTarget.mdl", u, "origin"))
                break
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
        if i >= count then
            SetUnitInvulnerable(caster, false)
            DestroyTimer(t)
        end
    end)
end

function Arena_OnUnitAttack(attacker, target)
    if attacker == nil or target == nil then return end
    local pid = GetPlayerId(GetOwningPlayer(attacker))
    local cid = GetHandleId(attacker)
    local kind = HeroKind[cid] or HeroKind[pid]

    if kind then
        if kind == 3 then
            local st = StormSupercharge[cid]
            if st and st.active then
                local pInt = GetHeroInt(attacker, true)
                UnitDamageTarget(attacker, target, pInt * 1.2, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Monsoon\\MonsoonBoltTarget.mdl", target, "origin"))
                local tid = GetHandleId(target)
                if not InductionStacks[tid] then InductionStacks[tid] = { count = 0, target = target, caster = attacker } end
                InductionStacks[tid].count = math.min(5, InductionStacks[tid].count + 2)
                InductionStacks[tid].duration = 6.0
            end
        end

        local priestessAuraDmg = 0.0
        for ppid = 0, 15 do
            if Heroes[ppid] and GetWidgetLife(Heroes[ppid]) > 0.405 and HeroKind[ppid] == 7 then
                local prHero = Heroes[ppid]
                local rankE = GetUnitAbilityLevel(prHero, ID('A10N'))
                if rankE > 0 then
                    local distP = math.sqrt((GetUnitX(attacker) - GetUnitX(prHero))^2 + (GetUnitY(attacker) - GetUnitY(prHero))^2)
                    if distP <= 900.0 then
                        local prInt = GetHeroInt(prHero, true)
                        priestessAuraDmg = priestessAuraDmg + (prInt * 0.10)
                    end
                end
            end
        end
        if priestessAuraDmg > 0.0 then
            UnitDamageTarget(attacker, target, priestessAuraDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Resurrection\\ResurrectionTarget.mdl", target, "origin"))
        end

        if kind == 6 then
            local rankE = GetUnitAbilityLevel(attacker, ID('A117'))
            if rankE > 0 then
                Arena_Ronin_E_Attack(attacker, target, rankE)
            end
        elseif kind == 8 then
            local rankE = GetUnitAbilityLevel(attacker, ID('A113'))
            if rankE > 0 then
                Arena_Bombardier_E_Attack(attacker, target, rankE)
            end
            local st = BombardierRocketState[cid]
            if st and st.active then
                st.attackCount = st.attackCount + 1
                if IsModZero(st.attackCount, 2) then
                    Arena_Bombardier_FireRocket(attacker, target, st.rank)
                end
            end
        end
    end
end

function Arena_DetonateTrap(trap, caster, rank)
    if trap == nil or not trap.active then return end
    trap.active = false
    if trap.effect ~= nil then
        DestroyEffect(trap.effect)
        trap.effect = nil
    end

    local tx, ty = trap.x, trap.y
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\LightningShield\\LightningShieldTarget.mdl", tx, ty))
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", tx, ty))

    local trapDmg = 150.0 + 100.0 * rank
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, tx, ty, 350.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, trapDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            PauseUnit(u, true)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Thunderclap\\ThunderclapTarget.mdl", u, "overhead"))
            local st = u
            local t = CreateTimer()
            SafeTimerStart(t, 1.5, false, function()
                if GetWidgetLife(st) > 0.405 then
                    PauseUnit(st, false)
                end
                DestroyTimer(t)
            end)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Bombardier_Q(caster, rank)
    local tx = GetSpellTargetX()
    local ty = GetSpellTargetY()
    if tx == 0.0 and ty == 0.0 then
        local facing = GetUnitFacing(caster) * (math.pi / 180.0)
        tx = GetUnitX(caster) + math.cos(facing) * 300.0
        ty = GetUnitY(caster) + math.sin(facing) * 300.0
    end

    local centerDmg = 120.0 + 100.0 * (rank - 1)
    if rank == 3 then centerDmg = 340.0 end
    if rank >= 4 then centerDmg = 480.0 end

    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Bombster\\BombsterTarget.mdl", tx, ty))
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", tx, ty))

    local hitByCenter = {}
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, tx, ty, 275.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, centerDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            local uid = GetHandleId(u)
            hitByCenter[uid] = u
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)

    for _, trap in ipairs(BombardierTraps) do
        if trap.active then
            local dx = trap.x - tx
            local dy = trap.y - ty
            if (dx * dx + dy * dy) <= (350.0 * 350.0) then
                Arena_DetonateTrap(trap, caster, rank)
            end
        end
    end

    local fragDmg = 60.0 + 50.0 * (rank - 1)
    if rank == 3 then fragDmg = 170.0 end
    if rank >= 4 then fragDmg = 240.0 end

    local angles = { 0.0, 1.5708, 3.14159, 4.71239 }
    local fragCoords = {}
    for i = 1, 4 do
        local fx = tx + math.cos(angles[i]) * 150.0
        local fy = ty + math.sin(angles[i]) * 150.0
        table.insert(fragCoords, { x = fx, y = fy })
    end

    local qTimer = CreateTimer()
    SafeTimerStart(qTimer, 0.5, false, function()
        local fragmentHitCounts = {}
        for _, fc in ipairs(fragCoords) do
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Bombster\\BombsterTarget.mdl", fc.x, fc.y))
            for _, trap in ipairs(BombardierTraps) do
                if trap.active then
                    local dx = trap.x - fc.x
                    local dy = trap.y - fc.y
                    if (dx * dx + dy * dy) <= (200.0 * 200.0) then
                        Arena_DetonateTrap(trap, caster, rank)
                    end
                end
            end
            local fg = CreateGroup()
            GroupEnumUnitsInRange(fg, fc.x, fc.y, 200.0, nil)
            local fu = FirstOfGroup(fg)
            while fu ~= nil do
                GroupRemoveUnit(fg, fu)
                if IsUnitEnemy(fu, GetOwningPlayer(caster)) and GetWidgetLife(fu) > 0.405 then
                    UnitDamageTarget(caster, fu, fragDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                    UnitAddAbility(fu, ID('Aslo'))
                    local fuid = GetHandleId(fu)
                    fragmentHitCounts[fuid] = (fragmentHitCounts[fuid] or 0) + 1
                end
                fu = FirstOfGroup(fg)
            end
            DestroyGroup(fg)
        end

        for fuid, count in pairs(fragmentHitCounts) do
            if count >= 2 and hitByCenter[fuid] ~= nil then
                local targetUnit = hitByCenter[fuid]
                if GetWidgetLife(targetUnit) > 0.405 then
                    PauseUnit(targetUnit, true)
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Thunderclap\\ThunderclapTarget.mdl", targetUnit, "overhead"))
                    local tu = targetUnit
                    local stTimer = CreateTimer()
                    SafeTimerStart(stTimer, 1.2, false, function()
                        if GetWidgetLife(tu) > 0.405 then
                            PauseUnit(tu, false)
                        end
                        DestroyTimer(stTimer)
                    end)
                end
            end
        end
        DestroyTimer(qTimer)
    end)
end

function Arena_Bombardier_W(caster, rank)
    local tx = GetSpellTargetX()
    local ty = GetSpellTargetY()
    if tx == 0.0 and ty == 0.0 then
        tx = GetUnitX(caster)
        ty = GetUnitY(caster)
    end

    local casterTraps = {}
    for i, trap in ipairs(BombardierTraps) do
        if trap.caster == caster and trap.active then
            table.insert(casterTraps, { index = i, trap = trap })
        end
    end

    if #casterTraps >= 3 then
        local oldest = casterTraps[1].trap
        oldest.active = false
        if oldest.effect ~= nil then
            DestroyEffect(oldest.effect)
            oldest.effect = nil
        end
    end

    local eff = AddSpecialEffect("Abilities\\Spells\\Orc\\StasisTrap\\StasisTotem.mdl", tx, ty)
    table.insert(BombardierTraps, {
        x = tx,
        y = ty,
        caster = caster,
        rank = rank,
        active = true,
        effect = eff
    })

    DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 3.0, "|cff00ff00[Инженер]:|r Капкан-растяжка установлен! (Всего: " .. (#casterTraps < 3 and (#casterTraps + 1) or 3) .. "/3)")
end

function Arena_ApplyShrapnelStack(target, caster, rank)
    if target == nil or GetWidgetLife(target) <= 0.405 then return end
    local tid = GetHandleId(target)
    if not ShrapnelDebuffs[tid] then
        ShrapnelDebuffs[tid] = { stacks = 0, duration = 3.0, caster = caster, rank = rank, target = target }
    end
    local data = ShrapnelDebuffs[tid]
    if data.stacks < 3 then
        data.stacks = data.stacks + 1
    end
    data.duration = 3.0
    data.rank = rank
    data.caster = caster
    UnitAddAbility(target, ID('ACrf'))
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\FaerieFire\\FaerieFireTarget.mdl", target, "overhead"))
end

function Arena_Bombardier_E(caster, rank)
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\NeutralExplode\\NeutralExplode.mdl", cx, cy))
    local burstDmg = 100.0 + 80.0 * rank
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 350.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, burstDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            Arena_ApplyShrapnelStack(u, caster, rank)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Bombardier_E_Attack(attacker, target, rank)
    if attacker == nil or target == nil then return end
    local agi = GetHeroAgi(attacker, true)
    local splashPct = 0.35 + 0.15 * (rank - 1)
    local baseDmg = 40.0 + 20.0 * rank + agi * 0.5
    local splashDmg = baseDmg * splashPct
    local tx, ty = GetUnitX(target), GetUnitY(target)
    Arena_ApplyShrapnelStack(target, attacker, rank)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, tx, ty, 250.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if u ~= target and IsUnitEnemy(u, GetOwningPlayer(attacker)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(attacker, u, splashDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            Arena_ApplyShrapnelStack(u, attacker, rank)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Bombardier_R(caster, rank)
    local cid = GetHandleId(caster)
    local st = BombardierRocketState[cid]
    if st == nil or not st.active then
        BombardierRocketState[cid] = {
            active = true,
            duration = 12.0,
            attackCount = 0,
            rank = rank,
            caster = caster
        }
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Avatar\\AvatarCaster.mdl", caster, "origin"))
        SetUnitMoveSpeed(caster, GetUnitDefaultMoveSpeed(caster) * 1.15)
        DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 5.0, "|cffffcc00[АРТИЛЛЕРИЯ]:|r Мобильная ракетная батарея АКТИВИРОВАНА на 12 секунд!")
    else
        st.active = false
        SetUnitMoveSpeed(caster, GetUnitDefaultMoveSpeed(caster))
        local bx, by = GetUnitX(caster), GetUnitY(caster)
        DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 4.0, "|cffff0000[АВАРИЙНЫЙ СБРОС]:|r Ракетная батарея сброшена! Детонация через 1 секунду!")
        local jettisonEff = AddSpecialEffect("Abilities\\Spells\\Human\\SiegeEngine\\SiegeEngineTarget.mdl", bx, by)
        local jTimer = CreateTimer()
        SafeTimerStart(jTimer, 1.0, false, function()
            DestroyEffect(jettisonEff)
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\NeutralExplode\\NeutralExplode.mdl", bx, by))
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", bx, by))
            local agi = GetHeroAgi(caster, true)
            local overloadDmg = 500.0 + 350.0 * (rank - 1) + agi * 2.0
            if rank == 3 then overloadDmg = 850.0 + agi * 2.0 end
            if rank >= 4 then overloadDmg = 1300.0 + agi * 2.0 end
            local g = CreateGroup()
            GroupEnumUnitsInRange(g, bx, by, 450.0, nil)
            local u = FirstOfGroup(g)
            while u ~= nil do
                GroupRemoveUnit(g, u)
                if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
                    UnitDamageTarget(caster, u, overloadDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                    PauseUnit(u, true)
                    local tu = u
                    local stt = CreateTimer()
                    SafeTimerStart(stt, 1.0, false, function()
                        if GetWidgetLife(tu) > 0.405 then PauseUnit(tu, false) end
                        DestroyTimer(stt)
                    end)
                end
                u = FirstOfGroup(g)
            end
            DestroyGroup(g)
            Arena_KnockbackArea(caster, 450.0, 400.0)
            for _, trap in ipairs(BombardierTraps) do
                if trap.active then
                    local dx = trap.x - bx
                    local dy = trap.y - by
                    if (dx * dx + dy * dy) <= (450.0 * 450.0) then
                        Arena_DetonateTrap(trap, caster, rank)
                    end
                end
            end
            DestroyTimer(jTimer)
        end)
    end
end

function Arena_Bombardier_FireRocket(caster, target, rank)
    if caster == nil or target == nil or GetWidgetLife(target) <= 0.405 then return end
    local tx, ty = GetUnitX(target), GetUnitY(target)
    DestroyEffect(AddSpecialEffect("Abilities\\Weapons\\RocketMissile\\RocketMissile.mdl", tx, ty))
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Bombster\\BombsterTarget.mdl", tx, ty))
    local agi = GetHeroAgi(caster, true)
    local rDmg = 250.0 + 200.0 * (rank - 1) + agi * 1.2
    if rank == 3 then rDmg = 700.0 + agi * 1.2 end
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, tx, ty, 250.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, rDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            PauseUnit(u, true)
            local tu = u
            local t = CreateTimer()
            SafeTimerStart(t, 0.3, false, function()
                if GetWidgetLife(tu) > 0.405 then PauseUnit(tu, false) end
                DestroyTimer(t)
            end)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Ronin_Q(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local tx, ty = GetSpellTargetX(), GetSpellTargetY()
    local dx = tx - cx
    local dy = ty - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local angle = GetUnitFacing(caster) * (math.pi / 180.0)
    if dist > 10.0 then
        angle = math.atan(dy, dx)
    end
    local dashDist = 650.0
    local endX = cx + math.cos(angle) * dashDist
    local endY = cy + math.sin(angle) * dashDist
    SetUnitPathing(caster, false)
    SetUnitPosition(caster, endX, endY)
    SetUnitPathing(caster, true)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\NightElf\\Blink\\BlinkCaster.mdl", cx, cy))
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\NightElf\\Blink\\BlinkTarget.mdl", endX, endY))
    local atkDmg = (BlzGetUnitBaseDamage and BlzGetUnitBaseDamage(caster, 0) or 50.0)
    local baseDmg = 100.0 + 80.0 * (rank - 1)
    if rank == 3 then baseDmg = 260.0 end
    if rank >= 4 then baseDmg = 340.0 end
    local totalDmg = baseDmg + (atkDmg * 1.2)
    local killedUnit = false
    local hitBoss = false
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, (cx + endX) * 0.5, (cy + endY) * 0.5, 350.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, totalDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\HeroBladeMaster\\BladeMasterTarget.mdl", u, "chest"))
            if GetWidgetLife(u) <= 0.405 then
                killedUnit = true
            end
            if udg_Boss ~= nil and u == udg_Boss then
                hitBoss = true
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
    if killedUnit then
        if UnitResetCooldowns then UnitResetCooldowns(caster) elseif UnitResetCooldown then UnitResetCooldown(caster) end
        local maxHp = GetUnitState(caster, UNIT_STATE_MAX_LIFE)
        local curHp = GetUnitState(caster, UNIT_STATE_LIFE)
        SetUnitState(caster, UNIT_STATE_LIFE, curHp + maxHp * 0.03)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Heal\\HealTarget.mdl", caster, "origin"))
    elseif hitBoss then
        local t = CreateTimer()
        SafeTimerStart(t, 0.1, false, function()
            if BlzStartUnitAbilityCooldown then BlzStartUnitAbilityCooldown(caster, ID('A115'), 4.0) end
            DestroyTimer(t)
        end)
    end
end

function Arena_Ronin_W(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cid = GetHandleId(caster)
    RoninParryState[cid] = {
        inStance = true,
        rank = rank,
        caster = caster,
        buffActive = false,
        duration = 1.2
    }
    SetUnitInvulnerable(caster, true)
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\DivineShield\\DivineShieldTarget.mdl", caster, "origin"))
    local t = CreateTimer()
    SafeTimerStart(t, 1.2, false, function()
        SetUnitInvulnerable(caster, false)
        local st = RoninParryState[cid]
        if st and st.inStance then
            st.inStance = false
        end
        DestroyTimer(t)
    end)
end

function Arena_Ronin_CounterAttack(caster, absorbedDamage)
    local cid = GetHandleId(caster)
    local st = RoninParryState[cid]
    if st == nil or not st.inStance then return end
    st.inStance = false
    SetUnitInvulnerable(caster, false)
    local rank = st.rank or 1
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", cx, cy))
    local baseCounter = 150.0 + 100.0 * (rank - 1)
    if rank == 3 then baseCounter = 350.0 end
    if rank >= 4 then baseCounter = 450.0 end
    local bonus = absorbedDamage or 100.0
    if bonus > 500.0 then bonus = 500.0 end
    local counterDmg = baseCounter + bonus
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 300.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, counterDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            PauseUnit(u, true)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Thunderclap\\ThunderclapTarget.mdl", u, "overhead"))
            local tu = u
            local stTimer = CreateTimer()
            SafeTimerStart(stTimer, 1.2, false, function()
                if GetWidgetLife(tu) > 0.405 then PauseUnit(tu, false) end
                DestroyTimer(stTimer)
            end)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
    st.buffActive = true
    st.buffDuration = 4.0
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Orc\\Bloodlust\\BloodlustTarget.mdl", caster, "origin"))
end

function Arena_Ronin_E(caster, rank)
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\HeroBladeMaster\\BladeMasterTarget.mdl", cx, cy))
    local burstDmg = 120.0 + 80.0 * rank
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 300.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, burstDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_HERO, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Blood\\BloodImpact.mdl", u, "overhead"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Ronin_E_Attack(attacker, target, rank)
    if attacker == nil or target == nil then return end
    local tid = GetHandleId(target)
    if not RoninDeepCut[tid] then
        RoninDeepCut[tid] = { count = 0, caster = attacker }
    end
    local dc = RoninDeepCut[tid]
    dc.count = dc.count + 1
    if dc.count >= 3 then
        dc.count = 0
        local agi = GetHeroAgi(attacker, true)
        local bonusPure = 80.0 + 60.0 * (rank - 1) + agi * 0.8
        if rank == 3 then bonusPure = 200.0 + agi * 0.8 end
        if rank >= 4 then bonusPure = 260.0 + agi * 0.8 end
        UnitDamageTarget(attacker, target, bonusPure, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Blood\\BloodImpact.mdl", target, "chest"))
    end
    local cid = GetHandleId(attacker)
    local pSt = RoninParryState[cid]
    local hasWBuff = pSt and pSt.buffActive
    local rTime = RoninCleaveTimer[cid] or 0.0
    local hasRBuff = rTime > 0.0
    if hasWBuff or hasRBuff then
        local cleavePct = 0.40 + 0.15 * (rank - 1)
        local atkDmg = (BlzGetUnitBaseDamage and BlzGetUnitBaseDamage(attacker, 0) or 50.0)
        local cleaveDmg = atkDmg * cleavePct
        local tx, ty = GetUnitX(target), GetUnitY(target)
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, tx, ty, 250.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if u ~= target and IsUnitEnemy(u, GetOwningPlayer(attacker)) and GetWidgetLife(u) > 0.405 then
                UnitDamageTarget(attacker, u, cleaveDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\HeroBladeMaster\\BladeMasterTarget.mdl", u, "origin"))
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
    end
end

function Arena_Ronin_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local tx, ty = GetSpellTargetX(), GetSpellTargetY()
    local dx = tx - cx
    local dy = ty - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local angle = GetUnitFacing(caster) * (math.pi / 180.0)
    if dist > 10.0 then
        angle = math.atan(dy, dx)
    end
    local length = 900.0
    local endX = cx + math.cos(angle) * length
    local endY = cy + math.sin(angle) * length
    SetUnitInvulnerable(caster, true)
    PauseUnit(caster, true)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\NightElf\\Blink\\BlinkCaster.mdl", cx, cy))
    local frozenUnits = {}
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, (cx + endX) * 0.5, (cy + endY) * 0.5, 450.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            PauseUnit(u, true)
            table.insert(frozenUnits, u)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\FreezingBreath\\FreezingBreathTarget.mdl", u, "origin"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
    local channelTimer = CreateTimer()
    SafeTimerStart(channelTimer, 0.4, false, function()
        SetUnitInvulnerable(caster, false)
        PauseUnit(caster, false)
        SetUnitPathing(caster, false)
        SetUnitPosition(caster, endX, endY)
        SetUnitPathing(caster, true)
        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\NightElf\\Blink\\BlinkTarget.mdl", endX, endY))
        if UnitResetCooldowns then UnitResetCooldowns(caster) elseif UnitResetCooldown then UnitResetCooldown(caster) end
        local cid = GetHandleId(caster)
        RoninCleaveTimer[cid] = 6.0
        local burstTimer = CreateTimer()
        SafeTimerStart(burstTimer, 1.1, false, function()
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", (cx + endX) * 0.5, (cy + endY) * 0.5))
            local agi = GetHeroAgi(caster, true)
            local baseDmg = 500.0 + 300.0 * (rank - 1) + agi * 2.5
            if rank == 3 then baseDmg = 1200.0 + agi * 2.5 end
            for _, targetUnit in ipairs(frozenUnits) do
                if GetWidgetLife(targetUnit) > 0.405 then
                    PauseUnit(targetUnit, false)
                    if udg_Boss ~= nil and targetUnit == udg_Boss then
                        local bossCurHp = GetUnitState(targetUnit, UNIT_STATE_LIFE)
                        local bossDmg = baseDmg + (bossCurHp * 0.12)
                        UnitDamageTarget(caster, targetUnit, bossDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
                        UnitAddAbility(targetUnit, ID('ACrf'))
                        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Blood\\BloodImpact.mdl", targetUnit, "chest"))
                    else
                        local curHp = GetUnitState(targetUnit, UNIT_STATE_LIFE)
                        local maxHp = GetUnitState(targetUnit, UNIT_STATE_MAX_LIFE)
                        if (curHp / maxHp) < 0.20 then
                            SetWidgetLife(targetUnit, 0.0)
                            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Blood\\BloodImpact.mdl", targetUnit, "origin"))
                        else
                            UnitDamageTarget(caster, targetUnit, baseDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\HeroBladeMaster\\BladeMasterTarget.mdl", targetUnit, "chest"))
                        end
                    end
                end
            end
            DestroyTimer(burstTimer)
        end)
        DestroyTimer(channelTimer)
    end)
end

function Arena_Colossus_Q(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local tx, ty = GetSpellTargetX(), GetSpellTargetY()
    local dx = tx - cx
    local dy = ty - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local angle = GetUnitFacing(caster) * (math.pi / 180.0)
    if dist > 10.0 then
        angle = math.atan(dy, dx)
    end
    local fistDist = 700.0
    local targetX = cx + math.cos(angle) * fistDist
    local targetY = cy + math.sin(angle) * fistDist
    DestroyEffect(AddSpecialEffect("Abilities\\Weapons\\RocketMissile\\RocketMissile.mdl", targetX, targetY))
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\FlakCannons\\FlakTarget.mdl", targetX, targetY))
    local str = GetHeroStr(caster, true)
    local baseDmg = 140.0 + 80.0 * (rank - 1) + str * 1.0
    if rank == 3 then baseDmg = 300.0 + str * 1.0 end
    if rank >= 4 then baseDmg = 380.0 + str * 1.0 end
    local hitTarget = nil
    local isBoss = false
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, (cx + targetX) * 0.5, (cy + targetY) * 0.5, 400.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if hitTarget == nil and IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            hitTarget = u
            if udg_Boss ~= nil and u == udg_Boss then
                isBoss = true
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
    if hitTarget ~= nil then
        UnitDamageTarget(caster, hitTarget, baseDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
        PauseUnit(hitTarget, true)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Thunderclap\\ThunderclapTarget.mdl", hitTarget, "overhead"))
        local tu = hitTarget
        local stTimer = CreateTimer()
        SafeTimerStart(stTimer, 1.5, false, function()
            if GetWidgetLife(tu) > 0.405 then PauseUnit(tu, false) end
            DestroyTimer(stTimer)
        end)
        if isBoss then
            local bx, by = GetUnitX(hitTarget), GetUnitY(hitTarget)
            SetUnitPathing(caster, false)
            SetUnitPosition(caster, bx, by)
            SetUnitPathing(caster, true)
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\WarStomp\\WarStompCaster.mdl", bx, by))
        else
            local pulledCount = 0
            local pg = CreateGroup()
            GroupEnumUnitsInRange(pg, GetUnitX(hitTarget), GetUnitY(hitTarget), 250.0, nil)
            local pu = FirstOfGroup(pg)
            while pu ~= nil and pulledCount < 3 do
                GroupRemoveUnit(pg, pu)
                if IsUnitEnemy(pu, GetOwningPlayer(caster)) and GetWidgetLife(pu) > 0.405 then
                    SetUnitPosition(pu, cx + GetRandomReal(-50.0, 50.0), cy + GetRandomReal(-50.0, 50.0))
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\FlakCannons\\FlakTarget.mdl", pu, "origin"))
                    pulledCount = pulledCount + 1
                end
                pu = FirstOfGroup(pg)
            end
            DestroyGroup(pg)
        end
    end
end

function Arena_Colossus_W(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Incinerate\\IncinerateBuff.mdl", cx, cy))
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\FlakCannons\\FlakTarget.mdl", cx, cy))
    local steamDmg = 100.0 + 80.0 * (rank - 1)
    if rank == 3 then steamDmg = 260.0 end
    if rank >= 4 then steamDmg = 340.0 end
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 400.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, steamDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            UnitAddAbility(u, ID('Aslo'))
            if udg_Boss == nil or u ~= udg_Boss then
                IssueTargetOrder(u, "attack", caster)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\HowlOfTerror\\HowlTarget.mdl", u, "overhead"))
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Colossus_ShrapnelBurst(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\FlakCannons\\FlakTarget.mdl", cx, cy))
    local maxHp = GetUnitState(caster, UNIT_STATE_MAX_LIFE)
    local burstDmg = 60.0 + 40.0 * (rank - 1) + maxHp * 0.04
    if rank == 3 then burstDmg = 140.0 + maxHp * 0.04 end
    if rank >= 4 then burstDmg = 180.0 + maxHp * 0.04 end
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 350.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, burstDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Blood\\BloodImpact.mdl", u, "chest"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Colossus_E(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    UnitAddAbility(caster, ID('Adef'))
    Arena_Colossus_ShrapnelBurst(caster, rank)
end

function Arena_Colossus_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local facing = GetUnitFacing(caster) * (math.pi / 180.0)
    local cx = GetUnitX(caster) + math.cos(facing) * 200.0
    local cy = GetUnitY(caster) + math.sin(facing) * 200.0
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTarget.mdl", cx, cy))
    local pulledUnits = {}
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 650.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            PauseUnit(u, true)
            table.insert(pulledUnits, u)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
    local pullTicks = 0
    local pTimer = CreateTimer()
    SafeTimerStart(pTimer, 0.1, true, function()
        pullTicks = pullTicks + 1
        for _, pu in ipairs(pulledUnits) do
            if GetWidgetLife(pu) > 0.405 then
                local ux, uy = GetUnitX(pu), GetUnitY(pu)
                local angle = math.atan(cy - uy, cx - ux)
                SetUnitPosition(pu, ux + math.cos(angle) * 35.0, uy + math.sin(angle) * 35.0)
            end
        end
        if pullTicks >= 15 then
            DestroyTimer(pTimer)
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", cx, cy))
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\WarStomp\\WarStompCaster.mdl", cx, cy))
            local str = GetHeroStr(caster, true)
            local hammerDmg = 450.0 + 300.0 * (rank - 1) + str * 2.5
            if rank == 3 then hammerDmg = 1100.0 + str * 2.5 end
            for _, pu in ipairs(pulledUnits) do
                if GetWidgetLife(pu) > 0.405 then
                    PauseUnit(pu, false)
                    UnitDamageTarget(caster, pu, hammerDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                    local stunDur = 2.5
                    if udg_Boss ~= nil and pu == udg_Boss then stunDur = 1.5 end
                    PauseUnit(pu, true)
                    UnitAddAbility(pu, ID('ACrf'))
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\FaerieFire\\FaerieFireTarget.mdl", pu, "overhead"))
                    local stu = pu
                    local sTimer = CreateTimer()
                    SafeTimerStart(sTimer, stunDur, false, function()
                        if GetWidgetLife(stu) > 0.405 then PauseUnit(stu, false) end
                        DestroyTimer(sTimer)
                    end)
                end
            end
        end
    end)
end

function Arena_Priestess_Q(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local tx, ty = GetSpellTargetX(), GetSpellTargetY()
    local dx = tx - cx
    local dy = ty - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local angle = GetUnitFacing(caster) * (math.pi / 180.0)
    if dist > 10.0 then
        angle = math.atan(dy, dx)
    end
    local beamLen = 800.0
    local endX = cx + math.cos(angle) * beamLen
    local endY = cy + math.sin(angle) * beamLen
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Resurrection\\ResurrectionTarget.mdl", (cx + endX) * 0.5, (cy + endY) * 0.5))
    local pInt = GetHeroInt(caster, true)
    local baseAmount = 140.0 + 100.0 * (rank - 1) + pInt * 1.2
    if rank == 3 then baseAmount = 360.0 + pInt * 1.2 end
    if rank >= 4 then baseAmount = 500.0 + pInt * 1.2 end
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, (cx + endX) * 0.5, (cy + endY) * 0.5, 450.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if GetWidgetLife(u) > 0.405 then
            if IsUnitAlly(u, GetOwningPlayer(caster)) then
                local maxHp = GetUnitState(u, UNIT_STATE_MAX_LIFE)
                local curHp = GetUnitState(u, UNIT_STATE_LIFE)
                local missingHp = maxHp - curHp
                local healVal = baseAmount + (missingHp * 0.04)
                SetUnitState(u, UNIT_STATE_LIFE, math.min(maxHp, curHp + healVal))
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Heal\\HealTarget.mdl", u, "origin"))
            elseif IsUnitEnemy(u, GetOwningPlayer(caster)) then
                UnitDamageTarget(caster, u, baseAmount, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                UnitAddAbility(u, ID('Aslo'))
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl", u, "origin"))
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Priestess_W(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local target = GetSpellTargetUnit()
    if target == nil then target = caster end
    UnitRemoveAbility(target, ID('Ashs'))
    UnitRemoveAbility(target, ID('ACrf'))
    UnitRemoveAbility(target, ID('Aslo'))
    local pInt = GetHeroInt(caster, true)
    local shieldAmount = 300.0 + 250.0 * (rank - 1) + pInt * 1.5
    if rank == 3 then shieldAmount = 800.0 + pInt * 1.5 end
    if rank >= 4 then shieldAmount = 1100.0 + pInt * 1.5 end
    local tid = GetHandleId(target)
    PriestessCoronaShield[tid] = {
        amount = shieldAmount,
        target = target,
        caster = caster,
        rank = rank,
        duration = 5.0
    }
    SetUnitMoveSpeed(target, GetUnitDefaultMoveSpeed(target) * 1.35)
    local eff = AddSpecialEffectTarget("Abilities\\Spells\\Human\\DivineShield\\DivineShieldTarget.mdl", target, "origin")
    local t = CreateTimer()
    SafeTimerStart(t, 5.0, false, function()
        DestroyEffect(eff)
        SetUnitMoveSpeed(target, GetUnitDefaultMoveSpeed(target))
        local st = PriestessCoronaShield[tid]
        if st ~= nil then
            PriestessCoronaShield[tid] = nil
            local tx, ty = GetUnitX(target), GetUnitY(target)
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", tx, ty))
            local g = CreateGroup()
            GroupEnumUnitsInRange(g, tx, ty, 300.0, nil)
            local u = FirstOfGroup(g)
            while u ~= nil do
                GroupRemoveUnit(g, u)
                if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
                    PauseUnit(u, true)
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Thunderclap\\ThunderclapTarget.mdl", u, "overhead"))
                    local tu = u
                    local stt = CreateTimer()
                    SafeTimerStart(stt, 1.2, false, function()
                        if GetWidgetLife(tu) > 0.405 then PauseUnit(tu, false) end
                        DestroyTimer(stt)
                    end)
                end
                u = FirstOfGroup(g)
            end
            DestroyGroup(g)
        end
        DestroyTimer(t)
    end)
end

function Arena_Priestess_E(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Resurrection\\ResurrectionTarget.mdl", cx, cy))
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 900.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitAlly(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            local curMp = GetUnitState(u, UNIT_STATE_MANA)
            local maxMp = GetUnitState(u, UNIT_STATE_MAX_MANA)
            SetUnitState(u, UNIT_STATE_MANA, math.min(maxMp, curMp + 50.0 + rank * 20.0))
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIam\\AIamTarget.mdl", u, "origin"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Priestess_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local sunEff = AddSpecialEffect("Abilities\\Spells\\Human\\Avatar\\AvatarCaster.mdl", cx, cy)
    PriestessSunState = {
        x = cx,
        y = cy,
        caster = caster,
        rank = rank,
        duration = 8.0,
        cheatDeathUsed = false
    }
    local t = CreateTimer()
    SafeTimerStart(t, 1.0, true, function()
        if PriestessSunState == nil or PriestessSunState.duration <= 0 then
            DestroyEffect(sunEff)
            PriestessSunState = nil
            DestroyTimer(t)
            return
        end
        PriestessSunState.duration = PriestessSunState.duration - 1.0
        local pInt = GetHeroInt(caster, true)
        local baseHeal = 150.0 + 100.0 * (rank - 1) + pInt * 0.5
        if rank == 3 then baseHeal = 400.0 + pInt * 0.5 end
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, cx, cy, 700.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if GetWidgetLife(u) > 0.405 then
                if IsUnitAlly(u, GetOwningPlayer(caster)) then
                    local maxHp = GetUnitState(u, UNIT_STATE_MAX_LIFE)
                    local curHp = GetUnitState(u, UNIT_STATE_LIFE)
                    SetUnitState(u, UNIT_STATE_LIFE, math.min(maxHp, curHp + baseHeal + maxHp * 0.03))
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Heal\\HealTarget.mdl", u, "origin"))
                    if not PriestessSunState.cheatDeathUsed and curHp < maxHp * 0.15 then
                        PriestessSunState.cheatDeathUsed = true
                        SetUnitState(u, UNIT_STATE_LIFE, maxHp * 0.30)
                        SetUnitInvulnerable(u, true)
                        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\DivineShield\\DivineShieldTarget.mdl", u, "origin"))
                        local tu = u
                        local cdTimer = CreateTimer()
                        SafeTimerStart(cdTimer, 1.5, false, function()
                            SetUnitInvulnerable(tu, false)
                            DestroyTimer(cdTimer)
                        end)
                    end
                elseif IsUnitEnemy(u, GetOwningPlayer(caster)) then
                    UnitDamageTarget(caster, u, baseHeal * 0.75, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl", u, "chest"))
                end
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
    end)
end

function Arena_Druid_Q(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local facing = GetUnitFacing(caster) * (math.pi / 180.0)
    local spawnX = cx + math.cos(facing) * 150.0
    local spawnY = cy + math.sin(facing) * 150.0
    local p = GetOwningPlayer(caster)
    local treant = CreateUnit(p, ID('entc'), spawnX, spawnY, GetUnitFacing(caster))
    if treant == nil then
        treant = CreateUnit(p, ID('efon'), spawnX, spawnY, GetUnitFacing(caster))
    end
    if treant == nil then return end
    local maxHpCaster = GetUnitState(caster, UNIT_STATE_MAX_LIFE)
    local treantHp = 800.0 + 600.0 * (rank - 1) + maxHpCaster * 1.5
    if rank == 3 then treantHp = 2200.0 + maxHpCaster * 1.5 end
    if rank >= 4 then treantHp = 3200.0 + maxHpCaster * 1.5 end
    if BlzSetUnitMaxHP then BlzSetUnitMaxHP(treant, math.floor(treantHp)) end
    SetUnitState(treant, UNIT_STATE_LIFE, treantHp)
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\EntanglingRoots\\EntanglingRootsTarget.mdl", treant, "origin"))
    local cid = GetHandleId(caster)
    if not DruidSummons[cid] then DruidSummons[cid] = {} end
    table.insert(DruidSummons[cid], treant)
    local autoTimer = CreateTimer()
    SafeTimerStart(autoTimer, 8.0, true, function()
        if treant == nil or GetWidgetLife(treant) <= 0.405 then
            DestroyTimer(autoTimer)
            return
        end
        local tg = CreateGroup()
        GroupEnumUnitsInRange(tg, GetUnitX(treant), GetUnitY(treant), 300.0, nil)
        local tu = FirstOfGroup(tg)
        while tu ~= nil do
            GroupRemoveUnit(tg, tu)
            if IsUnitEnemy(tu, p) and GetWidgetLife(tu) > 0.405 then
                PauseUnit(tu, true)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\EntanglingRoots\\EntanglingRootsTarget.mdl", tu, "origin"))
                local rootu = tu
                local rtimer = CreateTimer()
                SafeTimerStart(rtimer, 2.5, false, function()
                    if GetWidgetLife(rootu) > 0.405 then PauseUnit(rootu, false) end
                    DestroyTimer(rtimer)
                end)
                break
            end
            tu = FirstOfGroup(tg)
        end
        DestroyGroup(tg)
    end)
end

function Arena_Druid_W(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local facing = GetUnitFacing(caster) * (math.pi / 180.0)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\HowlOfTerror\\HowlTarget.mdl", cx, cy))
    local str = GetHeroStr(caster, true)
    local sporeDmg = 120.0 + 80.0 * (rank - 1) + str * 0.8
    if rank == 3 then sporeDmg = 280.0 + str * 0.8 end
    if rank >= 4 then sporeDmg = 360.0 + str * 0.8 end
    local p = GetOwningPlayer(caster)
    local cid = GetHandleId(caster)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx + math.cos(facing) * 200.0, cy + math.sin(facing) * 200.0, 400.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, sporeDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\PlagueCloud\\PlagueCloudCaster.mdl", u, "overhead"))
            local tu = u
            local dTimer = CreateTimer()
            SafeTimerStart(dTimer, 0.5, true, function()
                if GetWidgetLife(tu) <= 0.405 then
                    DestroyTimer(dTimer)
                    local sapling = CreateUnit(p, ID('espv'), GetUnitX(tu), GetUnitY(tu), 0.0)
                    if sapling == nil then sapling = CreateUnit(p, ID('ewsp'), GetUnitX(tu), GetUnitY(tu), 0.0) end
                    if sapling ~= nil then
                        UnitApplyTimedLife(sapling, ID('BTLF'), 12.0)
                        if not DruidSummons[cid] then DruidSummons[cid] = {} end
                        table.insert(DruidSummons[cid], sapling)
                    end
                end
            end)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Druid_E(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\NightElf\\Tranquility\\TranquilityTarget.mdl", cx, cy))
    local hpPct = 0.10 + 0.05 * (rank - 1)
    local maxHp = GetUnitState(caster, UNIT_STATE_MAX_LIFE)
    SetUnitState(caster, UNIT_STATE_LIFE, math.min(maxHp, GetUnitState(caster, UNIT_STATE_LIFE) + maxHp * hpPct))
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 900.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitAlly(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            local uMaxHp = GetUnitState(u, UNIT_STATE_MAX_LIFE)
            SetUnitState(u, UNIT_STATE_LIFE, math.min(uMaxHp, GetUnitState(u, UNIT_STATE_LIFE) + uMaxHp * 0.10))
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Heal\\HealTarget.mdl", u, "origin"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Druid_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cid = GetHandleId(caster)
    local activeCol = DruidDeepwoodColossus[cid]
    if activeCol ~= nil and GetWidgetLife(activeCol) > 0.405 then
        local bx, by = GetUnitX(activeCol), GetUnitY(activeCol)
        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\NeutralExplode\\NeutralExplode.mdl", bx, by))
        local colMaxHp = GetUnitState(activeCol, UNIT_STATE_MAX_LIFE)
        local explDmg = colMaxHp * 0.15
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, bx, by, 550.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if GetWidgetLife(u) > 0.405 then
                if IsUnitEnemy(u, GetOwningPlayer(caster)) then
                    UnitDamageTarget(caster, u, explDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
                elseif IsUnitAlly(u, GetOwningPlayer(caster)) then
                    SetUnitState(u, UNIT_STATE_LIFE, GetUnitState(u, UNIT_STATE_MAX_LIFE))
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Heal\\HealTarget.mdl", u, "origin"))
                end
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
        SetWidgetLife(activeCol, 0.0)
        DruidDeepwoodColossus[cid] = nil
    else
        local facing = GetUnitFacing(caster) * (math.pi / 180.0)
        local cx = GetUnitX(caster) + math.cos(facing) * 250.0
        local cy = GetUnitY(caster) + math.sin(facing) * 250.0
        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Demon\\Inferno\\InfernoTarget.mdl", cx, cy))
        local p = GetOwningPlayer(caster)
        local colossus = CreateUnit(p, ID('etop'), cx, cy, GetUnitFacing(caster))
        if colossus == nil then colossus = CreateUnit(p, ID('emow'), cx, cy, GetUnitFacing(caster)) end
        if colossus == nil then return end
        local str = GetHeroStr(caster, true)
        local colHp = 4000.0 + 3000.0 * (rank - 1) + str * 2.5
        if rank == 3 then colHp = 11000.0 + str * 2.5 end
        if BlzSetUnitMaxHP then BlzSetUnitMaxHP(colossus, math.floor(colHp)) end
        SetUnitState(colossus, UNIT_STATE_LIFE, colHp)
        UnitApplyTimedLife(colossus, ID('BTLF'), 25.0)
        DruidDeepwoodColossus[cid] = colossus
        if not DruidSummons[cid] then DruidSummons[cid] = {} end
        table.insert(DruidSummons[cid], colossus)
    end
end

function Arena_Lich_ExplodeSkeleton(skel, caster, rank)
    if skel == nil or GetWidgetLife(skel) <= 0.405 then return end
    local sx, sy = GetUnitX(skel), GetUnitY(skel)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\CorpseExplode\\CorpseExplodeTarget.mdl", sx, sy))
    local pInt = GetHeroInt(caster, true)
    local expDmg = 100.0 + 70.0 * (rank - 1) + pInt * 0.5
    if rank == 3 then expDmg = 240.0 + pInt * 0.5 end
    if rank >= 4 then expDmg = 310.0 + pInt * 0.5 end
    local p = GetOwningPlayer(caster)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, sx, sy, 250.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, expDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\PlagueCloud\\PlagueCloudCaster.mdl", u, "chest"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
    SetWidgetLife(skel, 0.0)
end

function Arena_Lich_Q(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local tx = GetSpellTargetX()
    local ty = GetSpellTargetY()
    if tx == 0.0 and ty == 0.0 then
        tx = GetUnitX(caster)
        ty = GetUnitY(caster)
    end
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl", tx, ty))
    local pInt = GetHeroInt(caster, true)
    local qDmg = 120.0 + 80.0 * (rank - 1) + pInt * 0.9
    if rank == 3 then qDmg = 280.0 + pInt * 0.9 end
    if rank >= 4 then qDmg = 360.0 + pInt * 0.9 end
    local p = GetOwningPlayer(caster)
    local cid = GetHandleId(caster)
    if not LichSkeletons[cid] then LichSkeletons[cid] = {} end
    local killedCount = 0
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, tx, ty, 350.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, qDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\DarkRitual\\DarkRitualCaster.mdl", u, "origin"))
            if GetWidgetLife(u) <= 0.405 then
                killedCount = killedCount + 1
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
    local skelHp = 350.0 + 250.0 * (rank - 1) + pInt * 0.6
    local skelSpawnCount = math.max(1 + rank, killedCount)
    for i = 1, skelSpawnCount do
        local rx = tx + GetRandomReal(-100.0, 100.0)
        local ry = ty + GetRandomReal(-100.0, 100.0)
        local skel = CreateUnit(p, ID('uske'), rx, ry, GetRandomReal(0, 360))
        if skel ~= nil then
            if BlzSetUnitMaxHP then BlzSetUnitMaxHP(skel, math.floor(skelHp)) end
            SetUnitState(skel, UNIT_STATE_LIFE, skelHp)
            UnitApplyTimedLife(skel, ID('BTLF'), 25.0)
            table.insert(LichSkeletons[cid], skel)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\RaiseDead\\RaiseDeadTarget.mdl", skel, "origin"))
        end
    end
end

function Arena_Lich_W(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cid = GetHandleId(caster)
    if LichRevenant[cid] ~= nil and GetWidgetLife(LichRevenant[cid]) > 0.405 then
        SetWidgetLife(LichRevenant[cid], 0.0)
    end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local facing = GetUnitFacing(caster) * (math.pi / 180.0)
    local spawnX = cx + math.cos(facing) * 150.0
    local spawnY = cy + math.sin(facing) * 150.0
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\FrostArmor\\FrostArmorTarget.mdl", spawnX, spawnY))
    local p = GetOwningPlayer(caster)
    local rev = CreateUnit(p, ID('ukob'), spawnX, spawnY, GetUnitFacing(caster))
    if rev == nil then rev = CreateUnit(p, ID('uabo'), spawnX, spawnY, GetUnitFacing(caster)) end
    if rev == nil then return end
    local pInt = GetHeroInt(caster, true)
    local revHp = 1200.0 + 1000.0 * (rank - 1) + pInt * 1.5
    if BlzSetUnitMaxHP then BlzSetUnitMaxHP(rev, math.floor(revHp)) end
    SetUnitState(rev, UNIT_STATE_LIFE, revHp)
    UnitApplyTimedLife(rev, ID('BTLF'), 35.0)
    LichRevenant[cid] = rev
end

function Arena_Lich_E(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cid = GetHandleId(caster)
    local skels = LichSkeletons[cid] or {}
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local explodedCount = 0
    for i = #skels, 1, -1 do
        local skel = skels[i]
        if skel ~= nil and GetWidgetLife(skel) > 0.405 then
            local sx, sy = GetUnitX(skel), GetUnitY(skel)
            local dist = math.sqrt((sx - cx)^2 + (sy - cy)^2)
            if dist <= 700.0 then
                Arena_Lich_ExplodeSkeleton(skel, caster, rank)
                explodedCount = explodedCount + 1
                table.remove(skels, i)
            end
        end
    end
    if explodedCount > 0 then
        local maxMp = GetUnitState(caster, UNIT_STATE_MAX_MANA)
        local curMp = GetUnitState(caster, UNIT_STATE_MANA)
        SetUnitState(caster, UNIT_STATE_MANA, math.min(maxMp, curMp + maxMp * 0.05 * explodedCount))
        local maxHp = GetUnitState(caster, UNIT_STATE_MAX_LIFE)
        local curHp = GetUnitState(caster, UNIT_STATE_LIFE)
        SetUnitState(caster, UNIT_STATE_LIFE, math.min(maxHp, curHp + maxHp * 0.04 * explodedCount))
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\DarkRitual\\DarkRitualCaster.mdl", caster, "origin"))
    else
        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\CorpseExplode\\CorpseExplodeTarget.mdl", cx, cy))
    end
end

function Arena_Lich_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cid = GetHandleId(caster)
    if LichWyrm[cid] ~= nil and GetWidgetLife(LichWyrm[cid]) > 0.405 then
        SetWidgetLife(LichWyrm[cid], 0.0)
    end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\FreezingBreath\\FreezingBreathTarget.mdl", cx, cy))
    local p = GetOwningPlayer(caster)
    local wyrm = CreateUnit(p, ID('ufro'), cx, cy, GetUnitFacing(caster))
    if wyrm == nil then wyrm = CreateUnit(p, ID('Udea'), cx, cy, GetUnitFacing(caster)) end
    if wyrm == nil then return end
    local pInt = GetHeroInt(caster, true)
    local wyrmHp = 5000.0 + 3000.0 * (rank - 1) + pInt * 3.0
    if BlzSetUnitMaxHP then BlzSetUnitMaxHP(wyrm, math.floor(wyrmHp)) end
    SetUnitState(wyrm, UNIT_STATE_LIFE, wyrmHp)
    UnitApplyTimedLife(wyrm, ID('BTLF'), 25.0)
    LichWyrm[cid] = wyrm
end

function Arena_Chrono_Q(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local tx = GetSpellTargetX()
    local ty = GetSpellTargetY()
    if tx == 0.0 and ty == 0.0 then
        tx = GetUnitX(caster)
        ty = GetUnitY(caster)
    end
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Tornado\\TornadoElemental.mdl", tx, ty))
    local pInt = GetHeroInt(caster, true)
    local qDmg = 140.0 + 80.0 * (rank - 1) + pInt * 0.9
    local p = GetOwningPlayer(caster)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, tx, ty, 350.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, qDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            SetUnitPosition(u, tx, ty)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Chrono_W(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local tx = GetSpellTargetX()
    local ty = GetSpellTargetY()
    if tx == 0.0 and ty == 0.0 then
        tx = GetUnitX(caster)
        ty = GetUnitY(caster)
    end
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\SpellShieldAura\\SpellShieldAura.mdl", tx, ty))
    local p = GetOwningPlayer(caster)
    local speedPct = 1.30 + 0.10 * (rank - 1)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, tx, ty, 400.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if GetWidgetLife(u) > 0.405 then
            if IsUnitAlly(u, p) then
                SetUnitMoveSpeed(u, GetUnitDefaultMoveSpeed(u) * speedPct)
                if UnitResetCooldowns then UnitResetCooldowns(u) elseif UnitResetCooldown then UnitResetCooldown(u) end
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Orc\\Bloodlust\\BloodlustTarget.mdl", u, "origin"))
            elseif IsUnitEnemy(u, p) then
                UnitAddAbility(u, ID('Aslo'))
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\Slow\\SlowTarget.mdl", u, "overhead"))
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Chrono_E(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local tx, ty = GetSpellTargetX(), GetSpellTargetY()
    local dx = tx - cx
    local dy = ty - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local angle = GetUnitFacing(caster) * (math.pi / 180.0)
    if dist > 10.0 then
        angle = math.atan(dy, dx)
    end
    local blinkDist = 500.0
    local endX = cx + math.cos(angle) * blinkDist
    local endY = cy + math.sin(angle) * blinkDist
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\NightElf\\Blink\\BlinkCaster.mdl", cx, cy))
    SetUnitPathing(caster, false)
    SetUnitPosition(caster, endX, endY)
    SetUnitPathing(caster, true)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\NightElf\\Blink\\BlinkTarget.mdl", endX, endY))
end

function Arena_Chrono_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local p = GetOwningPlayer(caster)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Tornado\\TornadoElemental.mdl", cx, cy))
    local domeDur = 5.0 + 1.0 * (rank - 1)
    local bonusDmgPct = 0.30 + 0.15 * (rank - 1)
    local frozenEnemies = {}
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 600.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if GetWidgetLife(u) > 0.405 and IsUnitEnemy(u, p) then
            PauseUnit(u, true)
            table.insert(frozenEnemies, u)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\FreezingBreath\\FreezingBreathTarget.mdl", u, "origin"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
    local domeTimer = CreateTimer()
    SafeTimerStart(domeTimer, domeDur, false, function()
        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", cx, cy))
        local pInt = GetHeroInt(caster, true)
        local burstDmg = 400.0 + pInt * 1.5
        for _, eu in ipairs(frozenEnemies) do
            if GetWidgetLife(eu) > 0.405 then
                PauseUnit(eu, false)
                UnitDamageTarget(caster, eu, burstDmg * (1.0 + bonusDmgPct), false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
            end
        end
        DestroyTimer(domeTimer)
    end)
end

function Arena_ApplyInductionStack(target, caster, count)
    if target == nil or GetWidgetLife(target) <= 0.405 then return end
    local tid = GetHandleId(target)
    if not InductionStacks[tid] then
        InductionStacks[tid] = { count = 0, target = target, caster = caster, duration = 6.0 }
    end
    local data = InductionStacks[tid]
    data.count = math.min(5, data.count + (count or 1))
    data.duration = 6.0
    data.caster = caster
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\LightningShield\\LightningShieldTarget.mdl", target, "origin"))
    if data.count >= 5 then
        InductionStacks[tid] = nil
        local pInt = GetHeroInt(caster, true)
        local tx, ty = GetUnitX(target), GetUnitY(target)
        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", tx, ty))
        UnitDamageTarget(caster, target, 400.0 + pInt * 2.0, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
    end
end

function Arena_Storm_Q(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Monsoon\\MonsoonBoltTarget.mdl", cx, cy))
    local pInt = GetHeroInt(caster, true)
    local baseDmg = 150.0 + 100.0 * (rank - 1) + pInt * 1.0
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 500.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, baseDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Monsoon\\MonsoonBoltTarget.mdl", u, "origin"))
            Arena_ApplyInductionStack(u, caster, 1)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Storm_W(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local tx = GetSpellTargetX()
    local ty = GetSpellTargetY()
    if tx == 0.0 and ty == 0.0 then
        tx = GetUnitX(caster)
        ty = GetUnitY(caster)
    end
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\LightningShield\\LightningShieldTarget.mdl", tx, ty))
    local pInt = GetHeroInt(caster, true)
    local p = GetOwningPlayer(caster)
    local wTicks = 0
    local wTimer = CreateTimer()
    SafeTimerStart(wTimer, 0.5, true, function()
        wTicks = wTicks + 1
        if wTicks > 10 or GetWidgetLife(caster) <= 0.405 then
            DestroyTimer(wTimer)
            return
        end
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, tx, ty, 450.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
                UnitDamageTarget(caster, u, 35.0 + pInt * 0.25, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
    end)
end

function Arena_Storm_E(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cid = GetHandleId(caster)
    StormSupercharge[cid] = { active = true, duration = 5.0, caster = caster }
    local maxMp = GetUnitState(caster, UNIT_STATE_MAX_MANA)
    local curMp = GetUnitState(caster, UNIT_STATE_MANA)
    SetUnitState(caster, UNIT_STATE_MANA, math.min(maxMp, curMp + maxMp * 0.25))
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\BlueDragonRoar\\BlueDragonRoar.mdl", caster, "origin"))
    local eTimer = CreateTimer()
    SafeTimerStart(eTimer, 5.0, false, function()
        if StormSupercharge[cid] then StormSupercharge[cid].active = false end
        DestroyTimer(eTimer)
    end)
end

function Arena_Storm_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local pInt = GetHeroInt(caster, true)
    local shieldHp = 1000.0 + 1000.0 * (rank - 1)
    SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + shieldHp)
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\LightningShield\\LightningShieldTarget.mdl", caster, "origin"))
    local rTicks = 0
    local rTimer = CreateTimer()
    SafeTimerStart(rTimer, 0.4, true, function()
        rTicks = rTicks + 1
        if rTicks > 15 or GetWidgetLife(caster) <= 0.405 then
            DestroyTimer(rTimer)
            return
        end
        local p = GetOwningPlayer(caster)
        local baseStrike = 180.0 + 120.0 * (rank - 1) + pInt * 0.4
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), 800.0, nil)
        local u = FirstOfGroup(g)
        local struckCount = 0
        while u ~= nil and struckCount < 3 do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
                UnitDamageTarget(caster, u, baseStrike, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Monsoon\\MonsoonBoltTarget.mdl", u, "chest"))
                struckCount = struckCount + 1
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
    end)
end

function Arena_InitBombardierSystem()
    local t = CreateTimer()
    SafeTimerStart(t, 0.5, true, function()
        for _, trap in ipairs(BombardierTraps) do
            if trap.active then
                local g = CreateGroup()
                GroupEnumUnitsInRange(g, trap.x, trap.y, 150.0, nil)
                local u = FirstOfGroup(g)
                local enemiesHit = 0
                while u ~= nil and enemiesHit < 3 do
                    GroupRemoveUnit(g, u)
                    if IsUnitEnemy(u, GetOwningPlayer(trap.caster)) and GetWidgetLife(u) > 0.405 then
                        enemiesHit = enemiesHit + 1
                        local rootDur = 2.5 + 0.5 * trap.rank
                        SetUnitMoveSpeed(u, 0.0)
                        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Net\\NetTarget.mdl", u, "origin"))
                        local tu = u
                        local origSpeed = GetUnitDefaultMoveSpeed(tu)
                        local rTimer = CreateTimer()
                        SafeTimerStart(rTimer, rootDur, false, function()
                            if GetWidgetLife(tu) > 0.405 then SetUnitMoveSpeed(tu, origSpeed) end
                            DestroyTimer(rTimer)
                        end)
                    end
                    u = FirstOfGroup(g)
                end
                DestroyGroup(g)
                if enemiesHit > 0 then
                    trap.active = false
                    if trap.effect ~= nil then
                        DestroyEffect(trap.effect)
                        trap.effect = nil
                    end
                end
            end
        end

        for tid, data in pairs(ShrapnelDebuffs) do
            local target = data.target
            if target ~= nil and GetWidgetLife(target) > 0.405 and data.duration > 0 then
                data.duration = data.duration - 0.5
                local agi = GetHeroAgi(data.caster, true)
                local maxHp = GetUnitState(target, UNIT_STATE_MAX_LIFE)
                local dotTick = ((agi * 0.15 + maxHp * 0.015) * data.stacks) * 0.5
                UnitDamageTarget(data.caster, target, dotTick, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            else
                if target ~= nil then UnitRemoveAbility(target, ID('ACrf')) end
                ShrapnelDebuffs[tid] = nil
            end
        end
    end)
end

function Arena_CustomFinisher(caster, damage)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), 450.0, nil)
    local target = FirstOfGroup(g)
    while target ~= nil do
        GroupRemoveUnit(g, target)
        if IsUnitEnemy(target, GetOwningPlayer(caster)) and GetWidgetLife(target) > 0.405 then
            if GetWidgetLife(target) < GetUnitState(target, UNIT_STATE_MAX_LIFE) * 0.25 then
                UnitDamageTarget(caster, target, damage * 2.4, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            else
                UnitDamageTarget(caster, target, damage, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            end
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl", target, "chest"))
        end
        target = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_CustomArea(caster, radius, amount, healing)
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    if not healing then
        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", cx, cy))
    end
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, radius, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if GetWidgetLife(u) > 0.405 then
            if healing and IsUnitAlly(u, GetOwningPlayer(caster)) and IsUnitType(u, UNIT_TYPE_HERO) then
                SetUnitState(u, UNIT_STATE_LIFE, GetUnitState(u, UNIT_STATE_LIFE) + amount)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl", u, "origin"))
            elseif not healing and IsUnitEnemy(u, GetOwningPlayer(caster)) then
                UnitDamageTarget(caster, u, amount, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", u, "origin"))
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_CustomMove(caster, dist)
    local ang = GetUnitFacing(caster) * (3.14159 / 180.0)
    local nx = GetUnitX(caster) + dist * math.cos(ang)
    local ny = GetUnitY(caster) + dist * math.sin(ang)
    SetUnitPosition(caster, nx, ny)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Orc\\Blink\\BlinkTarget.mdl", nx, ny))
end

-- ===========================================================================
-- 3. ВЫБОР ГЕРОЯ ЧЕРЕЗ ДИАЛОГОВОЕ ОКНО (БЕЗ ДУБЛИРОВАНИЯ DialogDisplay)
-- ===========================================================================

-- Таблица соответствия любых стандартных способностей слотам 1, 2, 3, 4 (на случай если игрок нажал стандартный скилл)
FallbackSpellSlot = {
    -- Паладин (Hpal)
    [ID('AHhb')] = 1, [ID('AHds')] = 2, [ID('AHad')] = 3, [ID('AHre')] = 4,
    -- Мастер клинка (Obla)
    [ID('AOwk')] = 1, [ID('AOmi')] = 2, [ID('AOcr')] = 3, [ID('AOww')] = 4,
    -- Архимаг (Hamg)
    [ID('AHbz')] = 1, [ID('AHwe')] = 2, [ID('AHab')] = 3, [ID('AHmt')] = 4,
    -- Рыцарь смерти (Udea)
    [ID('AUdc')] = 1, [ID('AUdp')] = 2, [ID('AUau')] = 3, [ID('AUan')] = 4,
    -- Охотник на демонов (Edem)
    [ID('AEmb')] = 1, [ID('AEim')] = 2, [ID('AEev')] = 3, [ID('AEme')] = 4,
    -- Горный король (Hmkg)
    [ID('AHtb')] = 1, [ID('AHtc')] = 2, [ID('AHbh')] = 3, [ID('AHav')] = 4,
    -- Жрица луны (Emoo)
    [ID('AEst')] = 1, [ID('AEfa')] = 2, [ID('AEar')] = 3, [ID('AEsf')] = 4,
    -- Алхимик (Nalc)
    [ID('ANhs')] = 1, [ID('ANab')] = 2, [ID('ANcr')] = 3, [ID('ANtm')] = 4,
    -- Смотрящая в ночь (Ewar)
    [ID('AEfk')] = 1, [ID('AEbl')] = 2, [ID('AEsh')] = 3, [ID('AEsv')] = 4,
    -- Лич (Ulic)
    [ID('AUfn')] = 1, [ID('AUfa')] = 2, [ID('AUfu')] = 3, [ID('AUdd')] = 4
}

function Arena_OnSpellEvent()
    local caster = GetTriggerUnit()
    if caster == nil then return end

    local spellId = GetSpellAbilityId()
    local pid = GetPlayerId(GetOwningPlayer(caster))
    local role = HeroKind[GetHandleId(caster)] or HeroKind[pid]
    if not role then role = 1 end

    -- Если сработал стандартный скилл героя, автоматически перенаправляем его на наш кастомный скилл (Q/W/E/R)!
    local slot = FallbackSpellSlot[spellId]
    if slot and HeroClasses[role] and HeroClasses[role].spells[slot] then
        spellId = HeroClasses[role].spells[slot]
    end

    -- Вызываем нашу систему способностей
    Arena_CustomCast_Lua(caster, pid, spellId)
end

function DoPickHero(roleIndex)
    local p = GetTriggerPlayer()
    if p == nil then
        p = Player(0)
    end
    local pid = GetPlayerId(p)

    if HeroDialog ~= nil then
        DialogDisplay(p, HeroDialog, false)
    end

    if Heroes[pid] ~= nil then return end

    local classData = HeroClasses[roleIndex]
    if not classData then return end

    local hero = CreateUnit(p, classData.id, 0.0, 0.0, 270.0)
    if hero == nil then
        hero = CreateUnit(p, ID('Hpal'), 0.0, 0.0, 270.0)
    end

    Heroes[pid] = hero
    HeroKind[pid] = roleIndex
    HeroKind[GetHandleId(hero)] = roleIndex

    -- 1. Удаляем стандартные способности Warcraft 3, чтобы они не мешали на панели
    for stdSpellId, _ in pairs(FallbackSpellSlot) do
        UnitRemoveAbility(hero, stdSpellId)
    end

    -- 2. Выдаем наши 4 кастомные способности класса
    for _, spellId in ipairs(classData.spells) do
        UnitAddAbility(hero, spellId)
        SetUnitAbilityLevel(hero, spellId, 1)
    end

    -- 3. НАПРЯМУЮ привязываем триггер каста способностей к этому герою (без KeepAlive!)
    local heroSpellTrig = CreateTrigger()
    TriggerRegisterUnitEvent(heroSpellTrig, hero, EVENT_UNIT_SPELL_EFFECT)
    TriggerRegisterUnitEvent(heroSpellTrig, hero, EVENT_UNIT_SPELL_CAST)
    TriggerRegisterUnitEvent(heroSpellTrig, hero, EVENT_UNIT_SPELL_CHANNEL)
    TriggerAddAction(heroSpellTrig, Arena_OnSpellEvent)

    -- 4. Напрямую привязываем триггер автоатаки (для пассивок Ронина, Бомбардира, Бури и Жрицы)
    local heroAtkTrig = CreateTrigger()
    TriggerRegisterPlayerUnitEvent(heroAtkTrig, Player(PLAYER_NEUTRAL_AGGRESSIVE), EVENT_PLAYER_UNIT_ATTACKED, nil)
    TriggerAddAction(heroAtkTrig, Arena_OnAttackEvent)

    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTarget.mdl", hero, "origin"))

    ClearSelection()
    SelectUnit(hero, true)
    PanCameraToTimed(0.0, 0.0, 0.0)

    Arena_Msg("|cff00ff00Герой выбран:|r " .. classData.name)

    if not udg_WavesStarted then
        udg_WavesStarted = true
        Arena_StartCountdown(15, "Волна 1")
        Arena_Msg("|cffffcc00Таймер запущен! Волна 1 начнётся через 15 секунд.|r")
    end
end

-- 10 прямых глобальных функций для 10 кнопок (100защита от потери ссылки в Lua)
function PickHero_1() DoPickHero(1) end
function PickHero_2() DoPickHero(2) end
function PickHero_3() DoPickHero(3) end
function PickHero_4() DoPickHero(4) end
function PickHero_5() DoPickHero(5) end
function PickHero_6() DoPickHero(6) end
function PickHero_7() DoPickHero(7) end
function PickHero_8() DoPickHero(8) end
function PickHero_9() DoPickHero(9) end
function PickHero_10() DoPickHero(10) end

PickHeroFuncs = {
    PickHero_1, PickHero_2, PickHero_3, PickHero_4, PickHero_5,
    PickHero_6, PickHero_7, PickHero_8, PickHero_9, PickHero_10
}

-- Дополнительный обработчик на весь диалог целиком (на случай если сработает DialogEvent вместо ButtonEvent)
function OnAnyDialogButtonClick()
    local clicked = GetClickedButton()
    for i = 1, 10 do
        if clicked == HeroDialogButtons[i] then
            DoPickHero(i)
            return
        end
    end
end

function ShowDialogDelayed()
    HeroDialog = DialogCreate()
    DialogClear(HeroDialog)
    DialogSetMessage(HeroDialog, "Выберите класс героя:")

    HeroDialogButtons = {}
    HeroButtonTriggers = {}

    for i = 1, 10 do
        local btn = DialogAddButton(HeroDialog, HeroClasses[i].name, 0)
        HeroDialogButtons[i] = btn

        -- 1. Отдельный триггер на конкретную кнопку с прямой функцией PickHero_X
        local trig = CreateTrigger()
        HeroButtonTriggers[i] = trig
        TriggerRegisterDialogButtonEvent(trig, btn)
        TriggerAddAction(trig, PickHeroFuncs[i])
    end

    -- 2. И общий триггер на сам диалог
    Trig_MainDialog = CreateTrigger()
    TriggerRegisterDialogEvent(Trig_MainDialog, HeroDialog)
    TriggerAddAction(Trig_MainDialog, OnAnyDialogButtonClick)

    -- ВАЖНО: Вызываем DialogDisplay СТРОГО 1 РАЗ на игрока (без второго вызова GetLocalPlayer поверх!)
    for pid = 0, 3 do
        if GetPlayerSlotState(Player(pid)) == PLAYER_SLOT_STATE_PLAYING and GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
            DialogDisplay(Player(pid), HeroDialog, true)
        end
    end
end

function CreateHeroPickDialog()
    Trig_ShowDialogDelay = CreateTrigger()
    TriggerRegisterTimerEvent(Trig_ShowDialogDelay, 1.00, false)
    TriggerAddAction(Trig_ShowDialogDelay, ShowDialogDelayed)
end
-- ===========================================================================
-- 4. ТАЙМЕР И ВОЛНЫ (НА БАЗЕ НАДЕЖНОГО ТРИГГЕРА ВРЕМЕНИ)
-- ===========================================================================

WaveTriggerId = 0

function Arena_StartCountdown(seconds, title)
    -- 1. Запускаем визуальный таймер в правом верхнем углу экрана
    if udg_WaveTimer == nil then
        udg_WaveTimer = CreateTimer()
    end
    if udg_WaveTD == nil then
        udg_WaveTD = CreateTimerDialog(udg_WaveTimer)
    end
    TimerDialogSetTitle(udg_WaveTD, title)
    TimerDialogDisplay(udg_WaveTD, true)
    TimerStart(udg_WaveTimer, seconds + 0.0, false, nil)

    -- 2. Создаем надежный триггер времени (точно такой же, как для диалогового окна!)
    WaveTriggerId = WaveTriggerId + 1
    local currentId = WaveTriggerId

    Trig_CurrentWaveTimer = CreateTrigger()
    TriggerRegisterTimerEvent(Trig_CurrentWaveTimer, seconds + 0.0, false)
    TriggerAddAction(Trig_CurrentWaveTimer, function()
        -- Проверяем, что этот таймер не был заменен досрочной зачисткой волны
        if currentId == WaveTriggerId then
            Arena_StartNextWave()
        end
    end)
end

function Arena_SpawnSingleEnemy(unitId, x, y, isElite)
    local u = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), unitId, x, y, 270.0)
    if u == nil then return end

    udg_EnemiesAlive = udg_EnemiesAlive + 1
    SetUnitCreepGuard(u, false)
    SetUnitAcquireRange(u, 5000.0)

    if isElite then
        SetUnitUserData(u, 888)
        SetUnitScale(u, 1.35, 1.35, 1.35)
        SetUnitVertexColor(u, 255, 140, 100, 255)
    else
        SetUnitUserData(u, 777)
    end

    local tx, ty = 0.0, 0.0
    for pid = 0, 15 do
        if Heroes[pid] ~= nil and GetWidgetLife(Heroes[pid]) > 0.405 then
            tx = GetUnitX(Heroes[pid])
            ty = GetUnitY(Heroes[pid])
            break
        end
    end
    IssuePointOrder(u, "attack", tx, ty)
end

function Arena_SpawnWaveUnits(wave)
    local creepTypes = {
        ID('nban'), ID('nrog'), ID('ngno'), ID('nftr'), ID('nogr'),
        ID('uske'), ID('nska'), ID('ucry'), ID('nfel'), ID('uabo')
    }
    local idx = math.min(10, math.floor((wave - 1) / 5) + 1)
    local mainUnit = creepTypes[idx]
    local count = 6 + math.floor(wave / 3)

    for i = 1, count do
        local ang = (6.28318 * i) / count
        local rx = 900.0 * math.cos(ang)
        local ry = 900.0 * math.sin(ang)
        Arena_SpawnSingleEnemy(mainUnit, rx, ry, false)
    end

    if IsDivBy5(wave) then
        Arena_SpawnSingleEnemy(mainUnit, 0.0, 1000.0, true)
        Arena_Msg("|cffff6600[Особая волна]:|r Появился элитный вожак волны " .. tostring(wave) .. "!")
    end
end

function Arena_SpawnFinalBoss()
    if udg_Boss ~= nil then return end
    TimerDialogDisplay(udg_WaveTD, false)
    udg_Boss = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), ID('Nplh'), 0.0, 900.0, 270.0)
    if udg_Boss ~= nil then
        SetHeroLevel(udg_Boss, 15, false)
        SetUnitAcquireRange(udg_Boss, 5000.0)
        IssuePointOrder(udg_Boss, "attack", 0.0, 0.0)
        Arena_Msg("|cffff2222[ФИНАЛ]:|r Босс Каз'Рул вышел на арену!")
    end
end

function Arena_StartNextWave()
    if udg_GameOver then return end

    if udg_Wave >= 50 then
        Arena_SpawnFinalBoss()
        return
    end

    udg_Wave = udg_Wave + 1
    Arena_SpawnWaveUnits(udg_Wave)

    local bonusGold = 40 + udg_Wave * 5
    for pid = 0, 3 do
        local p = Player(pid)
        SetPlayerState(p, PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(p, PLAYER_STATE_RESOURCE_GOLD) + bonusGold)
    end

    Arena_Msg("|cffffcc00=== Волна " .. tostring(udg_Wave) .. " / 50 ===|r Врагов на арене: " .. tostring(udg_EnemiesAlive))

    -- Запускаем таймер на 60 секунд до следующей волны
    if udg_Wave < 50 then
        Arena_StartCountdown(60, "Волна " .. tostring(udg_Wave + 1))
    else
        Arena_StartCountdown(60, "Босс Каз'Рул")
    end
end

function Arena_MasterPulse()
    -- Оставлена для совместимости
end

-- ===========================================================================
-- 5. ЗАПУСК ИГРЫ
-- ===========================================================================

function Arena_OnAttackEvent()
    local attacker = GetAttacker()
    local target = GetTriggerUnit()
    if attacker ~= nil and target ~= nil and GetWidgetLife(attacker) > 0.405 and GetWidgetLife(target) > 0.405 then
        Arena_OnUnitAttack(attacker, target)
        local tid = GetHandleId(target)
        local st = RoninParryState[tid]
        if st and st.inStance then
            Arena_Ronin_CounterAttack(target, 100.0)
        end
    end
end

function Arena_OnSpellEvent()
    local caster = GetTriggerUnit()
    local spellId = GetSpellAbilityId()
    local pid = GetPlayerId(GetOwningPlayer(caster))
    Arena_CustomCast_Lua(caster, pid, spellId)
end

function Arena_OnItemPickupEvent()
    local hero = GetManipulatingUnit()
    Arena_CheckItemCrafting(hero)
end

function Arena_OnChatCommand()
    local p = GetTriggerPlayer()
    local pid = GetPlayerId(p)
    local msg = GetEventPlayerChatString()
    local num = tonumber(string.sub(msg, 2))
    if num and num >= 1 and num <= 10 then
        DoPickHero(pid, num)
    end
end

function Arena_StartGame()
    if Arena_Started then return end
    Arena_Started = true

    SetFloatGameState(GAME_STATE_TIME_OF_DAY, 12.00)
    SuspendTimeOfDay(true)
    FogEnable(false)
    FogMaskEnable(false)
    PanCameraToTimed(0.0, 0.0, 0.0)

    Arena_InitData()

    -- Открываем диалоговое окно выбора героя (и переоткрываем через 0.5 сек на случай задержки UI)
    CreateHeroPickDialog()
    local reOpenTimer = CreateTimer()
    SafeTimerStart(reOpenTimer, 0.50, false, function()
        local lp = GetLocalPlayer()
        if Heroes[GetPlayerId(lp)] == nil and HeroDialog ~= nil then
            DialogDisplay(lp, HeroDialog, true)
        end
        DestroyTimer(reOpenTimer)
    end)

    Arena_Msg("|cff00ff00[АРЕНА]:|r Выберите класс героя в диалоговом окне!")

    Trig_Pulse = CreateTrigger()
    TriggerRegisterTimerEvent(Trig_Pulse, 1.00, true)
    TriggerAddAction(Trig_Pulse, KeepAlive(Arena_MasterPulse))

    Trig_Spells = CreateTrigger()
    NativeRegisterAnyUnitEvent(Trig_Spells, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    NativeRegisterAnyUnitEvent(Trig_Spells, EVENT_PLAYER_UNIT_SPELL_CAST)
    TriggerAddAction(Trig_Spells, KeepAlive(Arena_OnSpellEvent))

    Trig_Attacks = CreateTrigger()
    NativeRegisterAnyUnitEvent(Trig_Attacks, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddAction(Trig_Attacks, KeepAlive(Arena_OnAttackEvent))

    Trig_Items = CreateTrigger()
    NativeRegisterAnyUnitEvent(Trig_Items, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    TriggerAddAction(Trig_Items, KeepAlive(Arena_OnItemPickupEvent))

    Trig_Deaths = CreateTrigger()
    NativeRegisterAnyUnitEvent(Trig_Deaths, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddAction(Trig_Deaths, KeepAlive(Arena_OnAnyUnitDeath))

    Trig_Chat = CreateTrigger()
    for i = 0, 15 do
        TriggerRegisterPlayerChatEvent(Trig_Chat, Player(i), "-", false)
    end
    TriggerAddAction(Trig_Chat, KeepAlive(Arena_OnChatCommand))

    pcall(Arena_InitBleedSystem)
    pcall(Arena_InitBombardierSystem)
end

do
    local realInitBlizzard = InitBlizzard
    function InitBlizzard()
        if realInitBlizzard then realInitBlizzard() end
        FogEnable(false)
        FogMaskEnable(false)
        Trig_Boot = CreateTrigger()
        TriggerRegisterTimerEvent(Trig_Boot, 0.50, false)
        TriggerAddAction(Trig_Boot, KeepAlive(Arena_StartGame))
    end
end
function Trig_Untitled_Trigger_001_Actions()
DisplayTextToForce(GetPlayersAll(), "TRIGSTR_349")
TriggerSleepAction(0.50)
    Arena_StartGame()
end

function InitTrig_Untitled_Trigger_001()
gg_trg_Untitled_Trigger_001 = CreateTrigger()
TriggerAddAction(gg_trg_Untitled_Trigger_001, Trig_Untitled_Trigger_001_Actions)
end

function InitCustomTriggers()
InitTrig_Untitled_Trigger_001()
end

function RunInitializationTriggers()
ConditionalTriggerExecute(gg_trg_Untitled_Trigger_001)
end

function InitCustomPlayerSlots()
SetPlayerStartLocation(Player(0), 0)
SetPlayerColor(Player(0), ConvertPlayerColor(0))
SetPlayerRacePreference(Player(0), RACE_PREF_HUMAN)
SetPlayerRaceSelectable(Player(0), true)
SetPlayerController(Player(0), MAP_CONTROL_USER)
SetPlayerStartLocation(Player(1), 1)
SetPlayerColor(Player(1), ConvertPlayerColor(1))
SetPlayerRacePreference(Player(1), RACE_PREF_HUMAN)
SetPlayerRaceSelectable(Player(1), true)
SetPlayerController(Player(1), MAP_CONTROL_USER)
SetPlayerStartLocation(Player(2), 2)
SetPlayerColor(Player(2), ConvertPlayerColor(2))
SetPlayerRacePreference(Player(2), RACE_PREF_HUMAN)
SetPlayerRaceSelectable(Player(2), true)
SetPlayerController(Player(2), MAP_CONTROL_USER)
SetPlayerStartLocation(Player(3), 3)
SetPlayerColor(Player(3), ConvertPlayerColor(3))
SetPlayerRacePreference(Player(3), RACE_PREF_HUMAN)
SetPlayerRaceSelectable(Player(3), true)
SetPlayerController(Player(3), MAP_CONTROL_USER)
end

function InitCustomTeams()
SetPlayerTeam(Player(0), 0)
SetPlayerState(Player(0), PLAYER_STATE_ALLIED_VICTORY, 1)
SetPlayerTeam(Player(1), 0)
SetPlayerState(Player(1), PLAYER_STATE_ALLIED_VICTORY, 1)
SetPlayerTeam(Player(2), 0)
SetPlayerState(Player(2), PLAYER_STATE_ALLIED_VICTORY, 1)
SetPlayerTeam(Player(3), 0)
SetPlayerState(Player(3), PLAYER_STATE_ALLIED_VICTORY, 1)
SetPlayerAllianceStateAllyBJ(Player(0), Player(1), true)
SetPlayerAllianceStateAllyBJ(Player(0), Player(2), true)
SetPlayerAllianceStateAllyBJ(Player(0), Player(3), true)
SetPlayerAllianceStateAllyBJ(Player(1), Player(0), true)
SetPlayerAllianceStateAllyBJ(Player(1), Player(2), true)
SetPlayerAllianceStateAllyBJ(Player(1), Player(3), true)
SetPlayerAllianceStateAllyBJ(Player(2), Player(0), true)
SetPlayerAllianceStateAllyBJ(Player(2), Player(1), true)
SetPlayerAllianceStateAllyBJ(Player(2), Player(3), true)
SetPlayerAllianceStateAllyBJ(Player(3), Player(0), true)
SetPlayerAllianceStateAllyBJ(Player(3), Player(1), true)
SetPlayerAllianceStateAllyBJ(Player(3), Player(2), true)
end

function InitAllyPriorities()
SetStartLocPrioCount(0, 1)
SetStartLocPrio(0, 0, 2, MAP_LOC_PRIO_HIGH)
SetStartLocPrioCount(1, 3)
SetStartLocPrio(1, 0, 0, MAP_LOC_PRIO_HIGH)
SetStartLocPrio(1, 1, 2, MAP_LOC_PRIO_LOW)
SetStartLocPrio(1, 2, 3, MAP_LOC_PRIO_LOW)
SetStartLocPrioCount(2, 1)
SetStartLocPrio(2, 0, 0, MAP_LOC_PRIO_HIGH)
SetStartLocPrioCount(3, 2)
SetStartLocPrio(3, 0, 0, MAP_LOC_PRIO_LOW)
SetStartLocPrio(3, 1, 2, MAP_LOC_PRIO_HIGH)
end

function main()
SetCameraBounds(-9472.0 + GetCameraMargin(CAMERA_MARGIN_LEFT), -9728.0 + GetCameraMargin(CAMERA_MARGIN_BOTTOM), 9472.0 - GetCameraMargin(CAMERA_MARGIN_RIGHT), 9216.0 - GetCameraMargin(CAMERA_MARGIN_TOP), -9472.0 + GetCameraMargin(CAMERA_MARGIN_LEFT), 9216.0 - GetCameraMargin(CAMERA_MARGIN_TOP), 9472.0 - GetCameraMargin(CAMERA_MARGIN_RIGHT), -9728.0 + GetCameraMargin(CAMERA_MARGIN_BOTTOM))
SetDayNightModels("Environment\\DNC\\DNCLordaeron\\DNCLordaeronTerrain\\DNCLordaeronTerrain.mdl", "Environment\\DNC\\DNCLordaeron\\DNCLordaeronUnit\\DNCLordaeronUnit.mdl")
NewSoundEnvironment("Default")
SetAmbientDaySound("LordaeronSummerDay")
SetAmbientNightSound("LordaeronSummerNight")
SetMapMusic("Music", true, 0)
InitBlizzard()
InitGlobals()
InitCustomTriggers()
RunInitializationTriggers()
end

function config()
SetMapName("TRIGSTR_006")
SetMapDescription("TRIGSTR_008")
SetPlayers(4)
SetTeams(4)
SetGamePlacement(MAP_PLACEMENT_TEAMS_TOGETHER)
DefineStartLocation(0, 6592.0, -3904.0)
DefineStartLocation(1, -1664.0, -9280.0)
DefineStartLocation(2, 7104.0, 896.0)
DefineStartLocation(3, -896.0, 3648.0)
InitCustomPlayerSlots()
SetPlayerSlotAvailable(Player(0), MAP_CONTROL_USER)
SetPlayerSlotAvailable(Player(1), MAP_CONTROL_USER)
SetPlayerSlotAvailable(Player(2), MAP_CONTROL_USER)
SetPlayerSlotAvailable(Player(3), MAP_CONTROL_USER)
InitGenericPlayerSlots()
InitAllyPriorities()
end

