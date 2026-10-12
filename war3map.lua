-- ===========================================================================
-- Map Script: Warcraft III (Lua Mode)
-- ===========================================================================

function InitGlobals()
    -- Глобальные переменные
end

function InitCustomTriggers()
    -- Стартовое событие: через 1 секунду после старта
    local initTrigger = CreateTrigger()
    TriggerRegisterTimerEvent(initTrigger, 1.00, false)
    TriggerAddAction(initTrigger, function()
        -- Спавн героя Паладина в центре карты (X: 0, Y: 0)
        local hero = CreateUnit(Player(0), FourCC('Hpal'), 0.0, 0.0, 270.0)
        
        -- Стартовое сообщение
        DisplayTextToPlayer(Player(0), 0, 0, "|cffffcc00Задание получено:|r Исследуйте местность и победите босса!")

        -- Стартовый квест
        local myQuest = CreateQuest()
        QuestSetTitle(myQuest, "Очищение земель")
        QuestSetDescription(myQuest, "Найдите и уничтожьте лагерь врагов.")
        QuestSetRequired(myQuest, true)
        QuestSetDiscovered(myQuest, true)
        FlashQuestDialogButton()
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
