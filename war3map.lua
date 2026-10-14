-- ===========================================================================
-- Map Script: Warcraft III (Lua Mode)
-- ===========================================================================

function InitGlobals()
    -- Глобальные переменные
    Heroes = {}
    HeroKind = {}
    BleedStacks = {} -- Таблица учета кровотечения: BleedStacks[targetHandleId] = { count = N, expires = T, caster = U }
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
        { id = FourCC('Hpal'), name = "Тёмный Рыцарь (Сила / Танк)",     role = "tank",     spells = {FourCC('A101'), FourCC('A102'), FourCC('A10D'), FourCC('A10E')} },
        -- 2. Призрачный Ловчий (Ловкость / Ассасин)
        { id = FourCC('Obla'), name = "Призрачный Ловчий (Ловкость / Ассасин)", role = "assassin", spells = {FourCC('A103'), FourCC('A104'), FourCC('A10F'), FourCC('A10G')} },
        -- 3. Элементалист Бури / Архимаг Гроз (Интеллект / Абсолютный Магический AoE-Кастер)
        { id = FourCC('Hamg'), name = "Элементалист Бури (Интеллект / АоЕ-Маг)", role = "mage", spells = {FourCC('A105'), FourCC('A106'), FourCC('A10H'), FourCC('A10I')} },
        -- 4. Хранитель Древней / Друид Первобытного Леса (Сила / Саммонер & Биомасса)
        { id = FourCC('Udea'), name = "Хранитель Древней (Сила / Саммонер)", role = "summoner", spells = {FourCC('A107'), FourCC('A108'), FourCC('A10J'), FourCC('A10K')} },
        -- 5. Архилич Чумы / Повелитель Мёртвых (Интеллект / Некромант-Призыватель)
        { id = FourCC('Edem'), name = "Архилич Чумы (Интеллект / Некромант)", role = "dot_control", spells = {FourCC('A109'), FourCC('A10A'), FourCC('A10L'), FourCC('A10M')} },
        -- 6. Мастер Клинка / Ронин (Ловкость / Керри Ближнего Боя)
        { id = FourCC('Hmkg'), name = "Мастер Клинка-Ронин (Ловкость / Керри)", role = "carry", spells = {FourCC('A115'), FourCC('A116'), FourCC('A117'), FourCC('A118')} },
        -- 7. Жрица Рассвета (Интеллект / Боевой Саппорт, Защитник и Баффер)
        { id = FourCC('Emoo'), name = "Жрица Рассвета (Интеллект / Боевой Саппорт)", role = "healer", spells = {FourCC('A10B'), FourCC('A10C'), FourCC('A10N'), FourCC('A10O')} },
        -- 8. Инженер-Бомбардир (Ловкость / Осада и Зонинг)
        { id = FourCC('Nalc'), name = "Инженер-Бомбардир (Ловкость / Осада)", role = "siege",  spells = {FourCC('A111'), FourCC('A112'), FourCC('A113'), FourCC('A114')} },
        -- 9. Железный Исполин (Сила / Главный Танк, Инициатор и Стяжка)
        { id = FourCC('Ewar'), name = "Железный Исполин (Сила / Танк-Инициатор)", role = "initiator", spells = {FourCC('A119'), FourCC('A11A'), FourCC('A11B'), FourCC('A11C')} },
        -- 10. Хрономант / Хранитель Эпох (Интеллект / Тактический Саппорт-Манипулятор)
        { id = FourCC('Ulic'), name = "Хрономант (Интеллект / Контроль Времени)", role = "control", spells = {FourCC('A11D'), FourCC('A11E'), FourCC('A11F'), FourCC('A11G')} }
    }

    -- Переменные диалога
    HeroDialog = nil
    HeroDialogButtons = {}
end

function SpawnSelectedHero(pid, roleId)
    local p = Player(pid)
    local classData = HeroClasses[roleId]

    -- Спавн героя в центре карты (X: 0, Y: 0)
    local hero = CreateUnit(p, classData.id, 0.0, 0.0, 270.0)
    Heroes[pid] = hero
    HeroKind[pid] = roleId

    -- Выдаем способности
    for _, spellId in ipairs(classData.spells) do
        UnitAddAbility(hero, spellId)
    end

    SelectUnitForPlayerSingle(hero, p)
    PanCameraToTimedForPlayer(p, 0.0, 0.0, 0.0)
    DisplayTextToPlayer(p, 0, 0, "|cff88ff88Выбран класс:|r " .. classData.name)

    -- Стартовое сообщение
    DisplayTextToPlayer(p, 0, 0, "|cffffcc00Задание получено:|r Исследуйте местность и победите босса!")

    -- Стартовый квест
    local myQuest = CreateQuest()
    QuestSetTitle(myQuest, "Очищение земель")
    QuestSetDescription(myQuest, "Найдите и уничтожьте лагерь врагов.")
    QuestSetRequired(myQuest, true)
    QuestSetDiscovered(myQuest, true)
    FlashQuestDialogButton()

    -- Проверяем запуск волн при выборе каждого героя
    Arena_TryStartWaves()
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

    local rank = GetUnitAbilityLevel(caster, spellId)
    if rank < 1 then return end

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
            Arena_DoomChains(caster, 500.0, 4.0)
            Arena_CustomFinisher(caster, amount * 5.0)
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
        elseif spellId == FourCC('A116') then -- W: Стойка Парирования (Blade Parry)
            Arena_Ronin_W(caster, rank)
        elseif spellId == FourCC('A117') then -- E: Заточка Клинка: Рассечение Душ (Soul Edge)
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
        elseif spellId == FourCC('A104') then -- W: Слияние с Тенью (Неуязвимость + наложение кровотечения)
            Arena_DivineShield(caster, 2.0 + rank * 0.5)
        elseif spellId == FourCC('A10F') then -- E: Анатомический Удар (Критический урон + 3 стака кровотечения)
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
        components = { FourCC('I000'), FourCC('pman') }, -- Мантия Мудреца + Амулет Маны
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
    if hero == nil or GetWidgetLife(hero) <= 0.405 then return end

    for _, recipe in ipairs(ItemCraftRecipes) do
        local hasAll = true
        local matchedSlots = {}

        for _, reqComp in ipairs(recipe.components) do
            local found = false
            for slot = 0, 5 do
                local it = UnitItemInSlot(hero, slot)
                if it ~= nil and GetItemId(it) == reqComp and not matchedSlots[slot] then
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
end

function InitCustomTriggers()
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

            -- Check Ronin Parry stance on target
            local tid = GetHandleId(target)
            local st = RoninParryState[tid]
            if st and st.inStance then
                Arena_Ronin_CounterAttack(target, 100.0)
            end
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
            if num and num >= 1 and num <= 10 then
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
    InitCustomTriggers()
end

function config()
    SetMapName("TRIGSTR_001")
    SetMapDescription("TRIGSTR_003")
    SetPlayers(4)
    SetTeams(1)
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
    SetUnitCreepGuard(u, false)
    UnitWakeUp(u)
    SetUnitAcquireRange(u, 4000.0)
    IssuePointOrder(u, "attack", 0.0, 0.0)
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
    SetUnitCreepGuard(elite, false)
    UnitWakeUp(elite)
    SetUnitAcquireRange(elite, 4500.0)
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
    if pickedCount > 0 then
        udg_WavesStarted = true
        TimerStart(udg_WaveTimer, 15.00, false, Trig_Wave_Actions)
        TimerDialogSetTitle(udg_WaveTD, "Волна 1")
        TimerDialogDisplay(udg_WaveTD, true)
        Arena_Msg("Герой выбран! Первая волна через 15 секунд. Покупайте предметы в лавках!")
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
    TimerStart(udg_WaveTimer, 100.00, false, Trig_Wave_Actions)
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

function Arena_ShieldOfTorment(caster, shieldHp, armorBonus, duration)
    -- Временное увеличение макс. HP (для эффекта сильного щита) и брони
    UnitAddAbility(caster, FourCC('Adev')) -- Devotion Aura / Броня
    SetUnitAbilityLevel(caster, FourCC('Adev'), math.min(10, math.max(1, math.floor(armorBonus / 5))))
    UnitAddAbility(caster, FourCC('AImx')) -- Item Life Bonus / Запас HP
    SetUnitAbilityLevel(caster, FourCC('AImx'), 1)
    local curHp = GetUnitState(caster, UNIT_STATE_LIFE)
    SetUnitState(caster, UNIT_STATE_LIFE, curHp + shieldHp)
    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/DivineShield/DivineShieldTarget.mdl", caster, "origin"))
    local t = CreateTimer()
    TimerStart(t, duration, false, function()
        UnitRemoveAbility(caster, FourCC('Adev'))
        UnitRemoveAbility(caster, FourCC('AImx'))
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

    -- Накладываем стандартную иконку статуса "Теневой удар / Кровотечение" (Bshs)
    UnitAddAbility(target, FourCC('Ashs')) -- Shadow Strike debuff ability
    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Blood/BloodImpact.mdl", target, "origin"))
end

function Arena_InitBleedSystem()
    local t = CreateTimer()
    TimerStart(t, 1.0, true, function()
        for id, data in pairs(BleedStacks) do
            local target = data.target
            if target ~= nil and GetWidgetLife(target) > 0.405 and data.count > 0 and data.duration > 0 then
                data.duration = data.duration - 1.0
                -- Каждый стак отнимает 1 единицу здоровья в секунду
                local dmg = data.count * 1.0
                UnitDamageTarget(data.caster, target, dmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Blood/BloodImpact.mdl", target, "overhead"))
            else
                if target ~= nil then
                    UnitRemoveAbility(target, FourCC('Ashs'))
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
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/MonkThunderClap/MonkThunderClap.mdl", currentTarget, "origin"))

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
            local angle = math.atan2(uy - cy, ux - cx)
            local nx = ux + math.cos(angle) * dist
            local ny = uy + math.sin(angle) * dist
            SetUnitPosition(u, nx, ny)
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/WarStomp/WarStompCaster.mdl", nx, ny))
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
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Orc/Hex/HexTarget.mdl", u, "overhead"))
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
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Items/AIgold/AIgoldTarget.mdl", caster, "origin"))
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

function Arena_DoomChains(caster, radius, duration)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), radius, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, 120.0, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            PauseUnit(u, true)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/EntanglingRoots/EntanglingRootsTarget.mdl", u, "origin"))
            local victim = u
            local t = CreateTimer()
            TimerStart(t, duration, false, function()
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

        -- Storm Elementalist Supercharge Attacks (role == 3)
        if kind == 3 then
            local cid = GetHandleId(attacker)
            local st = StormSupercharge[cid]
            if st and st.active then
                local pInt = GetHeroInt(attacker, true)
                UnitDamageTarget(attacker, target, pInt * 1.2, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Monsoon/MonsoonBoltTarget.mdl", target, "origin"))

                local tid = GetHandleId(target)
                if not InductionStacks[tid] then InductionStacks[tid] = { count = 0, target = target, caster = attacker } end
                InductionStacks[tid].count = math.min(5, InductionStacks[tid].count + 2)
                InductionStacks[tid].duration = 6.0
            end
        end

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
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Resurrection/ResurrectionTarget.mdl", target, "origin"))
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
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/LightningShield/LightningShieldTarget.mdl", tx, ty))
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

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Other/Bombster/BombsterTarget.mdl", tx, ty))
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
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Other/Bombster/BombsterTarget.mdl", fc.x, fc.y))

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
                    UnitAddAbility(fu, FourCC('Aslow'))
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

    local eff = AddSpecialEffect("Abilities/Spells/Orc/StasisTrap/StasisTotem.mdl", tx, ty)
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

    UnitAddAbility(target, FourCC('ACrf'))
    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/NightElf/FaerieFire/FaerieFireTarget.mdl", target, "overhead"))
end

function Arena_Bombardier_E(caster, rank)
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Other/NeutralExplode/NeutralExplode.mdl", cx, cy))

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

        local jettisonEff = AddSpecialEffect("Abilities/Spells/Human/SiegeEngine/SiegeEngineTarget.mdl", bx, by)

        local jTimer = CreateTimer()
        TimerStart(jTimer, 1.0, false, function()
            DestroyEffect(jettisonEff)
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Other/NeutralExplode/NeutralExplode.mdl", bx, by))
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
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Other/Bombster/BombsterTarget.mdl", tx, ty))

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

function Arena_Ronin_Q(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local tx, ty = GetSpellTargetX(), GetSpellTargetY()

    local dx = tx - cx
    local dy = ty - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local angle = GetUnitFacing(caster) * (math.pi / 180.0)
    if dist > 10.0 then
        angle = math.atan2(dy, dx)
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
    GroupEnumUnitsInRange(g, (cx + endX) * 0.5, (cy + endY) * 0.5, 350.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, totalDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/HeroBladeMaster/BladeMasterTarget.mdl", u, "chest"))

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
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Heal/HealTarget.mdl", caster, "origin"))
        DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 3.0, "|cff00ff00[ПОТОК КЛИНКА]:|r Перезарядка сброшена (+3% HP)!")
    elseif hitBoss then
        local t = CreateTimer()
        TimerStart(t, 0.1, false, function()
            if BlzStartUnitAbilityCooldown then BlzStartUnitAbilityCooldown(caster, FourCC('A115'), 4.0) end
            DestroyTimer(t)
        end)
        DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 3.0, "|cffffcc00[ПОТОК КЛИНКА]:|r Кулдаун сокращен на 50%!")
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
    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/DivineShield/DivineShieldTarget.mdl", caster, "origin"))

    local t = CreateTimer()
    TimerStart(t, 1.2, false, function()
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
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", cx, cy))

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
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Thunderclap/ThunderclapTarget.mdl", u, "overhead"))
            local tu = u
            local stTimer = CreateTimer()
            TimerStart(stTimer, 1.2, false, function()
                if GetWidgetLife(tu) > 0.405 then PauseUnit(tu, false) end
                DestroyTimer(stTimer)
            end)
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)

    st.buffActive = true
    st.buffDuration = 4.0
    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Orc/Bloodlust/BloodlustTarget.mdl", caster, "origin"))
    DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 4.0, "|cff00ff00[КОНТРАТАКА]:|r Удар заблокирован! +50% скорости атаки и Клив активированы!")
end

function Arena_Ronin_E(caster, rank)
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/HeroBladeMaster/BladeMasterTarget.mdl", cx, cy))

    local burstDmg = 120.0 + 80.0 * rank
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 300.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, burstDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_HERO, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Blood/BloodImpact.mdl", u, "overhead"))
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
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Blood/BloodImpact.mdl", target, "chest"))
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
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/HeroBladeMaster/BladeMasterTarget.mdl", u, "origin"))
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
        angle = math.atan2(dy, dx)
    end

    local length = 900.0
    local endX = cx + math.cos(angle) * length
    local endY = cy + math.sin(angle) * length

    SetUnitInvulnerable(caster, true)
    PauseUnit(caster, true)

    DestroyEffect(AddSpecialEffect("Abilities/Spells/NightElf/Blink/BlinkCaster.mdl", cx, cy))

    local frozenUnits = {}
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, (cx + endX) * 0.5, (cy + endY) * 0.5, 450.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            PauseUnit(u, true)
            table.insert(frozenUnits, u)
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/FreezingBreath/FreezingBreathTarget.mdl", u, "origin"))
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

        if UnitResetCooldowns then UnitResetCooldowns(caster) elseif UnitResetCooldown then UnitResetCooldown(caster) end

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
                        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Blood/BloodImpact.mdl", targetUnit, "chest"))
                    else
                        local curHp = GetUnitState(targetUnit, UNIT_STATE_LIFE)
                        local maxHp = GetUnitState(targetUnit, UNIT_STATE_MAX_LIFE)
                        if (curHp / maxHp) < 0.20 then
                            SetWidgetLife(targetUnit, 0.0)
                            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Blood/BloodImpact.mdl", targetUnit, "origin"))
                        else
                            UnitDamageTarget(caster, targetUnit, baseDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/HeroBladeMaster/BladeMasterTarget.mdl", targetUnit, "chest"))
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
        angle = math.atan2(dy, dx)
    end

    local fistDist = 700.0
    local targetX = cx + math.cos(angle) * fistDist
    local targetY = cy + math.sin(angle) * fistDist

    DestroyEffect(AddSpecialEffect("Abilities/Weapons/RocketMissile/RocketMissile.mdl", targetX, targetY))
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/FlakCannons/FlakTarget.mdl", targetX, targetY))

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
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/WarStomp/WarStompCaster.mdl", bx, by))
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
            UnitAddAbility(u, FourCC('Aslow'))

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
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Blood/BloodImpact.mdl", u, "chest"))
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
                local angle = math.atan2(cy - uy, cx - ux)
                local nx = ux + math.cos(angle) * 35.0
                local ny = uy + math.sin(angle) * 35.0
                SetUnitPosition(pu, nx, ny)
            end
        end

        if pullTicks >= 15 then
            DestroyTimer(pTimer)

            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", cx, cy))
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/WarStomp/WarStompCaster.mdl", cx, cy))

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
    local tx, ty = GetSpellTargetX(), GetSpellTargetY()

    local dx = tx - cx
    local dy = ty - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local angle = GetUnitFacing(caster) * (math.pi / 180.0)
    if dist > 10.0 then
        angle = math.atan2(dy, dx)
    end

    local beamLen = 800.0
    local endX = cx + math.cos(angle) * beamLen
    local endY = cy + math.sin(angle) * beamLen

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/Resurrection/ResurrectionTarget.mdl", (cx + endX) * 0.5, (cy + endY) * 0.5))

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
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/Heal/HealTarget.mdl", u, "origin"))
            elseif IsUnitEnemy(u, GetOwningPlayer(caster)) then
                UnitDamageTarget(caster, u, baseAmount, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                UnitAddAbility(u, FourCC('Aslow'))
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
    if target == nil then target = caster end

    UnitRemoveAbility(target, FourCC('Ashs'))
    UnitRemoveAbility(target, FourCC('ACrf'))
    UnitRemoveAbility(target, FourCC('Aslow'))

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
    local eff = AddSpecialEffectTarget("Abilities/Spells/Human/DivineShield/DivineShieldTarget.mdl", target, "origin")

    local t = CreateTimer()
    TimerStart(t, 5.0, false, function()
        DestroyEffect(eff)
        SetUnitMoveSpeed(target, GetUnitDefaultMoveSpeed(target))
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
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/Resurrection/ResurrectionTarget.mdl", cx, cy))

    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 900.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitAlly(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            local curMp = GetUnitState(u, UNIT_STATE_MANA)
            local maxMp = GetUnitState(u, UNIT_STATE_MAX_MANA)
            SetUnitState(u, UNIT_STATE_MANA, math.min(maxMp, curMp + 50.0 + rank * 20.0))
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
                    UnitDamageTarget(caster, u, baseHeal * 0.75, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
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

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local facing = GetUnitFacing(caster) * (math.pi / 180.0)
    local spawnX = cx + math.cos(facing) * 150.0
    local spawnY = cy + math.sin(facing) * 150.0

    local p = GetOwningPlayer(caster)
    local treant = CreateUnit(p, FourCC('entc'), spawnX, spawnY, GetUnitFacing(caster)) -- Ironwood Treant
    if treant == nil then
        treant = CreateUnit(p, FourCC('eent'), spawnX, spawnY, GetUnitFacing(caster))
    end

    local maxHpCaster = GetUnitState(caster, UNIT_STATE_MAX_LIFE)
    local str = GetHeroStr(caster, true)

    local treantHp = 800.0 + 600.0 * (rank - 1) + maxHpCaster * 1.5
    if rank == 3 then treantHp = 2200.0 + maxHpCaster * 1.5 end
    if rank >= 4 then treantHp = 3200.0 + maxHpCaster * 1.5 end

    if BlzSetUnitMaxHP then BlzSetUnitMaxHP(treant, treantHp) end SetUnitState(treant, UNIT_STATE_MAX_LIFE, treantHp)
    SetUnitState(treant, UNIT_STATE_LIFE, treantHp)

    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/NightElf/EntanglingRoots/EntanglingRootsTarget.mdl", treant, "origin"))

    local cid = GetHandleId(caster)
    if not DruidSummons[cid] then DruidSummons[cid] = {} end
    table.insert(DruidSummons[cid], treant)

    local autoTimer = CreateTimer()
    TimerStart(autoTimer, 8.0, true, function()
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

            if udg_Boss ~= nil and u == udg_Boss then
                local bTimer = CreateTimer()
                local bTicks = 0
                TimerStart(bTimer, 2.0, true, function()
                    bTicks = bTicks + 1
                    if bTicks > 3 or GetWidgetLife(u) <= 0.405 then
                        DestroyTimer(bTimer)
                        return
                    end
                    local sapling = CreateUnit(p, FourCC('espv'), GetUnitX(u), GetUnitY(u), 0.0)
                    if sapling == nil then sapling = CreateUnit(p, FourCC('ewsp'), GetUnitX(u), GetUnitY(u), 0.0) end
                    UnitApplyTimedLife(sapling, FourCC('BTLF'), 12.0)
                    if not DruidSummons[cid] then DruidSummons[cid] = {} end
                    table.insert(DruidSummons[cid], sapling)
                end)
            else
                local tu = u
                local dTimer = CreateTimer()
                TimerStart(dTimer, 0.5, true, function()
                    if GetWidgetLife(tu) <= 0.405 then
                        DestroyTimer(dTimer)
                        local sapling = CreateUnit(p, FourCC('espv'), GetUnitX(tu), GetUnitY(tu), 0.0)
                        if sapling == nil then sapling = CreateUnit(p, FourCC('ewsp'), GetUnitX(tu), GetUnitY(tu), 0.0) end
                        UnitApplyTimedLife(sapling, FourCC('BTLF'), 12.0)
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

function Arena_Druid_E(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/NightElf/Tranquility/TranquilityTarget.mdl", cx, cy))

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
        DestroyEffect(AddSpecialEffect("Abilities/Spells/Other/NeutralExplode/NeutralExplode.mdl", bx, by))

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

        DestroyEffect(AddSpecialEffect("Abilities/Spells/Demon/Inferno/InfernoTarget.mdl", cx, cy))

        local p = GetOwningPlayer(caster)
        local colossus = CreateUnit(p, FourCC('etop'), cx, cy, GetUnitFacing(caster)) -- Deepwood Colossus / Ancient Protector
        if colossus == nil then colossus = CreateUnit(p, FourCC('eanc'), cx, cy, GetUnitFacing(caster)) end

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
            DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/WarStomp/WarStompCaster.mdl", bx, by))

            local sg = CreateGroup()
            GroupEnumUnitsInRange(sg, bx, by, 500.0, nil)
            local su = FirstOfGroup(sg)
            while su ~= nil do
                GroupRemoveUnit(sg, su)
                if IsUnitEnemy(su, p) and GetWidgetLife(su) > 0.405 then
                    UnitDamageTarget(colossus, su, 300.0 + str * 1.0, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                    UnitAddAbility(su, FourCC('Aslow'))
                end
                su = FirstOfGroup(sg)
            end
            DestroyGroup(sg)
        end)
    end
end

function Arena_Lich_ExplodeSkeleton(skel, caster, rank)
    if skel == nil or GetWidgetLife(skel) <= 0.405 then return end

    local sx, sy = GetUnitX(skel), GetUnitY(skel)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Undead/CorpseExplode/CorpseExplodeTarget.mdl", sx, sy))

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

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Undead/AnimateDead/AnimateDeadTarget.mdl", tx, ty))

    local pInt = GetHeroInt(caster, true)
    local qDmg = 120.0 + 80.0 * (rank - 1) + pInt * 0.9
    if rank == 3 then qDmg = 280.0 + pInt * 0.9 end
    if rank >= 4 then qDmg = 360.0 + pInt * 0.9 end

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

        if BlzSetUnitMaxHP then BlzSetUnitMaxHP(skel, skelHp) end SetUnitState(skel, UNIT_STATE_MAX_LIFE, skelHp)
        SetUnitState(skel, UNIT_STATE_LIFE, skelHp)

        UnitApplyTimedLife(skel, FourCC('BTLF'), 25.0)
        table.insert(LichSkeletons[cid], skel)
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/RaiseDead/RaiseDeadTarget.mdl", skel, "origin"))
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
    local rev = CreateUnit(p, FourCC('ukob'), spawnX, spawnY, GetUnitFacing(caster)) -- Frostbone Revenant / Golem
    if rev == nil then rev = CreateUnit(p, FourCC('ugol'), spawnX, spawnY, GetUnitFacing(caster)) end

    local pInt = GetHeroInt(caster, true)
    local revHp = 1200.0 + 1000.0 * (rank - 1) + pInt * 1.5
    if rank == 3 then revHp = 3500.0 + pInt * 1.5 end
    if rank >= 4 then revHp = 5000.0 + pInt * 1.5 end

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
        DestroyEffect(AddSpecialEffect("Abilities/Spells/Undead/FreezingBreath/FreezingBreathTarget.mdl", rx, ry))

        local g = CreateGroup()
        GroupEnumUnitsInRange(g, rx, ry, 350.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
                UnitDamageTarget(rev, u, 50.0 + pInt * 0.2, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_COLD, WEAPON_TYPE_WHOKNOWS)
                UnitAddAbility(u, FourCC('Aslow'))
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
                UnitAddAbility(u, FourCC('ACrf'))
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/FrostNova/FrostNovaTarget.mdl", u, "overhead"))

                local tu = u
                local stTimer = CreateTimer()
                TimerStart(stTimer, 1.5, false, function()
                    if GetWidgetLife(tu) > 0.405 then PauseUnit(tu, false) end
                    DestroyTimer(stTimer)
                end)
                break
            end
            tu = FirstOfGroup(g)
        end
        DestroyGroup(g)
    end)
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

        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/DarkRitual/DarkRitualCaster.mdl", caster, "origin"))
        DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 4.0, "|cff00ff00[ЧУМНАЯ ДЕТОНАЦИЯ]:|r Взорвано " .. explodedCount .. " скелетов! Восполнено MP и HP.")
    end
end

function Arena_Lich_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cid = GetHandleId(caster)
    if LichWyrm[cid] ~= nil and GetWidgetLife(LichWyrm[cid]) > 0.405 then
        SetWidgetLife(LichWyrm[cid], 0.0)
    end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Undead/FreezingBreath/FreezingBreathTarget.mdl", cx, cy))

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
        DestroyEffect(AddSpecialEffect("Abilities/Spells/Undead/FreezingBreath/FreezingBreathTarget.mdl", wx, wy))

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
                    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/FreezingBreath/FreezingBreathTarget.mdl", u, "origin"))
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
                    UnitRemoveAbility(target, FourCC('Ashs'))
                    UnitRemoveAbility(target, FourCC('ACrf'))
                    UnitRemoveAbility(target, FourCC('Aslow'))
                    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/MassTeleport/MassTeleportTarget.mdl", target, "origin"))
                    DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 4.0, "|cff00ff00[ОТКАТ ВРЕМЕНИ]:|r Союзник спасен и возвращен!")
                end
            end
            DestroyTimer(pTimer)
        end)
    else
        local tx = GetSpellTargetX()
        local ty = GetSpellTargetY()
        if tx == 0.0 and ty == 0.0 then
            tx = GetUnitX(caster)
            ty = GetUnitY(caster)
        end

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

function Arena_Chrono_W(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local tx = GetSpellTargetX()
    local ty = GetSpellTargetY()
    if tx == 0.0 and ty == 0.0 then
        tx = GetUnitX(caster)
        ty = GetUnitY(caster)
    end

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Other/SpellShieldAura/SpellShieldAura.mdl", tx, ty))

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
                UnitResetCooldowns(u)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Orc/Bloodlust/BloodlustTarget.mdl", u, "origin"))
                local tu = u
                local origSpd = GetUnitDefaultMoveSpeed(tu)
                local wTimer = CreateTimer()
                TimerStart(wTimer, 5.0, false, function()
                    if GetWidgetLife(tu) > 0.405 then SetUnitMoveSpeed(tu, origSpd) end
                    DestroyTimer(wTimer)
                end)
            elseif IsUnitEnemy(u, p) then
                UnitAddAbility(u, FourCC('Aslow'))
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
    local tx, ty = GetSpellTargetX(), GetSpellTargetY()
    local dx = tx - cx
    local dy = ty - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local angle = GetUnitFacing(caster) * (math.pi / 180.0)
    if dist > 10.0 then
        angle = math.atan2(dy, dx)
    end

    local blinkDist = 500.0
    local endX = cx + math.cos(angle) * blinkDist
    local endY = cy + math.sin(angle) * blinkDist

    DestroyEffect(AddSpecialEffect("Abilities/Spells/NightElf/Blink/BlinkCaster.mdl", cx, cy))

    local echo = CreateUnit(GetOwningPlayer(caster), FourCC('ulic'), cx, cy, GetUnitFacing(caster))
    if echo == nil then echo = CreateUnit(GetOwningPlayer(caster), FourCC('ebon'), cx, cy, GetUnitFacing(caster)) end

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
    local p = GetOwningPlayer(caster)

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Other/Tornado/TornadoElemental.mdl", cx, cy))

    local domeDur = 5.0 + 1.0 * (rank - 1)
    local bonusDmgPct = 0.30 + 0.15 * (rank - 1)

    local frozenEnemies = {}
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, cx, cy, 600.0, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if GetWidgetLife(u) > 0.405 then
            if IsUnitEnemy(u, p) then
                PauseUnit(u, true)
                table.insert(frozenEnemies, u)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Undead/FreezingBreath/FreezingBreathTarget.mdl", u, "origin"))
            elseif IsUnitAlly(u, p) then
                SetUnitMoveSpeed(u, 522.0)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Orc/Bloodlust/BloodlustTarget.mdl", u, "origin"))
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)

    local domeTimer = CreateTimer()
    TimerStart(domeTimer, domeDur, false, function()
        DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", cx, cy))
        local pInt = GetHeroInt(caster, true)
        local burstDmg = 400.0 + pInt * 1.5

        for _, eu in ipairs(frozenEnemies) do
            if GetWidgetLife(eu) > 0.405 then
                PauseUnit(eu, false)
                UnitDamageTarget(caster, eu, burstDmg * (1.0 + bonusDmgPct), false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/HolyBolt/HolyBoltSpecialArt.mdl", eu, "chest"))
            end
        end

        for pid = 0, 3 do
            if Heroes[pid] and GetWidgetLife(Heroes[pid]) > 0.405 then
                SetUnitMoveSpeed(Heroes[pid], GetUnitDefaultMoveSpeed(Heroes[pid]))
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

    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/LightningShield/LightningShieldTarget.mdl", target, "origin"))

    if data.count >= 5 then
        Arena_Storm_ShortCircuit(target, caster)
    end
end

function Arena_Storm_ShortCircuit(target, caster)
    if target == nil or GetWidgetLife(target) <= 0.405 then return end
    local tid = GetHandleId(target)
    InductionStacks[tid] = nil

    local pInt = GetHeroInt(caster, true)
    local tx, ty = GetUnitX(target), GetUnitY(target)
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/ThunderClap/ThunderClapCaster.mdl", tx, ty))

    if udg_Boss ~= nil and target == udg_Boss then
        local bossCurHp = GetUnitState(target, UNIT_STATE_LIFE)
        local baseDmg = 800.0 + pInt * 2.5 + (bossCurHp * 0.10)
        UnitDamageTarget(caster, target, baseDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
        PauseUnit(target, true)
        UnitAddAbility(target, FourCC('ACrf'))
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/NightElf/FaerieFire/FaerieFireTarget.mdl", target, "overhead"))

        local tu = target
        local stTimer = CreateTimer()
        TimerStart(stTimer, 2.0, false, function()
            if GetWidgetLife(tu) > 0.405 then PauseUnit(tu, false) end
            DestroyTimer(stTimer)
        end)
        DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 4.0, "|cff00ff00[КОРОТКОЕ ЗАМЫКАНИЕ]:|r Босс оглушен и его маг. резист снижен на 40%!")
    else
        SetWidgetLife(target, 0.0)
        DestroyEffect(AddSpecialEffect("Abilities/Spells/Other/NeutralExplode/NeutralExplode.mdl", tx, ty))

        local g = CreateGroup()
        GroupEnumUnitsInRange(g, tx, ty, 300.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
                UnitDamageTarget(caster, u, 300.0 + pInt * 1.0, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Monsoon/MonsoonBoltTarget.mdl", u, "origin"))
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
    end
end

function Arena_Storm_Q(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local target = GetSpellTargetUnit()
    local cx, cy = GetUnitX(caster), GetUnitY(caster)

    local pInt = GetHeroInt(caster, true)
    local baseDmg = 150.0 + 100.0 * (rank - 1) + pInt * 1.0
    if rank == 3 then baseDmg = 360.0 + pInt * 1.0 end
    if rank >= 4 then baseDmg = 480.0 + pInt * 1.0 end

    local maxJumps = 5 + (rank - 1) * 2 -- 5, 7, 9, 12
    if rank >= 4 then maxJumps = 12 end

    local currentUnit = target
    if currentUnit == nil then
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, cx, cy, 600.0, nil)
        currentUnit = FirstOfGroup(g)
        DestroyGroup(g)
    end

    if currentUnit == nil or not IsUnitEnemy(currentUnit, GetOwningPlayer(caster)) then return end

    local hitUnits = {}
    local currentDmg = baseDmg

    for jump = 1, maxJumps do
        if currentUnit == nil or GetWidgetLife(currentUnit) <= 0.405 then break end

        local tid = GetHandleId(currentUnit)
        hitUnits[tid] = true

        if InductionStacks[tid] then
            currentDmg = currentDmg * 1.08
        end

        UnitDamageTarget(caster, currentUnit, currentDmg, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Monsoon/MonsoonBoltTarget.mdl", currentUnit, "origin"))
        Arena_ApplyInductionStack(currentUnit, caster, 1)

        local ux, uy = GetUnitX(currentUnit), GetUnitY(currentUnit)
        local nextUnit = nil
        local ng = CreateGroup()
        GroupEnumUnitsInRange(ng, ux, uy, 400.0, nil)
        local nu = FirstOfGroup(ng)
        while nu ~= nil do
            GroupRemoveUnit(ng, nu)
            local ntid = GetHandleId(nu)
            if not hitUnits[ntid] and IsUnitEnemy(nu, GetOwningPlayer(caster)) and GetWidgetLife(nu) > 0.405 then
                nextUnit = nu
                break
            end
            nu = FirstOfGroup(ng)
        end
        DestroyGroup(ng)

        currentUnit = nextUnit
    end
end

function Arena_Storm_W(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local tx = GetSpellTargetX()
    local ty = GetSpellTargetY()
    if tx == 0.0 and ty == 0.0 then
        tx = GetUnitX(caster)
        ty = GetUnitY(caster)
    end

    DestroyEffect(AddSpecialEffect("Abilities/Spells/Human/LightningShield/LightningShieldTarget.mdl", tx, ty))

    local pInt = GetHeroInt(caster, true)
    local p = GetOwningPlayer(caster)

    local wTicks = 0
    local wTimer = CreateTimer()
    TimerStart(wTimer, 0.5, true, function()
        wTicks = wTicks + 1
        if wTicks > 12 or GetWidgetLife(caster) <= 0.405 then
            DestroyTimer(wTimer)
            return
        end

        local g = CreateGroup()
        GroupEnumUnitsInRange(g, tx, ty, 450.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if IsUnitEnemy(u, p) and GetWidgetLife(u) > 0.405 then
                UnitDamageTarget(caster, u, 30.0 + pInt * 0.2, false, false, ATTACK_TYPE_HERO, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)

                if wTicks % 2 == 0 then
                    Arena_ApplyInductionStack(u, caster, 1)
                end

                if wTicks % 3 == 0 then
                    UnitAddAbility(u, FourCC('Aslow'))
                    local ux, uy = GetUnitX(u), GetUnitY(u)
                    local angle = math.atan2(ty - uy, tx - ux)
                    SetUnitPosition(u, ux + math.cos(angle) * 20.0, uy + math.sin(angle) * 20.0)
                end
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
    end)
end

function Arena_Storm_E(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cid = GetHandleId(caster)
    StormSupercharge[cid] = {
        active = true,
        duration = 5.0,
        caster = caster
    }

    local maxMp = GetUnitState(caster, UNIT_STATE_MAX_MANA)
    local curMp = GetUnitState(caster, UNIT_STATE_MANA)
    SetUnitState(caster, UNIT_STATE_MANA, math.min(maxMp, curMp + maxMp * 0.25))

    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/BlueDragonRoar/BlueDragonRoar.mdl", caster, "origin"))
    DisplayTimedTextToPlayer(GetOwningPlayer(caster), 0, 0, 4.0, "|cff00ff00[СВЕРХПРОВОДИМОСТЬ]:|r Перегрузка ядра на 5 секунд!")

    local eTimer = CreateTimer()
    TimerStart(eTimer, 5.0, false, function()
        if StormSupercharge[cid] then
            StormSupercharge[cid].active = false
        end
        DestroyTimer(eTimer)
    end)
end

function Arena_Storm_R(caster, rank)
    if caster == nil or GetWidgetLife(caster) <= 0.405 then return end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local pInt = GetHeroInt(caster, true)

    local shieldHp = 1000.0 + 1000.0 * (rank - 1)
    local curHp = GetUnitState(caster, UNIT_STATE_LIFE)
    SetUnitState(caster, UNIT_STATE_LIFE, curHp + shieldHp)
    DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Human/LightningShield/LightningShieldTarget.mdl", caster, "origin"))

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
                        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Net/NetTarget.mdl", u, "origin"))

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
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Other/Blood/BloodImpact.mdl", target, "origin"))
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

        for cid, st in pairs(RoninParryState) do
            if st.buffActive then
                st.buffDuration = st.buffDuration - 0.5
                if st.buffDuration <= 0 then
                    st.buffActive = false
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
            DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Orc/Voodoo/VoodooTarget.mdl", u, "origin"))
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
    DestroyEffect(AddSpecialEffect("Abilities/Spells/Orc/Blink/BlinkTarget.mdl", nx, ny))
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
                DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Items/ClarifyPotion/ClarifyPotionTarget.mdl", u, "origin"))
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
        DestroyEffect(AddSpecialEffectTarget("Abilities/Spells/Items/ClarifyPotion/ClarifyPotionTarget.mdl", caster, "origin"))
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
