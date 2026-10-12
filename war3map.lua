-- ===========================================================================
-- Map Script: Warcraft III (Lua Mode) - ARENA SMERTI
-- ===========================================================================

function InitGlobals()
    Heroes = {}
    HeroKind = {}
    
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
    udg_ReviveTimer = {}
    udg_PlayerKills = {0, 0, 0, 0}

    HeroClasses = {
        { id = FourCC('Hpal'), name = "Паладин-защитник",   spells = {FourCC('A101'), FourCC('A102'), FourCC('A10D'), FourCC('A10E')} },
        { id = FourCC('Obla'), name = "Мастер клинка",      spells = {FourCC('A103'), FourCC('A104'), FourCC('A10F'), FourCC('A10G')} },
        { id = FourCC('Hamg'), name = "Боевой архимаг",     spells = {FourCC('A105'), FourCC('A106'), FourCC('A10H'), FourCC('A10I')} },
        { id = FourCC('Udea'), name = "Рыцарь смерти",      spells = {FourCC('A107'), FourCC('A108'), FourCC('A10J'), FourCC('A10K')} },
        { id = FourCC('Edem'), name = "Охотник на демонов", spells = {FourCC('A109'), FourCC('A10A'), FourCC('A10L'), FourCC('A10M')} },
        { id = FourCC('Emoo'), name = "Лунная жрица",       spells = {FourCC('A10B'), FourCC('A10C'), FourCC('A10N'), FourCC('A10O')} },
        { id = FourCC('Nalc'), name = "Алхимик-боевик",     spells = {FourCC('A111'), FourCC('A112'), FourCC('A113'), FourCC('A114')} },
        { id = FourCC('Hmkg'), name = "Горный король",      spells = {FourCC('A115'), FourCC('A116'), FourCC('A117'), FourCC('A118')} },
        { id = FourCC('Ewar'), name = "Сумрачная охотница", spells = {FourCC('A119'), FourCC('A11A'), FourCC('A11B'), FourCC('A11C')} },
        { id = FourCC('Ulic'), name = "Ледяной лич",        spells = {FourCC('A11D'), FourCC('A11E'), FourCC('A11F'), FourCC('A11G')} }
    }
    
    HeroDialog = nil
    HeroDialogButtons = {}
end

function SpawnSelectedHero(pid, roleId)
    local p = Player(pid)
    local classData = HeroClasses[roleId]
    if classData == nil then return end
    
    local hero = CreateUnit(p, classData.id, 0.0, 0.0, 270.0)
    Heroes[pid] = hero
    HeroKind[pid] = roleId
    
    for _, spellId in ipairs(classData.spells) do
        UnitAddAbility(hero, spellId)
    end
    
    SelectUnitForPlayerSingle(hero, p)
    PanCameraToTimedForPlayer(p, 0.0, 0.0, 0.0)
    DisplayTextToPlayer(p, 0, 0, "|cff88ff88Выбран класс:|r " .. classData.name)
    DisplayTextToPlayer(p, 0, 0, "|cffffcc00Задание:|r Защитите арену от 50 волн врагов!")

    local myQuest = CreateQuest()
    QuestSetTitle(myQuest, "Арена Смерти")
    QuestSetDescription(myQuest, "Уничтожьте 50 волн и победите финального босса.")
    QuestSetRequired(myQuest, true)
    QuestSetDiscovered(myQuest, true)
    FlashQuestDialogButton()

    -- СРАЗУ запускаем таймер волн без ожидания других игроков!
    Arena_TryStartWaves()
end

function Arena_TryStartWaves()
    if udg_WavesStarted then return end
    udg_WavesStarted = true

    print("|cff00ff00[Арена]: Герой выбран! Запуск волны 1...|r")

    if udg_WaveTimer == nil then
        udg_WaveTimer = CreateTimer()
    end
    if udg_WaveTD == nil then
        udg_WaveTD = CreateTimerDialog(udg_WaveTimer)
    end

    TimerStart(udg_WaveTimer, 15.00, false, function()
        Trig_Wave_Actions()
    end)
    TimerDialogSetTitle(udg_WaveTD, "Волна 1")
    TimerDialogDisplay(udg_WaveTD, true)
    Arena_Msg("|cffffcc00Первая волна начнется через 15 секунд! Подготовьтесь.|r")
end

function Arena_CustomCast_Lua(caster, pid, spellId)
    if not Heroes[pid] or Heroes[pid] ~= caster then return end
    local role = HeroKind[pid]
    if not role then return end
    local rank = GetUnitAbilityLevel(caster, spellId)
    if rank < 1 then return end
    local amount = 32.0 + 21.0 * rank

    if role == 1 then
        if spellId == FourCC('A101') then Arena_CustomFinisher(caster, amount * 2.5)
        elseif spellId == FourCC('A102') then Arena_CustomArea(caster, 600.0, amount * 2.1, true)
        elseif spellId == FourCC('A10D') then
            SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + amount * 2.4)
            Arena_CustomArea(caster, 240.0, amount * 0.4, false)
        elseif spellId == FourCC('A10E') then
            for i = 0, 3 do
                if Heroes[i] ~= nil and GetWidgetLife(Heroes[i]) <= 0.405 and IsUnitAlly(Heroes[i], GetOwningPlayer(caster)) then
                    ReviveHero(Heroes[i], GetUnitX(caster), GetUnitY(caster), true)
                end
            end
            Arena_CustomArea(caster, 900.0, amount * 3.1, true)
        end
    elseif role == 2 then
        if spellId == FourCC('A103') then
            Arena_CustomMove(caster, 200.0 + 30.0 * rank)
            Arena_CustomArea(caster, 310.0, amount * 1.3, false)
        elseif spellId == FourCC('A104') then
            for i = 0, 3 do Arena_CustomArea(caster, 260.0 + i * 65.0, amount * 0.50, false) end
        elseif spellId == FourCC('A10F') then Arena_CustomSummon(caster, FourCC('uske'), 1 + math.floor(rank / 2), 12.0 + rank)
        elseif spellId == FourCC('A10G') then
            Arena_CustomSummon(caster, FourCC('uske'), 2, 16.0)
            Arena_CustomArea(caster, 550.0, amount * 4.4, false)
        end
    elseif role == 3 then
        if spellId == FourCC('A105') then Arena_CustomArea(caster, 390.0 + 22.0 * rank, amount * 1.8, false)
        elseif spellId == FourCC('A106') then
            Arena_CustomArea(caster, 520.0, amount * 1.1, false)
            SetUnitState(caster, UNIT_STATE_MANA, GetUnitState(caster, UNIT_STATE_MANA) + amount)
        elseif spellId == FourCC('A10H') then Arena_ItemPulses(caster, amount, amount * 0.7)
        elseif spellId == FourCC('A10I') then
            for i = 0, 7 do Arena_CustomArea(caster, 600.0 + i * 25.0, amount * 0.58, false) end
        end
    elseif role == 4 then
        if spellId == FourCC('A107') then Arena_CustomFinisher(caster, amount * 2.5)
        elseif spellId == FourCC('A108') then Arena_CustomSummon(caster, FourCC('uske'), 1 + math.floor(rank / 2), 14.0)
        elseif spellId == FourCC('A10J') then Arena_CustomSummon(caster, FourCC('uske'), 1 + math.floor(rank / 2), 12.0 + rank)
        elseif spellId == FourCC('A10K') then
            Arena_CustomSummon(caster, FourCC('uske'), 3 + rank, 25.0)
            Arena_CustomArea(caster, 400.0, amount * 1.6, false)
        end
    elseif role == 5 then
        if spellId == FourCC('A109') then
            Arena_CustomMove(caster, 200.0 + 30.0 * rank)
            Arena_CustomArea(caster, 310.0, amount * 1.3, false)
        elseif spellId == FourCC('A10A') then
            Arena_CustomArea(caster, 520.0, amount * 1.1, false)
            SetUnitState(caster, UNIT_STATE_MANA, GetUnitState(caster, UNIT_STATE_MANA) + amount)
        elseif spellId == FourCC('A10L') then
            SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + amount * 2.4)
            Arena_CustomArea(caster, 240.0, amount * 0.4, false)
        elseif spellId == FourCC('A10M') then Arena_CustomArea(caster, 500.0, amount * 3.3, false)
        end
    elseif role == 6 then
        if spellId == FourCC('A10B') then Arena_CustomArea(caster, 450.0, amount * 0.65, true)
        elseif spellId == FourCC('A10C') then Arena_CustomArea(caster, 600.0, amount * 2.1, true)
        elseif spellId == FourCC('A10N') then Arena_ItemPulses(caster, amount, amount * 0.7)
        elseif spellId == FourCC('A10O') then
            for i = 0, 9 do Arena_CustomArea(caster, 700.0 + i * 20.0, amount * 0.75, true) end
        end
    elseif role == 7 then
        if spellId == FourCC('A111') then Arena_CustomArea(caster, 260.0, amount, false)
        elseif spellId == FourCC('A112') then
            for i = 0, 3 do Arena_CustomArea(caster, 260.0 + i * 65.0, amount * 0.50, false) end
        elseif spellId == FourCC('A113') then Arena_ItemPulses(caster, amount, amount * 0.7)
        elseif spellId == FourCC('A114') then
            SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_MAX_LIFE))
            SetUnitState(caster, UNIT_STATE_MANA, GetUnitState(caster, UNIT_STATE_MAX_MANA))
            Arena_CustomArea(caster, 600.0, amount * 2.5, false)
        end
    elseif role == 8 then
        if spellId == FourCC('A115') then Arena_CustomArea(caster, 390.0 + 22.0 * rank, amount * 1.8, false)
        elseif spellId == FourCC('A116') then Arena_CustomArea(caster, 300.0, amount * 1.5, false)
        elseif spellId == FourCC('A117') then
            SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + amount * 2.4)
            Arena_CustomArea(caster, 240.0, amount * 0.4, false)
        elseif spellId == FourCC('A118') then
            Arena_CustomArea(caster, 650.0, amount * 4.0, false)
            SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + amount * 2.0)
        end
    elseif role == 9 then
        if spellId == FourCC('A119') then Arena_CustomFinisher(caster, amount * 2.5)
        elseif spellId == FourCC('A11A') then
            for i = 0, 3 do Arena_CustomArea(caster, 260.0 + i * 65.0, amount * 0.50, false) end
        elseif spellId == FourCC('A11B') then
            Arena_CustomMove(caster, 230.0 + 20.0 * rank)
            SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + amount)
        elseif spellId == FourCC('A11C') then Arena_CustomFinisher(caster, amount * 5.0)
        end
    elseif role == 10 then
        if spellId == FourCC('A11D') then Arena_CustomArea(caster, 390.0 + 22.0 * rank, amount * 1.8, false)
        elseif spellId == FourCC('A11E') then
            for i = 0, 3 do Arena_CustomArea(caster, 260.0 + i * 65.0, amount * 0.50, false) end
        elseif spellId == FourCC('A11F') then Arena_CustomSummon(caster, FourCC('uske'), 1 + math.floor(rank / 2), 12.0 + rank)
        elseif spellId == FourCC('A11G') then
            for i = 0, 7 do Arena_CustomArea(caster, 600.0 + i * 25.0, amount * 0.58, false) end
        end
    end
end

function InitCustomTriggers()
    udg_WaveTimer = CreateTimer()
    udg_WaveTD = CreateTimerDialog(udg_WaveTimer)
    udg_HumanCount = 1

    local spellTrigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(spellTrigger, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    TriggerAddAction(spellTrigger, function()
        local caster = GetTriggerUnit()
        local spellId = GetSpellAbilityId()
        local pid = GetPlayerId(GetOwningPlayer(caster))
        Arena_CustomCast_Lua(caster, pid, spellId)
    end)

    local deathTrigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(deathTrigger, EVENT_PLAYER_UNIT_DEATH)
    TriggerAddAction(deathTrigger, function() Trig_Death_Actions() end)

    local bossDeathTrigger = CreateTrigger()
    TriggerRegisterPlayerUnitEvent(bossDeathTrigger, Player(PLAYER_NEUTRAL_AGGRESSIVE), EVENT_PLAYER_UNIT_DEATH, nil)
    TriggerAddAction(bossDeathTrigger, function() Trig_Boss_Actions() end)

    local bossThinkTrigger = CreateTrigger()
    TriggerRegisterTimerEvent(bossThinkTrigger, 1.00, true)
    TriggerAddAction(bossThinkTrigger, function() Trig_BossThink_Actions() end)

    local initTimer = CreateTrigger()
    TriggerRegisterTimerEvent(initTimer, 0.50, false)
    TriggerAddAction(initTimer, function()
        FogEnableOff()
        FogMaskEnableOff()
        print("|cffffcc00[Инициализация]: Запуск выбора героев...|r")

        HeroDialog = DialogCreate()
        DialogSetMessage(HeroDialog, "Выберите класс героя:")

        HeroDialogButtons = {}
        for i, classData in ipairs(HeroClasses) do
            HeroDialogButtons[i] = DialogAddButton(HeroDialog, classData.name, 0)
        end

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

        for pid = 0, 3 do
            DialogDisplay(Player(pid), HeroDialog, true)
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
    for i = 0, 3 do SetPlayerTeam(Player(i), 0) end
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
    for i = 0, 3 do SetPlayerSlotAvailable(Player(i), MAP_CONTROL_USER) end
end

function Arena_Msg(s)
    DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 10.0, s)
end

function Arena_CreateEnemy(unitId, x, y)
    local u = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), unitId, x, y, 270.0)
    if u == nil then return end
    udg_EnemiesAlive = udg_EnemiesAlive + 1
    SetUnitUserData(u, 777)
    SetUnitCreepGuard(u, false)
    UnitWakeUp(u)
    SetUnitAcquireRange(u, 4000.0)
    IssuePointOrder(u, "attack", 0.0, 0.0)
end

function Arena_SpawnRing(unitId, count, dist)
    local scaled = math.floor((count * (udg_HumanCount + 2) + 3) / 4)
    if scaled < 2 then scaled = 2 end
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
    if wave <= 10 then return "Units\\Creeps\\Bandit\\BanditPissed1.wav"
    elseif wave <= 20 then return "Units\\Creeps\\Ogre\\OgrePissed1.wav"
    elseif wave <= 30 then return "Units\\Undead\\Necromancer\\NecromancerPissed1.wav"
    elseif wave <= 40 then return "Units\\Demon\\FelGuard\\FelGuardPissed1.wav"
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
    if udg_EnemiesAlive >= 70 then return end
    local elite = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), Arena_EliteType(wave), x, y, 270.0)
    if elite == nil then return end
    udg_EnemiesAlive = udg_EnemiesAlive + 1
    SetUnitUserData(elite, 888)
    local scale = 1.20 + 0.003 * wave
    SetUnitScale(elite, scale, scale, scale)
    SetUnitVertexColor(elite, 255, 155, 110, 255)
    SetUnitCreepGuard(elite, false)
    UnitWakeUp(elite)
    SetUnitAcquireRange(elite, 4500.0)
    if wave >= 25 then UnitAddAbility(elite, FourCC('ACav')) end
    Arena_EliteAnnouncement(wave, x, y)
    IssuePointOrder(elite, "attack", 0.0, 0.0)
end

function Arena_PayWaveGold(gold)
    for i = 0, 3 do
        local p = Player(i)
        SetPlayerState(p, PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(p, PLAYER_STATE_RESOURCE_GOLD) + gold)
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
    if wave % 5 == 0 then eliteSupport = 1 end
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

function Arena_SpawnBoss()
    if udg_Boss ~= nil or udg_GameOver then return end
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
    if udg_GameOver or udg_Boss == nil or GetWidgetLife(udg_Boss) <= 0.405 then return end
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
    if udg_GameOver then return end
    if udg_Wave >= 50 then
        TimerDialogDisplay(udg_WaveTD, false)
        Arena_SpawnBoss()
        return
    end
    udg_Wave = udg_Wave + 1
    udg_WaveCleared = false
    Arena_SpawnWaveCreeps(udg_Wave)
    if udg_Wave % 5 == 0 then Arena_SpawnElite(udg_Wave) end
    Arena_PayWaveGold(38 + udg_Wave * 5)
    Arena_Msg("|cffffcc00Волна " .. tostring(udg_Wave) .. "/50|r — " .. Arena_WaveTheme(udg_Wave) .. ". Врагов: " .. tostring(udg_EnemiesAlive))
    if udg_Wave < 50 then
        TimerDialogSetTitle(udg_WaveTD, "Волна " .. tostring(udg_Wave + 1))
    else
        TimerDialogSetTitle(udg_WaveTD, "Финальный босс")
    end
    TimerStart(udg_WaveTimer, 100.00, false, function() Trig_Wave_Actions() end)
end

function Arena_ReviveHero(pid)
    if udg_GameOver or Heroes[pid] == nil then return end
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
        TimerStart(udg_WaveTimer, 7.00, false, function() Trig_Wave_Actions() end)
    end
end

function Trig_Death_Actions()
    local u = GetDyingUnit()
    local killer = GetKillingUnit()
    if GetOwningPlayer(u) == Player(PLAYER_NEUTRAL_AGGRESSIVE) and u ~= udg_Boss then
        if udg_EnemiesAlive > 0 then udg_EnemiesAlive = udg_EnemiesAlive - 1 end
        udg_TotalKills = udg_TotalKills + 1
        if GetUnitUserData(u) == 888 then
            Arena_Msg("|cffffcc66Побеждён мини-босс! Команде начислена награда.|r")
            Arena_PayWaveGold(50 + udg_Wave * 3)
        end
        if udg_EnemiesAlive == 0 then Arena_CheckWaveClear() end
        if killer ~= nil then
            local pid = GetPlayerId(GetOwningPlayer(killer))
            if pid >= 0 and pid < 4 then
                local reward = 5 + udg_Wave
                udg_PlayerKills[pid + 1] = (udg_PlayerKills[pid + 1] or 0) + 1
                SetPlayerState(Player(pid), PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(Player(pid), PLAYER_STATE_RESOURCE_GOLD) + reward)
            end
        end
        return
    end
    if not IsUnitType(u, UNIT_TYPE_HERO) or GetOwningPlayer(u) == Player(PLAYER_NEUTRAL_AGGRESSIVE) then return end
    local pid = GetPlayerId(GetOwningPlayer(u))
    if pid < 0 or pid > 3 or u ~= Heroes[pid] then return end
    DisplayTimedTextToPlayer(Player(pid), 0, 0, 8.00, "Смерть. Воскрешение через 12 сек.")
    if not udg_ReviveTimer[pid] then udg_ReviveTimer[pid] = CreateTimer() end
    TimerStart(udg_ReviveTimer[pid], 12.00, false, function() Arena_ReviveHero(pid) end)
end

function Trig_Boss_Actions()
    if udg_GameOver or GetDyingUnit() ~= udg_Boss then return end
    udg_GameOver = true
    PauseTimer(udg_WaveTimer)
    TimerDialogDisplay(udg_WaveTD, false)
    Arena_Msg("|cff00ff00Победа! Каз'Рул повержен. Арена остается открытой для свободной игры.|r")
    Arena_PayWaveGold(800)
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

function Arena_CustomSummon(caster, unitId, count, duration)
    local i = 0
    local p = GetOwningPlayer(caster)
    local x = GetUnitX(caster)
    local y = GetUnitY(caster)
    while i < count do
        local u = CreateUnit(p, unitId, x + math.random(-80, 80), y + math.random(-80, 80), GetUnitFacing(caster))
        UnitApplyTimedLife(u, FourCC('BTLF'), duration)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl", u, "origin"))
        i = i + 1
    end
end
