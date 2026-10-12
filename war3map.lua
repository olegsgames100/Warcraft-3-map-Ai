-- ===========================================================================
-- Map Script: Warcraft III (Lua Mode)
-- ===========================================================================

function InitGlobals()
    -- Глобальные переменные
    Heroes = {}
    HeroKind = {}
    
    -- Данные классов героев
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
end

function Arena_CustomCast_Lua(caster, pid, spellId)
    -- Диспетчер способностей
    if not Heroes[pid] or Heroes[pid] ~= caster then return end
    
    local role = HeroKind[pid]
    if not role then return end
    
    local rank = GetUnitAbilityLevel(caster, spellId)
    if rank < 1 then return end
    
    local amount = 32.0 + 21.0 * rank
    
    -- 1. Паладин-защитник
    if role == 1 then
        if spellId == FourCC('A101') then -- Q: Клеймо света
            Arena_CustomFinisher(caster, amount * 2.5)
        elseif spellId == FourCC('A102') then -- W: Купол клятвы
            Arena_CustomArea(caster, 600.0, amount * 2.1, true)
        elseif spellId == FourCC('A10D') then -- E: Перехват
            SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + amount * 2.4)
            Arena_CustomArea(caster, 240.0, amount * 0.4, false)
        elseif spellId == FourCC('A10E') then -- R: Последний рассвет
            for i = 0, 3 do
                if Heroes[i] ~= nil and GetWidgetLife(Heroes[i]) <= 0.405 and IsUnitAlly(Heroes[i], GetOwningPlayer(caster)) then
                    ReviveHero(Heroes[i], GetUnitX(caster), GetUnitY(caster), true)
                end
            end
            Arena_CustomArea(caster, 900.0, amount * 3.1, true)
        end
    -- 2. Мастер клинка
    elseif role == 2 then
        if spellId == FourCC('A103') then -- Q: Песчаный рывок
            Arena_CustomMove(caster, 200.0 + 30.0 * rank)
            Arena_CustomArea(caster, 310.0, amount * 1.3, false)
        elseif spellId == FourCC('A104') then -- W: Рваные клинки
            for i = 0, 3 do
                Arena_CustomArea(caster, 260.0 + i * 65.0, amount * 0.50, false)
            end
        elseif spellId == FourCC('A10F') then -- E: Миражи барханов
            Arena_CustomSummon(caster, FourCC('uske'), 1 + math.floor(rank / 2), 12.0 + rank)
        elseif spellId == FourCC('A10G') then -- R: Буря тысячи лезвий
            Arena_CustomSummon(caster, FourCC('uske'), 2, 16.0)
            Arena_CustomArea(caster, 550.0, amount * 4.4, false)
        end
    -- 3. Боевой архимаг
    elseif role == 3 then
        if spellId == FourCC('A105') then -- Q: Цепной разряд
            Arena_CustomArea(caster, 390.0 + 22.0 * rank, amount * 1.8, false)
        elseif spellId == FourCC('A106') then -- W: Грозовой столб
            Arena_CustomArea(caster, 520.0, amount * 1.1, false)
            SetUnitState(caster, UNIT_STATE_MANA, GetUnitState(caster, UNIT_STATE_MANA) + amount)
        elseif spellId == FourCC('A10H') then -- E: Магический контур
            Arena_ItemPulses(caster, amount, amount * 0.7)
        elseif spellId == FourCC('A10I') then -- R: Штормовой катаклизм
            for i = 0, 7 do
                Arena_CustomArea(caster, 600.0 + i * 25.0, amount * 0.58, false)
            end
        end
    -- 4. Рыцарь смерти
    elseif role == 4 then
        if spellId == FourCC('A107') then -- Q: Печать погибели
            Arena_CustomFinisher(caster, amount * 2.5)
        elseif spellId == FourCC('A108') then -- W: Костяной дозор
            Arena_CustomSummon(caster, FourCC('uske'), 1 + math.floor(rank / 2), 14.0)
        elseif spellId == FourCC('A10J') then -- E: Жатва эссенции
            Arena_CustomSummon(caster, FourCC('uske'), 1 + math.floor(rank / 2), 12.0 + rank)
        elseif spellId == FourCC('A10K') then -- R: Чёрный легион
            Arena_CustomSummon(caster, FourCC('uske'), 3 + rank, 25.0)
            Arena_CustomArea(caster, 400.0, amount * 1.6, false)
        end
    -- 5. Охотник на демонов
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
        elseif spellId == FourCC('A10M') then
            Arena_CustomArea(caster, 500.0, amount * 3.3, false)
        end
    -- 6. Лунная жрица
    elseif role == 6 then
        if spellId == FourCC('A10B') then
            Arena_CustomArea(caster, 450.0, amount * 0.65, true)
        elseif spellId == FourCC('A10C') then
            Arena_CustomArea(caster, 600.0, amount * 2.1, true)
        elseif spellId == FourCC('A10N') then
            Arena_ItemPulses(caster, amount, amount * 0.7)
        elseif spellId == FourCC('A10O') then
            for i = 0, 9 do
                Arena_CustomArea(caster, 700.0 + i * 20.0, amount * 0.75, true)
            end
        end
    -- 7. Алхимик-боевик
    elseif role == 7 then
        if spellId == FourCC('A111') then
            Arena_CustomArea(caster, 260.0, amount, false)
        elseif spellId == FourCC('A112') then
            for i = 0, 3 do
                Arena_CustomArea(caster, 260.0 + i * 65.0, amount * 0.50, false)
            end
        elseif spellId == FourCC('A113') then
            Arena_ItemPulses(caster, amount, amount * 0.7)
        elseif spellId == FourCC('A114') then
            SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_MAX_LIFE))
            SetUnitState(caster, UNIT_STATE_MANA, GetUnitState(caster, UNIT_STATE_MAX_MANA))
            Arena_CustomArea(caster, 600.0, amount * 2.5, false)
        end
    -- 8. Горный король
    elseif role == 8 then
        if spellId == FourCC('A115') then
            Arena_CustomArea(caster, 390.0 + 22.0 * rank, amount * 1.8, false)
        elseif spellId == FourCC('A116') then
            Arena_CustomArea(caster, 300.0, amount * 1.5, false)
        elseif spellId == FourCC('A117') then
            SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + amount * 2.4)
            Arena_CustomArea(caster, 240.0, amount * 0.4, false)
        elseif spellId == FourCC('A118') then
            Arena_CustomArea(caster, 650.0, amount * 4.0, false)
            SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + amount * 2.0)
        end
    -- 9. Сумрачная охотница
    elseif role == 9 then
        if spellId == FourCC('A119') then
            Arena_CustomFinisher(caster, amount * 2.5)
        elseif spellId == FourCC('A11A') then
            for i = 0, 3 do
                Arena_CustomArea(caster, 260.0 + i * 65.0, amount * 0.50, false)
            end
        elseif spellId == FourCC('A11B') then
            Arena_CustomMove(caster, 230.0 + 20.0 * rank)
            SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + amount)
        elseif spellId == FourCC('A11C') then
            Arena_CustomFinisher(caster, amount * 5.0)
        end
    -- 10. Ледяной лич
    elseif role == 10 then
        if spellId == FourCC('A11D') then
            Arena_CustomArea(caster, 390.0 + 22.0 * rank, amount * 1.8, false)
        elseif spellId == FourCC('A11E') then
            for i = 0, 3 do
                Arena_CustomArea(caster, 260.0 + i * 65.0, amount * 0.50, false)
            end
        elseif spellId == FourCC('A11F') then
            Arena_CustomSummon(caster, FourCC('uske'), 1 + math.floor(rank / 2), 12.0 + rank)
        elseif spellId == FourCC('A11G') then
            for i = 0, 7 do
                Arena_CustomArea(caster, 600.0 + i * 25.0, amount * 0.58, false)
            end
        end
    end
end

function InitCustomTriggers()
    -- Стартовое событие: создание диалога
    local initTrigger = CreateTrigger()
    TriggerRegisterTimerEvent(initTrigger, 1.00, false)
    TriggerAddAction(initTrigger, function()
        -- Отключаем туман войны
        FogEnableOff()
        FogMaskEnableOff()
        
        HeroDialog = DialogCreate()
        DialogSetMessage(HeroDialog, "Выберите класс героя:")
        
        for i, classData in ipairs(HeroClasses) do
            HeroDialogButtons[i] = DialogAddButton(HeroDialog, classData.name, 0)
        end
        
        -- Показываем диалог всем играющим игрокам
        for pid = 0, 3 do
            if GetPlayerSlotState(Player(pid)) == PLAYER_SLOT_STATE_PLAYING and GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                DialogDisplay(Player(pid), HeroDialog, true)
            end
        end
    end)
    
    -- Триггер обработки выбора в диалоге
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

    -- Триггер для отлова применения заклинаний
    local spellTrigger = CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(spellTrigger, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    TriggerAddAction(spellTrigger, function()
        local caster = GetTriggerUnit()
        local spellId = GetSpellAbilityId()
        local pid = GetPlayerId(GetOwningPlayer(caster))
        
        Arena_CustomCast_Lua(caster, pid, spellId)
    end)
end

function InitCustomPlayerSlots()
    SetPlayerStartLocation(Player(0), 0)
    SetPlayerColor(Player(0), ConvertPlayerColor(0))
    SetPlayerRacePreference(Player(0), RACE_PREF_HUMAN)
    SetPlayerRaceSelectable(Player(0), true)
    SetPlayerController(Player(0), MAP_CONTROL_USER)
end

function InitCustomTeams()
    SetPlayerTeam(Player(0), 0)
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
    SetPlayers(1)
    SetTeams(1)
    InitCustomPlayerSlots()
    InitCustomTeams()
end

-- ===========================================================================
-- Helper functions for Custom Spells
-- ===========================================================================

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
        local u = CreateUnit(p, unitId, x + math.random(-80, 80), y + math.random(-80, 80), GetUnitFacing(caster))
        UnitApplyTimedLife(u, FourCC('BTLF'), duration)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl", u, "origin"))
        i = i + 1
    end
end
