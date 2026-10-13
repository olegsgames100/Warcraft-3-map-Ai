-- ===========================================================================
-- Map Script: Warcraft III (Lua Mode)
-- ===========================================================================

function InitGlobals()
    -- Глобальные переменные
    Heroes = {}
    HeroKind = {}
    
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
        -- 3. Элементалист Бури (Интеллект / Маг)
        { id = FourCC('Hamg'), name = "Элементалист Бури (Интеллект / Маг)", role = "mage",     spells = {FourCC('A105'), FourCC('A106'), FourCC('A10H'), FourCC('A10I')} },
        -- 4. Хозяин Стаи (Сила / Саммонер)
        { id = FourCC('Udea'), name = "Хозяин Стаи (Сила / Саммонер)",   role = "summoner", spells = {FourCC('A107'), FourCC('A108'), FourCC('A10J'), FourCC('A10K')} },
        -- 5. Токсиколог (Интеллект / ДоТ & Контроль)
        { id = FourCC('Edem'), name = "Токсиколог (Интеллект / ДоТ)",    role = "dot_control", spells = {FourCC('A109'), FourCC('A10A'), FourCC('A10L'), FourCC('A10M')} },
        -- 6. Мастер Клинка / Ронин (Ловкость / Керри Ближнего Боя)
        { id = FourCC('Hmkg'), name = "Мастер Клинка-Ронин (Ловкость / Керри)", role = "carry", spells = {FourCC('A115'), FourCC('A116'), FourCC('A117'), FourCC('A118')} },
        -- 7. Жрица Солнца (Интеллект / Саппорт-Хилер)
        { id = FourCC('Emoo'), name = "Жрица Солнца (Интеллект / Хилер)", role = "healer",   spells = {FourCC('A10B'), FourCC('A10C'), FourCC('A10N'), FourCC('A10O')} },
        -- 8. Инженер-Бомбардир (Ловкость / Осада и Зонинг)
        { id = FourCC('Nalc'), name = "Инженер-Бомбардир (Ловкость / Осада)", role = "siege",  spells = {FourCC('A111'), FourCC('A112'), FourCC('A113'), FourCC('A114')} },
        -- 9. Каменный Исполин (Сила / Инициатор)
        { id = FourCC('Ewar'), name = "Каменный Исполин (Сила / Инициатор)", role = "initiator", spells = {FourCC('A119'), FourCC('A11A'), FourCC('A11B'), FourCC('A11C')} },
        -- 10. Хрономант (Интеллект / Тактический Контроль)
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
    -- Диспетчер способностей с балансировкой ролей
    if not Heroes[pid] or Heroes[pid] ~= caster then return end

    local role = HeroKind[pid]
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

    -- 4. Хозяин Стаи (Сила / Призыватель)
    elseif role == 4 then
        if spellId == FourCC('A107') then -- Q: Призыв Волков-Фантомов
            Arena_CustomSummon(caster, FourCC('nska'), 2, 25.0)
        elseif spellId == FourCC('A108') then -- W: Охотничий Клич (Усиление отряда)
            Arena_ItemPulses(caster, amount * 1.2, 0)
        elseif spellId == FourCC('A10J') then -- E: Дух Вожака (Аура восстановления HP)
            Arena_ItemPulses(caster, amount * 1.8, 0)
        elseif spellId == FourCC('A10K') then -- R: Гнев Природы (Форма Древнего Медведя + сплеш)
            SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + amount * 4.0)
            Arena_CustomArea(caster, 450.0, amount * 3.0, false)
        end

    -- 6. Мастер Клинка / Ронин (Ловкость / Керри Ближнего Боя)
    elseif role == 6 then
        if spellId == FourCC('A115') then -- Q: Рассекающий Выпад (Рывок вперед)
            Arena_CustomMove(caster, 300.0 + 30.0 * rank)
            Arena_CustomArea(caster, 250.0, amount * 1.5, false)
        elseif spellId == FourCC('A116') then -- W: Парирование (Контратака / Щит)
            Arena_DivineShield(caster, 1.5)
            Arena_CustomFinisher(caster, amount * 2.0)
        elseif spellId == FourCC('A117') then -- E: Заточка Клинка (Пробивание брони)
            Arena_ArmorSunder(caster, 300.0, 8.0)
            Arena_CustomFinisher(caster, amount * 2.5)
        elseif spellId == FourCC('A118') then -- R: Абсолютный Разрез (Разрубание пространства)
            Arena_CustomArea(caster, 650.0, amount * 6.0, false)
        end

    -- 9. Каменный Исполин (Сила / Инициатор и Контроль)
    elseif role == 9 then
        if spellId == FourCC('A119') then -- Q: Бросок Валуна (Оглушающий валун)
            Arena_CustomFinisher(caster, amount * 2.5)
        elseif spellId == FourCC('A11A') then -- W: Дрожь Земли (Замедление в области)
            Arena_CustomArea(caster, 450.0, amount * 1.8, false)
        elseif spellId == FourCC('A11B') then -- E: Гранитная Кожа (Блок урона и самоисцеление)
            SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + amount * 3.0)
        elseif spellId == FourCC('A11C') then -- R: Тектонический Разлом (Врезание + каменный барьер)
            Arena_EarthquakeWall(caster, 500.0)
        end

    -- 2. Призрачный Ловчий / Ассасин (Ловкость / Одиночный урон)
    elseif role == 2 then
        if spellId == FourCC('A103') then -- Q: Теневой Бросок (Бросок кинжала + телепорт)
            Arena_CustomFinisher(caster, amount * 2.2)
            Arena_CustomMove(caster, 250.0)
        elseif spellId == FourCC('A104') then -- W: Слияние с Тенью (Невидимость / Неуязвимость)
            Arena_DivineShield(caster, 2.0 + rank * 0.5)
        elseif spellId == FourCC('A10F') then -- E: Анатомический Удар (Критический урон)
            Arena_CustomFinisher(caster, amount * 3.5)
        elseif spellId == FourCC('A10G') then -- R: Танец Лезвий (Омнислаш 5 ударов)
            Arena_Omnislash(caster, 5, amount * 1.8)
        end

    -- 3. Элементалист Бури (Интеллект / Магический прокастер)
    elseif role == 3 then
        if spellId == FourCC('A105') then -- Q: Цепной Разряд (Молния + накапливание и перескок 4/5/6/7/8 зарядов)
            Arena_CustomArea(caster, 550.0, amount * 1.8, false)
            Arena_ApplyStaticCharges(caster, rank, 550.0, amount * 0.6)
        elseif spellId == FourCC('A106') then -- W: Статическое Поле (Электрическая зона + перескоки)
            Arena_CustomArea(caster, 450.0, amount * 1.4, false)
            Arena_ApplyStaticCharges(caster, rank, 450.0, amount * 0.5)
        elseif spellId == FourCC('A10H') then -- E: Перегрузка (Восполнение маны + перескок статитики)
            Arena_ItemPulses(caster, 0, amount * 1.5)
            Arena_ApplyStaticCharges(caster, rank, 500.0, amount * 0.4)
        elseif spellId == FourCC('A10I') then -- R: Око Бури (Грозовой фронт + массовые перескоки зарядов)
            for i = 0, 4 do
                Arena_CustomArea(caster, 650.0, amount * 0.8, false)
            end
            Arena_ApplyStaticCharges(caster, rank, 650.0, amount * 0.8)
        end

    -- 5. Токсиколог / Чумной Доктор (Интеллект / Контроль и ДоТ)
    elseif role == 5 then
        if spellId == FourCC('A109') then -- Q: Склянка с Ядом (Ядовитый газ)
            Arena_PoisonGas(caster, 400.0, amount * 1.5, 5.0)
        elseif spellId == FourCC('A10A') then -- W: Едкая Инъекция (-броня)
            Arena_ArmorSunder(caster, 350.0, 6.0)
            Arena_CustomFinisher(caster, amount * 2.0)
        elseif spellId == FourCC('A10L') then -- E: Эпидемия (Заражение окружающих)
            Arena_PoisonGas(caster, 450.0, amount * 1.2, 6.0)
        elseif spellId == FourCC('A10M') then -- R: Биологический Коллапс (Мгновенный взрыв ядов)
            Arena_CustomArea(caster, 600.0, amount * 5.0, false)
        end

    -- 7. Жрица Солнца (Интеллект / Саппорт-Хилер)
    elseif role == 7 then
        if spellId == FourCC('A10B') then -- Q: Благодать Света (Лечение/урон)
            Arena_CustomArea(caster, 400.0, amount * 1.8, true)
        elseif spellId == FourCC('A10C') then -- W: Очищающее Сияние (Снятие негатива + ускорение)
            Arena_ItemPulses(caster, amount * 1.5, amount * 1.0)
        elseif spellId == FourCC('A10N') then -- E: Солнечная Аура (Регенерация маны/броня)
            Arena_ItemPulses(caster, amount * 1.0, amount * 2.0)
        elseif spellId == FourCC('A10O') then -- R: Восход (Солнечный свет + ослепление + хил)
            Arena_CustomArea(caster, 800.0, amount * 3.5, true)
        end

    -- 8. Инженер-Бомбардир (Ловкость / Осада и Зонинг)
    elseif role == 8 then
        if spellId == FourCC('A111') then -- Q: Кластерная Граната
            Arena_ClusterGrenade(caster, GetUnitX(caster) + 200.0, GetUnitY(caster), amount * 2.0)
        elseif spellId == FourCC('A112') then -- W: Капкан с Проводами (Обездвиживание)
            Arena_HexTarget(caster, 350.0)
        elseif spellId == FourCC('A113') then -- E: Разрывные Пули (Сплеш урон)
            Arena_CustomArea(caster, 300.0, amount * 1.8, false)
        elseif spellId == FourCC('A114') then -- R: Развертывание Мортиры (Осадный обстрел)
            Arena_CustomArea(caster, 750.0, amount * 5.0, false)
        end

    -- 10. Хрономант / Повелитель Времени (Интеллект / Тактический контроль)
    elseif role == 10 then
        if spellId == FourCC('A11D') then -- Q: Петля Времени (Возврат положения/HP)
            Arena_TimeLoop(caster, 4.0)
        elseif spellId == FourCC('A11E') then -- W: Ускорение / Замедление
            Arena_CustomArea(caster, 450.0, amount * 1.5, false)
        elseif spellId == FourCC('A11F') then -- E: Предвидение (Щит от уклонения)
            Arena_DivineShield(caster, 2.0)
        elseif spellId == FourCC('A11G') then -- R: Хроносфера (Временной купол полного замирания)
            Arena_Chronosphere(caster, 600.0, 4.0)
        end
    end
end

function InitCustomTriggers()
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

        -- Показываем диалог игрокам
        for pid = 0, 3 do
            local p = Player(pid)
            -- Проверяем: если игрок управляется человеком
            if GetPlayerController(p) == MAP_CONTROL_USER then
                DialogDisplay(p, HeroDialog, true)
            end
        end
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

    SetDayNightModels("Environment\\DNC\\DNCLordaeron\\DNCLordaeronTerrain\\DNCLordaeronTerrain.mdl", 
                       "Environment\\DNC\\DNCLordaeron\\DNCLordaeronUnit\\DNCLordaeronUnit.mdl")
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
        return "Units\\Creeps\\Bandit\\BanditPissed1.wav"
    elseif wave <= 20 then
        return "Units\\Creeps\\Ogre\\OgrePissed1.wav"
    elseif wave <= 30 then
        return "Units\\Undead\\Necromancer\\NecromancerPissed1.wav"
    elseif wave <= 40 then
        return "Units\\Demon\\FelGuard\\FelGuardPissed1.wav"
    end
    return "Units\\Undead\\Abomination\\AbominationPissed1.wav"
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
    udg_HumanCount = Arena_CountHumans()
    local pickedCount = Arena_CountPickedHumans()
    if pickedCount < udg_HumanCount or pickedCount == 0 then
        return
    end
    udg_WavesStarted = true
    TimerStart(udg_WaveTimer, 15.00, false, Trig_Wave_Actions)
    TimerDialogSetTitle(udg_WaveTD, "Волна 1")
    TimerDialogDisplay(udg_WaveTD, true)
    Arena_Msg("Все герои выбраны. Первая волна через 15 сек. Магазины по углам центра.")
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
    local fx = AddSpecialEffect("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", GetUnitX(udg_Boss), GetUnitY(udg_Boss))
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
            Arena_Msg("|cffffcc66Побеждён мини-босс! Команде начислена награда.|r")
            Arena_PayWaveGold(50 + udg_Wave * 3)
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
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\DarkRitual\\DarkRitualCaster.mdl", cx, cy))
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
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl", caster, "origin"))
end

function Arena_ShieldOfTorment(caster, shieldHp, armorBonus, duration)
    -- Временное увеличение макс. HP (для эффекта сильного щита) и брони
    UnitAddAbility(caster, FourCC('Adev')) -- Devotion Aura / Броня
    SetUnitAbilityLevel(caster, FourCC('Adev'), math.min(10, math.max(1, math.floor(armorBonus / 5))))
    UnitAddAbility(caster, FourCC('AImx')) -- Item Life Bonus / Запас HP
    SetUnitAbilityLevel(caster, FourCC('AImx'), 1)
    local curHp = GetUnitState(caster, UNIT_STATE_LIFE)
    SetUnitState(caster, UNIT_STATE_LIFE, curHp + shieldHp)
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\DivineShield\\DivineShieldTarget.mdl", caster, "origin"))
    local t = CreateTimer()
    TimerStart(t, duration, false, function()
        UnitRemoveAbility(caster, FourCC('Adev'))
        UnitRemoveAbility(caster, FourCC('AImx'))
        DestroyTimer(t)
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
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\MonkThunderClap\\MonkThunderClap.mdl", currentTarget, "origin"))

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
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\HowlOfTerror\\HowlTarget.mdl", u, "overhead"))
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
            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\WarStomp\\WarStompCaster.mdl", nx, ny))
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
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\FaerieFire\\FaerieFireTarget.mdl", u, "overhead"))
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
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\ManaBurn\\ManaBurnTarget.mdl", u, "origin"))
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
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Orc\\Hex\\HexTarget.mdl", u, "overhead"))
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
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIgold\\AIgoldTarget.mdl", caster, "origin"))
            break
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_DivineShield(caster, duration)
    SetUnitInvulnerable(caster, true)
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\DivineShield\\DivineShieldTarget.mdl", caster, "origin"))
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
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\EntanglingRoots\\EntanglingRootsTarget.mdl", u, "origin"))
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

function Arena_PoisonGas(caster, radius, damage, duration)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), radius, nil)
    local u = FirstOfGroup(g)
    while u ~= nil do
        GroupRemoveUnit(g, u)
        if IsUnitEnemy(u, GetOwningPlayer(caster)) and GetWidgetLife(u) > 0.405 then
            UnitDamageTarget(caster, u, damage, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_POISON, WEAPON_TYPE_WHOKNOWS)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\PlagueCloud\\PlagueCloudCaster.mdl", u, "head"))
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_ClusterGrenade(caster, x, y, damage)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Bombster\\BombsterTarget.mdl", x, y))
    local i = 0
    while i < 3 do
        local rx = x + GetRandomReal(-120.0, 120.0)
        local ry = y + GetRandomReal(-120.0, 120.0)
        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Bombster\\BombsterTarget.mdl", rx, ry))
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, rx, ry, 200.0, nil)
        local u = FirstOfGroup(g)
        while u ~= nil do
            GroupRemoveUnit(g, u)
            if GetWidgetLife(u) > 0.405 and IsUnitEnemy(u, GetOwningPlayer(caster)) then
                UnitDamageTarget(caster, u, damage * 0.5, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", u, "origin"))
            end
            u = FirstOfGroup(g)
        end
        DestroyGroup(g)
        i = i + 1
    end
end

function Arena_TimeLoop(target, duration)
    if target == nil or GetWidgetLife(target) <= 0.405 then return end
    local x, y = GetUnitX(target), GetUnitY(target)
    local hp = GetUnitState(target, UNIT_STATE_LIFE)
    local mp = GetUnitState(target, UNIT_STATE_MANA)
    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIam\\AIamTarget.mdl", target, "origin"))
    local t = CreateTimer()
    TimerStart(t, duration, false, function()
        if GetWidgetLife(target) > 0.405 then
            SetUnitPosition(target, x, y)
            SetUnitState(target, UNIT_STATE_LIFE, hp)
            SetUnitState(target, UNIT_STATE_MANA, mp)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTarget.mdl", target, "origin"))
        end
        DestroyTimer(t)
    end)
end

function Arena_Chronosphere(caster, radius, duration)
    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Tornado\\TornadoElemental.mdl", cx, cy))
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
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Demon\\DemonBoltImpact\\DemonBoltImpact.mdl", GetUnitX(caster), GetUnitY(caster)))
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
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Orc\\Voodoo\\VoodooTarget.mdl", u, "origin"))
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
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl", target, "chest"))
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
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\HealingSalve\\HealingSalveTarget.mdl", u, "origin"))
            end
            if manaAmount > 0 then
                SetUnitState(u, UNIT_STATE_MANA, GetUnitState(u, UNIT_STATE_MANA) + manaAmount)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\ClarifyPotion\\ClarifyPotionTarget.mdl", u, "origin"))
            end
        end
        u = FirstOfGroup(g)
    end
    DestroyGroup(g)
end

function Arena_SpellAid(caster, hpAmount, manaAmount)
    if hpAmount > 0 then
        SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + hpAmount)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\HealingSalve\\HealingSalveTarget.mdl", caster, "origin"))
    end
    if manaAmount > 0 then
        SetUnitState(caster, UNIT_STATE_MANA, GetUnitState(caster, UNIT_STATE_MANA) + manaAmount)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\ClarifyPotion\\ClarifyPotionTarget.mdl", caster, "origin"))
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
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl", u, "origin"))
        i = i + 1
    end
end
