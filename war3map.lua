-- ===========================================================================
-- Map Script: Warcraft III Reforged (Lua Mode)
-- Full 50-Wave Arena, 10 Custom Hero Skillsets, 3-Tier Item Crafting
-- ===========================================================================

function InitGlobals()
    -- Глобальные переменные
    Heroes = {}
    ArenaLeft = {}
    HeroKind = {}
    HeroLearningHidden = {}
    UltimateLocked = {}
    RoninResolve = {}
    RoninRewards = {}
    ReflectingDamage = false
    DruidGuardians = {}
    SaplingLife = {}
    EquippedItemStats = {}
    ItemPoisons = {}
    ItemResetReady = {}
    CraftingHeroes = {}
    ItemCombatBusy = false
    TormentShields = {}
    MoveSlows = {}
    StackIndicators = {}
    EngineerTurrets = {}
    ArenaEnemies = {}
    CooldownAcceleration = {}
    ChronoFreeze = {}
    ChronoHaste = {}
    BleedStacks = {} -- Таблица учета кровотечения: BleedStacks[targetHandleId] = { count = N, expires = T, caster = U }
    BombardierTraps = {}
    BombardierRocketState = {}
    ShrapnelDebuffs = {}
    RoninDeepCut = {}
    RoninIaiCuts = {}
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

    -- Глобальные переменные волн
    udg_Wave = 0
    udg_HumanCount = 0
    udg_EnemiesAlive = 0
    udg_TotalKills = 0
    udg_BossPhase = 0
    udg_WavesStarted = false
    udg_GameOver = false
    udg_WaveCleared = false
    udg_Boss = nil
    udg_WaveTimer = nil
    udg_WaveTD = nil
    udg_ReviveTimer = {}
    udg_PlayerKills = {0, 0, 0, 0}

    -- Концепция 10 героев AI Studio с их архетипами и уникальными способностями
    HeroClasses = {
        -- 1. Тёмный Рыцарь (Сила / Танк-Джаггернаут)
        { id = FourCC('H001'), name = "Тёмный Рыцарь (Сила / Танк)",     role = "tank",     spells = {FourCC('A101'), FourCC('A102'), FourCC('A10D'), FourCC('A10E')} },
        -- 2. Призрачный Ловчий (Ловкость / Ассасин)
        { id = FourCC('O001'), name = "Призрачный Ловчий (Ловкость / Ассасин)", role = "assassin", spells = {FourCC('A103'), FourCC('A104'), FourCC('A10F'), FourCC('A10G')} },
        -- 3. Элементалист Бури / Архимаг Гроз (Интеллект / Абсолютный Магический AoE-Кастер)
        { id = FourCC('H002'), name = "Элементалист Бури (Интеллект / АоЕ-Маг)", role = "mage", spells = {FourCC('A105'), FourCC('A106'), FourCC('A10H'), FourCC('A10I')} },
        -- 4. Хранитель Древней / Друид Первобытного Леса (Сила / Саммонер & Биомасса)
        { id = FourCC('U001'), name = "Хранитель Древней (Сила / Саммонер)", role = "summoner", spells = {FourCC('A107'), FourCC('A108'), FourCC('A10J'), FourCC('A10K')} },
        -- 5. Архилич Чумы / Повелитель Мёртвых (Интеллект / Некромант-Призыватель)
        { id = FourCC('E001'), name = "Архилич Чумы (Интеллект / Некромант)", role = "dot_control", spells = {FourCC('A109'), FourCC('A10A'), FourCC('A10L'), FourCC('A10M')} },
        -- 6. Мастер Клинка / Ронин (Ловкость / Керри Ближнего Боя)
        { id = FourCC('H003'), name = "Мастер Клинка-Ронин (Ловкость / Керри)", role = "carry", spells = {FourCC('A115'), FourCC('A116'), FourCC('A117'), FourCC('A118')} },
        -- 7. Жрица Рассвета (Интеллект / Боевой Саппорт, Защитник и Баффер)
        { id = FourCC('E002'), name = "Жрица Рассвета (Интеллект / Боевой Саппорт)", role = "healer", spells = {FourCC('A10B'), FourCC('A10C'), FourCC('A10N'), FourCC('A10O')} },
        -- 8. Инженер-Бомбардир (Ловкость / Осада и Зонинг)
        { id = FourCC('N001'), name = "Инженер-Бомбардир (Ловкость / Осада)", role = "siege",  spells = {FourCC('A111'), FourCC('A112'), FourCC('A113'), FourCC('A114')} },
        -- 9. Железный Исполин (Сила / Главный Танк, Инициатор и Стяжка)
        { id = FourCC('E003'), name = "Железный Исполин (Сила / Танк-Инициатор)", role = "initiator", spells = {FourCC('A119'), FourCC('A11A'), FourCC('A11B'), FourCC('A11C')} },
        -- 10. Хрономант / Хранитель Эпох (Интеллект / Тактический Саппорт-Манипулятор)
        { id = FourCC('U002'), name = "Хрономант (Интеллект / Контроль Времени)", role = "control", spells = {FourCC('A11D'), FourCC('A11E'), FourCC('A11F'), FourCC('A11G')} }
    }

    -- Переменные диалога
    HeroDialog = nil
    HeroDialogButtons = {}
end

function SpawnSelectedHero(pid, roleId)
    if pid < 0 or pid > 3 or not Arena_IsHuman(pid) or Heroes[pid] ~= nil then
        return
    end
    local classData = HeroClasses[roleId]
    if classData == nil then
        return
    end
    local p = Player(pid)

    -- Спавн героя в центре карты (X: 0, Y: 0)
    local starts = {{-160,0},{160,0},{0,-160},{0,160}}
    local sx,sy = starts[pid+1][1],starts[pid+1][2]
    local hero = CreateUnit(p, classData.id, sx, sy, 270.0)
    if hero == nil then
        DisplayTextToPlayer(p, 0, 0, "Не удалось создать героя. Выберите класс ещё раз.")
        return
    end
    Heroes[pid] = hero
    HeroKind[pid] = roleId
    Arena_DisableHeroLearning(hero)

    -- Выдаем способности
    for _, spellId in ipairs(classData.spells) do
        UnitAddAbility(hero, spellId)
        Arena_ConfigureCastRange(hero, spellId)
    end
    if roleId == 2 then BlzUnitDisableAbility(hero,FourCC('A10F'),true,false) end
    Arena_UpdateRanks(hero, roleId)
    Arena_UpdateUltimate(hero, roleId)

    SelectUnitForPlayerSingle(hero, p)
    PanCameraToTimedForPlayer(p, sx, sy, 0.0)
    DisplayTextToPlayer(p, 0, 0, "|cff88ff88Выбран класс:|r " .. classData.name)

    -- Стартовое сообщение
    DisplayTextToPlayer(p, 0, 0, "|cffffcc00Цель арены:|r Пройдите 50 волн и победите Каз'Рула.")

    -- Стартовый квест
    local myQuest = CreateQuest()
    QuestSetTitle(myQuest, "Испытание арены")
    QuestSetDescription(myQuest, "Выдержите 50 волн и победите финального босса Каз'Рула. Погибший герой воскресает через 12 секунд.")
    QuestSetRequired(myQuest, true)
    QuestSetDiscovered(myQuest, true)
    FlashQuestDialogButton()

    -- Проверяем запуск волн при выборе каждого героя
    Arena_TryStartWaves()
end

function Arena_ConfigureCastRange(hero, spellId)
    local ranges = {
        A103=900, A105=1200, A106=1200, A109=1200, A10L=900, A115=900, A116=900, A118=900,
        A10B=900, A10C=900, A111=900, A112=900, A119=900, A11D=900, A11E=900, A11F=900
    }
    for raw, range in pairs(ranges) do
        if spellId == FourCC(raw) then
            local ability = BlzGetUnitAbility(hero, spellId)
            if ability ~= nil then
                for level = 0, 4 do
                    BlzSetAbilityRealLevelField(ability, ABILITY_RLF_CAST_RANGE, level, range)
                end
                -- Refresh the engine's cached ability data before the first order.
                local rank = GetUnitAbilityLevel(hero, spellId)
                SetUnitAbilityLevel(hero, spellId, rank == 1 and 2 or 1)
                SetUnitAbilityLevel(hero, spellId, rank)
            end
            return
        end
    end
end

function Arena_GetAimPoint(caster)
    local target = GetSpellTargetUnit()
    if target ~= nil then return GetUnitX(target), GetUnitY(target) end
    return GetSpellTargetX(), GetSpellTargetY()
end

function Arena_ClearMoveSlow(unit)
    local state = MoveSlows[unit]
    if state == nil then return end
    MoveSlows[unit] = nil
    DestroyTimer(state.timer)
    DestroyEffect(state.effect)
    if GetUnitTypeId(unit) ~= 0 then SetUnitMoveSpeed(unit, state.speed) end
end

function Arena_ApplyMoveSlow(unit, fraction, duration)
    local previous = MoveSlows[unit]
    local speed = previous and previous.speed or GetUnitMoveSpeed(unit)
    Arena_ClearMoveSlow(unit)
    local timer = CreateTimer()
    MoveSlows[unit] = {speed=speed, timer=timer,
        effect=AddSpecialEffectTarget("Abilities/Spells/Undead/FrostArmor/FrostArmorTarget.mdl", unit, "origin")}
    SetUnitMoveSpeed(unit, speed * (1.0 - fraction))
    TimerStart(timer, duration, false, function() Arena_ClearMoveSlow(unit) end)
end

function Arena_ClearStackIndicator(unit, kind)
    local indicators = StackIndicators[unit]
    local data = indicators and indicators[kind]
    if data == nil then return end
    DestroyTextTag(data.tag)
    if data.effect ~= nil then DestroyEffect(data.effect) end
    indicators[kind] = nil
    if next(indicators) == nil then StackIndicators[unit] = nil end
end

function Arena_UpdateStackIndicator(unit, kind, stacks)
    StackIndicators[unit] = StackIndicators[unit] or {}
    local data = StackIndicators[unit][kind]
    if data == nil then
        data = {tag=CreateTextTag()}
        SetTextTagPermanent(data.tag, true)
        if kind == 'induction' then
            data.effect = AddSpecialEffectTarget("Abilities/Spells/Orc/LightningShield/LightningShieldTarget.mdl", unit, "origin")
        end
        StackIndicators[unit][kind] = data
    end
    local label = kind == 'bleed' and ('Кровотечение: ' .. stacks) or ('Сверхпроводимость: ' .. stacks .. '/5')
    SetTextTagText(data.tag, label, 0.018)
    SetTextTagColor(data.tag, kind == 'bleed' and 255 or 100, kind == 'bleed' and 85 or 200, kind == 'bleed' and 85 or 255, 255)
    SetTextTagPosUnit(data.tag, unit, kind == 'bleed' and 65.0 or 90.0)
end

function Arena_UnitInLine(unit, sx, sy, ex, ey, width)
    local dx, dy = ex - sx, ey - sy
    local lengthSquared = dx * dx + dy * dy
    if lengthSquared == 0 then return false, 0 end
    local ux, uy = GetUnitX(unit) - sx, GetUnitY(unit) - sy
    local projection = (ux * dx + uy * dy) / lengthSquared
    if projection < 0 or projection > 1 then return false, projection end
    local px, py = ux - projection * dx, uy - projection * dy
    return px * px + py * py <= width * width, projection
end

function Arena_ShowProjectile(sx, sy, ex, ey)
    local effect = AddSpecialEffect("Abilities/Weapons/RocketMissile/RocketMissile.mdl", sx, sy)
    BlzSetSpecialEffectYaw(effect, math.atan(ey - sy, ex - sx))
    local timer, ticks = CreateTimer(), 0
    TimerStart(timer, 0.03, true, function()
        ticks = ticks + 1
        BlzSetSpecialEffectX(effect, sx + (ex - sx) * ticks / 10)
        BlzSetSpecialEffectY(effect, sy + (ey - sy) * ticks / 10)
        if ticks >= 10 then DestroyEffect(effect); DestroyTimer(timer) end
    end)
end

function Arena_ShowArea(x, y, radius, duration)
    local points, edges = {}, {}
    for i = 1, 16 do
        local angle = (i - 1) * math.pi * 2.0 / 16
        local px, py = x + math.cos(angle) * radius, y + math.sin(angle) * radius
        local location = Location(px, py)
        points[i] = {px, py, GetLocationZ(location) + 25.0}
        RemoveLocation(location)
    end
    for i = 1, 16 do
        local a, b = points[i], points[i % 16 + 1]
        local edge = AddLightningEx('DRAM', false, a[1], a[2], a[3], b[1], b[2], b[3])
        SetLightningColor(edge, 0.3, 0.7, 1.0, 0.65)
        edges[i] = edge
    end
    local timer = CreateTimer()
    TimerStart(timer, duration, false, function()
        for _, edge in ipairs(edges) do DestroyLightning(edge) end
        DestroyTimer(timer)
    end)
end

function Arena_PlayAbilityCue(caster, spellId)
    local areas = {
        A103={300,0.7,'point'}, A101={500,0.7}, A10D={350,0.7}, A10E={500,4}, A106={450,6,'point'},
        A10I={800,6}, A10J={900,1}, A109={350,1,'point'}, A10L={250,1,'point'},
        A117={350,0.7}, A10N={900,1}, A10O={700,8}, A111={275,1,'point'},
        A112={700,1,'point'}, A113={350,0.7}, A11A={400,0.7}, A11B={350,0.7},
        A11C={650,1.5}, A11D={350,4.5,'point'}, A11E={400,5,'point'}, A11G={600,5}
    }
    for raw, area in pairs(areas) do
        if spellId == FourCC(raw) then
            local x, y = GetUnitX(caster), GetUnitY(caster)
            if area[3] == 'point' then x, y = Arena_GetAimPoint(caster) end
            if raw == 'A11C' then
                local angle = GetUnitFacing(caster) * math.pi / 180.0
                x, y = x + math.cos(angle) * 200.0, y + math.sin(angle) * 200.0
            end
            if raw == 'A11G' then area[2] = 4.0 + GetUnitAbilityLevel(caster, spellId) end
            Arena_ShowArea(x, y, area[1], area[2])
            break
        end
    end
    local fx = {
        blood = "Abilities/Weapons/Blood/BloodImpact.mdl",
        heal = "Abilities/Spells/Undead/VampiricAura/VampiricAuraTarget.mdl",
        shield = "Abilities/Spells/Human/DivineShield/DivineShieldTarget.mdl",
        death = "Abilities/Spells/Undead/DeathAndDecay/DeathAndDecayTarget.mdl",
        blink = "Abilities/Spells/NightElf/Blink/BlinkCaster.mdl",
        electric = "Abilities/Spells/Orc/LightningShield/LightningShieldTarget.mdl",
        field = "Doodads/Cinematic/EnergyField/EnergyField.mdl",
        roots = "Abilities/Spells/NightElf/EntanglingRoots/EntanglingRootsTarget.mdl",
        nature = "Abilities/Spells/NightElf/Rejuvenation/RejuvenationTarget.mdl",
        raise = "Abilities/Spells/Undead/RaiseSkeletonWarrior/RaiseSkeleton.mdl",
        frost = "Abilities/Spells/Undead/FrostNova/FrostNovaTarget.mdl",
        parry = "Abilities/Spells/Human/Defend/DefendCaster.mdl",
        sun = "Abilities/Spells/NightElf/Tranquility/TranquilityTarget.mdl",
        metal = "Abilities/Spells/Human/FlakCannons/FlakTarget.mdl",
        time = "Abilities/Spells/Human/MassTeleport/MassTeleportTarget.mdl",
    }
    local cues = {
        [FourCC('A101')] = {fx.death, 0.5, 'ground'},
        [FourCC('A102')] = {fx.heal, 1, 'caster'},
        [FourCC('A10D')] = {fx.shield, 8, 'caster'},
        [FourCC('A10E')] = {"Abilities/Spells/Other/ImmolationRed/ImmolationRedTarget.mdl", 4, 'caster'},
        [FourCC('A103')] = {fx.blink, 0.5, 'caster'},
        [FourCC('A104')] = {fx.blink, 0.5, 'caster'},
        [FourCC('A10F')] = {fx.blood, 0.7, 'caster'},
        [FourCC('A10G')] = {fx.blood, 1, 'caster'},
        [FourCC('A105')] = {fx.electric, 0.7, 'target'},
        [FourCC('A106')] = {fx.field, 6, 'point'},
        [FourCC('A10H')] = {fx.electric, 5, 'caster'},
        [FourCC('A10I')] = {fx.field, 6, 'ground'},
        [FourCC('A107')] = {fx.roots, 1, 'ground'},
        [FourCC('A108')] = {fx.roots, 1, 'caster'},
        [FourCC('A10J')] = {fx.nature, 1.5, 'caster'},
        [FourCC('A10K')] = {fx.roots, 1.5, 'ground'},
        [FourCC('A109')] = {fx.raise, 1, 'point'},
        [FourCC('A10A')] = {fx.frost, 1, 'ground'},
        [FourCC('A10L')] = {fx.death, 1, 'ground'},
        [FourCC('A10M')] = {fx.frost, 1, 'ground'},
        [FourCC('A115')] = {fx.blink, 0.7, 'caster'},
        [FourCC('A116')] = {"Abilities/Spells/Orc/MirrorImage/MirrorImageCaster.mdl", 0.5, 'caster'},
        [FourCC('A117')] = {fx.parry, 1, 'caster'},
        [FourCC('A118')] = {fx.blink, 0.7, 'caster'},
        [FourCC('A10B')] = {fx.sun, 1, 'caster'},
        [FourCC('A10C')] = {fx.shield, 0.7, 'target'},
        [FourCC('A10N')] = {fx.sun, 1.5, 'caster'},
        [FourCC('A10O')] = {fx.sun, 8, 'ground'},
        [FourCC('A111')] = {fx.metal, 1, 'point'},
        [FourCC('A112')] = {fx.metal, 1, 'point'},
        [FourCC('A113')] = {fx.metal, 1, 'caster'},
        [FourCC('A114')] = {fx.metal, 1, 'caster'},
        [FourCC('A119')] = {fx.metal, 0.6, 'caster'},
        [FourCC('A11A')] = {fx.metal, 1, 'ground'},
        [FourCC('A11B')] = {fx.metal, 1, 'caster'},
        [FourCC('A11C')] = {fx.field, 1.5, 'ground'},
        [FourCC('A11D')] = {fx.time, 1, 'point'},
        [FourCC('A11E')] = {fx.field, 5, 'point'},
        [FourCC('A11F')] = {fx.blink, 0.7, 'caster'},
        [FourCC('A11G')] = {fx.field, 5, 'ground'},
    }
    local cue = cues[spellId]
    if cue == nil then return end
    local target = cue[3] == 'target' and GetSpellTargetUnit() or nil
    local effect
    if cue[3] == 'caster' or target ~= nil then
        effect = AddSpecialEffectTarget(cue[1], target or caster, "origin")
    else
        local x, y = GetUnitX(caster), GetUnitY(caster)
        if cue[3] == 'point' then x, y = Arena_GetAimPoint(caster) end
        effect = AddSpecialEffect(cue[1], x, y)
    end
    local timer = CreateTimer()
    TimerStart(timer, cue[2], false, function() DestroyEffect(effect); DestroyTimer(timer) end)
end

function Arena_CustomCast_Lua(caster, pid, spellId)
    -- Диспетчер способностей с гарантированной обработкой кастов
    local role = HeroKind[pid]
    if not role then
        for rId, cData in ipairs(HeroClasses) do
            for _, sId in ipairs(cData.spells) do
                if sId == spellId then
                    role = rId
                    HeroKind[pid] = rId
                    Heroes[pid] = caster
                    break
                end
            end
            if role then break end
        end
    end
    if not role then return end
    if spellId == HeroClasses[role].spells[4] and GetHeroLevel(caster) < 5 then return end

    local rank = GetUnitAbilityLevel(caster, spellId)
    if rank < 1 then return end
    if spellId ~= FourCC('A105') then Arena_PlayAbilityCue(caster, spellId) end

    local amount = 35.0 + 25.0 * rank

    -- 1. Тёмный Рыцарь (Сила / Танк-Джаггернаут)
    if role == 1 then
        if spellId == FourCC('A101') then -- Q: Раскол Рока (Стягивание 0.5с + АоЕ урон + таунт)
            Arena_PullArea(caster, 500.0, 0.5, amount * 2.0)
        elseif spellId == FourCC('A102') then -- W: Кровавая Жатва (Активная, процент от недостающего HP отряда)
            Arena_BloodHarvestActive(caster, amount * 0.08)
        elseif spellId == FourCC('A10D') then -- E: Щит Мучений (Щит здоровья + доп. броня)
            Arena_ShieldOfTorment(caster, amount * 3.5, 10 + rank * 5, 8.0)
            Arena_CustomArea(caster, 350.0, amount * 1.2, false)
        elseif spellId == FourCC('A10E') then -- R: Врата Преисподней (Приковывающие цепи рока)
            Arena_DoomChains(caster, 500.0, 4.0, 60.0 + rank * 25.0 + GetHeroStr(caster, true) * 0.5)
        end

    -- 4. Хранитель Древней / Друид Первобытного Леса (Сила / Саммонер & Биомасса)
    elseif role == 4 then
        if spellId == FourCC('A107') then -- Q: Пробуждение Древня-Защитника (Awaken Ironwood Treant)
            Arena_Druid_Q(caster, rank)
        elseif spellId == FourCC('A108') then -- W: Паразитические Споры / Рой Светляков (Spore Infestation)
            Arena_Druid_W(caster, rank)
        elseif spellId == FourCC('A10J') then -- E: Командный Симбиоз / Древесная Связь (Symbiotic Bond)
            Arena_Druid_E(caster, rank)
        elseif spellId == FourCC('A10K') then -- R: Первобытный Колосс: Аватар Леса (Colossus of the Deepwood)
            Arena_Druid_R(caster, rank)
        end

    -- 6. Мастер Клинка / Ронин (Ловкость / Керри Ближнего Боя)
    elseif role == 6 then
        if spellId == FourCC('A115') then -- Q: Рассекающий Выпад (Flash Step)
            Arena_Ronin_Q(caster, rank)
        elseif spellId == FourCC('A116') then -- W: Метка Иай: отложенный разрез
            Arena_Ronin_W(caster, rank)
        elseif spellId == FourCC('A117') then -- E: Стойка Возмездия
            Arena_Ronin_E(caster, rank)
        elseif spellId == FourCC('A118') then -- R: Абсолютный Разрез: Суд Времени (Spatial Rend)
            Arena_Ronin_R(caster, rank)
        end

    -- 9. Железный Исполин (Сила / Главный Танк, Инициатор и Стяжка)
    elseif role == 9 then
        if spellId == FourCC('A119') then -- Q: Стальной Снаряд / Запуск Кулака (Rocket Fist)
            Arena_Colossus_Q(caster, rank)
        elseif spellId == FourCC('A11A') then -- W: Сброс Давления: Паровой Выброс (Vent Steam)
            Arena_Colossus_W(caster, rank)
        elseif spellId == FourCC('A11B') then -- E: Литая Броня: Амортизация (Forged Plating)
            Arena_Colossus_E(caster, rank)
        elseif spellId == FourCC('A11C') then -- R: Магнитный Коллапс / Сейсмический Пресс (Magnetic Singularity)
            Arena_Colossus_R(caster, rank)
        end

    -- 2. Призрачный Ловчий / Ассасин (Ловкость / Одиночный урон — Мастер Клинка)
    elseif role == 2 then
        if spellId == FourCC('A103') then -- Q: Теневой Бросок (Урон + наложение 2 стаков кровотечения)
            Arena_ShadowThrow(caster, rank)
        elseif spellId == FourCC('A104') then -- Native Wind Walk handles invisibility and its break conditions.
            return
        elseif spellId == FourCC('A10F') then
            return -- Passive: applies on a landed attack.
        elseif spellId == FourCC('A10G') then -- R: Танец Лезвий (Омнислаш + 5 стаков кровотечения на цели)
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

    -- 3. Элементалист Бури / Архимаг Гроз (Интеллект / Абсолютный Магический AoE-Кастер)
    elseif role == 3 then
        if spellId == FourCC('A105') then -- Q: Цепной Разряд «Каскадная Дуга» (Arcing Discharge)
            Arena_Storm_Q(caster, rank)
        elseif spellId == FourCC('A106') then -- W: Статическое Поле «Грозовая Ловушка» (Static Field)
            Arena_Storm_W(caster, rank)
        elseif spellId == FourCC('A10H') then -- E: Перегрузка Ядра «Сверхпроводимость» (Core Supercharge)
            Arena_Storm_E(caster, rank)
        elseif spellId == FourCC('A10I') then -- R: Катаклизм Бури «Око Сверхновой» (Supercell Cataclysm)
            Arena_Storm_R(caster, rank)
        end

    -- 5. Архилич Чумы / Повелитель Мёртвых (Интеллект / Некромант-Призыватель)
    elseif role == 5 then
        if spellId == FourCC('A109') then -- Q: Восстание Могил: Скелеты-Осквернители (Grave Awakening)
            Arena_Lich_Q(caster, rank)
        elseif spellId == FourCC('A10A') then -- W: Ледяной Конструкт: Костяной Голем (Frostbone Revenant)
            Arena_Lich_W(caster, rank)
        elseif spellId == FourCC('A10L') then -- E: Взрыв Трупов: Чумная Детонация (Corpse Explosion)
            Arena_Lich_E(caster, rank)
        elseif spellId == FourCC('A10M') then -- R: Чёрные Врата: Призыв Дракона Нежити (Frost Wyrm Avatar)
            Arena_Lich_R(caster, rank)
        end

    -- 7. Жрица Рассвета (Интеллект / Боевой Саппорт, Защитник и Баффер)
    elseif role == 7 then
        if spellId == FourCC('A10B') then -- Q: Луч Рассвета (Dawn Beam)
            Arena_Priestess_Q(caster, rank)
        elseif spellId == FourCC('A10C') then -- W: Очищающий Ореол / Сфера Света (Cleansing Corona)
            Arena_Priestess_W(caster, rank)
        elseif spellId == FourCC('A10N') then -- E: Солнечный Источник (Solar Font)
            Arena_Priestess_E(caster, rank)
        elseif spellId == FourCC('A10O') then -- R: Триумф Солнца: Новая Заря (Dawn Awakening)
            Arena_Priestess_R(caster, rank)
        end

    -- 8. Инженер-Бомбардир (Ловкость / Осада и Зонинг)
    elseif role == 8 then
        if spellId == FourCC('A111') then -- Q: Кластерная Бомба «Осколочный Каскад»
            Arena_Bombardier_Q(caster, rank)
        elseif spellId == FourCC('A112') then -- W: Барьер из Растяжек и Капканов
            Arena_Bombardier_W(caster, rank)
        elseif spellId == FourCC('A113') then -- E: Зажигательно-разрывные патроны
            Arena_Bombardier_E(caster, rank)
        elseif spellId == FourCC('A114') then -- R: Передвижная Батарея «Град Огня»
            Arena_Bombardier_R(caster, rank)
        end

    -- 10. Хрономант / Хранитель Эпох (Интеллект / Тактический Саппорт-Манипулятор)
    elseif role == 10 then
        if spellId == FourCC('A11D') then -- Q: Временной Парадокс (Time Paradox)
            Arena_Chrono_Q(caster, rank)
        elseif spellId == FourCC('A11E') then -- W: Искажение Хронотока (Chrono Shift)
            Arena_Chrono_W(caster, rank)
        elseif spellId == FourCC('A11F') then -- E: Эхо Будущего (Echoes of the Future)
            Arena_Chrono_E(caster, rank)
        elseif spellId == FourCC('A11G') then -- R: Хроносфера: Зона Временного Стазиса (Grand Chronosphere)
            Arena_Chrono_R(caster, rank)
        end
    end
end

-- ===========================================================================
-- 3-Tier Item & Auto-Crafting System Data
-- ===========================================================================

ItemCraftRecipes = {
    -- 1. Переходные предметы (Midgame)
    {
        result = FourCC('I001'), -- Сапоги Скитальца
        components = { FourCC('boot'), FourCC('glov') }, -- Сапоги Ветра + Перчатки Проворства
        name = "Сапоги Скитальца"
    },
    {
        result = FourCC('I002'), -- Каменный Бастион
        components = { FourCC('rng1'), FourCC('prt5') }, -- Кольцо Закалки + Кристалл Жизни
        name = "Каменный Бастион"
    },
    {
        result = FourCC('I003'), -- Жало Пустоты
        components = { FourCC('rat6'), FourCC('glov') }, -- Клинок Остроты + Перчатки Проворства
        name = "Жало Пустоты"
    },
    {
        result = FourCC('I004'), -- Кодекс Тайной Магии
        components = { FourCC('I000'), FourCC('I0MA') }, -- Мантия Мудреца + Амулет Маны
        name = "Кодекс Тайной Магии"
    },

    -- 2. Уникальные Легендарные Артефакты (Реликвии мини-боссов)
    {
        result = FourCC('I005'), -- Эгида Несокрушимости
        components = { FourCC('I002'), FourCC('I00G') }, -- Каменный Бастион + Сердце Голема
        name = "Эгида Несокрушимости"
    },
    {
        result = FourCC('I006'), -- Погибель Миров: Клык Королевы
        components = { FourCC('I003'), FourCC('I00V') }, -- Жало Пустоты + Хелицера Королевы Яда
        name = "Погибель Миров: Клык Королевы"
    },
    {
        result = FourCC('I007'), -- Секира Пекла
        components = { FourCC('rat6'), FourCC('belv'), FourCC('I00F') }, -- Клинок Остроты + Пояс Титана + Пылающий Осколок
        name = "Секира Пекла"
    },
    {
        result = FourCC('I008'), -- Астральный Скипетр Времени
        components = { FourCC('I004'), FourCC('I00E') }, -- Кодекс Тайной Магии + Око Вечности
        name = "Астральный Скипетр Времени"
    },
    {
        result = FourCC('I009'), -- Призрачные Поступи
        components = { FourCC('I001'), FourCC('I00C') }, -- Сапоги Скитальца + Мантия Сумерек
        name = "Призрачные Поступи"
    }
}

function Arena_CheckItemCrafting(hero)
    if hero == nil or GetWidgetLife(hero) <= 0.405 or CraftingHeroes[hero] then return end
    CraftingHeroes[hero]=true
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
            -- Удаляем компоненты
            for _, it in pairs(matchedSlots) do
                RemoveItem(it)
            end
            -- Создаем собранный артефакт
            local crafted = UnitAddItemById(hero, recipe.result)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Items/AIam/AIamTarget.mdl", hero, "origin"))
            DisplayTimedTextToPlayer(GetOwningPlayer(hero), 0, 0, 8.0, "|cffffcc00[АРТЕФАКТ СОБРАН]:|r " .. recipe.name)
            break
        end
    end
    CraftingHeroes[hero]=nil
end

function Arena_DisableHeroLearning(hero)
    -- AHer contains the hero's internal state. Removing it can crash selection.
    -- Hide only its command button, keeping the ability enabled and attached.
    -- Hide flags are counters in the engine, so apply the UI change once.
    if not HeroLearningHidden[hero] then
        BlzUnitDisableAbility(hero, FourCC('AHer'), false, true)
        HeroLearningHidden[hero] = true
    end
    local points = GetHeroSkillPoints(hero)
    if points > 0 then UnitModifySkillPoints(hero, -points) end
end

function Arena_UpdateRanks(hero, role)
    local level = GetHeroLevel(hero)
    for slot, spell in ipairs(HeroClasses[role].spells) do
        local rank = math.min(5, 1 + math.floor(math.max(0,level-(slot==4 and 5 or 1))/4))
        SetUnitAbilityLevel(hero,spell,rank)
    end
end

function Arena_UpdateUltimate(hero, role)
    local spell = HeroClasses[role].spells[4]
    local locked = GetHeroLevel(hero) < 5
    if locked and not UltimateLocked[hero] then
        BlzUnitDisableAbility(hero, spell, true, false)
        UltimateLocked[hero] = true
    elseif not locked and UltimateLocked[hero] then
        BlzUnitDisableAbility(hero, spell, false, false)
        UltimateLocked[hero] = nil
        DisplayTextToPlayer(GetOwningPlayer(hero), 0, 0, "|cffffcc00Открыта ультимативная способность!|r")
    end
end

function InitCustomTriggers()
    local leave = CreateTrigger()
    for pid=0,3 do TriggerRegisterPlayerEvent(leave,Player(pid),EVENT_PLAYER_LEAVE) end
    TriggerAddAction(leave,function()
        ArenaLeft[GetPlayerId(GetTriggerPlayer())]=true
        udg_HumanCount=Arena_CountHumans()
        Arena_TryStartWaves()
    end)
    local enemyTimer = CreateTimer()
    TimerStart(enemyTimer, 1.0, true, Arena_UpdateEnemyOrders)
    local statusTimer = CreateTimer()
    TimerStart(statusTimer, 0.2, true, function()
        for id, data in pairs(InductionStacks) do
            data.duration = data.duration - 0.2
            if GetUnitTypeId(data.target) == 0 or GetWidgetLife(data.target) <= 0.405 or data.duration <= 0 then
                Arena_ClearStackIndicator(data.target, 'induction')
                InductionStacks[id] = nil
            end
        end
        for unit, indicators in pairs(StackIndicators) do
            if GetUnitTypeId(unit) == 0 or GetWidgetLife(unit) <= 0.405 then
                Arena_ClearStackIndicator(unit, 'bleed')
                Arena_ClearStackIndicator(unit, 'induction')
            else
                for kind, data in pairs(indicators) do
                    SetTextTagPosUnit(data.tag, unit, kind == 'bleed' and 65.0 or 90.0)
                end
            end
        end
    end)
    local parryDamage = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(parryDamage, EVENT_PLAYER_UNIT_DAMAGED)
    TriggerAddAction(parryDamage, function()
        Arena_ItemDamage(GetEventDamageSource(),GetTriggerUnit(),GetEventDamage(),BlzGetEventIsAttack())
        Arena_ResolveReflect(GetTriggerUnit(), GetEventDamageSource(), GetEventDamage())
        if GetEventDamage() > 0 and BlzGetEventIsAttack() then
            Arena_Storm_OnAttackHit(GetEventDamageSource(), GetTriggerUnit())
            Arena_HeroHitPassives(GetEventDamageSource(), GetTriggerUnit())
        end
    end)
    local levelTrigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(levelTrigger, EVENT_PLAYER_HERO_LEVEL)
    TriggerAddAction(levelTrigger, function()
        local hero = GetTriggerUnit()
        local pid = GetPlayerId(GetOwningPlayer(hero))
        if Heroes[pid] == hero then
            Arena_DisableHeroLearning(hero)
            Arena_UpdateRanks(hero, HeroKind[pid])
            Arena_UpdateUltimate(hero, HeroKind[pid])
        end
    end)
    local cancelStance=CreateTrigger()
    for _,event in ipairs({EVENT_PLAYER_UNIT_ISSUED_ORDER,EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER,EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER}) do
        TriggerRegisterAnyUnitEventBJ(cancelStance,event)
    end
    TriggerAddAction(cancelStance,function()
        Arena_ResolveOrder(GetTriggerUnit(),GetIssuedOrderId())
    end)
    -- Инициализация глобальной системы кровотечения
    Arena_InitBleedSystem()
    -- Инициализация систем Инженера-Бомбардира
    Arena_InitBombardierSystem()

    -- Триггер автоатак
    local attackTrigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(attackTrigger, EVENT_PLAYER_UNIT_ATTACKED)
    TriggerAddAction(attackTrigger, function()
        local attacker = GetAttacker()
        local target = GetTriggerUnit()
        if attacker ~= nil and target ~= nil and GetWidgetLife(attacker) > 0.405 and GetWidgetLife(target) > 0.405 then
            Arena_OnUnitAttack(attacker, target)

        end
    end)
    -- Инициализация таймера и диалога таймера волн
    udg_WaveTimer = CreateTimer()
    udg_WaveTD = CreateTimerDialog(udg_WaveTimer)

    -- Считаем количество игроков-людей
    udg_HumanCount = 0
    for i = 0, 3 do
        if Arena_IsHuman(i) then
            udg_HumanCount = udg_HumanCount + 1
        end
    end
    if udg_HumanCount == 0 then
        udg_HumanCount = 1
    end

    -- 1. Триггер для отлова применения заклинаний (создаем сразу)
    local spellTrigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(spellTrigger, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    TriggerAddAction(spellTrigger, function()
        local caster = GetTriggerUnit()
        local spellId = GetSpellAbilityId()
        local pid = GetPlayerId(GetOwningPlayer(caster))
        Arena_CustomCast_Lua(caster, pid, spellId)
    end)


    -- Триггер поднятия предметов для подбора рецептов / автосборки
    local itemPickupTrigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(itemPickupTrigger, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    TriggerAddAction(itemPickupTrigger, function()
        local hero = GetManipulatingUnit()
        Arena_CheckItemCrafting(hero)
    end)

    -- Триггер гибели юнитов (начисление золота, зачистка волны, воскрешение)
    local deathTrigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(deathTrigger, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddAction(deathTrigger, Trig_Death_Actions)

    -- Триггер гибели босса
    local bossDeathTrigger = CreateTrigger()
    TriggerRegisterPlayerUnitEvent(bossDeathTrigger, Player(PLAYER_NEUTRAL_AGGRESSIVE), EVENT_PLAYER_UNIT_DEATH, nil)
    TriggerAddAction(bossDeathTrigger, Trig_Boss_Actions)

    -- Периодический триггер мышления босса (фазы 65% и 30%)
    local bossThinkTrigger = CreateTrigger()
    TriggerRegisterTimerEvent(bossThinkTrigger, 1.00, true)
    TriggerAddAction(bossThinkTrigger, Trig_BossThink_Actions)

    -- 2. Стартовый триггер (срабатывает через 0.5 сек ПОСЛЕ старта игры)
    local initTimer = CreateTrigger()
    TriggerRegisterTimerEvent(initTimer, 0.50, false)
    TriggerAddAction(initTimer, function()
        -- Отключаем туман войны
        FogEnableOff()
        FogMaskEnableOff()

        print("|cffffcc00[Инициализация]: Запуск выбора героев...|r")

        -- СОЗДАЕМ ДИАЛОГ ТОЛЬКО СЕЙЧАС (когда движок игры готов):
        HeroDialog = DialogCreate()
        DialogSetMessage(HeroDialog, "Выберите класс героя:")

        HeroDialogButtons = {}
        for i, classData in ipairs(HeroClasses) do
            HeroDialogButtons[i] = DialogAddButton(HeroDialog, classData.name, 0)
        end

        -- Регистрируем триггер клика по кнопкам
        local dialogTrigger = CreateTrigger()
        TriggerRegisterDialogEvent(dialogTrigger, HeroDialog)
        TriggerAddAction(dialogTrigger, function()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            local clickedBtn = GetClickedButton()

            for i, btn in ipairs(HeroDialogButtons) do
                if btn == clickedBtn then
                    SpawnSelectedHero(pid, i)
                    break
                end
            end
        end)

        function ShowHeroSelectionDialog()
            for pid = 0, 3 do
                local p = Player(pid)
                if GetPlayerSlotState(p) == PLAYER_SLOT_STATE_PLAYING then
                    DialogDisplay(p, HeroDialog, true)
                end
            end
        end

        ShowHeroSelectionDialog()

        -- Чат-триггер выбора героя через -1 .. -10
        Arena_ChatTrigger = CreateTrigger()
        for pid = 0, 3 do
            TriggerRegisterPlayerChatEvent(Arena_ChatTrigger, Player(pid), "-", false)
        end
        TriggerAddAction(Arena_ChatTrigger, function()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            local msg = GetEventPlayerChatString()
            local num = tonumber(string.sub(msg, 2))
            if num and num % 1 == 0 and num >= 1 and num <= #HeroClasses then
                if HeroDialog ~= nil then
                    DialogDisplay(p, HeroDialog, false)
                end
                SpawnSelectedHero(pid, num)
            end
        end)
        DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 15.0, "|cffff0000[АРЕНА]:|r Выберите класс героя в окне (или напишите в чат от -1 до -10)!")
    end)
end

function InitCustomPlayerSlots()
    for i = 0, 3 do
        SetPlayerStartLocation(Player(i), i)
        SetPlayerColor(Player(i), ConvertPlayerColor(i))
        SetPlayerRacePreference(Player(i), RACE_PREF_HUMAN)
        SetPlayerRaceSelectable(Player(i), false)
        SetPlayerController(Player(i), MAP_CONTROL_USER)
    end
end

function InitCustomTeams()
    for i = 0, 3 do
        SetPlayerTeam(Player(i), 0)
        for j = 0, 3 do
            if i ~= j then
                SetPlayerAlliance(Player(i),Player(j),ALLIANCE_PASSIVE,true)
                SetPlayerAlliance(Player(i),Player(j),ALLIANCE_SHARED_VISION,true)
            end
        end
    end
end

function main()
    SetCameraBounds(-3328.0 + GetCameraMargin(CAMERA_MARGIN_LEFT),
                    -3584.0 + GetCameraMargin(CAMERA_MARGIN_BOTTOM),
                     3328.0 - GetCameraMargin(CAMERA_MARGIN_RIGHT),
                     3072.0 - GetCameraMargin(CAMERA_MARGIN_TOP),
                    -3328.0 + GetCameraMargin(CAMERA_MARGIN_LEFT),
                     3072.0 - GetCameraMargin(CAMERA_MARGIN_TOP),
                     3328.0 - GetCameraMargin(CAMERA_MARGIN_RIGHT),
                    -3584.0 + GetCameraMargin(CAMERA_MARGIN_BOTTOM))

    SetDayNightModels("Environment/DNC/DNCLordaeron/DNCLordaeronTerrain/DNCLordaeronTerrain.mdl",
                       "Environment/DNC/DNCLordaeron/DNCLordaeronUnit/DNCLordaeronUnit.mdl")
    NewSoundEnvironment("Default")
    SetAmbientDaySound("LordaeronSummerDay")
    SetAmbientNightSound("LordaeronSummerNight")
    SetMapMusic("Music", true, 0)

    InitBlizzard()
    InitGlobals()
    Arena_CreateLandscape()
    InitCustomTriggers()
    Arena_InitEconomy()
end

function config()
    SetMapName("Hero Arena")
    SetMapDescription("Кооперативная арена: 10 героев, 50 волн и финальный босс.")
    SetPlayers(4)
    SetTeams(1)
    SetGamePlacement(MAP_PLACEMENT_TEAMS_TOGETHER)
    for i = 0, 3 do
        DefineStartLocation(i, 0.0, 0.0)
    end
    InitCustomPlayerSlots()
    InitCustomTeams()
    for i = 0, 3 do
        SetPlayerSlotAvailable(Player(i), MAP_CONTROL_USER)
    end
end

-- ===========================================================================
-- Wave System Helper Functions
-- ===========================================================================

function Arena_Msg(s)
    DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 10.0, s)
end

function Arena_IsHuman(pid)
    if ArenaLeft and ArenaLeft[pid] then return false end
    local p = Player(pid)
    local slotState = GetPlayerSlotState(p)
    local controller = GetPlayerController(p)
    if slotState == PLAYER_SLOT_STATE_PLAYING then
        return controller == MAP_CONTROL_USER or controller == MAP_CONTROL_COMPUTER
    end
    return false
end

function Arena_CountHumans()
    local n = 0
    for pid = 0, 3 do
        if Arena_IsHuman(pid) then
            n = n + 1
        end
    end
    if n < 1 then
        n = 1
    end
    return n
end

function Arena_CreateEnemy(unitId, x, y)
    local u = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), unitId, x, y, 270.0)
    if u == nil then
        return
    end
    udg_EnemiesAlive = udg_EnemiesAlive + 1
    SetUnitUserData(u, 777)
    Arena_PrepareEnemy(u)
    IssuePointOrder(u, "attack", 0.0, 0.0)
end

function Arena_PrepareEnemy(unit)
    -- Neutral owners keep their camp leash when only SetUnitCreepGuard is used.
    -- Clear it under an unused regular owner, then restore the neutral owner.
    local owner = GetOwningPlayer(unit)
    SetUnitOwner(unit, Player(9), false)
    SetUnitCreepGuard(unit, false)
    RemoveGuardPosition(unit)
    SetUnitOwner(unit, owner, false)
    UnitIgnoreAlarm(unit, true)
    UnitWakeUp(unit)
    SetUnitAcquireRange(unit, 5000.0)
    ArenaEnemies[unit] = true
end

function Arena_UpdateEnemyOrders()
    for unit in pairs(ArenaEnemies) do
        if GetUnitTypeId(unit) == 0 or GetWidgetLife(unit) <= 0.405 then
            ArenaEnemies[unit] = nil
        elseif not IsUnitPaused(unit) then
            local order = GetUnitCurrentOrder(unit)
            -- Repair retreat/idle orders without interrupting attacks or spells.
            if order == 0 or order == OrderId('move') or order == OrderId('smart') then
                local closest, distance = nil, math.huge
                for pid = 0, 3 do
                    local hero = Heroes[pid]
                    if hero ~= nil and GetWidgetLife(hero) > 0.405 then
                        local d = (GetUnitX(hero)-GetUnitX(unit))^2 + (GetUnitY(hero)-GetUnitY(unit))^2
                        if d < distance then closest, distance = hero, d end
                    end
                end
                if closest ~= nil then IssueTargetOrder(unit, 'attack', closest) end
            end
        end
    end
end

function Arena_SpawnRing(unitId, count, dist)
    local scaled = math.floor((count * (udg_HumanCount + 2) + 3) / 4)
    if scaled < 2 then
        scaled = 2
    end
    local i = 0
    while i < scaled and udg_EnemiesAlive < 70 do
        local ang = (3.14159 * 2.0) * i / scaled
        local rx = dist * math.cos(ang) + GetRandomReal(-70.0, 70.0)
        local ry = dist * math.sin(ang) + GetRandomReal(-70.0, 70.0)
        Arena_CreateEnemy(unitId, rx, ry)
        i = i + 1
    end
end

function Arena_EliteName(wave)
    if wave == 5 then return "Вожак головорезов"
    elseif wave == 10 then return "Капитан беззакония"
    elseif wave == 15 then return "Тролль-знахарь"
    elseif wave == 20 then return "Огр-землелом"
    elseif wave == 25 then return "Пророк костей"
    elseif wave == 30 then return "Паучий патриарх"
    elseif wave == 35 then return "Ловчий Скверны"
    elseif wave == 40 then return "Пожиратель стали"
    elseif wave == 45 then return "Собиратель душ"
    end
    return "Предвестник Каз'Рула"
end

function Arena_EliteType(wave)
    if wave == 5 then return FourCC('nrog')
    elseif wave == 10 then return FourCC('ngno')
    elseif wave == 15 then return FourCC('nftr')
    elseif wave == 20 then return FourCC('nogr')
    elseif wave == 25 then return FourCC('nska')
    elseif wave == 30 then return FourCC('ucry')
    elseif wave == 35 then return FourCC('nfel')
    elseif wave == 40 then return FourCC('nogr')
    elseif wave == 45 then return FourCC('uabo')
    end
    return FourCC('uabo')
end

function Arena_EliteVoicePath(wave)
    if wave <= 10 then
        return "Units/Creeps/Bandit/BanditPissed1.wav"
    elseif wave <= 20 then
        return "Units/Creeps/Ogre/OgrePissed1.wav"
    elseif wave <= 30 then
        return "Units/Undead/Necromancer/NecromancerPissed1.wav"
    elseif wave <= 40 then
        return "Units/Demon/FelGuard/FelGuardPissed1.wav"
    end
    return "Units/Undead/Abomination/AbominationPissed1.wav"
end

function Arena_EliteTaunt(wave)
    if wave == 5 then return "Ваши головы украсят нашу крепость!"
    elseif wave == 10 then return "Закон здесь задаём мы!"
    elseif wave == 15 then return "Духи предков требуют вашу кровь!"
    elseif wave == 20 then return "Я раскрошу ваши кости!"
    elseif wave == 25 then return "Мёртвые встают по моей воле!"
    elseif wave == 30 then return "Паутина станет вашей могилой!"
    elseif wave == 35 then return "Скверна пожрёт вашу плоть!"
    elseif wave == 40 then return "Ваши клинки сломаются!"
    elseif wave == 45 then return "Каждая смерть приближает повелителя!"
    end
    return "Каз'Рул уже ждёт вас!"
end

function Arena_EliteAnnouncement(wave, x, y)
    local tag = CreateTextTag()
    local alert = CreateSound(Arena_EliteVoicePath(wave), false, false, false, 10, 10, "")
    local title = Arena_EliteName(wave)
    Arena_Msg("|cffff8844[ОСОБАЯ ВОЛНА " .. tostring(wave) .. "]|r " .. title .. ": |cffffcc77" .. Arena_EliteTaunt(wave) .. "|r")
    SetTextTagText(tag, "|cffff6622" .. title .. "|r", 0.035)
    SetTextTagPos(tag, x - 180.0, y, 140.0)
    SetTextTagColor(tag, 255, 150, 65, 255)
    SetTextTagPermanent(tag, false)
    SetTextTagLifespan(tag, 7.0)
    SetTextTagFadepoint(tag, 5.0)
    PingMinimap(x, y, 5.0)
    if alert ~= nil then
        SetSoundVolume(alert, 105)
        StartSound(alert)
        KillSoundWhenDone(alert)
    end
end

function Arena_SpawnElite(wave)
    local x = 0.0
    local y = 1510.0
    if udg_EnemiesAlive >= 70 then
        return
    end
    local elite = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), Arena_EliteType(wave), x, y, 270.0)
    if elite == nil then
        return
    end
    udg_EnemiesAlive = udg_EnemiesAlive + 1
    SetUnitUserData(elite, 888)
    local scale = 1.20 + 0.003 * wave
    SetUnitScale(elite, scale, scale, scale)
    SetUnitVertexColor(elite, 255, 155, 110, 255)
    Arena_PrepareEnemy(elite)
    if wave >= 25 then
        UnitAddAbility(elite, FourCC('ACav'))
    end
    Arena_EliteAnnouncement(wave, x, y)
    IssuePointOrder(elite, "attack", 0.0, 0.0)
end

function Arena_PayWaveGold(gold)
    for i = 0, 3 do
        if Arena_IsHuman(i) then
            local p = Player(i)
            SetPlayerState(p, PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(p, PLAYER_STATE_RESOURCE_GOLD) + gold)
        end
    end
end

function Arena_WaveTheme(wave)
    local chapter = math.floor((wave - 1) / 5)
    if chapter == 0 then return "Разбойничий тракт"
    elseif chapter == 1 then return "Гнолльи стаи"
    elseif chapter == 2 then return "Троллья засада"
    elseif chapter == 3 then return "Огрские заставы"
    elseif chapter == 4 then return "Восстание костей"
    elseif chapter == 5 then return "Склеп паучьего короля"
    elseif chapter == 6 then return "Осквернённая охота"
    elseif chapter == 7 then return "Врата Скверны"
    elseif chapter == 8 then return "Некрополь"
    end
    return "Последняя армия Каз'Рула"
end

function Arena_SpawnWaveCreeps(wave)
    local chapter = math.floor((wave - 1) / 5)
    local front = 5 + math.floor(wave / 8)
    local back = 2 + math.floor(wave / 15)
    local eliteSupport = 0
    if wave % 5 == 0 then
        eliteSupport = 1
    end
    if chapter == 0 then
        Arena_SpawnRing(FourCC('nban'), front, 1210.0)
        Arena_SpawnRing(FourCC('ngno'), back, 1480.0)
    elseif chapter == 1 then
        Arena_SpawnRing(FourCC('nrog'), front, 1220.0)
        Arena_SpawnRing(FourCC('ngna'), back, 1450.0)
    elseif chapter == 2 then
        Arena_SpawnRing(FourCC('nftr'), front, 1260.0)
        Arena_SpawnRing(FourCC('nftb'), back, 1480.0)
    elseif chapter == 3 then
        Arena_SpawnRing(FourCC('ngno'), front + 2, 1220.0)
        Arena_SpawnRing(FourCC('nogr'), back, 1470.0)
    elseif chapter == 4 then
        Arena_SpawnRing(FourCC('uske'), front + 2, 1210.0)
        Arena_SpawnRing(FourCC('nska'), back + 1, 1490.0)
    elseif chapter == 5 then
        Arena_SpawnRing(FourCC('uske'), front, 1240.0)
        Arena_SpawnRing(FourCC('ucry'), back, 1490.0)
    elseif chapter == 6 then
        Arena_SpawnRing(FourCC('nfel'), front, 1250.0)
        Arena_SpawnRing(FourCC('nska'), back + 1, 1490.0)
    elseif chapter == 7 then
        Arena_SpawnRing(FourCC('nfel'), front + 1, 1220.0)
        Arena_SpawnRing(FourCC('nogr'), back, 1480.0)
    elseif chapter == 8 then
        Arena_SpawnRing(FourCC('uske'), front + 3, 1210.0)
        Arena_SpawnRing(FourCC('nfel'), back + 1, 1480.0)
    else
        Arena_SpawnRing(FourCC('uske'), front + 4, 1240.0)
        Arena_SpawnRing(FourCC('uabo'), 1 + eliteSupport, 1480.0)
        Arena_SpawnRing(FourCC('nska'), back + 1, 1600.0)
    end
end

function Arena_CountPickedHumans()
    local count = 0
    for pid = 0, 3 do
        if Arena_IsHuman(pid) and Heroes[pid] ~= nil then
            count = count + 1
        end
    end
    return count
end

function Arena_TryStartWaves()
    if udg_WavesStarted then
        return
    end
    local pickedCount = Arena_CountPickedHumans()
    if pickedCount > 0 and pickedCount == Arena_CountHumans() then
        udg_WavesStarted = true
        TimerStart(udg_WaveTimer, 15.00, false, Trig_Wave_Actions)
        TimerDialogSetTitle(udg_WaveTD, "Волна 1")
        TimerDialogDisplay(udg_WaveTD, true)
        Arena_Msg("Герой выбран! Первая волна через 15 секунд. Покупайте предметы в лавках!")
    elseif pickedCount > 0 then
        Arena_Msg("Готовы " .. pickedCount .. "/" .. Arena_CountHumans() .. ". Ждём выбора героев остальными игроками.")
    end
end

function Arena_SpawnBoss()
    if udg_Boss ~= nil or udg_GameOver then
        return
    end
    udg_BossPhase = 0
    udg_Boss = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), FourCC('Nplh'), 0.0, 900.0, 270.0)
    if udg_Boss == nil then
        Arena_Msg("Boss creation failed: check Nplh.")
        return
    end
    Arena_PrepareEnemy(udg_Boss)
    SetHeroLevel(udg_Boss, 14 + udg_HumanCount, false)
    SetHeroStr(udg_Boss, 52 + 12 * udg_HumanCount, true)
    SetHeroAgi(udg_Boss, 20 + 3 * udg_HumanCount, true)
    SetHeroInt(udg_Boss, 25 + 4 * udg_HumanCount, true)
    SetUnitState(udg_Boss, UNIT_STATE_LIFE, GetUnitState(udg_Boss, UNIT_STATE_MAX_LIFE))
    UnitAddAbility(udg_Boss, FourCC('ACua'))
    UnitAddAbility(udg_Boss, FourCC('ACah'))
    UnitAddItemById(udg_Boss, FourCC('ckng'))
    UnitAddItemById(udg_Boss, FourCC('modt'))
    SetUnitAcquireRange(udg_Boss, 5000.0)
    IssuePointOrder(udg_Boss, "attack", 0.0, 0.0)
    Arena_Msg("|cffff4444Kaz'Rul has arrived! At 65% and 30% health he summons reinforcements.|r")
    PingMinimap(0.0, 900.0, 6.00)
end

function Arena_BossNova(damage)
    local fx = AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", GetUnitX(udg_Boss), GetUnitY(udg_Boss))
    DestroyEffect(fx)
    for i = 0, 3 do
        local hero = Heroes[i]
        if hero ~= nil and GetWidgetLife(hero) > 0.405 and IsUnitInRange(hero, udg_Boss, 600.0) then
            UnitDamageTarget(udg_Boss, hero, damage, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
        end
    end
end

function Trig_BossThink_Actions()
    if udg_GameOver or udg_Boss == nil or GetWidgetLife(udg_Boss) <= 0.405 then
        return
    end
    local health = GetUnitLifePercent(udg_Boss)
    if udg_BossPhase == 0 and health <= 65.0 then
        udg_BossPhase = 1
        Arena_Msg("|cffff8844Kaz'Rul summons his Bone Legion!|r")
        Arena_SpawnRing(FourCC('uske'), 4 + 2 * udg_HumanCount, 780.0)
        Arena_BossNova(45.0 + 12.0 * udg_HumanCount)
    elseif udg_BossPhase == 1 and health <= 30.0 then
        udg_BossPhase = 2
        Arena_Msg("|cffff4444Kaz'Rul is enraged!|r")
        Arena_SpawnRing(FourCC('uske'), 3 + udg_HumanCount, 850.0)
        UnitAddAbility(udg_Boss, FourCC('ACro'))
        IssueImmediateOrder(udg_Boss, "roar")
        Arena_BossNova(70.0 + 16.0 * udg_HumanCount)
    end
end

function Trig_Wave_Actions()
    if udg_GameOver then
        return
    end
    if udg_Wave >= 50 then
        TimerDialogDisplay(udg_WaveTD, false)
        Arena_SpawnBoss()
        return
    end
    udg_Wave = udg_Wave + 1
    udg_WaveCleared = false
    Arena_SpawnWaveCreeps(udg_Wave)
    if udg_Wave % 5 == 0 then
        Arena_SpawnElite(udg_Wave)
    end
    Arena_PayWaveGold(38 + udg_Wave * 5)
    Arena_Msg("|cffffcc00Волна " .. tostring(udg_Wave) .. "/50|r — " .. Arena_WaveTheme(udg_Wave) .. ". Врагов: " .. tostring(udg_EnemiesAlive))
    if udg_Wave < 50 then
        TimerDialogSetTitle(udg_WaveTD, "Волна " .. tostring(udg_Wave + 1))
    else
        TimerDialogSetTitle(udg_WaveTD, "Финальный босс")
    end
    TimerStart(udg_WaveTimer, 45.00, false, Trig_Wave_Actions)
end

function Arena_ReviveHero(pid)
    if udg_GameOver or Heroes[pid] == nil then
        return
    end
    local x, y = -144.0, -144.0
    if pid == 1 then x, y = 144.0, -144.0
    elseif pid == 2 then x, y = -144.0, 144.0
    elseif pid == 3 then x, y = 144.0, 144.0
    end
    ReviveHero(Heroes[pid], x, y, true)
    SetUnitState(Heroes[pid], UNIT_STATE_LIFE, GetUnitState(Heroes[pid], UNIT_STATE_MAX_LIFE) * 0.60)
    SetUnitState(Heroes[pid], UNIT_STATE_MANA, GetUnitState(Heroes[pid], UNIT_STATE_MAX_MANA) * 0.40)
    PanCameraToTimedForPlayer(Player(pid), x, y, 0.00)
    DisplayTimedTextToPlayer(Player(pid), 0, 0, 6.00, "Вы воскресли в центре арены.")
end

function Arena_CheckWaveClear()
    if udg_WavesStarted and udg_Wave >= 1 and udg_Wave <= 50 and udg_EnemiesAlive == 0 and not udg_WaveCleared and udg_Boss == nil and not udg_GameOver then
        udg_WaveCleared = true
        Arena_Msg("|cff66ff99Волна зачищена! Следующая через 7 секунд.|r")
        TimerStart(udg_WaveTimer, 7.00, false, Trig_Wave_Actions)
    end
end

function Trig_Death_Actions()
    local u = GetDyingUnit()
    local killer = GetKillingUnit()
    if GetOwningPlayer(u) == Player(PLAYER_NEUTRAL_AGGRESSIVE) and u ~= udg_Boss then
        if udg_EnemiesAlive > 0 then
            udg_EnemiesAlive = udg_EnemiesAlive - 1
        end
        udg_TotalKills = udg_TotalKills + 1
        if GetUnitUserData(u) == 888 then
            Arena_Msg("|cffffcc66Побеждён мини-босс! Команде начислена награда и выпала Реликвия.|r")
            Arena_PayWaveGold(50 + udg_Wave * 3)
            -- Выпадение реликвий с конкретных мини-боссов
            local ux, uy = GetUnitX(u), GetUnitY(u)
            if udg_Wave == 5 or udg_Wave == 20 then
                CreateItem(FourCC('I00G'), ux, uy) -- Сердце Голема
            elseif udg_Wave == 10 or udg_Wave == 30 then
                CreateItem(FourCC('I00V'), ux, uy) -- Хелицера Королевы Яда
            elseif udg_Wave == 15 or udg_Wave == 35 then
                CreateItem(FourCC('I00F'), ux, uy) -- Пылающий Осколок Метеорита
            elseif udg_Wave == 25 or udg_Wave == 40 then
                CreateItem(FourCC('I00E'), ux, uy) -- Око Вечности
            else
                CreateItem(FourCC('I00C'), ux, uy) -- Мантия Сумерек
            end
        end
        if udg_EnemiesAlive == 0 then
            Arena_CheckWaveClear()
        end
        if killer ~= nil then
            local pid = GetPlayerId(GetOwningPlayer(killer))
            if pid >= 0 and pid < 4 and Arena_IsHuman(pid) then
                local reward = 5 + udg_Wave
                udg_PlayerKills[pid + 1] = (udg_PlayerKills[pid + 1] or 0) + 1
                SetPlayerState(Player(pid), PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(Player(pid), PLAYER_STATE_RESOURCE_GOLD) + reward)
            end
        end
        return
    end
    if not IsUnitType(u, UNIT_TYPE_HERO) or GetOwningPlayer(u) == Player(PLAYER_NEUTRAL_AGGRESSIVE) then
        return
    end
    local pid = GetPlayerId(GetOwningPlayer(u))
    if pid < 0 or pid > 3 or not Arena_IsHuman(pid) or u ~= Heroes[pid] then
        return
    end
    DisplayTimedTextToPlayer(Player(pid), 0, 0, 8.00, "Смерть. Воскрешение через 12 сек.")
    if not udg_ReviveTimer[pid] then
        udg_ReviveTimer[pid] = CreateTimer()
    end
    TimerStart(udg_ReviveTimer[pid], 12.00, false, function()
        Arena_ReviveHero(pid)
    end)
end

function Trig_Boss_Actions()
    if udg_GameOver or GetDyingUnit() ~= udg_Boss then
        return
    end
    udg_GameOver = true
    PauseTimer(udg_WaveTimer)
    TimerDialogDisplay(udg_WaveTD, false)
    Arena_Msg("|cff00ff00Победа! Каз'Рул повержен. Арена остается открытой для свободной игры.|r")
    Arena_PayWaveGold(800)
end

-- ===========================================================================
-- Helper functions for Custom Spells
-- ===========================================================================

function Arena_PullArea(caster, radius, delay, damageAmount)
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Undead/DarkRitual/DarkRitualCaster.mdl", cx, cy))
    local t = CreateTimer()
    TimerStart(t, delay, false, function()
        local ncx, ncy = GetUnitX(caster), GetUnitY(caster)
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, ncx, ncy, radius, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
                SetUnitPosition(u, ncx + GetRandomReal(-40.0, 40.0), ncy + GetRandomReal(-40.0, 40.0))
                IssueTargetOrder(u, "attack", caster)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/HowlOfTerror/HowlTarget.mdl", u, "overhead"))
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
    for i = 0, 3 do
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
    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/VampiricAura/VampiricAuraTarget.mdl", caster, "origin"))
end

function Arena_ClearTormentShield(caster)
    local state = TormentShields[caster]
    if state == nil then return end
    TormentShields[caster] = nil
    DestroyTimer(state.timer)
    if GetUnitTypeId(caster) == 0 then return end
    BlzSetUnitArmor(caster, BlzGetUnitArmor(caster) - state.armor)
    BlzSetUnitMaxHP(caster, math.max(1, BlzGetUnitMaxHP(caster) - state.hp))
    UnitRemoveAbility(caster, FourCC('AS01'))
    UnitRemoveAbility(caster, FourCC('BS01'))
end

function Arena_ShieldOfTorment(caster, shieldHp, armorBonus, duration)
    Arena_ClearTormentShield(caster)
    local bonusHp = math.floor(shieldHp)
    BlzSetUnitMaxHP(caster, BlzGetUnitMaxHP(caster) + bonusHp)
    BlzSetUnitArmor(caster, BlzGetUnitArmor(caster) + armorBonus)
    SetWidgetLife(caster, GetWidgetLife(caster) + bonusHp)
    -- Adev is Devour, not Devotion Aura. Use a dedicated self-only status aura.
    UnitAddAbility(caster, FourCC('AS01'))
    local timer = CreateTimer()
    TormentShields[caster] = {hp = bonusHp, armor = armorBonus, timer = timer}
    TimerStart(timer, duration, false, function() Arena_ClearTormentShield(caster) end)
end

function Arena_ApplyBleedStack(target, caster, stacksToAdd, duration)
    if target == nil or GetWidgetLife(target) <= 0.405 then return end
    local id = GetHandleId(target)
    if not BleedStacks[id] then
        BleedStacks[id] = { count = 0, duration = duration, caster = caster, target = target }
    end

    BleedStacks[id].count = math.min(10+5*GetUnitAbilityLevel(caster,FourCC('A10F')), BleedStacks[id].count + stacksToAdd)
    BleedStacks[id].duration = duration

    -- Накладываем стандартную иконку статуса "Теневой удар / Кровотечение" (Bshs)
    Arena_UpdateStackIndicator(target, 'bleed', BleedStacks[id].count)
    DestroyEffect(AddSpecialEffectTarget("Abilities/Weapons/Blood/BloodImpact.mdl", target, "origin"))
end

function Arena_InitBleedSystem()
    local t = CreateTimer()
    TimerStart(t, 1.0, true, function()
        for id, data in pairs(BleedStacks) do
            local target = data.target
            if target ~= nil and GetWidgetLife(target) > 0.405 and data.count > 0 and data.duration > 0 then
                data.duration = data.duration - 1.0
                -- Каждый стак отнимает 1 единицу здоровья в секунду
                local dmg = data.count * 5.0
                UnitDamageTarget(data.caster, target, dmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Weapons/Blood/BloodImpact.mdl", target, "overhead"))
            else
                if target ~= nil then
                    Arena_ClearStackIndicator(target, 'bleed')
                end
                BleedStacks[id] = nil
            end
        end
    end)
end

function Arena_ApplyStaticCharges(caster, spellRank, radius, baseDamage)
    local maxJumps = 3 + spellRank -- 4 jumps at rank 1, 5 at rank 2, 6 at rank 3, 7 at rank 4, 8 at rank 5
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, radius, nil)
    local currentTarget = FirstOfGroup(g)
    while currentTarget ~= nil and not (IsUnitEnemy(currentTarget, GetOwningPlayer(caster)) and GetWidgetLife(currentTarget) > 0.405) do
        GroupRemoveUnit(g, currentTarget)
        currentTarget = FirstOfGroup(g)
    end
    DestroyGroup(g)

    if currentTarget == nil then return end

    local jumpsDone = 0
    local t = CreateTimer()
    TimerStart(t, 0.35, true, function()
        jumpsDone = jumpsDone + 1
        if currentTarget ~= nil and GetWidgetLife(currentTarget) > 0.405 then
            UnitDamageTarget(caster, currentTarget, baseDamage, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_LIGHTNING, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", currentTarget, "origin"))

            -- Find next jump target
            local tx, ty = GetUnitX(currentTarget), GetUnitY(currentTarget)
            local nextGroup = CreateGroup()
            GroupEnumUnitsInRange(nextGroup, tx, ty, 450.0, nil)
            local nextTarget = FirstOfGroup(nextGroup)
            local found = nil
            while nextTarget ~= nil do
                GroupRemoveUnit(nextGroup, nextTarget)
                if nextTarget ~= currentTarget and IsUnitEnemy(nextTarget, GetOwningPlayer(caster)) and GetWidgetLife(nextTarget) > 0.405 then
                    found = nextTarget
                    break
                end
                nextTarget = FirstOfGroup(nextGroup)
            end
            DestroyGroup(nextGroup)

            if found ~= nil then
                currentTarget = found
            end
        end

        if jumpsDone >= maxJumps or currentTarget == nil or GetWidgetLife(currentTarget) <= 0.405 then
            DestroyTimer(t)
        end
    end)
end

function Arena_TauntArea(caster, radius)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), radius, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            IssueTargetOrder(u, "attack", caster)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/HowlOfTerror/HowlTarget.mdl", u, "overhead"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
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
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", nx, ny))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_ArmorSunder(caster, radius, duration)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), radius, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitAddAbility(u, FourCC('ACrf')) -- Faerie Fire
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/NightElf/FaerieFire/FaerieFireTarget.mdl", u, "overhead"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_ManaBurn(caster, amount)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), 450.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            local currentMana = GetUnitState(u, UNIT_STATE_MANA)
            local burned = math.min(currentMana, amount)
            SetUnitState(u, UNIT_STATE_MANA, currentMana - burned)
            UnitDamageTarget(caster, u, burned * 1.5, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/NightElf/ManaBurn/ManaBurnTarget.mdl", u, "origin"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_HexTarget(caster, radius)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), radius, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 and u ~= udg_Boss then
            UnitAddAbility(u, FourCC('Ahex'))
            PauseUnit(u, true)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Polymorph/PolyMorphTarget.mdl", u, "overhead"))
            local victim = u
            local t = CreateTimer()
            TimerStart(t, 3.5, false, function()
                if GetWidgetLife(victim) > 0.405 then
                    PauseUnit(victim, false)
                end
                DestroyTimer(t)
            end)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_TransmuteTarget(caster, radius, goldBonus)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), radius, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 and u ~= udg_Boss then
            KillUnit(u)
            local p = GetOwningPlayer(caster)
            SetPlayerState(p, PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(p, PLAYER_STATE_RESOURCE_GOLD) + goldBonus)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Transmute/PileofGold.mdl", caster, "origin"))
            break
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_DivineShield(caster, duration)
    SetUnitInvulnerable(caster, true)
    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/DivineShield/DivineShieldTarget.mdl", caster, "origin"))
    local t = CreateTimer()
    TimerStart(t, duration, false, function()
        SetUnitInvulnerable(caster, false)
        DestroyTimer(t)
    end)
end

function Arena_DoomChains(caster, radius, duration, damage)
    local victims = {}
    local group = CreateGroup()
    GroupEnumUnitsInRange(group, GetUnitX(caster), GetUnitY(caster), radius, nil)
    local unit = FirstOfGroup(group)
    while unit ~= nil do
        GroupRemoveUnit(group, unit)
        if IsUnitEnemy(unit, GetOwningPlayer(caster)) and GetWidgetLife(unit) > 0.405 then
            -- Share pause ownership with chronospheres, including overlapping chains.
            local state = ChronoFreeze[unit]
            if state == nil then
                state = {count=0, wasPaused=IsUnitPaused(unit)}
                ChronoFreeze[unit] = state
            end
            state.count = state.count + 1
            PauseUnit(unit, true)
            victims[unit] = {
                chain=AddLightningEx('HWSB', false, GetUnitX(caster), GetUnitY(caster), 80,
                    GetUnitX(unit), GetUnitY(unit), 55),
                fire=AddSpecialEffectTarget("Abilities/Spells/Other/ImmolationRed/ImmolationRedTarget.mdl", unit, "origin")
            }
        end
        unit = FirstOfGroup(group)
    end
    DestroyGroup(group)
    local function release(target)
        local visual = victims[target]
        DestroyLightning(visual.chain)
        DestroyEffect(visual.fire)
        victims[target] = nil
        local state = ChronoFreeze[target]
        if state ~= nil then
            state.count = state.count - 1
            if state.count == 0 then
                ChronoFreeze[target] = nil
                if GetUnitTypeId(target) ~= 0 then PauseUnit(target, state.wasPaused) end
            end
        end
    end
    local ticks, timer = 0, CreateTimer()
    TimerStart(timer, 0.05, true, function()
        ticks = ticks + 1
        local alive = GetUnitTypeId(caster) ~= 0 and GetWidgetLife(caster) > 0.405
        local ended = ticks >= math.floor(duration / 0.05 + 0.5) or not alive
        local cx, cy = GetUnitX(caster), GetUnitY(caster)
        for target, visual in pairs(victims) do
            if not alive or GetUnitTypeId(target) == 0 or GetWidgetLife(target) <= 0.405 then
                release(target)
            else
                PauseUnit(target, true)
                local x, y = GetUnitX(target), GetUnitY(target)
                local dx, dy = cx-x, cy-y
                local distance = math.sqrt(dx*dx + dy*dy)
                if distance > 180 then
                    local step = math.min(distance-180, 24.0)
                    local nx, ny = x+dx/distance*step, y+dy/distance*step
                    if not IsTerrainPathable(nx, ny, PATHING_TYPE_WALKABILITY) then
                        SetUnitX(target, nx); SetUnitY(target, ny)
                    end
                end
                local from, dest = Location(cx,cy), Location(GetUnitX(target),GetUnitY(target))
                MoveLightningEx(visual.chain, false, cx,cy,GetLocationZ(from)+80,
                    GetUnitX(target),GetUnitY(target),GetLocationZ(dest)+55)
                RemoveLocation(from); RemoveLocation(dest)
                if ticks % 20 == 0 then
                    UnitDamageTarget(caster,target,damage,false,false,ATTACK_TYPE_MAGIC,DAMAGE_TYPE_FIRE,WEAPON_TYPE_WHOKNOWS)
                end
                if ended then release(target) end
            end
        end
        if ended or next(victims) == nil then DestroyTimer(timer) end
    end)
end

function Arena_Omnislash(caster, count, damage)
    SetUnitInvulnerable(caster, true)
    local i = 0
    local t = CreateTimer()
    TimerStart(t, 0.25, true, function()
        i = i + 1
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), 450.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
                SetUnitPosition(caster, GetUnitX(u), GetUnitY(u))
                UnitDamageTarget(caster, u, damage, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/NightElf/Blink/BlinkTarget.mdl", u, "origin"))
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

function Arena_PoisonGas(caster, radius, damage, duration)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), radius, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, damage, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_POISON, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/PlagueCloud/PlagueCloudCaster.mdl", u, "head"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_OnUnitAttack(attacker, target)
    if attacker == nil or target == nil then return end
    local pid = GetPlayerId(GetOwningPlayer(attacker))

    if Heroes[pid] and Heroes[pid] == attacker then
        local kind = HeroKind[pid]

        -- Priestess Sacred Flame Aura Bonus (role == 7)
        local priestessAuraDmg = 0.0
        for ppid = 0, 3 do
            if Heroes[ppid] and GetWidgetLife(Heroes[ppid]) > 0.405 and HeroKind[ppid] == 7 then
                local prHero = Heroes[ppid]
                local rankE = GetUnitAbilityLevel(prHero, FourCC('A10N'))
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
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Resurrect/ResurrectTarget.mdl", target, "origin"))
        end

        -- Ronin Attack Handlers (role == 6)
        if kind == 6 then
            local rankE = GetUnitAbilityLevel(attacker, FourCC('A117'))
            if rankE > 0 then
                Arena_Ronin_E_Attack(attacker, target, rankE)
            end
        -- Bombardier Attack Handlers (role == 8)
        elseif kind == 8 then
            -- 1. E (Incendiary Munitions) passive splash & shrapnel
            local rankE = GetUnitAbilityLevel(attacker, FourCC('A113'))
            if rankE > 0 then
                Arena_Bombardier_E_Attack(attacker, target, rankE)
            end

            -- 2. R (Mobile Rocket Battery) homing rockets every 2nd attack
            local cid = GetHandleId(attacker)
            local st = BombardierRocketState[cid]
            if st and st.active then
                st.attackCount = st.attackCount + 1
                if st.attackCount % 2 == 0 then
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
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Orc/LightningShield/LightningShieldTarget.mdl", tx, ty))
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", tx, ty))

    local trapDmg = 150.0 + 100.0 * rank
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, tx, ty, 350.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, trapDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            PauseUnit(u, true)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Thunderclap/ThunderclapTarget.mdl", u, "overhead"))
            local st = u
            local t = CreateTimer()
            TimerStart(t, 1.5, false, function()
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
    local tx, ty = Arena_GetAimPoint(caster)

    local centerDmg = 120.0 + 100.0 * (rank - 1)
    if rank == 3 then centerDmg = 340.0 end
    if rank >= 4 then centerDmg = 480.0 end

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/FlakCannons/FlakTarget.mdl", tx, ty))
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", tx, ty))

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
    TimerStart(qTimer, 0.5, false, function()
        local fragmentHitCounts = {}

        for _, fc in ipairs(fragCoords) do
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/FlakCannons/FlakTarget.mdl", fc.x, fc.y))

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
                    Arena_ApplyMoveSlow(fu, 0.30, 2.5)
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
                    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Thunderclap/ThunderclapTarget.mdl", targetUnit, "overhead"))
                    local tu = targetUnit
                    local stTimer = CreateTimer()
                    TimerStart(stTimer, 1.2, false, function()
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
    local tx, ty = Arena_GetAimPoint(caster)
    local cid = GetHandleId(caster)
    local list = EngineerTurrets[cid] or {}
    EngineerTurrets[cid] = list
    for i = #list, 1, -1 do
        if GetUnitTypeId(list[i]) == 0 or GetWidgetLife(list[i]) <= 0.405 then table.remove(list, i) end
    end
    if #list >= 3 then RemoveUnit(table.remove(list, 1)) end
    local turret = CreateUnit(GetOwningPlayer(caster), FourCC('hT01'), tx, ty, 270.0)
    if turret == nil then return end
    table.insert(list, turret)
    UnitApplyTimedLife(turret, FourCC('BTLF'), 25.0)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", tx, ty))
    local timer = CreateTimer()
    TimerStart(timer, 1.0, true, function()
        if GetUnitTypeId(turret) == 0 or GetWidgetLife(turret) <= 0.405 then DestroyTimer(timer); return end
        local x, y = GetUnitX(turret), GetUnitY(turret)
        local group = CreateGroup()
        GroupEnumUnitsInRange(group, x, y, 700.0, nil)
        local target, nearest = nil, math.huge
        local unit = FirstOfGroup(group)
        while unit ~= nil do
            GroupRemoveUnit(group, unit)
            local distance = (GetUnitX(unit)-x)^2 + (GetUnitY(unit)-y)^2
            if IsUnitEnemy(unit, GetOwningPlayer(turret)) and GetWidgetLife(unit) > 0.405 and distance < nearest then
                target, nearest = unit, distance
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        if target ~= nil then
            Arena_ShowProjectile(x, y, GetUnitX(target), GetUnitY(target))
            UnitDamageTarget(turret, target, 50.0 + 20.0 * rank + GetHeroAgi(caster, true) * 0.4,
                false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Weapons/RocketMissile/RocketMissile.mdl", target, "chest"))
        end
    end)
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

    UnitAddAbility(target, FourCC('ACrf'))
    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/NightElf/FaerieFire/FaerieFireTarget.mdl", target, "overhead"))
end

function Arena_Bombardier_E(caster, rank)
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/FlakCannons/FlakTarget.mdl", cx, cy))

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
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Avatar/AvatarCaster.mdl", caster, "origin"))
        SetUnitMoveSpeed(caster, GetUnitDefaultMoveSpeed(caster) * 1.15)
        DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 5.0, "|cffffcc00[АРТИЛЛЕРИЯ]:|r Мобильная ракетная батарея АКТИВИРОВАНА на 12 секунд!")
    else
        st.active = false
        SetUnitMoveSpeed(caster, GetUnitDefaultMoveSpeed(caster))

        local bx, by = GetUnitX(caster), GetUnitY(caster)
        DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 4.0, "|cffff0000[АВАРИЙНЫЙ СБРОС]:|r Ракетная батарея сброшена! Детонация через 1 секунду!")

        local jettisonEff = AddSpecialEffect("Abilities/Spells/Human/FlakCannons/FlakTarget.mdl", bx, by)

        local jTimer = CreateTimer()
        TimerStart(jTimer, 1.0, false, function()
            DestroyEffect(jettisonEff)
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/FlakCannons/FlakTarget.mdl", bx, by))
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", bx, by))

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
                    TimerStart(stt, 1.0, false, function()
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
    DestroyEffect(AddSpecialEffect("Abilities/Weapons/RocketMissile/RocketMissile.mdl", tx, ty))
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/FlakCannons/FlakTarget.mdl", tx, ty))

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
            TimerStart(t, 0.3, false, function()
                if GetWidgetLife(tu) > 0.405 then PauseUnit(tu, false) end
                DestroyTimer(t)
            end)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_StartRoninDashCooldown(caster)
    local timer = CreateTimer()
    TimerStart(timer, 0.0, false, function()
        if GetUnitTypeId(caster) ~= 0 then BlzStartUnitAbilityCooldown(caster, FourCC('A115'),8.0) end
        DestroyTimer(timer)
    end)
end

function Arena_Ronin_Q(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local tx, ty = Arena_GetAimPoint(caster)

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

    DestroyEffect(AddSpecialEffect("Abilities/Spells/NightElf/Blink/BlinkCaster.mdl", cx, cy))
    DestroyEffect(AddSpecialEffect("Abilities/Spells/NightElf/Blink/BlinkTarget.mdl", endX, endY))

    local atkDmg = (BlzGetUnitBaseDamage and BlzGetUnitBaseDamage(caster, 0) or 50.0)
    local baseDmg = 100.0 + 80.0 * (rank - 1)
    if rank == 3 then baseDmg = 260.0 end
    if rank >= 4 then baseDmg = 340.0 end
    local totalDmg = baseDmg + (atkDmg * 1.2)

    local killedUnit = false
    local hitBoss = false

    local g = CreateGroup()
    GroupEnumUnitsInRange(g, (cx + endX) * 0.5, (cy + endY) * 0.5, dashDist * 0.5 + 125.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 and Arena_UnitInLine(u, cx, cy, endX, endY, 125.0) then
            UnitDamageTarget(caster, u, totalDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Weapons/Blood/BloodImpact.mdl", u, "chest"))

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
        local maxHp = GetUnitState(caster, UNIT_STATE_MAX_LIFE)
        local curHp = GetUnitState(caster, UNIT_STATE_LIFE)
        SetUnitState(caster, UNIT_STATE_LIFE, curHp + maxHp * 0.03)
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Heal/HealTarget.mdl", caster, "origin"))
        DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 3.0, "|cff00ff00[ПОТОК КЛИНКА]:|r Убийство восстановило 3% здоровья!")
    end
    Arena_StartRoninDashCooldown(caster)
end


function Arena_IaiArmorCut(target,amount)
    local old=RoninIaiCuts[target]
    if old then
        amount=math.max(amount,old.amount)
        DestroyTimer(old.timer)
        BlzSetUnitArmor(target,BlzGetUnitArmor(target)+old.amount)
    end
    local state={amount=amount,timer=CreateTimer()}
    RoninIaiCuts[target]=state
    BlzSetUnitArmor(target,BlzGetUnitArmor(target)-amount)
    TimerStart(state.timer,4,false,function()
        if RoninIaiCuts[target]==state then
            RoninIaiCuts[target]=nil
            if GetUnitTypeId(target)~=0 then BlzSetUnitArmor(target,BlzGetUnitArmor(target)+state.amount) end
        end
        DestroyTimer(state.timer)
    end)
end

function Arena_Ronin_W(caster,rank)
    if not caster or GetWidgetLife(caster)<=0.405 then return end
    Arena_EndResolve(caster,false)
    local x,y=GetUnitX(caster),GetUnitY(caster)
    local tx,ty=Arena_GetAimPoint(caster)
    local dx,dy=tx-x,ty-y
    local length=math.sqrt(dx*dx+dy*dy)
    if length<1 then
        local facing=GetUnitFacing(caster)*math.pi/180
        dx,dy=math.cos(facing),math.sin(facing);length=1
    end
    local ex,ey=x+dx/length*600,y+dy/length*600
    local marks,group={},CreateGroup()
    GroupEnumUnitsInRange(group,(x+ex)/2,(y+ey)/2,450,nil)
    local target=FirstOfGroup(group)
    while target do
        GroupRemoveUnit(group,target)
        if IsUnitEnemy(target,GetOwningPlayer(caster)) and GetWidgetLife(target)>0.405
            and Arena_UnitInLine(target,x,y,ex,ey,130) then
            marks[#marks+1]={unit=target,effect=AddSpecialEffectTarget("Abilities/Spells/NightElf/FaerieFire/FaerieFireTarget.mdl",target,"overhead")}
        end
        target=FirstOfGroup(group)
    end
    DestroyGroup(group)
    local damage=100+50*(rank-1)+GetHeroAgi(caster,true)*0.8
    if RoninRewards[caster] then damage=damage*1.25 end
    local timer=CreateTimer()
    TimerStart(timer,0.8,false,function()
        for _,mark in ipairs(marks) do
            DestroyEffect(mark.effect)
            local unit=mark.unit
            if GetUnitTypeId(caster)~=0 and GetUnitTypeId(unit)~=0 and GetWidgetLife(unit)>0.405
                and IsUnitEnemy(unit,GetOwningPlayer(caster)) then
                local ux,uy=GetUnitX(unit),GetUnitY(unit)
                local slash=AddLightningEx('HWPB',false,ux-90,uy-50,35,ux+90,uy+50,130)
                local blood=AddSpecialEffectTarget("Abilities/Weapons/Blood/BloodImpact.mdl",unit,"chest")
                local cleanup=CreateTimer()
                TimerStart(cleanup,0.25,false,function() DestroyLightning(slash);DestroyEffect(blood);DestroyTimer(cleanup) end)
                UnitDamageTarget(caster,unit,damage,false,false,ATTACK_TYPE_HERO,DAMAGE_TYPE_NORMAL,WEAPON_TYPE_WHOKNOWS)
                if GetWidgetLife(unit)>0.405 then Arena_IaiArmorCut(unit,1+rank) end
            end
        end
        DestroyTimer(timer)
    end)
end

function Arena_ResolveOrder(unit,order)
    if order==OrderId('stop') then Arena_EndResolve(unit,false) end
end

function Arena_EndResolve(caster, success)
    local state = RoninResolve[caster]
    if not state then return end
    RoninResolve[caster] = nil
    DestroyTimer(state.timer); DestroyEffect(state.effect)
    if state.progress then DestroyTimer(state.progress);DestroyTextTag(state.tag) end
    SetUnitMoveSpeed(caster,state.speed)
    if success and GetWidgetLife(caster)>0.405 then
        local old=RoninRewards[caster]
        if old then DestroyTimer(old.timer);BlzSetUnitArmor(caster,BlzGetUnitArmor(caster)-old.armor) end
        local reward={armor=3+state.rank*2, timer=CreateTimer(), rank=state.rank, speed=state.speed}
        RoninRewards[caster]=reward
        BlzSetUnitArmor(caster,BlzGetUnitArmor(caster)+reward.armor)
        SetUnitMoveSpeed(caster,state.speed*1.2)
        TimerStart(reward.timer,6,false,function()
            if RoninRewards[caster]==reward then
                RoninRewards[caster]=nil
                BlzSetUnitArmor(caster,BlzGetUnitArmor(caster)-reward.armor)
                SetUnitMoveSpeed(caster,state.speed)
            end
            DestroyTimer(reward.timer)
        end)
    end
end

function Arena_Ronin_E(caster, rank)
    if RoninResolve[caster] then Arena_EndResolve(caster,false);return end
    local old=RoninRewards[caster]
    if old then
        DestroyTimer(old.timer)
        BlzSetUnitArmor(caster,BlzGetUnitArmor(caster)-old.armor)
        SetUnitMoveSpeed(caster,old.speed)
        RoninRewards[caster]=nil
    end
    local state={rank=rank,speed=GetUnitMoveSpeed(caster),timer=CreateTimer(),
        effect=AddSpecialEffectTarget("Abilities/Spells/Human/Defend/DefendCaster.mdl",caster,"origin")}
    RoninResolve[caster]=state
    state.x,state.y=GetUnitX(caster),GetUnitY(caster)
    state.progress,state.tag=CreateTimer(),CreateTextTag()
    SetTextTagPermanent(state.tag,true)
    SetTextTagColor(state.tag,120,210,255,255)
    local elapsed=0
    TimerStart(state.progress,0.1,true,function()
        if RoninResolve[caster]~=state then return end
        if GetWidgetLife(caster)<=0.405 then Arena_EndResolve(caster,false);return end
        elapsed=elapsed+0.1
        SetUnitX(caster,state.x)
        SetUnitY(caster,state.y)
        SetTextTagPosUnit(state.tag,caster,110)
        SetTextTagText(state.tag,string.format("Возмездие: %.1f сек | S — отмена",math.max(0,rank+1-elapsed)),0.018)
    end)
    SetUnitMoveSpeed(caster,0)
    TimerStart(state.timer,rank+1,false,function() Arena_EndResolve(caster,true) end)
end

function Arena_ResolveReflect(target, source, damage)
    local state=RoninResolve[target]
    if ReflectingDamage or not state or not source or damage<=0 or not IsUnitEnemy(source,GetOwningPlayer(target)) then return end
    ReflectingDamage=true
    UnitDamageTarget(target,source,math.min(300,damage*(0.3+0.1*state.rank)),false,false,ATTACK_TYPE_MAGIC,DAMAGE_TYPE_NORMAL,WEAPON_TYPE_WHOKNOWS)
    ReflectingDamage=false
    local flash=AddLightningEx('CLPB',false,GetUnitX(target),GetUnitY(target),70,GetUnitX(source),GetUnitY(source),70)
    local visualTimer=CreateTimer()
    TimerStart(visualTimer,0.25,false,function() DestroyLightning(flash);DestroyTimer(visualTimer) end)
    Arena_ApplyMoveSlow(source,0.3,3)
end

function Arena_HeroHitPassives(attacker,target)
    if not attacker or not target or GetWidgetLife(target)<=0.405 or not IsUnitEnemy(target,GetOwningPlayer(attacker)) then return end
    local pid=GetPlayerId(GetOwningPlayer(attacker))
    if Heroes[pid]~=attacker then return end
    if HeroKind[pid]==2 then
        local rank=GetUnitAbilityLevel(attacker,FourCC('A10F'))
        if rank>0 then Arena_ApplyBleedStack(target,attacker,1,4+2*rank) end
    end
    Arena_ItemHit(attacker,target)
    local reward=RoninRewards[attacker]
    if reward then UnitDamageTarget(attacker,target,20*reward.rank+GetHeroAgi(attacker,true)*0.3,false,false,ATTACK_TYPE_HERO,DAMAGE_TYPE_NORMAL,WEAPON_TYPE_WHOKNOWS) end
end

function Arena_ShadowThrow(caster,rank)
    local x,y=Arena_GetAimPoint(caster)
    local group,targets=CreateGroup(),{}
    GroupEnumUnitsInRange(group,x,y,300,nil)
    local unit=FirstOfGroup(group)
    while unit do
        GroupRemoveUnit(group,unit)
        if IsUnitEnemy(unit,GetOwningPlayer(caster)) and GetWidgetLife(unit)>0.405 then targets[#targets+1]=unit end
        unit=FirstOfGroup(group)
    end
    DestroyGroup(group)
    local pool=(35+25*rank)*2.2+GetHeroAgi(caster,true)
    for _,target in ipairs(targets) do
        UnitDamageTarget(caster,target,pool/#targets,false,false,ATTACK_TYPE_HERO,DAMAGE_TYPE_NORMAL,WEAPON_TYPE_WHOKNOWS)
        Arena_ApplyBleedStack(target,caster,2,8)
    end
end

function Arena_Ronin_E_Attack(attacker, target, rank)
    if attacker == nil or target == nil then return end

    local cid = GetHandleId(attacker)
    local rTime = RoninCleaveTimer[cid] or 0.0
    local hasRBuff = rTime > 0.0

    if hasRBuff then
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
                DestroyEffect(AddSpecialEffectTarget("Abilities/Weapons/Blood/BloodImpact.mdl", u, "origin"))
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
    end
end

function Arena_Ronin_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local tx, ty = Arena_GetAimPoint(caster)
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

    DestroyEffect(AddSpecialEffect("Abilities/Spells/NightElf/Blink/BlinkCaster.mdl", cx, cy))

    local frozenUnits = {}
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, (cx + endX) * 0.5, (cy + endY) * 0.5, length * 0.5 + 175.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 and Arena_UnitInLine(u, cx, cy, endX, endY, 175.0) then
            PauseUnit(u, true)
            table.insert(frozenUnits, u)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/FreezingBreath/FreezingBreathTargetArt.mdl", u, "origin"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)

    local channelTimer = CreateTimer()
    TimerStart(channelTimer, 0.4, false, function()
        SetUnitInvulnerable(caster, false)
        PauseUnit(caster, false)

        SetUnitPathing(caster, false)
        SetUnitPosition(caster, endX, endY)
        SetUnitPathing(caster, true)

        DestroyEffect(AddSpecialEffect("Abilities/Spells/NightElf/Blink/BlinkTarget.mdl", endX, endY))


        local cid = GetHandleId(caster)
        RoninCleaveTimer[cid] = 6.0

        local burstTimer = CreateTimer()
        TimerStart(burstTimer, 1.1, false, function()
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", (cx + endX) * 0.5, (cy + endY) * 0.5))

            local agi = GetHeroAgi(caster, true)
            local baseDmg = 500.0 + 300.0 * (rank - 1) + agi * 2.5
            if rank == 3 then baseDmg = 1200.0 + agi * 2.5 end

            for _, targetUnit in ipairs(frozenUnits) do
                if GetWidgetLife(targetUnit) > 0.405 then
                    PauseUnit(targetUnit, false)

                    if udg_Boss ~= nil and targetUnit == udg_Boss then
                        local bossMaxHp = GetUnitState(targetUnit, UNIT_STATE_MAX_LIFE)
                        local bossCurHp = GetUnitState(targetUnit, UNIT_STATE_LIFE)
                        local bossDmg = baseDmg + (bossCurHp * 0.12)
                        UnitDamageTarget(caster, targetUnit, bossDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
                        UnitAddAbility(targetUnit, FourCC('ACrf'))
                        DestroyEffect(AddSpecialEffectTarget("Abilities/Weapons/Blood/BloodImpact.mdl", targetUnit, "chest"))
                    else
                        local curHp = GetUnitState(targetUnit, UNIT_STATE_LIFE)
                        local maxHp = GetUnitState(targetUnit, UNIT_STATE_MAX_LIFE)
                        if (curHp / maxHp) < 0.20 then
                            SetWidgetLife(targetUnit, 0.0)
                            DestroyEffect(AddSpecialEffectTarget("Abilities/Weapons/Blood/BloodImpact.mdl", targetUnit, "origin"))
                        else
                            UnitDamageTarget(caster, targetUnit, baseDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                            DestroyEffect(AddSpecialEffectTarget("Abilities/Weapons/Blood/BloodImpact.mdl", targetUnit, "chest"))
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
    local tx, ty = Arena_GetAimPoint(caster)

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


    local str = GetHeroStr(caster, true)
    local baseDmg = 140.0 + 80.0 * (rank - 1) + str * 1.0
    if rank == 3 then baseDmg = 300.0 + str * 1.0 end
    if rank >= 4 then baseDmg = 380.0 + str * 1.0 end

    local hitTarget = nil
    local nearest = math.huge
    local isBoss = false

    local g = CreateGroup()
    GroupEnumUnitsInRange(g, (cx + targetX) * 0.5, (cy + targetY) * 0.5, fistDist * 0.5 + 100.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        local onLine, projection = Arena_UnitInLine(u, cx, cy, targetX, targetY, 100.0)
        if onLine and projection < nearest and IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            hitTarget = u
            nearest = projection
            isBoss = udg_Boss ~= nil and u == udg_Boss
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)

    if hitTarget ~= nil then
        Arena_ShowProjectile(cx, cy, GetUnitX(hitTarget), GetUnitY(hitTarget))
    else
        Arena_ShowProjectile(cx, cy, targetX, targetY)
    end
    if hitTarget ~= nil then
        UnitDamageTarget(caster, hitTarget, baseDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
        PauseUnit(hitTarget, true)
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Thunderclap/ThunderclapTarget.mdl", hitTarget, "overhead"))

        local tu = hitTarget
        local stTimer = CreateTimer()
        TimerStart(stTimer, 1.5, false, function()
            if GetWidgetLife(tu) > 0.405 then PauseUnit(tu, false) end
            DestroyTimer(stTimer)
        end)

        if isBoss then
            local bx, by = GetUnitX(hitTarget), GetUnitY(hitTarget)
            SetUnitPathing(caster, false)
            SetUnitPosition(caster, bx, by)
            SetUnitPathing(caster, true)
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", bx, by))
            DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 3.0, "|cff00ff00[ТЯГАЧ]:|r Исполин притянулся в упор к Боссу!")
        else
            local pulledCount = 0
            local pg = CreateGroup()
            GroupEnumUnitsInRange(pg, GetUnitX(hitTarget), GetUnitY(hitTarget), 250.0, nil)
            local pu = FirstOfGroup(pg)
            while pu ~= nil and pulledCount < 3 do
                GroupRemoveUnit(pg, pu)
                if IsUnitEnemy(pu, GetOwningPlayer(caster)) and GetWidgetLife(pu) > 0.405 then
                    SetUnitPosition(pu, cx + GetRandomReal(-50.0, 50.0), cy + GetRandomReal(-50.0, 50.0))
                    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/FlakCannons/FlakTarget.mdl", pu, "origin"))
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
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Other/Incinerate/IncinerateBuff.mdl", cx, cy))
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/FlakCannons/FlakTarget.mdl", cx, cy))

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
            Arena_ApplyMoveSlow(u, 0.30, 2.5)

            if udg_Boss == nil or u ~= udg_Boss then
                IssueTargetOrder(u, "attack", caster)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/HowlOfTerror/HowlTarget.mdl", u, "overhead"))
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Colossus_ShrapnelBurst(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/FlakCannons/FlakTarget.mdl", cx, cy))

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
            DestroyEffect(AddSpecialEffectTarget("Abilities/Weapons/Blood/BloodImpact.mdl", u, "chest"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Colossus_E(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local blockDmg = 25.0 + 20.0 * (rank - 1)
    if rank == 3 then blockDmg = 65.0 end
    if rank >= 4 then blockDmg = 85.0 end

    UnitAddAbility(caster, FourCC('AAdef')) -- Defend / Hardened skin bonus
    Arena_Colossus_ShrapnelBurst(caster, rank)
    DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 3.0, "|cff00ff00[ЛИТАЯ БРОНЯ]:|r Поглощение урона: " .. math.floor(blockDmg) .. " ед!")
end

function Arena_Colossus_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local facing = GetUnitFacing(caster) * (math.pi / 180.0)
    local cx = GetUnitX(caster) + math.cos(facing) * 200.0
    local cy = GetUnitY(caster) + math.sin(facing) * 200.0

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/MassTeleport/MassTeleportTarget.mdl", cx, cy))

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
    TimerStart(pTimer, 0.1, true, function()
        pullTicks = pullTicks + 1
        for _, pu in ipairs(pulledUnits) do
            if GetWidgetLife(pu) > 0.405 then
                local ux, uy = GetUnitX(pu), GetUnitY(pu)
                local angle = math.atan(cy - uy, cx - ux)
                local nx = ux + math.cos(angle) * 35.0
                local ny = uy + math.sin(angle) * 35.0
                SetUnitPosition(pu, nx, ny)
            end
        end

        if pullTicks >= 15 then
            DestroyTimer(pTimer)

            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", cx, cy))
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", cx, cy))

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
                    UnitAddAbility(pu, FourCC('ACrf'))
                    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/NightElf/FaerieFire/FaerieFireTarget.mdl", pu, "overhead"))

                    local stu = pu
                    local sTimer = CreateTimer()
                    TimerStart(sTimer, stunDur, false, function()
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
    local tx, ty = Arena_GetAimPoint(caster)

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

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/Resurrect/ResurrectTarget.mdl", (cx + endX) * 0.5, (cy + endY) * 0.5))

    local beam = AddLightningEx("HWPB", false, cx, cy, 70.0, endX, endY, 70.0)
    local beamTimer = CreateTimer()
    TimerStart(beamTimer, 0.5, false, function() DestroyLightning(beam); DestroyTimer(beamTimer) end)
    local pInt = GetHeroInt(caster, true)
    local baseAmount = 130.0 + 60.0 * (rank-1) + pInt*0.85

    local selfMax=GetUnitState(caster,UNIT_STATE_MAX_LIFE)
    SetUnitState(caster,UNIT_STATE_LIFE,math.min(selfMax,GetWidgetLife(caster)+baseAmount))
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, (cx + endX) * 0.5, (cy + endY) * 0.5, beamLen * 0.5 + 125.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if GetWidgetLife(u) > 0.405 and Arena_UnitInLine(u, cx, cy, endX, endY, 125.0) then
            if u==caster then
                -- Already healed once above.
            elseif IsUnitAlly(u, GetOwningPlayer(caster)) then
                local maxHp = GetUnitState(u, UNIT_STATE_MAX_LIFE)
                local curHp = GetUnitState(u, UNIT_STATE_LIFE)
                local missingHp = maxHp - curHp
                local healVal = baseAmount + (missingHp * 0.04)
                SetUnitState(u, UNIT_STATE_LIFE, math.min(maxHp, curHp + healVal))
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Heal/HealTarget.mdl", u, "origin"))
            elseif IsUnitEnemy(u, GetOwningPlayer(caster)) then
                UnitDamageTarget(caster, u, baseAmount * 0.7, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/HolyBolt/HolyBoltSpecialArt.mdl", u, "origin"))
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Priestess_W(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local target = GetSpellTargetUnit()
    if target == nil or not IsUnitAlly(target, GetOwningPlayer(caster)) then target = caster end

    UnitRemoveAbility(target, FourCC('Ashs'))
    UnitRemoveAbility(target, FourCC('ACrf'))
    Arena_ClearMoveSlow(target)

    local pInt = GetHeroInt(caster, true)
    local shieldAmount = 300.0 + 250.0 * (rank - 1) + pInt * 1.5
    if rank == 3 then shieldAmount = 800.0 + pInt * 1.5 end
    if rank >= 4 then shieldAmount = 1100.0 + pInt * 1.5 end

    local tid = GetHandleId(target)
    local previous = PriestessCoronaShield[tid]
    if previous ~= nil then
        DestroyTimer(previous.timer)
        DestroyEffect(previous.effect)
        SetUnitMoveSpeed(target, previous.speed)
    end
    local originalSpeed = GetUnitMoveSpeed(target)
    PriestessCoronaShield[tid] = {
        amount = shieldAmount,
        target = target,
        caster = caster,
        rank = rank,
        speed = originalSpeed,
        duration = 5.0
    }

    UnitAddAbility(target, FourCC('AC01'))
    SetUnitMoveSpeed(target, originalSpeed * 1.35)
    local eff = AddSpecialEffectTarget("Abilities/Spells/Human/DivineShield/DivineShieldTarget.mdl", target, "origin")

    local t = CreateTimer()
    local state = PriestessCoronaShield[tid]
    state.effect, state.timer = eff, t
    TimerStart(t, 5.0, false, function()
        if PriestessCoronaShield[tid] ~= state then DestroyTimer(t); return end
        DestroyEffect(eff)
        SetUnitMoveSpeed(target, state.speed)
        UnitRemoveAbility(target, FourCC('AC01'))
        UnitRemoveAbility(target, FourCC('BC01'))
        local st = PriestessCoronaShield[tid]
        if st ~= nil then
            PriestessCoronaShield[tid] = nil
            local tx, ty = GetUnitX(target), GetUnitY(target)
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", tx, ty))

            local g = CreateGroup()
            GroupEnumUnitsInRange(g, tx, ty, 300.0, nil)
            local u = FirstOfGroup(g)
            while u ~= nil do
                GroupRemoveUnit(g, u)
                if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
                    PauseUnit(u, true)
                    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Thunderclap/ThunderclapTarget.mdl", u, "overhead"))
                    local tu = u
                    local stt = CreateTimer()
                    TimerStart(stt, 1.2, false, function()
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

    local pInt = GetHeroInt(caster, true)
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/Resurrect/ResurrectTarget.mdl", cx, cy))

    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 900.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitAlly(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            local curMp = GetUnitState(u, UNIT_STATE_MANA)
            local maxMp = GetUnitState(u, UNIT_STATE_MAX_MANA)
            SetUnitState(u, UNIT_STATE_MANA, math.min(maxMp, curMp + 40.0 + rank * 10.0))
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Items/AIam/AIamTarget.mdl", u, "origin"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Priestess_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local sunEff = AddSpecialEffect("Abilities/Spells/Human/Avatar/AvatarCaster.mdl", cx, cy)

    PriestessSunState = {
        x = cx,
        y = cy,
        caster = caster,
        rank = rank,
        duration = 8.0,
        cheatDeathUsed = false
    }

    local t = CreateTimer()
    TimerStart(t, 1.0, true, function()
        if PriestessSunState == nil or PriestessSunState.duration <= 0 then
            DestroyEffect(sunEff)
            PriestessSunState = nil
            DestroyTimer(t)
            return
        end

        PriestessSunState.duration = PriestessSunState.duration - 1.0
        local pInt = GetHeroInt(caster, true)
        local baseHeal = 90.0 + 50.0 * (rank - 1) + pInt * 0.35

        local g = CreateGroup()
        GroupEnumUnitsInRange(g, cx, cy, 700.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if GetWidgetLife(u) > 0.405 then
                if IsUnitAlly(u, GetOwningPlayer(caster)) then
                    local maxHp = GetUnitState(u, UNIT_STATE_MAX_LIFE)
                    local curHp = GetUnitState(u, UNIT_STATE_LIFE)
                    SetUnitState(u, UNIT_STATE_LIFE, math.min(maxHp, curHp + baseHeal + maxHp * 0.02))
                    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Heal/HealTarget.mdl", u, "origin"))

                    if not PriestessSunState.cheatDeathUsed and curHp < maxHp * 0.15 then
                        PriestessSunState.cheatDeathUsed = true
                        SetUnitState(u, UNIT_STATE_LIFE, maxHp * 0.30)
                        SetUnitInvulnerable(u, true)
                        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/DivineShield/DivineShieldTarget.mdl", u, "origin"))
                        local tu = u
                        local cdTimer = CreateTimer()
                        TimerStart(cdTimer, 1.5, false, function()
                            SetUnitInvulnerable(tu, false)
                            DestroyTimer(cdTimer)
                        end)
                        DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 4.0, "|cff00ff00[СПАСЕНИЕ СОЛНЦА]:|r Союзник спасен от гибели!")
                    end
                elseif IsUnitEnemy(u, GetOwningPlayer(caster)) then
                    UnitDamageTarget(caster, u, baseHeal * 0.35, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/HolyBolt/HolyBoltSpecialArt.mdl", u, "chest"))
                end
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
    end)
end

function Arena_Druid_Q(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cid = GetHandleId(caster)
    local existing = DruidGuardians[cid]
    if existing ~= nil and GetUnitTypeId(existing) ~= 0 and GetWidgetLife(existing) > 0.405 then return end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local facing = GetUnitFacing(caster) * (math.pi / 180.0)
    local spawnX = cx + math.cos(facing) * 150.0
    local spawnY = cy + math.sin(facing) * 150.0

    local p = GetOwningPlayer(caster)
    local treant = CreateUnit(p, FourCC('eD01'), spawnX, spawnY, GetUnitFacing(caster))
    if treant == nil then return end

    local maxHpCaster = GetUnitState(caster, UNIT_STATE_MAX_LIFE)
    local str = GetHeroStr(caster, true)

    local treantHp = math.floor(400.0 + 300.0 * (rank - 1) + maxHpCaster * 0.5)
    DruidGuardians[cid] = treant
    BlzUnitDisableAbility(caster, FourCC('A107'), true, false)
    BlzSetUnitBaseDamage(treant, math.floor(30 + 15 * rank + str * 0.6)-1, 0)

    if BlzSetUnitMaxHP then BlzSetUnitMaxHP(treant, treantHp) end SetUnitState(treant, UNIT_STATE_MAX_LIFE, treantHp)
    SetUnitState(treant, UNIT_STATE_LIFE, treantHp)

    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/NightElf/EntanglingRoots/EntanglingRootsTarget.mdl", treant, "origin"))

    if not DruidSummons[cid] then DruidSummons[cid] = {} end
    table.insert(DruidSummons[cid], treant)

    local autoTimer, ticks = CreateTimer(), 0
    TimerStart(autoTimer, 0.5, true, function()
        if GetUnitTypeId(treant) == 0 or GetWidgetLife(treant) <= 0.405 then
            if DruidGuardians[cid] == treant then
                DruidGuardians[cid] = nil
                if GetUnitTypeId(caster) ~= 0 then BlzUnitDisableAbility(caster, FourCC('A107'), false, false) end
            end
            DestroyTimer(autoTimer)
            return
        end
        if GetUnitTypeId(caster) ~= 0 then
            local currentRank = GetUnitAbilityLevel(caster, FourCC('A107'))
            BlzSetUnitBaseDamage(treant, math.floor(30 + 15 * currentRank + GetHeroStr(caster, true) * 0.6)-1, 0)
        end
        ticks = ticks + 1
        if ticks % 16 ~= 0 then return end

        local tg = CreateGroup()
        GroupEnumUnitsInRange(tg, GetUnitX(treant), GetUnitY(treant), 300.0, nil)
        local tu = FirstOfGroup(tg)
        while tu ~= nil do
            GroupRemoveUnit(tg, tu)
            if IsUnitEnemy(tu, p) and GetWidgetLife(tu) > 0.405 then
                PauseUnit(tu, true)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/NightElf/EntanglingRoots/EntanglingRootsTarget.mdl", tu, "origin"))
                local rootu = tu
                local rtimer = CreateTimer()
                TimerStart(rtimer, 2.5, false, function()
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

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Other/HowlOfTerror/HowlTarget.mdl", cx, cy))

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
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/PlagueCloud/PlagueCloudCaster.mdl", u, "overhead"))

            local infected = u
            if udg_Boss ~= nil and u == udg_Boss then
                local bTimer = CreateTimer()
                local bTicks = 0
                TimerStart(bTimer, 2.0, true, function()
                    bTicks = bTicks + 1
                    if bTicks > 3 or GetWidgetLife(infected) <= 0.405 then
                        DestroyTimer(bTimer)
                        return
                    end
                    local sapling = CreateUnit(p, FourCC('eD03'), GetUnitX(infected), GetUnitY(infected), 0.0)
                    if sapling == nil then sapling = CreateUnit(p, FourCC('eD03'), GetUnitX(infected), GetUnitY(infected), 0.0) end
                    Arena_StartSaplingLife(sapling, caster)
                    if not DruidSummons[cid] then DruidSummons[cid] = {} end
                    table.insert(DruidSummons[cid], sapling)
                end)
            else
                local tu = u
                local dTimer = CreateTimer()
                TimerStart(dTimer, 0.5, true, function()
                    if GetWidgetLife(tu) <= 0.405 then
                        DestroyTimer(dTimer)
                        local sapling = CreateUnit(p, FourCC('eD03'), GetUnitX(tu), GetUnitY(tu), 0.0)
                        if sapling == nil then sapling = CreateUnit(p, FourCC('eD03'), GetUnitX(tu), GetUnitY(tu), 0.0) end
                        Arena_StartSaplingLife(sapling, caster)
                        if not DruidSummons[cid] then DruidSummons[cid] = {} end
                        table.insert(DruidSummons[cid], sapling)
                    end
                end)
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_StartSaplingLife(sapling,caster)
    if not sapling then return end
    local state={owner=caster,timer=CreateTimer()}
    SaplingLife[sapling]=state
    TimerStart(state.timer,1,true,function()
        if GetUnitTypeId(sapling)==0 or GetWidgetLife(sapling)<=0.405 then
            SaplingLife[sapling]=nil;DestroyTimer(state.timer);return
        end
        local hp=GetWidgetLife(sapling)
        if hp<=10 then
            KillUnit(sapling);SaplingLife[sapling]=nil;DestroyTimer(state.timer)
        else SetUnitState(sapling,UNIT_STATE_LIFE,hp-10) end
    end)
end

function Arena_Druid_E(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/NightElf/Tranquility/TranquilityTarget.mdl", cx, cy))

    local hpPct = 0.10 + 0.05 * (rank - 1)
    local maxHp = GetUnitState(caster, UNIT_STATE_MAX_LIFE)
    SetUnitState(caster, UNIT_STATE_LIFE, math.min(maxHp, GetUnitState(caster, UNIT_STATE_LIFE) + maxHp * hpPct))

    for sapling,state in pairs(SaplingLife) do
        if state.owner==caster and GetWidgetLife(sapling)>0.405 and (GetUnitX(sapling)-cx)^2+(GetUnitY(sapling)-cy)^2<=900^2 then
            local maxHp=GetUnitState(sapling,UNIT_STATE_MAX_LIFE)
            SetUnitState(sapling,UNIT_STATE_LIFE,math.min(maxHp,GetWidgetLife(sapling)+maxHp*(0.15+rank*0.05)))
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/NightElf/Rejuvenation/RejuvenationTarget.mdl",sapling,"origin"))
        end
    end
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 900.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitAlly(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            local uMaxHp = GetUnitState(u, UNIT_STATE_MAX_LIFE)
            SetUnitState(u, UNIT_STATE_LIFE, math.min(uMaxHp, GetUnitState(u, UNIT_STATE_LIFE) + uMaxHp * 0.10))
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Heal/HealTarget.mdl", u, "origin"))
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
        DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/FlakCannons/FlakTarget.mdl", bx, by))

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
                    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Heal/HealTarget.mdl", u, "origin"))
                end
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)

        SetWidgetLife(activeCol, 0.0)
        DruidDeepwoodColossus[cid] = nil
        DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 4.0, "|cff00ff00[ЖАТВА]:|r Колосс взорван! Союзники полностью исцелены!")
    else
        local facing = GetUnitFacing(caster) * (math.pi / 180.0)
        local cx = GetUnitX(caster) + math.cos(facing) * 250.0
        local cy = GetUnitY(caster) + math.sin(facing) * 250.0

        DestroyEffect(AddSpecialEffect("Units/Demon/Infernal/InfernalBirth.mdl", cx, cy))

        local p = GetOwningPlayer(caster)
        local colossus = CreateUnit(p, FourCC('eD02'), cx, cy, GetUnitFacing(caster))
        if colossus == nil then return end

        local str = GetHeroStr(caster, true)
        local colHp = 4000.0 + 3000.0 * (rank - 1) + str * 2.5
        if rank == 3 then colHp = 11000.0 + str * 2.5 end

        if BlzSetUnitMaxHP then BlzSetUnitMaxHP(colossus, colHp) end SetUnitState(colossus, UNIT_STATE_MAX_LIFE, colHp)
        SetUnitState(colossus, UNIT_STATE_LIFE, colHp)

        UnitApplyTimedLife(colossus, FourCC('BTLF'), 25.0)
        DruidDeepwoodColossus[cid] = colossus

        if not DruidSummons[cid] then DruidSummons[cid] = {} end
        table.insert(DruidSummons[cid], colossus)

        local stompTimer = CreateTimer()
        TimerStart(stompTimer, 6.0, true, function()
            if colossus == nil or GetWidgetLife(colossus) <= 0.405 then
                DestroyTimer(stompTimer)
                return
            end
            local bx, by = GetUnitX(colossus), GetUnitY(colossus)
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", bx, by))

            local sg = CreateGroup()
            GroupEnumUnitsInRange(sg, bx, by, 500.0, nil)
            local su = FirstOfGroup(sg)
            while su ~= nil do
                GroupRemoveUnit(sg, su)
                if IsUnitEnemy(su, p) and GetWidgetLife(su) > 0.405 then
                    UnitDamageTarget(colossus, su, 300.0 + str * 1.0, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                    -- Stomp damage is handled above; do not grant a Slow spell to the enemy.
                end
                su = FirstOfGroup(sg)
            end
            DestroyGroup(sg)
        end)
    end
end

function Arena_Lich_ExplodeSkeleton(skel, caster, rank)
    if skel == nil or GetUnitTypeId(skel) == 0 then return end

    local sx, sy = GetUnitX(skel), GetUnitY(skel)
    local burst=AddSpecialEffect("Objects/Spawnmodels/Undead/UndeadLargeDeathExplode/UndeadLargeDeathExplode.mdl",sx,sy)
    local blood=AddSpecialEffect("Abilities/Weapons/Blood/BloodImpact.mdl",sx,sy)
    local cleanup=CreateTimer()
    TimerStart(cleanup,1,false,function() DestroyEffect(burst);DestroyEffect(blood);DestroyTimer(cleanup) end)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Undead/DeathPact/DeathPactTarget.mdl", sx, sy))

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
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/PlagueCloud/PlagueCloudCaster.mdl", u, "chest"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)

    if GetWidgetLife(skel) > 0.405 then
        KillUnit(skel)
    end
    RemoveUnit(skel)
end

function Arena_Lich_Q(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local tx, ty = Arena_GetAimPoint(caster)

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Undead/AnimateDead/AnimateDeadTarget.mdl", tx, ty))

    local pInt = GetHeroInt(caster, true)
    local qDmg = 120.0 + 80.0 * (rank - 1) + pInt * 0.4
    if rank == 3 then qDmg = 280.0 + pInt * 0.4 end
    if rank >= 4 then qDmg = 360.0 + pInt * 0.4 end

    local p = GetOwningPlayer(caster)
    local cid = GetHandleId(caster)
    if not LichSkeletons[cid] then LichSkeletons[cid] = {} end

    local killedCount = 0
    local hitBossOrElite = false

    local g = CreateGroup()
    GroupEnumUnitsInRange(g, tx, ty, 350.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, qDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/DarkRitual/DarkRitualCaster.mdl", u, "origin"))

            if GetWidgetLife(u) <= 0.405 then
                killedCount = killedCount + 1
            end
            if udg_Boss ~= nil and u == udg_Boss then
                hitBossOrElite = true
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)

    local skelHp = 350.0 + 250.0 * (rank - 1) + pInt * 0.6
    if rank == 3 then skelHp = 950.0 + pInt * 0.6 end
    if rank >= 4 then skelHp = 1400.0 + pInt * 0.6 end

    local skelSpawnCount = killedCount
    if hitBossOrElite or skelSpawnCount == 0 then
        skelSpawnCount = 1 + rank -- 2, 3, 4, 5 skeletons
    end

    for i = 1, skelSpawnCount do
        local rx = tx + GetRandomReal(-100.0, 100.0)
        local ry = ty + GetRandomReal(-100.0, 100.0)
        local skel = CreateUnit(p, FourCC('uske'), rx, ry, GetRandomReal(0, 360))
        if skel == nil then skel = CreateUnit(p, FourCC('uskr'), rx, ry, GetRandomReal(0, 360)) end

        if skel == nil then return end
        skelHp = math.floor(skelHp)
        if BlzSetUnitMaxHP then BlzSetUnitMaxHP(skel, skelHp) end SetUnitState(skel, UNIT_STATE_MAX_LIFE, skelHp)
        SetUnitState(skel, UNIT_STATE_LIFE, skelHp)

        UnitApplyTimedLife(skel, FourCC('BTLF'), 25.0)
        table.insert(LichSkeletons[cid], skel)
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/RaiseSkeletonWarrior/RaiseSkeleton.mdl", skel, "origin"))
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

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Undead/FrostArmor/FrostArmorTarget.mdl", spawnX, spawnY))

    local p = GetOwningPlayer(caster)
    local rev = CreateUnit(p, FourCC('uL01'), spawnX, spawnY, GetUnitFacing(caster)) -- Blue flying Sky Barge
    if rev == nil then return end

    SetUnitFlyHeight(rev, 150.0, 0.0)
    local pInt = GetHeroInt(caster, true)
    local revHp = 1200.0 + 1000.0 * (rank - 1) + pInt * 1.5
    if rank == 3 then revHp = 3500.0 + pInt * 1.5 end
    if rank >= 4 then revHp = 5000.0 + pInt * 1.5 end

    revHp = math.floor(revHp)
    if BlzSetUnitMaxHP then BlzSetUnitMaxHP(rev, revHp) end SetUnitState(rev, UNIT_STATE_MAX_LIFE, revHp)
    SetUnitState(rev, UNIT_STATE_LIFE, revHp)

    UnitApplyTimedLife(rev, FourCC('BTLF'), 35.0)
    LichRevenant[cid] = rev

    local auraTimer = CreateTimer()
    TimerStart(auraTimer, 2.0, true, function()
        if rev == nil or GetWidgetLife(rev) <= 0.405 then
            DestroyTimer(auraTimer)
            return
        end
        local rx, ry = GetUnitX(rev), GetUnitY(rev)
        DestroyEffect(AddSpecialEffect("Abilities/Spells/Undead/FreezingBreath/FreezingBreathTargetArt.mdl", rx, ry))

        local g = CreateGroup()
        GroupEnumUnitsInRange(g, rx, ry, 350.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
                UnitDamageTarget(rev, u, 50.0 + pInt * 0.2, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_COLD, WEAPON_TYPE_WHOKNOWS)
                Arena_ApplyMoveSlow(u, 0.30, 2.5)
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
    end)

    local shardTimer = CreateTimer()
    TimerStart(shardTimer, 6.0, true, function()
        if rev == nil or GetWidgetLife(rev) <= 0.405 then
            DestroyTimer(shardTimer)
            return
        end
        local rx, ry = GetUnitX(rev), GetUnitY(rev)
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, rx, ry, 500.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
                UnitDamageTarget(rev, u, 150.0 + pInt * 0.5, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_COLD, WEAPON_TYPE_WHOKNOWS)
                PauseUnit(u, true)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/FrostNova/FrostNovaTarget.mdl", u, "overhead"))

                local tu = u
                local stTimer = CreateTimer()
                TimerStart(stTimer, 1.5, false, function()
                    if GetWidgetLife(tu) > 0.405 then PauseUnit(tu, false) end
                    DestroyTimer(stTimer)
                end)
                break
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
    end)
end

function Arena_Lich_E(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = Arena_GetAimPoint(caster)
    local owner, cid = GetOwningPlayer(caster), GetHandleId(caster)
    local candidates, seen = {}, {}
    local corpses = CreateGroup()
    GroupEnumUnitsInRange(corpses, cx, cy, 250.0, nil)
    local corpse = FirstOfGroup(corpses)
    while corpse ~= nil do
        GroupRemoveUnit(corpses, corpse)
        if GetUnitTypeId(corpse) ~= 0 and GetWidgetLife(corpse) <= 0.405
            and not IsUnitType(corpse, UNIT_TYPE_HERO)
            and (IsUnitEnemy(corpse, owner) or GetOwningPlayer(corpse) == owner) then
            candidates[#candidates+1] = corpse
            seen[corpse] = true
        end
        corpse = FirstOfGroup(corpses)
    end
    DestroyGroup(corpses)
    local skels = LichSkeletons[cid] or {}
    for _, skel in ipairs(skels) do
        if GetUnitTypeId(skel) ~= 0 and GetOwningPlayer(skel) == owner and not seen[skel]
            and (GetUnitX(skel)-cx)^2 + (GetUnitY(skel)-cy)^2 <= 250^2 then
            candidates[#candidates+1] = skel
        end
    end
    -- Snapshot before damaging anything: the same cast cannot chain through newly killed corpses.
    table.sort(candidates, function(a,b)
        return (GetUnitX(a)-cx)^2+(GetUnitY(a)-cy)^2 < (GetUnitX(b)-cx)^2+(GetUnitY(b)-cy)^2
    end)
    local explodedCount = math.min(#candidates, 3 + 2 * rank)
    for i = 1, explodedCount do Arena_Lich_ExplodeSkeleton(candidates[i], caster, rank) end
    for i = #skels, 1, -1 do
        if GetUnitTypeId(skels[i]) == 0 then table.remove(skels, i) end
    end
    if explodedCount > 0 then
        local maxMp = GetUnitState(caster, UNIT_STATE_MAX_MANA)
        SetUnitState(caster, UNIT_STATE_MANA, math.min(maxMp, GetUnitState(caster, UNIT_STATE_MANA) + maxMp * 0.01 * explodedCount))
        local maxHp = GetUnitState(caster, UNIT_STATE_MAX_LIFE)
        SetUnitState(caster, UNIT_STATE_LIFE, math.min(maxHp, GetUnitState(caster, UNIT_STATE_LIFE) + maxHp * 0.04 * explodedCount))
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/DarkRitual/DarkRitualCaster.mdl", caster, "origin"))
    else
        DisplayTimedTextToPlayer(owner, 0, 0, 3.0, "В выбранной области нет трупов или ваших скелетов.")
    end
end

function Arena_Lich_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cid = GetHandleId(caster)
    if LichWyrm[cid] ~= nil and GetWidgetLife(LichWyrm[cid]) > 0.405 then
        SetWidgetLife(LichWyrm[cid], 0.0)
    end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Undead/FreezingBreath/FreezingBreathTargetArt.mdl", cx, cy))

    local p = GetOwningPlayer(caster)
    local wyrm = CreateUnit(p, FourCC('ufro'), cx, cy, GetUnitFacing(caster)) -- Frost Wyrm
    if wyrm == nil then wyrm = CreateUnit(p, FourCC('udread'), cx, cy, GetUnitFacing(caster)) end

    local pInt = GetHeroInt(caster, true)
    local wyrmHp = 5000.0 + 3000.0 * (rank - 1) + pInt * 3.0
    if rank == 3 then wyrmHp = 11000.0 + pInt * 3.0 end

    if BlzSetUnitMaxHP then BlzSetUnitMaxHP(wyrm, wyrmHp) end SetUnitState(wyrm, UNIT_STATE_MAX_LIFE, wyrmHp)
    SetUnitState(wyrm, UNIT_STATE_LIFE, wyrmHp)

    UnitApplyTimedLife(wyrm, FourCC('BTLF'), 25.0)
    LichWyrm[cid] = wyrm

    local breathTimer = CreateTimer()
    TimerStart(breathTimer, 4.0, true, function()
        if wyrm == nil or GetWidgetLife(wyrm) <= 0.405 then
            DestroyTimer(breathTimer)
            return
        end
        local wx, wy = GetUnitX(wyrm), GetUnitY(wyrm)
        DestroyEffect(AddSpecialEffect("Abilities/Spells/Undead/FreezingBreath/FreezingBreathTargetArt.mdl", wx, wy))

        local breathDmg = 600.0 + 400.0 * (rank - 1) + pInt * 2.0
        if rank == 3 then breathDmg = 1500.0 + pInt * 2.0 end

        local g = CreateGroup()
        GroupEnumUnitsInRange(g, wx, wy, 550.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
                if udg_Boss ~= nil and u == udg_Boss then
                    UnitDamageTarget(wyrm, u, breathDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
                    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/FrostNova/FrostNovaTarget.mdl", u, "chest"))
                else
                    PauseUnit(u, true)
                    UnitDamageTarget(wyrm, u, breathDmg * 0.6, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_COLD, WEAPON_TYPE_WHOKNOWS)
                    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/FreezingBreath/FreezingBreathTargetArt.mdl", u, "origin"))
                    local tu = u
                    local fTimer = CreateTimer()
                    TimerStart(fTimer, 2.5, false, function()
                        if GetWidgetLife(tu) > 0.405 then PauseUnit(tu, false) end
                        DestroyTimer(fTimer)
                    end)
                end
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
    end)
end

function Arena_Chrono_Q(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local target = GetSpellTargetUnit()
    local pInt = GetHeroInt(caster, true)

    if target ~= nil and IsUnitAlly(target, GetOwningPlayer(caster)) then
        local tid = GetHandleId(target)
        local origX, origY = GetUnitX(target), GetUnitY(target)
        local origHp = GetUnitState(target, UNIT_STATE_LIFE)

        ChronoParadoxSaved[tid] = {
            x = origX,
            y = origY,
            hp = origHp,
            active = true
        }

        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Items/AIam/AIamTarget.mdl", target, "origin"))
        DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 3.0, "|cff00ff00[ПАРАДОКС]:|r Временная страховка наложена на союзника!")

        local pTimer = CreateTimer()
        TimerStart(pTimer, 4.0, false, function()
            local st = ChronoParadoxSaved[tid]
            if st and st.active then
                st.active = false
                local curHp = GetUnitState(target, UNIT_STATE_LIFE)
                local maxHp = GetUnitState(target, UNIT_STATE_MAX_LIFE)
                if curHp < (st.hp * 0.60) or GetWidgetLife(target) <= 0.405 then
                    if GetWidgetLife(target) <= 0.405 then SetWidgetLife(target, 1.0) end
                    SetUnitPosition(target, st.x, st.y)
                    SetUnitState(target, UNIT_STATE_LIFE, math.min(maxHp, st.hp))
                    Arena_ClearStackIndicator(target, 'bleed')
                    UnitRemoveAbility(target, FourCC('ACrf'))
                    Arena_ClearMoveSlow(target)
                    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/MassTeleport/MassTeleportTarget.mdl", target, "origin"))
                    DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 4.0, "|cff00ff00[ОТКАТ ВРЕМЕНИ]:|r Союзник спасен и возвращен!")
                end
            end
            DestroyTimer(pTimer)
        end)
    else
        local tx, ty = Arena_GetAimPoint(caster)

        DestroyEffect(AddSpecialEffect("Abilities/Spells/Other/Tornado/TornadoElemental.mdl", tx, ty))

        local qDmg = 140.0 + 80.0 * (rank - 1) + pInt * 0.9
        if rank == 3 then qDmg = 300.0 + pInt * 0.9 end
        if rank >= 4 then qDmg = 380.0 + pInt * 0.9 end

        local p = GetOwningPlayer(caster)
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, tx, ty, 350.0, nil)
        local u = FirstOfGroup(g)
        local pulledTargets = {}
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
                UnitDamageTarget(caster, u, qDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                table.insert(pulledTargets, u)
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)

        local vortexTicks = 0
        local vTimer = CreateTimer()
        TimerStart(vTimer, 1.5, true, function()
            vortexTicks = vortexTicks + 1
            for _, pu in ipairs(pulledTargets) do
                if GetWidgetLife(pu) > 0.405 then
                    SetUnitPosition(pu, tx, ty)
                    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/NightElf/Blink/BlinkTarget.mdl", pu, "origin"))
                end
            end
            if vortexTicks >= 3 then
                DestroyTimer(vTimer)
            end
        end)
    end
end

function Arena_TickCooldowns(unit, delta)
    local pid = GetPlayerId(GetOwningPlayer(unit))
    local role = HeroKind[pid]
    if Heroes[pid] ~= unit or role == nil then return end
    for slot = 1, 3 do
        local spell = HeroClasses[role].spells[slot]
        local remaining = BlzGetUnitAbilityCooldownRemaining(unit, spell)
        if remaining > 0 then
            BlzStartUnitAbilityCooldown(unit, spell, math.max(0, remaining - delta))
        end
    end
end

function Arena_AccelerateCooldowns(unit, duration)
    local previous = CooldownAcceleration[unit]
    if previous ~= nil then DestroyTimer(previous) end
    local timer, elapsed = CreateTimer(), 0.0
    CooldownAcceleration[unit] = timer
    TimerStart(timer, 0.5, true, function()
        if GetUnitTypeId(unit) == 0 then
            CooldownAcceleration[unit] = nil; DestroyTimer(timer); return
        end
        Arena_TickCooldowns(unit, 0.5)
        elapsed = elapsed + 0.5
        if elapsed >= duration then CooldownAcceleration[unit] = nil; DestroyTimer(timer) end
    end)
end

function Arena_Chrono_W(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local tx, ty = Arena_GetAimPoint(caster)

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Items/SpellShieldAmulet/SpellShieldCaster.mdl", tx, ty))

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
                Arena_AccelerateCooldowns(u, 5.0)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Orc/Bloodlust/BloodlustTarget.mdl", u, "origin"))
                local tu = u
                local origSpd = GetUnitDefaultMoveSpeed(tu)
                local wTimer = CreateTimer()
                TimerStart(wTimer, 5.0, false, function()
                    if GetWidgetLife(tu) > 0.405 then SetUnitMoveSpeed(tu, origSpd) end
                    DestroyTimer(wTimer)
                end)
            elseif IsUnitEnemy(u, p) then
                Arena_ApplyMoveSlow(u, 0.30, 2.5)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Slow/SlowTarget.mdl", u, "overhead"))
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_Chrono_E(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local tx, ty = Arena_GetAimPoint(caster)
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

    DestroyEffect(AddSpecialEffect("Abilities/Spells/NightElf/Blink/BlinkCaster.mdl", cx, cy))

    local echo = CreateUnit(GetOwningPlayer(caster), FourCC('eC01'), cx, cy, GetUnitFacing(caster))
    if echo ~= nil then UnitApplyTimedLife(echo, FourCC('BTLF'), 4.1) end
    local cooldownTimer = CreateTimer()
    TimerStart(cooldownTimer, 0.0, false, function()
        if GetUnitTypeId(caster) ~= 0 then BlzStartUnitAbilityCooldown(caster, FourCC('A11F'), 16.0) end
        DestroyTimer(cooldownTimer)
    end)

    SetUnitPathing(caster, false)
    SetUnitPosition(caster, endX, endY)
    SetUnitPathing(caster, true)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/NightElf/Blink/BlinkTarget.mdl", endX, endY))

    local pInt = GetHeroInt(caster, true)
    local echoTimer = CreateTimer()
    TimerStart(echoTimer, 4.0, false, function()
        if echo ~= nil and GetWidgetLife(echo) > 0.405 then
            local ex, ey = GetUnitX(echo), GetUnitY(echo)
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", ex, ey))

            local g = CreateGroup()
            GroupEnumUnitsInRange(g, ex, ey, 300.0, nil)
            local u = FirstOfGroup(g)
            while u ~= nil do
                GroupRemoveUnit(g, u)
                if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
                    UnitDamageTarget(caster, u, 150.0 + pInt * 0.8, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                    PauseUnit(u, true)
                    local tu = u
                    local stTimer = CreateTimer()
                    TimerStart(stTimer, 1.5, false, function()
                        if GetWidgetLife(tu) > 0.405 then PauseUnit(tu, false) end
                        DestroyTimer(stTimer)
                    end)
                end
                u = FirstOfGroup(g)
            end
            DestroyGroup(g)
            SetWidgetLife(echo, 0.0)
        end
        DestroyTimer(echoTimer)
    end)
end

function Arena_Chrono_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local owner = GetOwningPlayer(caster)
    local duration = 4.0 + rank
    local enemies, allies = {}, {}
    local function releaseAlly(unit)
        allies[unit] = nil
        local state = ChronoHaste[unit]
        if state == nil then return end
        state.count = state.count - 1
        if state.count == 0 then
            ChronoHaste[unit] = nil
            if GetUnitTypeId(unit) ~= 0 then SetUnitMoveSpeed(unit, state.speed) end
        end
    end
    local function release(unit)
        if not enemies[unit] then return end
        DestroyEffect(enemies[unit])
        enemies[unit] = nil
        local state = ChronoFreeze[unit]
        if state ~= nil then
            state.count = state.count - 1
            if state.count == 0 then
                ChronoFreeze[unit] = nil
                if GetUnitTypeId(unit) ~= 0 then PauseUnit(unit, state.wasPaused) end
            end
        end
    end
    local function scan()
        local seen = {}
        local group = CreateGroup()
        GroupEnumUnitsInRange(group, cx, cy, 600.0, nil)
        local unit = FirstOfGroup(group)
        while unit ~= nil do
            GroupRemoveUnit(group, unit)
            if GetWidgetLife(unit) > 0.405 then
                seen[unit] = true
                if IsUnitEnemy(unit, owner) then
                    if enemies[unit] == nil then
                        local state = ChronoFreeze[unit]
                        if state == nil then
                            state = {count=0, wasPaused=IsUnitPaused(unit)}
                            ChronoFreeze[unit] = state
                            PauseUnit(unit, true)
                        end
                        state.count = state.count + 1
                        enemies[unit] = AddSpecialEffectTarget("Abilities/Spells/Undead/FreezingBreath/FreezingBreathTargetArt.mdl", unit, "origin")
                    end
                    if not IsUnitPaused(unit) then
                        ChronoFreeze[unit].wasPaused = false
                        PauseUnit(unit, true)
                    end
                elseif IsUnitAlly(unit, owner) then
                    if allies[unit] == nil then
                        local state = ChronoHaste[unit]
                        if state == nil then
                            state = {count=0, speed=GetUnitMoveSpeed(unit)}
                            ChronoHaste[unit] = state
                        end
                        state.count = state.count + 1
                        allies[unit] = true
                    end
                    SetUnitMoveSpeed(unit, 522.0)
                end
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        for unit in pairs(enemies) do
            if not seen[unit] then release(unit) end
        end
        for unit in pairs(allies) do
            if not seen[unit] then
                releaseAlly(unit)
            end
        end
    end
    scan()
    local elapsed, timer = 0.0, CreateTimer()
    TimerStart(timer, 0.1, true, function()
        elapsed = elapsed + 0.1
        if elapsed + 0.0001 < duration then scan(); return end
        local damage = (400.0 + GetHeroInt(caster, true) * 1.5) * (1.3 + 0.15 * (rank-1))
        for unit in pairs(enemies) do
            release(unit)
            if GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405 then
                UnitDamageTarget(caster, unit, damage, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
            end
        end
        for unit in pairs(allies) do releaseAlly(unit) end
        DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", cx, cy))
        DestroyTimer(timer)
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

    Arena_UpdateStackIndicator(target, 'induction', data.count)

    if data.count >= 5 then
        Arena_Storm_ShortCircuit(target, caster)
    end
end

function Arena_ChainLightning(caster,target,damage,maxHits,stacks)
    if not target or not IsUnitEnemy(target,GetOwningPlayer(caster)) then return end
    local seen,previous,hits={},caster,0
    local timer=CreateTimer()
    local function jump()
        if not target or GetUnitTypeId(caster)==0 or GetWidgetLife(target)<=0.405 then DestroyTimer(timer);return end
        local hit=target
        seen[hit]=true;hits=hits+1
        local bolt=AddLightningEx('CLPB',false,GetUnitX(previous),GetUnitY(previous),70,GetUnitX(hit),GetUnitY(hit),70)
        local cleanup=CreateTimer()
        TimerStart(cleanup,0.3,false,function() DestroyLightning(bolt);DestroyTimer(cleanup) end)
        UnitDamageTarget(caster,hit,damage,false,false,ATTACK_TYPE_MAGIC,DAMAGE_TYPE_LIGHTNING,WEAPON_TYPE_WHOKNOWS)
        if stacks then Arena_ApplyInductionStack(hit,caster,1) end
        if hits>=maxHits then DestroyTimer(timer);return end
        local group,nearest,dist=CreateGroup(),nil,math.huge
        GroupEnumUnitsInRange(group,GetUnitX(hit),GetUnitY(hit),400,nil)
        local u=FirstOfGroup(group)
        while u do
            GroupRemoveUnit(group,u)
            local d=(GetUnitX(u)-GetUnitX(hit))^2+(GetUnitY(u)-GetUnitY(hit))^2
            if not seen[u] and GetWidgetLife(u)>0.405 and IsUnitEnemy(u,GetOwningPlayer(caster)) and d<dist then nearest=u;dist=d end
            u=FirstOfGroup(group)
        end
        DestroyGroup(group)
        previous,target=hit,nearest;damage=damage*0.8
        if not target then DestroyTimer(timer) end
    end
    TimerStart(timer,0.15,true,jump)
    jump()
    return timer
end

function Arena_Storm_ShortCircuit(target,caster)
    if not target or GetWidgetLife(target)<=0.405 then return end
    InductionStacks[GetHandleId(target)]=nil
    Arena_ClearStackIndicator(target,'induction')
    Arena_ChainLightning(caster,target,100+GetHeroInt(caster,true)*0.6,4,false)
    local maxMana=GetUnitState(caster,UNIT_STATE_MAX_MANA)
    SetUnitState(caster,UNIT_STATE_MANA,math.min(maxMana,GetUnitState(caster,UNIT_STATE_MANA)+math.min(20,maxMana*0.01)))
end

function Arena_Storm_OnAttackHit(attacker, target)
    if attacker == nil or target == nil then return end
    local pid = GetPlayerId(GetOwningPlayer(attacker))
    local state = StormSupercharge[GetHandleId(attacker)]
    if Heroes[pid] ~= attacker or HeroKind[pid] ~= 3 or state == nil or not state.active
        or not IsUnitEnemy(target, GetOwningPlayer(attacker)) or GetWidgetLife(target) <= 0.405 then return end
    UnitDamageTarget(attacker,target,GetHeroInt(attacker,true)*1.2,false,false,ATTACK_TYPE_MAGIC,DAMAGE_TYPE_LIGHTNING,WEAPON_TYPE_WHOKNOWS)
    Arena_ApplyInductionStack(target,attacker,2)
end

function Arena_Storm_Q(caster,rank)
    if not caster or GetWidgetLife(caster)<=0.405 then return end
    local base=({150,250,360,480,580})[rank]+GetHeroInt(caster,true)
    Arena_ChainLightning(caster,GetSpellTargetUnit(),base,({5,7,9,12,14})[rank],true)
end

function Arena_Storm_W(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local tx, ty = Arena_GetAimPoint(caster)

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Orc/LightningShield/LightningShieldTarget.mdl", tx, ty))

    local pInt = GetHeroInt(caster, true)
    local p = GetOwningPlayer(caster)

    local wTicks = 0
    local wTimer = CreateTimer()
    TimerStart(wTimer, 1.5, true, function()
        wTicks = wTicks + 1
        if wTicks > 4 or GetWidgetLife(caster) <= 0.405 then
            DestroyTimer(wTimer)
            return
        end

        local g = CreateGroup()
        GroupEnumUnitsInRange(g, tx, ty, 450.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
                UnitDamageTarget(caster, u, 15.0 + pInt * 0.05, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)

                Arena_ApplyInductionStack(u, caster, 1)

                if wTicks % 3 == 0 then
                    local ux, uy = GetUnitX(u), GetUnitY(u)
                    local angle = math.atan(ty - uy, tx - ux)
                    SetUnitPosition(u, ux + math.cos(angle) * 20.0, uy + math.sin(angle) * 20.0)
                end
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
        if wTicks == 4 then DestroyTimer(wTimer) end
    end)
end

function Arena_Storm_E(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cid = GetHandleId(caster)
    local previous = StormSupercharge[cid]
    if previous ~= nil then DestroyEffect(previous.effect) end
    StormSupercharge[cid] = {
        active = true,
        duration = 5.0,
        caster = caster
    }

    local state = StormSupercharge[cid]
    state.effect = AddSpecialEffectTarget("Abilities/Spells/Orc/LightningShield/LightningShieldTarget.mdl", caster, "origin")

    local eTimer = CreateTimer()
    TimerStart(eTimer, 5.0, false, function()
        if StormSupercharge[cid] == state then
            StormSupercharge[cid] = nil
            DestroyEffect(state.effect)
        end
        DestroyTimer(eTimer)
    end)
end

function Arena_Storm_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local pInt = GetHeroInt(caster, true)

    local rTicks = 0
    local rTimer = CreateTimer()
    TimerStart(rTimer, 0.4, true, function()
        rTicks = rTicks + 1
        if rTicks > 15 or GetWidgetLife(caster) <= 0.405 then
            DestroyTimer(rTimer)
            return
        end

        local p = GetOwningPlayer(caster)
        local baseStrike = 180.0 + 120.0 * (rank - 1) + pInt * 0.4
        if rank == 3 then baseStrike = 450.0 + pInt * 0.4 end

        local g = CreateGroup()
        GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), 800.0, nil)
        local u = FirstOfGroup(g)
        local struckCount = 0
        while u ~= nil and struckCount < 3 do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
                UnitDamageTarget(caster, u, baseStrike, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Monsoon/MonsoonBoltTarget.mdl", u, "chest"))
                Arena_ApplyInductionStack(u, caster, 1)
                struckCount = struckCount + 1
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
    end)
end

function Arena_InitBombardierSystem()
    local t = CreateTimer()
    TimerStart(t, 0.5, true, function()
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
                        if udg_Boss ~= nil and u == udg_Boss then rootDur = 1.5 end

                        SetUnitMoveSpeed(u, 0.0)
                        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Orc/Ensnare/EnsnareTarget.mdl", u, "origin"))

                        local tu = u
                        local origSpeed = GetUnitDefaultMoveSpeed(tu)
                        local rTimer = CreateTimer()
                        TimerStart(rTimer, rootDur, false, function()
                            if GetWidgetLife(tu) > 0.405 then
                                SetUnitMoveSpeed(tu, origSpeed)
                            end
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

                local dotPerSec = (agi * 0.15 + maxHp * 0.015) * data.stacks
                local dotTick = dotPerSec * 0.5

                UnitDamageTarget(data.caster, target, dotTick, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Weapons/Blood/BloodImpact.mdl", target, "origin"))
            else
                if target ~= nil then
                    UnitRemoveAbility(target, FourCC('ACrf'))
                end
                ShrapnelDebuffs[tid] = nil
            end
        end

        for cid, st in pairs(BombardierRocketState) do
            if st.active then
                st.duration = st.duration - 0.5
                if st.duration <= 0 then
                    st.active = false
                    SetUnitMoveSpeed(st.caster, GetUnitDefaultMoveSpeed(st.caster))
                    DisplayTimedTextToPlayer(GetOwningPlayer(st.caster), 0, 0, 4.0, "|cffffcc00[АРТИЛЛЕРИЯ]:|r Режим Мобильной Батареи завершен.")
                end
            end
        end

        for cid, tLeft in pairs(RoninCleaveTimer) do
            if tLeft > 0 then
                RoninCleaveTimer[cid] = tLeft - 0.5
            end
        end
    end)
end

function Arena_TimeLoop(target, duration)
    if target == nil or GetWidgetLife(target) <= 0.405 then return end
    local x, y = GetUnitX(target), GetUnitY(target)
    local hp = GetUnitState(target, UNIT_STATE_LIFE)
    local mp = GetUnitState(target, UNIT_STATE_MANA)
    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Items/AIam/AIamTarget.mdl", target, "origin"))
    local t = CreateTimer()
    TimerStart(t, duration, false, function()
        if GetWidgetLife(target) > 0.405 then
            SetUnitPosition(target, x, y)
            SetUnitState(target, UNIT_STATE_LIFE, hp)
            SetUnitState(target, UNIT_STATE_MANA, mp)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/MassTeleport/MassTeleportTarget.mdl", target, "origin"))
        end
        DestroyTimer(t)
    end)
end

function Arena_Chronosphere(caster, radius, duration)
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Other/Tornado/TornadoElemental.mdl", cx, cy))
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, radius, nil)
    local u = FirstOfGroup(g)
    local pausedUnits = {}
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if u ~= caster and GetWidgetLife(u) > 0.405 then
            PauseUnit(u, true)
            table.insert(pausedUnits, u)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
    local t = CreateTimer()
    TimerStart(t, duration, false, function()
        for _, pUnit in ipairs(pausedUnits) do
            if GetWidgetLife(pUnit) > 0.405 then
                PauseUnit(pUnit, false)
            end
        end
        DestroyTimer(t)
    end)
end

function Arena_EarthquakeWall(caster, radius)
    Arena_KnockbackArea(caster, radius, 150.0)
    Arena_CustomArea(caster, radius, 200.0, false)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Demon/DemonBoltImpact/DemonBoltImpact.mdl", GetUnitX(caster), GetUnitY(caster)))
end

function Arena_VoodooInvuln(caster, radius, duration)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), radius, nil)
    local u = FirstOfGroup(g)
    local allies = {}
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitAlly(u, GetOwningPlayer(caster)) and u ~= caster and GetWidgetLife(u) > 0.405 then
            SetUnitInvulnerable(u, true)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Orc/Voodoo/VoodooAuraTarget.mdl", u, "origin"))
            table.insert(allies, u)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
    local t = CreateTimer()
    TimerStart(t, duration, false, function()
        for _, ally in ipairs(allies) do
            if GetWidgetLife(ally) > 0.405 then
                SetUnitInvulnerable(ally, false)
            end
        end
        DestroyTimer(t)
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
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/DeathCoil/DeathCoilSpecialArt.mdl", target, "chest"))
        end
        target = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_CustomArea(caster, radius, amount, healing)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), radius, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if GetWidgetLife(u) > 0.405 then
            if healing and IsUnitAlly(u, GetOwningPlayer(caster)) and IsUnitType(u, UNIT_TYPE_HERO) then
                SetUnitState(u, UNIT_STATE_LIFE, GetUnitState(u, UNIT_STATE_LIFE) + amount)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/HolyBolt/HolyBoltSpecialArt.mdl", u, "origin"))
            elseif not healing and IsUnitEnemy(u, GetOwningPlayer(caster)) then
                UnitDamageTarget(caster, u, amount, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", u, "origin"))
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
    DestroyEffect(AddSpecialEffect("Abilities/Spells/NightElf/Blink/BlinkTarget.mdl", nx, ny))
end

function Arena_HeroBurst(caster, radius, damage, friendlyFire)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), radius, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if GetWidgetLife(u) > 0.405 then
            if friendlyFire or IsUnitEnemy(u, GetOwningPlayer(caster)) then
                UnitDamageTarget(caster, u, damage, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_ItemPulses(caster, hpAmount, manaAmount)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), 600.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if GetWidgetLife(u) > 0.405 and IsUnitAlly(u, GetOwningPlayer(caster)) and IsUnitType(u, UNIT_TYPE_HERO) then
            if hpAmount > 0 then
                SetUnitState(u, UNIT_STATE_LIFE, GetUnitState(u, UNIT_STATE_LIFE) + hpAmount)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Items/HealingSalve/HealingSalveTarget.mdl", u, "origin"))
            end
            if manaAmount > 0 then
                SetUnitState(u, UNIT_STATE_MANA, GetUnitState(u, UNIT_STATE_MANA) + manaAmount)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Items/ClarityPotion/ClarityTarget.mdl", u, "origin"))
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_SpellAid(caster, hpAmount, manaAmount)
    if hpAmount > 0 then
        SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + hpAmount)
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Items/HealingSalve/HealingSalveTarget.mdl", caster, "origin"))
    end
    if manaAmount > 0 then
        SetUnitState(caster, UNIT_STATE_MANA, GetUnitState(caster, UNIT_STATE_MANA) + manaAmount)
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Items/ClarityPotion/ClarityTarget.mdl", caster, "origin"))
    end
end

function Arena_CustomSummon(caster, unitId, count, duration)
    local i = 0
    local p = GetOwningPlayer(caster)
    local x = GetUnitX(caster)
    local y = GetUnitY(caster)
    while i < count do
        local rx = x + GetRandomReal(-80.0, 80.0)
        local ry = y + GetRandomReal(-80.0, 80.0)
        local u = CreateUnit(p, unitId, rx, ry, GetUnitFacing(caster))
        UnitApplyTimedLife(u, FourCC('BTLF'), duration)
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/AnimateDead/AnimateDeadTarget.mdl", u, "origin"))
        i = i + 1
    end
end



function Arena_UpdateGear(hero)
    local total,old={},EquippedItemStats[hero]
    for slot=0,5 do
        local item=UnitItemInSlot(hero,slot)
        local stats=item and ArenaItemStats[GetItemTypeId(item)]
        if stats then
            for key,value in pairs(stats) do
                if key=='move' or key=='block' or key=='evasion' or key=='poisoncap' or key=='reset' then
                    total[key]=math.max(total[key] or 0,value)
                else total[key]=(total[key] or 0)+value end
            end
        end
    end
    if not old and next(total)==nil then return end
    old=old or {}
    local function delta(key) return (total[key] or 0)-(old[key] or 0) end
    if delta('str')~=0 then SetHeroStr(hero,GetHeroStr(hero,false)+delta('str'),true) end
    if delta('agi')~=0 then SetHeroAgi(hero,GetHeroAgi(hero,false)+delta('agi'),true) end
    if delta('int')~=0 then SetHeroInt(hero,GetHeroInt(hero,false)+delta('int'),true) end
    if delta('armor')~=0 then BlzSetUnitArmor(hero,BlzGetUnitArmor(hero)+delta('armor')) end
    if delta('hp')~=0 then
        local life=GetWidgetLife(hero)
        BlzSetUnitMaxHP(hero,BlzGetUnitMaxHP(hero)+delta('hp'))
        SetUnitState(hero,UNIT_STATE_LIFE,math.min(life,BlzGetUnitMaxHP(hero)))
    end
    if delta('mana')~=0 then
        local mana=GetUnitState(hero,UNIT_STATE_MANA)
        BlzSetUnitMaxMana(hero,BlzGetUnitMaxMana(hero)+delta('mana'))
        SetUnitState(hero,UNIT_STATE_MANA,math.min(mana,BlzGetUnitMaxMana(hero)))
    end
    if delta('damage')~=0 then BlzSetUnitBaseDamage(hero,BlzGetUnitBaseDamage(hero,0)+delta('damage'),0) end
    if delta('move')~=0 then
        local base=GetUnitMoveSpeed(hero)-(old._moveApplied or old.move or 0)
        local speed=math.min(522,base+(total.move or 0))
        total._moveApplied=speed-base
        SetUnitMoveSpeed(hero,speed)
    else total._moveApplied=old._moveApplied end
    if delta('as')~=0 then
        BlzSetUnitAttackCooldown(hero,BlzGetUnitAttackCooldown(hero,0)*(1+(old['as'] or 0))/(1+(total['as'] or 0)),0)
    end
    EquippedItemStats[hero]=total
end

function Arena_ItemDamage(source,target,damage,attack)
    if ItemCombatBusy or damage<=0 then return end
    local defense=EquippedItemStats[target] or {}
    if attack and defense.evasion and GetRandomInt(1,100)<=defense.evasion then BlzSetEventDamage(0);return end
    local dealt=damage
    if attack then dealt=math.max(0,dealt-(defense.block or 0)) end
    local offense=EquippedItemStats[source] or {}
    if not attack then
        dealt=dealt*(1+(offense.magic or 0))
        if offense.reset and not ItemResetReady[source] then
            ItemResetReady[source]=true
            local cooldown=CreateTimer()
            TimerStart(cooldown,0,false,function()
                local pid=GetPlayerId(GetOwningPlayer(source))
                if Heroes[pid]==source then
                    for slot=1,3 do BlzEndUnitAbilityCooldown(source,HeroClasses[HeroKind[pid]].spells[slot]) end
                end
                DestroyTimer(cooldown)
            end)
            local timer=CreateTimer()
            TimerStart(timer,offense.reset,false,function() ItemResetReady[source]=nil;DestroyTimer(timer) end)
        end
    end
    if dealt~=damage then BlzSetEventDamage(dealt) end
end

function Arena_ItemHit(hero,target)
    if ItemCombatBusy then return end
    local stats=EquippedItemStats[hero]
    if not stats then return end
    if stats.poison then
        local state=ItemPoisons[target]
        if not state or state.caster~=hero then state={count=0,caster=hero};ItemPoisons[target]=state end
        state.count=math.min(stats.poisoncap or 1,state.count+1);state.remaining=3;state.damage=stats.poison
        DestroyEffect(AddSpecialEffectTarget("Abilities/Weapons/PoisonSting/PoisonStingTarget.mdl",target,"origin"))
    end
    if stats.splash then
        ItemCombatBusy=true
        local group=CreateGroup()
        GroupEnumUnitsInRange(group,GetUnitX(target),GetUnitY(target),220,nil)
        local unit=FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group,unit)
            if unit~=target and IsUnitEnemy(unit,GetOwningPlayer(hero)) and GetWidgetLife(unit)>0.405 then
                UnitDamageTarget(hero,unit,BlzGetUnitBaseDamage(hero,0)*stats.splash,false,false,ATTACK_TYPE_HERO,DAMAGE_TYPE_NORMAL,WEAPON_TYPE_WHOKNOWS)
            end
            unit=FirstOfGroup(group)
        end
        DestroyGroup(group);ItemCombatBusy=false
    end
end

function Arena_InitEconomy()
    local shop=CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE),FourCC('nS01'),-850,-650,45)
    for _,raw in ipairs({'phea','pman','shea','spro','hslv'}) do AddItemToStock(shop,FourCC(raw),3,3) end
    local forge=CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE),FourCC('nS02'),850,-650,135)
    for _,raw in ipairs({'rng1','belv','boot','rat6','glov','I0MA','prt5','I000'}) do AddItemToStock(forge,FourCC(raw),4,4) end
    local guide=CreateQuest()
    QuestSetTitle(guide,'Сборка артефактов')
    QuestSetRequired(guide,false);QuestSetDiscovered(guide,true)
    QuestSetDescription(guide,'Кузница справа внизу продаёт компоненты. Лавка слева внизу продаёт расходники. Артефакты собираются автоматически при подборе компонентов.|n|nСапоги Скитальца = Сапоги Ветра + Перчатки.|nКаменный Бастион = Кольцо + Кристалл Жизни.|nЖало Пустоты = Клинок + Перчатки.|nКодекс = Мантия Мудреца + Амулет Маны.|n|nЭгида = Бастион + Сердце Голема.|nКлык Королевы = Жало + Хелицера.|nСекира Пекла = Клинок + Пояс + Пылающий Осколок.|nСкипетр = Кодекс + Око Вечности.|nПризрачные Поступи = Сапоги Скитальца + Мантия Сумерек.|n|nРеликвии выпадают с мини-боссов. Готовые артефакты не продаются в лавке. Бонус скорости от сапог не складывается.')
    local timer=CreateTimer()
    TimerStart(timer,1,true,function()
        for _,hero in pairs(Heroes) do
            if GetUnitTypeId(hero)~=0 then
                Arena_UpdateGear(hero)
                local stats=EquippedItemStats[hero]
                if stats and GetWidgetLife(hero)>0.405 then
                    if stats.hpreg then SetUnitState(hero,UNIT_STATE_LIFE,math.min(BlzGetUnitMaxHP(hero),GetWidgetLife(hero)+stats.hpreg)) end
                    if stats.mpreg then SetUnitState(hero,UNIT_STATE_MANA,math.min(BlzGetUnitMaxMana(hero),GetUnitState(hero,UNIT_STATE_MANA)+stats.mpreg)) end
                    if stats.burn then
                        ItemCombatBusy=true
                        Arena_CustomArea(hero,250,stats.burn,false)
                        ItemCombatBusy=false
                    end
                end
            end
        end
        for unit,state in pairs(ItemPoisons) do
            if GetUnitTypeId(unit)==0 or GetWidgetLife(unit)<=0.405 or state.remaining<=0 then ItemPoisons[unit]=nil
            else
                state.remaining=state.remaining-1
                UnitDamageTarget(state.caster,unit,state.count*state.damage,false,false,ATTACK_TYPE_HERO,DAMAGE_TYPE_POISON,WEAPON_TYPE_WHOKNOWS)
            end
        end
    end)
end



-- BEGIN GENERATED LANDSCAPE
function Arena_CreateLandscape()
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2373.71, 1106.01, 6.67, 0.980, 7), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2513.14, 1136.23, 350.15, 0.998, 7), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2231.48, 777.78, 236.23, 1.034, 5), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2331.75, 746.75, 263.94, 0.949, 7), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2351.65, 868.13, 74.53, 0.928, 0), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2085.66, 1014.53, 163.24, 0.933, 1), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2207.80, 1061.68, 146.45, 1.086, 6), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2275.26, 1212.38, 66.68, 0.993, 4), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2639.58, 1114.58, 343.17, 1.119, 0), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 838.78, 2778.66, 108.93, 1.072, 4), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 1025.79, 2254.73, 323.64, 1.179, 2), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 919.28, 2159.13, 15.65, 1.115, 1), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 999.24, 2622.62, 315.78, 1.198, 2), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 807.55, 2617.41, 180.80, 1.163, 1), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 914.84, 2539.98, 227.90, 1.048, 8), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 798.26, 2707.52, 194.89, 1.036, 3), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 950.11, 2445.88, 86.88, 1.128, 7), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 878.34, 2702.42, 330.56, 0.855, 8), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -994.12, 2447.73, 140.95, 1.079, 7), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -720.05, 2240.42, 90.91, 0.897, 6), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -900.88, 2259.06, 64.94, 0.874, 1), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -993.40, 2295.51, 119.15, 0.901, 0), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -1131.08, 2428.99, 326.32, 0.937, 7), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -1037.91, 2456.57, 285.30, 0.860, 4), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -868.54, 2205.53, 95.15, 1.021, 1), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -1190.33, 2397.80, 126.65, 1.145, 8), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -1005.61, 2467.64, 189.15, 0.857, 3), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2577.61, 704.86, 311.43, 0.998, 2), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2191.01, 1026.71, 236.26, 1.151, 9), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2294.14, 724.85, 120.59, 1.133, 9), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2233.92, 669.09, 312.28, 1.041, 0), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2324.56, 1062.80, 83.38, 1.175, 8), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2151.18, 894.09, 265.91, 1.026, 0), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2692.71, 1152.75, 57.31, 0.989, 1), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2304.86, 742.50, 283.44, 1.119, 8), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2765.30, 906.94, 75.40, 0.877, 6), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2156.06, -1007.75, 351.37, 1.180, 8), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2451.21, -1219.17, 142.17, 0.880, 0), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2208.38, -781.79, 194.42, 1.131, 5), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2143.28, -881.37, 219.39, 1.100, 6), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2069.86, -1066.02, 165.67, 0.965, 3), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2763.39, -1009.96, 121.13, 1.175, 5), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2212.45, -843.69, 265.32, 0.891, 9), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2541.35, -1129.48, 345.78, 0.954, 6), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -2121.37, -1140.06, 176.43, 1.104, 1), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -728.74, -2699.37, 158.88, 0.856, 8), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -877.37, -2548.09, 239.23, 0.917, 2), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -1007.86, -2418.99, 267.10, 0.888, 9), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -866.01, -2309.46, 157.59, 1.105, 3), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -1166.92, -2625.16, 250.63, 1.198, 1), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -797.33, -2268.66, 230.69, 0.960, 6), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -1017.30, -2451.66, 125.61, 1.158, 7), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -795.37, -2211.41, 335.99, 1.046, 7), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), -662.60, -2183.99, 144.67, 1.089, 0), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 811.10, -2153.36, 47.38, 0.870, 8), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 1165.29, -2705.60, 309.52, 1.022, 7), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 800.76, -2342.41, 198.04, 1.141, 2), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 1130.03, -2542.66, 180.57, 1.153, 8), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 769.30, -2127.14, 208.31, 1.020, 2), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 1214.87, -2443.55, 21.34, 0.887, 2), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 1176.36, -2564.97, 159.10, 0.979, 4), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 1220.93, -2187.60, 254.98, 1.062, 4), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 1084.58, -2685.75, 137.30, 1.079, 5), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2151.42, -754.66, 162.11, 1.139, 2), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2220.31, -1087.39, 36.56, 0.905, 5), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2516.90, -1080.59, 21.57, 1.186, 3), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2583.38, -872.83, 335.67, 0.891, 8), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2298.20, -703.67, 222.03, 0.938, 8), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2631.36, -1121.98, 37.69, 1.181, 5), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2211.33, -1126.44, 111.33, 0.985, 8), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2760.88, -782.45, 352.15, 1.074, 5), true)
    SetDestructableInvulnerable(CreateDestructable(FourCC('LTlt'), 2323.02, -966.64, 270.16, 0.963, 3), true)
    local effect
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks2.mdl", 1917.41, 1003.27)
    BlzSetSpecialEffectYaw(effect, 1.301)
    BlzSetSpecialEffectScale(effect, 0.757)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks0.mdl", 1881.53, 855.74)
    BlzSetSpecialEffectYaw(effect, 1.110)
    BlzSetSpecialEffectScale(effect, 0.929)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub2.mdl", 1863.61, 923.55)
    BlzSetSpecialEffectYaw(effect, 2.996)
    BlzSetSpecialEffectScale(effect, 0.987)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub1.mdl", 2034.19, 693.08)
    BlzSetSpecialEffectYaw(effect, 1.506)
    BlzSetSpecialEffectScale(effect, 1.033)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks3.mdl", 684.34, 1895.78)
    BlzSetSpecialEffectYaw(effect, 3.534)
    BlzSetSpecialEffectScale(effect, 0.886)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks1.mdl", 963.20, 1949.77)
    BlzSetSpecialEffectYaw(effect, 3.985)
    BlzSetSpecialEffectScale(effect, 0.864)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub0.mdl", 889.10, 1821.61)
    BlzSetSpecialEffectYaw(effect, 2.302)
    BlzSetSpecialEffectScale(effect, 0.900)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub1.mdl", 947.05, 1919.33)
    BlzSetSpecialEffectYaw(effect, 5.905)
    BlzSetSpecialEffectScale(effect, 0.855)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks2.mdl", -1120.62, 1887.40)
    BlzSetSpecialEffectYaw(effect, 3.768)
    BlzSetSpecialEffectScale(effect, 0.784)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks4.mdl", -992.38, 1842.66)
    BlzSetSpecialEffectYaw(effect, 1.772)
    BlzSetSpecialEffectScale(effect, 1.025)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub1.mdl", -897.41, 1890.55)
    BlzSetSpecialEffectYaw(effect, 5.726)
    BlzSetSpecialEffectScale(effect, 0.963)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub1.mdl", -1017.76, 1853.96)
    BlzSetSpecialEffectYaw(effect, 4.865)
    BlzSetSpecialEffectScale(effect, 0.760)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks3.mdl", -2059.91, 667.35)
    BlzSetSpecialEffectYaw(effect, 1.799)
    BlzSetSpecialEffectScale(effect, 0.996)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks3.mdl", -1876.51, 758.01)
    BlzSetSpecialEffectYaw(effect, 3.294)
    BlzSetSpecialEffectScale(effect, 0.715)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub0.mdl", -1913.50, 965.70)
    BlzSetSpecialEffectYaw(effect, 3.851)
    BlzSetSpecialEffectScale(effect, 0.783)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub2.mdl", -1911.60, 836.78)
    BlzSetSpecialEffectYaw(effect, 5.445)
    BlzSetSpecialEffectScale(effect, 0.751)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks5.mdl", -1969.16, -786.06)
    BlzSetSpecialEffectYaw(effect, 4.955)
    BlzSetSpecialEffectScale(effect, 0.787)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks3.mdl", -1995.76, -654.14)
    BlzSetSpecialEffectYaw(effect, 1.135)
    BlzSetSpecialEffectScale(effect, 0.968)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub0.mdl", -1842.19, -916.42)
    BlzSetSpecialEffectYaw(effect, 0.973)
    BlzSetSpecialEffectScale(effect, 0.982)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub2.mdl", -1948.10, -665.31)
    BlzSetSpecialEffectYaw(effect, 4.777)
    BlzSetSpecialEffectScale(effect, 0.990)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks1.mdl", -640.15, -2031.88)
    BlzSetSpecialEffectYaw(effect, 1.523)
    BlzSetSpecialEffectScale(effect, 0.948)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks1.mdl", -731.91, -1873.22)
    BlzSetSpecialEffectYaw(effect, 4.709)
    BlzSetSpecialEffectScale(effect, 0.881)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub1.mdl", -682.54, -1947.25)
    BlzSetSpecialEffectYaw(effect, 3.893)
    BlzSetSpecialEffectScale(effect, 0.811)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub1.mdl", -679.25, -1924.57)
    BlzSetSpecialEffectYaw(effect, 3.968)
    BlzSetSpecialEffectScale(effect, 1.039)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks2.mdl", 938.25, -1957.19)
    BlzSetSpecialEffectYaw(effect, 4.869)
    BlzSetSpecialEffectScale(effect, 0.803)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks2.mdl", 992.51, -1788.30)
    BlzSetSpecialEffectYaw(effect, 4.193)
    BlzSetSpecialEffectScale(effect, 1.000)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub2.mdl", 1060.00, -1868.95)
    BlzSetSpecialEffectYaw(effect, 1.595)
    BlzSetSpecialEffectScale(effect, 0.911)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub0.mdl", 965.80, -1765.77)
    BlzSetSpecialEffectYaw(effect, 5.397)
    BlzSetSpecialEffectScale(effect, 0.796)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks0.mdl", 1930.57, -588.85)
    BlzSetSpecialEffectYaw(effect, 3.797)
    BlzSetSpecialEffectScale(effect, 0.964)
    effect = AddSpecialEffect("Doodads/LordaeronSummer/Terrain/LoardaeronRockChunks/LoardaeronRockChunks0.mdl", 1812.77, -940.62)
    BlzSetSpecialEffectYaw(effect, 4.548)
    BlzSetSpecialEffectScale(effect, 0.946)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub0.mdl", 1925.55, -625.39)
    BlzSetSpecialEffectYaw(effect, 2.202)
    BlzSetSpecialEffectScale(effect, 0.849)
    effect = AddSpecialEffect("Doodads/Ruins/Plants/Ruins_Shrub/Ruins_Shrub0.mdl", 1921.33, -590.15)
    BlzSetSpecialEffectYaw(effect, 4.756)
    BlzSetSpecialEffectScale(effect, 0.827)
end
-- END GENERATED LANDSCAPE





-- BEGIN ITEM STATS
ArenaItemStats = {
    [FourCC('rng1')] = {['armor']=4},
    [FourCC('belv')] = {['str']=6},
    [FourCC('boot')] = {['move']=55},
    [FourCC('rat6')] = {['damage']=14},
    [FourCC('glov')] = {['as']=0.15,['agi']=3},
    [FourCC('I0MA')] = {['mana']=150,['mpreg']=1},
    [FourCC('prt5')] = {['hp']=200,['hpreg']=2.5},
    [FourCC('I000')] = {['int']=6},
    [FourCC('I001')] = {['move']=70,['as']=0.2,['str']=5,['agi']=5,['int']=5},
    [FourCC('I002')] = {['armor']=6,['hp']=300,['hpreg']=4,['block']=25},
    [FourCC('I003')] = {['damage']=22,['as']=0.2,['agi']=6,['poison']=12},
    [FourCC('I004')] = {['int']=10,['mana']=250,['mpreg']=2.5},
    [FourCC('I005')] = {['armor']=14,['hp']=850,['hpreg']=16,['block']=50},
    [FourCC('I006')] = {['damage']=55,['as']=0.35,['poison']=18,['poisoncap']=5},
    [FourCC('I007')] = {['damage']=60,['str']=20,['splash']=0.25,['burn']=25},
    [FourCC('I008')] = {['int']=32,['mana']=500,['magic']=0.15,['reset']=45},
    [FourCC('I009')] = {['move']=100,['as']=0.3,['evasion']=20},
}
-- END ITEM STATS
