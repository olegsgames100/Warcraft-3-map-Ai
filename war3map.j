//===========================================================================
//
// Hero Arena
//
//   Warcraft III map script (1.26a JASS)
//   Coop arena: pick a hero, buy items, survive 10 waves, kill the boss.
//
//===========================================================================

globals
    trigger                 gg_trg___________________________u = null
    trigger                 gg_trg_____________________________________001 = null
    trigger                 gg_trg_Arena                   = null
    trigger                 gg_trg_Pick                    = null
    trigger                 gg_trg_Wave                    = null
    trigger                 gg_trg_Death                   = null
    trigger                 gg_trg_Boss                    = null
    trigger                 gg_trg_Aura                    = null

    integer                 udg_HumanCount                 = 0
    integer                 udg_PickCount                  = 0
    integer                 udg_Wave                       = 0
    boolean                 udg_WavesStarted               = false
    boolean                 udg_GameOver                   = false

    unit            array   udg_Heroes
    boolean         array   udg_Picked
    integer         array   udg_PendingPick
    // Deterministic level growth. Object Editor's passive growth is disabled.
    real            array   udg_GrowthStr
    real            array   udg_GrowthAgi
    real            array   udg_GrowthInt
    integer         array   udg_AppliedGrowthStr
    integer         array   udg_AppliedGrowthAgi
    integer         array   udg_AppliedGrowthInt
    integer         array   udg_HeroKind
    integer         array   udg_ReviveWait

    region          array   udg_SelectRegion
    unit            array   udg_SelectPreview
    unit            array   udg_SelectWisp
    trigger                 gg_trg_SelectPoll = null
    trigger                 gg_trg_SelectChat = null
    timer                   udg_SelectTimeout = null

    timer                   udg_WaveTimer                  = null
    timerdialog             udg_WaveTD                     = null
    timer                   udg_AuraTimer                  = null
    timer           array   udg_ReviveTimer

    unit                    udg_Boss                       = null
    unit                    udg_ShopWeapon                 = null
    unit                    udg_ShopArmor                  = null
    unit                    udg_ShopMagic                  = null
    unit                    udg_ShopRelic                  = null

    integer                 udg_EnemiesAlive = 0
    integer                 udg_TotalKills = 0
    integer                 udg_BossPhase = 0
    boolean                 udg_WaveCleared = false
    integer         array   udg_PlayerKills
    boolean         array   udg_BonusAdded
    trigger                 gg_trg_Leave = null
    trigger                 gg_trg_BossThink = null
    trigger                 gg_trg_Signature = null
    trigger                 gg_trg_Craft = null

    unit            array   udg_AuraCarrier
    texttag         array   udg_HeroSubtitle
    trigger                 gg_trg_HeroLevel = null
    trigger                 gg_trg_Cheat = null
    trigger                 gg_trg_HeroSpell = null
    trigger                 gg_trg_ItemPickup = null
    trigger                 gg_trg_ItemDrop = null
    trigger                 gg_trg_ItemUse = null
    quest                   udg_QuestMain                  = null
    quest                   udg_QuestBoss                  = null
endglobals

function InitGlobals takes nothing returns nothing
    local integer i = 0
    loop
        exitwhen i > 3
        set udg_Heroes[i] = null
        set udg_Picked[i] = false
        set udg_HeroKind[i] = 0
        set udg_ReviveWait[i] = 0
        set i = i + 1
    endloop
endfunction

//===========================================================================
function Arena_IsHuman takes integer pid returns boolean
    return GetPlayerSlotState(Player(pid)) == PLAYER_SLOT_STATE_PLAYING and GetPlayerController(Player(pid)) == MAP_CONTROL_USER
endfunction

function Arena_CountHumans takes nothing returns integer
    local integer i = 0
    local integer n = 0
    loop
        exitwhen i > 3
        if Arena_IsHuman(i) then
            set n = n + 1
        endif
        set i = i + 1
    endloop
    return n
endfunction

function Arena_Msg takes string s returns nothing
    local integer i = 0
    loop
        exitwhen i > 3
        call DisplayTimedTextToPlayer(Player(i), 0, 0, 8.00, s)
        set i = i + 1
    endloop
endfunction

function Arena_AllyPlayers takes nothing returns nothing
    local integer i
    local integer j
    set i = 0
    loop
        exitwhen i > 3
        set j = 0
        loop
            exitwhen j > 3
            if i != j then
                call SetPlayerAlliance(Player(i), Player(j), ALLIANCE_PASSIVE, true)
                call SetPlayerAlliance(Player(i), Player(j), ALLIANCE_HELP_REQUEST, true)
                call SetPlayerAlliance(Player(i), Player(j), ALLIANCE_HELP_RESPONSE, true)
                call SetPlayerAlliance(Player(i), Player(j), ALLIANCE_SHARED_XP, true)
                call SetPlayerAlliance(Player(i), Player(j), ALLIANCE_SHARED_VISION, true)
                call SetPlayerAlliance(Player(i), Player(j), ALLIANCE_SHARED_SPELLS, true)
            endif
            set j = j + 1
        endloop
        call SetPlayerAlliance(Player(i), Player(PLAYER_NEUTRAL_PASSIVE), ALLIANCE_PASSIVE, true)
        call SetPlayerState(Player(i), PLAYER_STATE_RESOURCE_GOLD, 450)
        call SetPlayerState(Player(i), PLAYER_STATE_RESOURCE_LUMBER, 0)
        call SetPlayerState(Player(i), PLAYER_STATE_RESOURCE_FOOD_CAP, 100)
        call SetPlayerState(Player(i), PLAYER_STATE_RESOURCE_FOOD_USED, 0)
        set i = i + 1
    endloop
endfunction

function Arena_ApplyHandicap takes nothing returns nothing
    local integer i = 0
    local real hp = 1.0
    local real xp = 1.0
    // Avoid exponential or excessive hero health from handicap and stat scaling.
    if udg_HumanCount <= 1 then
        set hp = 1.20
        set xp = 1.22
    elseif udg_HumanCount == 2 then
        set hp = 1.12
        set xp = 1.12
    elseif udg_HumanCount == 3 then
        set hp = 1.06
        set xp = 1.05
    endif
    loop
        exitwhen i >= 4
        call SetPlayerHandicap(Player(i), hp)
        call SetPlayerHandicapXP(Player(i), xp)
        set i = i + 1
    endloop
endfunction

//===========================================================================
// Shops — vanilla items, custom loadout / names in the quest text
//===========================================================================
function Arena_DoNothing takes nothing returns nothing
endfunction

function Arena_Stock takes unit shop, integer itemId, integer stock returns nothing
    if shop == null then
        return
    endif
    call AddItemToStock(shop, itemId, stock, stock)
endfunction

function Arena_ShopLabel takes real x, real y, string name, integer r, integer g, integer b returns nothing
    local texttag t = CreateTextTag()
    call SetTextTagText(t, name, 0.027)
    call SetTextTagPos(t, x - 200.0, y, 220.0)
    call SetTextTagColor(t, r, g, b, 255)
    call SetTextTagPermanent(t, true)
    call SetTextTagVisibility(t, true)
    set t = null
endfunction

function Arena_PrepareShop takes unit shop, integer r, integer g, integer b returns nothing
    if shop == null then
        return
    endif
    call SetUnitInvulnerable(shop, true)
    call SetUnitVertexColor(shop, r, g, b, 255)
    call SetUnitScale(shop, 1.15, 1.15, 1.15)
    call RemoveGuardPosition(shop)
endfunction

function Arena_CreateShops takes nothing returns nothing
    // Four distinct Warcraft III object types with independent built-in item inventories.
    set udg_ShopWeapon = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), 'nS01', -760.0, -380.0, 270.0)
    set udg_ShopArmor = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), 'nS02', 760.0, -380.0, 270.0)
    set udg_ShopMagic = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), 'nS03', -760.0, 380.0, 270.0)
    set udg_ShopRelic = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), 'nS04', 760.0, 380.0, 270.0)
    call Arena_PrepareShop(udg_ShopWeapon, 255, 130, 110)
    call Arena_PrepareShop(udg_ShopArmor, 130, 185, 255)
    call Arena_PrepareShop(udg_ShopMagic, 120, 255, 160)
    call Arena_PrepareShop(udg_ShopRelic, 255, 215, 125)
    // No AddItemToStock calls: Object Editor 'Items Sold' now owns the inventory.
    call Arena_ShopLabel(-760.0, -380.0, "КУЗНИЦА ОСКОЛКОВ", 255, 160, 135)
    call Arena_ShopLabel(760.0, -380.0, "ОПЛОТ СТРАЖА", 150, 190, 255)
    call Arena_ShopLabel(-760.0, 380.0, "АЛХИМИЧЕСКАЯ ЛАВКА", 150, 255, 170)
    call Arena_ShopLabel(760.0, 380.0, "ХРАНИЛИЩЕ РЕЛИКВИЙ", 255, 220, 125)
endfunction

//===========================================================================
function Arena_HeroType takes integer kind returns integer
    if kind == 1 then
        return 'H001'
    elseif kind == 2 then
        return 'O001'
    elseif kind == 3 then
        return 'H002'
    elseif kind == 4 then
        return 'U001'
    elseif kind == 5 then
        return 'E001'
    elseif kind == 6 then
        return 'E002'
    elseif kind == 7 then
        return 'N001'
    elseif kind == 8 then
        return 'H003'
    elseif kind == 9 then
        return 'E003'
    endif
    return 'U002'
endfunction

function Arena_HeroTitle takes integer k returns string
    if k == 1 then
        return "Рейнар Светокованный"
    elseif k == 2 then
        return "Зархан Быстрокрылый"
    elseif k == 3 then
        return "Мирелла Искророждённая"
    elseif k == 4 then
        return "Морвен Праховестник"
    elseif k == 5 then
        return "Вальтир Безликий"
    elseif k == 6 then
        return "Селена Звездочёт"
    elseif k == 7 then
        return "Фенн Медный Котёл"
    elseif k == 8 then
        return "Торвин Громовой Камень"
    elseif k == 9 then
        return "Лириса Сумеречная"
    endif
    return "Иссара Морозная"
endfunction

function Arena_HeroProfession takes integer kind returns string
    if kind == 1 then
        return "Паладин-защитник"
    elseif kind == 2 then
        return "Мастер клинка"
    elseif kind == 3 then
        return "Боевой архимаг"
    elseif kind == 4 then
        return "Рыцарь смерти"
    elseif kind == 5 then
        return "Охотник на демонов"
    elseif kind == 6 then
        return "Лунная жрица"
    elseif kind == 7 then
        return "Алхимик-боевик"
    elseif kind == 8 then
        return "Горный король"
    elseif kind == 9 then
        return "Сумрачная охотница"
    endif
    return "Ледяной лич"
endfunction

function Arena_HeroEpithet takes integer k returns string
    if k == 1 then
        return "Хранитель рассвета"
    elseif k == 2 then
        return "Танцующий среди песков"
    elseif k == 3 then
        return "Шепчущая бурям"
    elseif k == 4 then
        return "Наследник забытого трона"
    elseif k == 5 then
        return "Блуждающий между мирами"
    elseif k == 6 then
        return "Последняя дочь ночи"
    elseif k == 7 then
        return "Алхимик семи эликсиров"
    elseif k == 8 then
        return "Молот северных твердынь"
    elseif k == 9 then
        return "Клинок тихой охоты"
    endif
    return "Повелительница льда"
endfunction

function Arena_CustomSpell takes integer kind, integer slot returns integer
    if kind == 1 then
        if slot == 1 then
            return 'A101'
        elseif slot == 2 then
            return 'A102'
        elseif slot == 3 then
            return 'A10D'
        elseif slot == 4 then
            return 'A10E'
        endif
    elseif kind == 2 then
        if slot == 1 then
            return 'A103'
        elseif slot == 2 then
            return 'A104'
        elseif slot == 3 then
            return 'A10F'
        elseif slot == 4 then
            return 'A10G'
        endif
    elseif kind == 3 then
        if slot == 1 then
            return 'A105'
        elseif slot == 2 then
            return 'A106'
        elseif slot == 3 then
            return 'A10H'
        elseif slot == 4 then
            return 'A10I'
        endif
    elseif kind == 4 then
        if slot == 1 then
            return 'A107'
        elseif slot == 2 then
            return 'A108'
        elseif slot == 3 then
            return 'A10J'
        elseif slot == 4 then
            return 'A10K'
        endif
    elseif kind == 5 then
        if slot == 1 then
            return 'A109'
        elseif slot == 2 then
            return 'A10A'
        elseif slot == 3 then
            return 'A10L'
        elseif slot == 4 then
            return 'A10M'
        endif
    elseif kind == 6 then
        if slot == 1 then
            return 'A10B'
        elseif slot == 2 then
            return 'A10C'
        elseif slot == 3 then
            return 'A10N'
        elseif slot == 4 then
            return 'A10O'
        endif
    elseif kind == 7 then
        if slot == 1 then
            return 'A111'
        elseif slot == 2 then
            return 'A112'
        elseif slot == 3 then
            return 'A113'
        elseif slot == 4 then
            return 'A114'
        endif
    elseif kind == 8 then
        if slot == 1 then
            return 'A115'
        elseif slot == 2 then
            return 'A116'
        elseif slot == 3 then
            return 'A117'
        elseif slot == 4 then
            return 'A118'
        endif
    elseif kind == 9 then
        if slot == 1 then
            return 'A119'
        elseif slot == 2 then
            return 'A11A'
        elseif slot == 3 then
            return 'A11B'
        elseif slot == 4 then
            return 'A11C'
        endif
    elseif kind == 10 then
        if slot == 1 then
            return 'A11D'
        elseif slot == 2 then
            return 'A11E'
        elseif slot == 3 then
            return 'A11F'
        elseif slot == 4 then
            return 'A11G'
        endif
    endif
    return 0
endfunction

function Arena_GiveSkills takes unit hero, integer kind returns nothing
    local integer slot = 1
    local integer id
    local integer success = 0
    if hero == null then
        return
    endif
    loop
        exitwhen slot > 4
        set id = Arena_CustomSpell(kind, slot)
        if id != 0 then
            if GetUnitAbilityLevel(hero, id) == 0 then
                call UnitAddAbility(hero, id)
            endif
            if GetUnitAbilityLevel(hero, id) > 0 then
                set success = success + 1
            endif
        endif
        set slot = slot + 1
    endloop
    if GetHeroSkillPoints(hero) > 0 then
        call UnitModifySkillPoints(hero, -GetHeroSkillPoints(hero))
    endif
    if success == 4 then
        call DisplayTimedTextToPlayer(GetOwningPlayer(hero), 0.0, 0.0, 8.0, "|cff66ff99Умения Q/W/E/R доступны с 1 уровня.|r")
    else
        call DisplayTimedTextToPlayer(GetOwningPlayer(hero), 0.0, 0.0, 15.0, "|cffff5555Загружено умений: " + I2S(success) + "/4. Проверь war3map.w3a и war3map.w3u.|r")
    endif
endfunction

function Arena_UpdateCustomRanks takes nothing returns nothing
    local integer pid = 0
    local integer rank
    local integer slot
    local integer id
    local unit hero
    loop
        exitwhen pid >= 4
        set hero = udg_Heroes[pid]
        if hero != null and GetWidgetLife(hero) > 0.405 and udg_HeroKind[pid] >= 1 then
            set rank = 1 + (GetHeroLevel(hero) - 1) / 4
            if rank > 5 then
                set rank = 5
            endif
            if rank < 1 then
                set rank = 1
            endif
            set slot = 1
            loop
                exitwhen slot > 4
                set id = Arena_CustomSpell(udg_HeroKind[pid], slot)
                if id != 0 then
                    if GetUnitAbilityLevel(hero, id) == 0 then
                        call UnitAddAbility(hero, id)
                    endif
                    if GetUnitAbilityLevel(hero, id) > 0 and GetUnitAbilityLevel(hero, id) != rank then
                        call SetUnitAbilityLevel(hero, id, rank)
                    endif
                endif
                set slot = slot + 1
            endloop
            if GetHeroSkillPoints(hero) > 0 then
                call UnitModifySkillPoints(hero, -GetHeroSkillPoints(hero))
            endif
        endif
        set pid = pid + 1
    endloop
    set hero = null
endfunction

function Arena_ClearAuras takes nothing returns nothing
    local integer i = 0
    loop
        exitwhen i >= 4
        if udg_AuraCarrier[i] != null then
            call RemoveUnit(udg_AuraCarrier[i])
            set udg_AuraCarrier[i] = null
        endif
        set i = i + 1
    endloop
endfunction

function Arena_GiveAuras takes unit hero returns nothing
    local integer pid = GetPlayerId(GetOwningPlayer(hero))
    local unit carrier
    if pid < 0 or pid > 3 or udg_HumanCount >= 4 then
        return
    endif
    // A farm is noncombat and immobile in 1.26a. Unlike an invisible footman,
    // it can never chase, attack or be mistaken for a playable arena hero.
    set carrier = CreateUnit(Player(pid), 'hhou', 0.0, 0.0, 270.0)
    if carrier == null then
        return
    endif
    set udg_AuraCarrier[pid] = carrier
    call UnitAddAbility(carrier, 'Aloc')
    call UnitRemoveAbility(carrier, 'Aatk')
    call SetUnitPathing(carrier, false)
    call SetUnitInvulnerable(carrier, true)
    // Stock aura templates only. No crash-prone custom unit/ability rawcodes.
    call UnitAddAbility(carrier, 'ACae')
    if udg_HumanCount <= 2 then
        call UnitAddAbility(carrier, 'ACua')
    endif
    if udg_HumanCount == 1 then
        call UnitAddAbility(carrier, 'ACav')
        call UnitAddAbility(carrier, 'ACac')
    endif
    call SetUnitVertexColor(carrier, 255, 255, 255, 0)
    set carrier = null
endfunction

function Arena_RefreshBalance takes nothing returns nothing
    local integer i = 0
    call Arena_ClearAuras()
    set udg_HumanCount = Arena_CountHumans()
    if udg_HumanCount < 1 then
        set udg_HumanCount = 1
    endif
    call Arena_ApplyHandicap()
    loop
        exitwhen i >= 4
        if Arena_IsHuman(i) and udg_Heroes[i] != null then
            call Arena_GiveAuras(udg_Heroes[i])
        endif
        set i = i + 1
    endloop
endfunction

function Arena_NormalizeHeroStats takes unit hero returns nothing
    // Keep the old Object Editor hero's base growth only. Extreme values are capped.
    if GetHeroStr(hero, false) > 60 then
        call SetHeroStr(hero, 60, true)
    endif
    if GetHeroAgi(hero, false) > 60 then
        call SetHeroAgi(hero, 60, true)
    endif
    if GetHeroInt(hero, false) > 60 then
        call SetHeroInt(hero, 60, true)
    endif
endfunction

function Arena_SyncHeroGrowth takes integer pid returns nothing
    local unit hero
    local integer level
    local integer desiredStr
    local integer desiredAgi
    local integer desiredInt
    local integer diff
    if pid < 0 or pid > 3 then
        return
    endif
    set hero = udg_Heroes[pid]
    if hero == null or not IsUnitType(hero, UNIT_TYPE_HERO) then
        return
    endif
    set level = GetHeroLevel(hero)
    if level < 1 then
        set level = 1
    endif
    if level > 20 then
        set level = 20
    endif
    // Retain fractions instead of rounding +3.6 to +4 at each level.
    // An absolute cumulative target makes -maxlvl and skipped levels deterministic.
    set desiredStr = R2I(I2R(level - 1) * udg_GrowthStr[pid] + 0.5)
    set desiredAgi = R2I(I2R(level - 1) * udg_GrowthAgi[pid] + 0.5)
    set desiredInt = R2I(I2R(level - 1) * udg_GrowthInt[pid] + 0.5)
    set diff = desiredStr - udg_AppliedGrowthStr[pid]
    if diff != 0 then
        call SetHeroStr(hero, GetHeroStr(hero, false) + diff, true)
        set udg_AppliedGrowthStr[pid] = desiredStr
    endif
    set diff = desiredAgi - udg_AppliedGrowthAgi[pid]
    if diff != 0 then
        call SetHeroAgi(hero, GetHeroAgi(hero, false) + diff, true)
        set udg_AppliedGrowthAgi[pid] = desiredAgi
    endif
    set diff = desiredInt - udg_AppliedGrowthInt[pid]
    if diff != 0 then
        call SetHeroInt(hero, GetHeroInt(hero, false) + diff, true)
        set udg_AppliedGrowthInt[pid] = desiredInt
    endif
    set hero = null
endfunction

function Trig_HeroLevel_Actions takes nothing returns nothing
    local unit hero = GetTriggerUnit()
    local integer pid = GetPlayerId(GetOwningPlayer(hero))
    if pid >= 0 and pid < 4 and hero == udg_Heroes[pid] then
        call Arena_SyncHeroGrowth(pid)
        call Arena_UpdateCustomRanks()
    endif
    set hero = null
endfunction

function Arena_SpawnHero takes integer pid, integer kind returns boolean
    local real x = -144.0
    local real y = -144.0
    local unit hero
    if pid == 1 then
        set x = 144.0
    elseif pid == 2 then
        set y = 144.0
    elseif pid == 3 then
        set x = 144.0
        set y = 144.0
    endif
    call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 7.0, "[Выбор 1/3] Создание базового героя...")
    set hero = CreateUnit(Player(pid), Arena_HeroType(kind), x, y, 270.0)
    if hero == null then
        call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 9.0, "|cffff4444Создание героя не удалось. Попробуйте другой номер.|r")
        return false
    endif
    // Set up distinct starting stats while staying with engine-defined hero data.
    if kind == 1 then
        call SetHeroStr(hero, 28, true)
        call SetHeroAgi(hero, 14, true)
        call SetHeroInt(hero, 20, true)
    elseif kind == 2 then
        call SetHeroStr(hero, 19, true)
        call SetHeroAgi(hero, 29, true)
        call SetHeroInt(hero, 13, true)
    elseif kind == 3 then
        call SetHeroStr(hero, 16, true)
        call SetHeroAgi(hero, 15, true)
        call SetHeroInt(hero, 29, true)
    elseif kind == 4 then
        call SetHeroStr(hero, 26, true)
        call SetHeroAgi(hero, 16, true)
        call SetHeroInt(hero, 22, true)
    elseif kind == 5 then
        call SetHeroStr(hero, 20, true)
        call SetHeroAgi(hero, 28, true)
        call SetHeroInt(hero, 17, true)
    elseif kind == 6 then
        call SetHeroStr(hero, 18, true)
        call SetHeroAgi(hero, 25, true)
        call SetHeroInt(hero, 24, true)
    elseif kind == 7 then
        call SetHeroStr(hero, 19, true)
        call SetHeroAgi(hero, 16, true)
        call SetHeroInt(hero, 29, true)
    elseif kind == 8 then
        call SetHeroStr(hero, 30, true)
        call SetHeroAgi(hero, 15, true)
        call SetHeroInt(hero, 17, true)
    elseif kind == 9 then
        call SetHeroStr(hero, 20, true)
        call SetHeroAgi(hero, 27, true)
        call SetHeroInt(hero, 20, true)
    else
        call SetHeroStr(hero, 17, true)
        call SetHeroAgi(hero, 18, true)
        call SetHeroInt(hero, 30, true)
    endif
    call Arena_NormalizeHeroStats(hero)
    if kind == 1 then
        set udg_GrowthStr[pid] = 3.60
        set udg_GrowthAgi[pid] = 1.60
        set udg_GrowthInt[pid] = 2.20
    elseif kind == 2 then
        set udg_GrowthStr[pid] = 2.00
        set udg_GrowthAgi[pid] = 3.70
        set udg_GrowthInt[pid] = 1.60
    elseif kind == 3 then
        set udg_GrowthStr[pid] = 1.80
        set udg_GrowthAgi[pid] = 1.70
        set udg_GrowthInt[pid] = 3.80
    elseif kind == 4 then
        set udg_GrowthStr[pid] = 3.30
        set udg_GrowthAgi[pid] = 1.70
        set udg_GrowthInt[pid] = 2.80
    elseif kind == 5 then
        set udg_GrowthStr[pid] = 2.20
        set udg_GrowthAgi[pid] = 3.40
        set udg_GrowthInt[pid] = 2.00
    elseif kind == 6 then
        set udg_GrowthStr[pid] = 2.00
        set udg_GrowthAgi[pid] = 3.10
        set udg_GrowthInt[pid] = 3.00
    elseif kind == 7 then
        set udg_GrowthStr[pid] = 2.10
        set udg_GrowthAgi[pid] = 2.20
        set udg_GrowthInt[pid] = 3.10
    elseif kind == 8 then
        set udg_GrowthStr[pid] = 2.10
        set udg_GrowthAgi[pid] = 2.20
        set udg_GrowthInt[pid] = 3.10
    elseif kind == 9 then
        set udg_GrowthStr[pid] = 2.10
        set udg_GrowthAgi[pid] = 2.20
        set udg_GrowthInt[pid] = 3.10
    elseif kind == 10 then
        set udg_GrowthStr[pid] = 2.10
        set udg_GrowthAgi[pid] = 2.20
        set udg_GrowthInt[pid] = 3.10
    endif
    set udg_AppliedGrowthStr[pid] = 0
    set udg_AppliedGrowthAgi[pid] = 0
    set udg_AppliedGrowthInt[pid] = 0
    set udg_Heroes[pid] = hero
    set udg_HeroKind[pid] = kind
    call Arena_SyncHeroGrowth(pid)
    call Arena_GiveSkills(hero, kind)
    // Reforged custom hero class with four native Object Editor spells.
    // QWER abilities are embedded in war3map.w3u and implemented by JASS.
    call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 7.0, "[Выбор 2/3] Герой создан. Выдаём снаряжение...")
    call UnitAddItemById(hero, 'phea')
    call UnitAddItemById(hero, 'pman')
    call UnitAddItemById(hero, 'ciri')
    call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 7.0, "[Выбор 3/3] Создаём отдельного носителя бонусов...")
    call Arena_GiveAuras(hero)
    call SelectUnitForPlayerSingle(hero, Player(pid))
    call PanCameraToTimedForPlayer(Player(pid), x, y, 0.00)
    call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 8.0, "|cff66ff99" + Arena_HeroProfession(kind) + " — " + Arena_HeroTitle(kind) + "|r")
    set hero = null
    return true
endfunction

//===========================================================================

function Arena_ItemStat takes integer id returns integer
    if id == 'I001' or id == 'I00C' then
        return 1
    elseif id == 'I002' or id == 'I006' or id == 'I00B' then
        return 2
    elseif id == 'I003' or id == 'I004' or id == 'I005' or id == 'I00A' then
        return 3
    endif
    return 0
endfunction

function Arena_ItemBonus takes integer id returns integer
    if id == 'I001' or id == 'I005' then
        return 5
    elseif id == 'I002' then
        return 4
    elseif id == 'I003' then
        return 3
    elseif id == 'I004' then
        return 8
    elseif id == 'I006' then
        return 6
    elseif id == 'I00A' or id == 'I00B' then
        return 9
    elseif id == 'I00C' then
        return 7
    endif
    return 0
endfunction

function Arena_UpdateItemStats takes unit hero, integer id, integer sign returns nothing
    local integer bonus = Arena_ItemBonus(id) * sign
    if not IsUnitType(hero, UNIT_TYPE_HERO) or bonus == 0 then
        return
    endif
    if Arena_ItemStat(id) == 1 then
        call SetHeroAgi(hero, GetHeroAgi(hero, false) + bonus, true)
    elseif Arena_ItemStat(id) == 2 then
        call SetHeroInt(hero, GetHeroInt(hero, false) + bonus, true)
    elseif Arena_ItemStat(id) == 3 then
        call SetHeroStr(hero, GetHeroStr(hero, false) + bonus, true)
    endif
endfunction

function Trig_ItemPickup_Actions takes nothing returns nothing
    call Arena_UpdateItemStats(GetTriggerUnit(), GetItemTypeId(GetManipulatedItem()), 1)
endfunction

function Trig_ItemDrop_Actions takes nothing returns nothing
    call Arena_UpdateItemStats(GetTriggerUnit(), GetItemTypeId(GetManipulatedItem()), -1)
endfunction

function Arena_ItemPulses takes unit caster, real hp, real mp returns nothing
    local integer i = 0
    local unit hero
    loop
        exitwhen i >= 4
        set hero = udg_Heroes[i]
        if hero != null and GetWidgetLife(hero) > 0.405 and IsUnitAlly(hero, GetOwningPlayer(caster)) and IsUnitInRange(hero, caster, 650.0) then
            call SetUnitState(hero, UNIT_STATE_LIFE, GetUnitState(hero, UNIT_STATE_LIFE) + hp)
            call SetUnitState(hero, UNIT_STATE_MANA, GetUnitState(hero, UNIT_STATE_MANA) + mp)
        endif
        set i = i + 1
    endloop
    set hero = null
endfunction

function Trig_ItemUse_Actions takes nothing returns nothing
    local unit caster = GetTriggerUnit()
    local integer id = GetItemTypeId(GetManipulatedItem())
    if id == 'I007' then
        call Arena_ItemPulses(caster, 65.0, 0.0)
    elseif id == 'I008' then
        call Arena_ItemPulses(caster, 0.0, 45.0)
    elseif id == 'I009' then
        call Arena_ItemPulses(caster, 40.0, 0.0)
    endif
    set caster = null
endfunction

function Arena_DropLoot takes unit dying returns nothing
    local integer danger = udg_Wave
    local integer roll = GetRandomInt(1, 1000)
    local integer chance = 9 + danger * 2
    local integer itemId
    if IsUnitType(dying, UNIT_TYPE_HERO) then
        set chance = chance + 20
    endif
    if GetUnitLevel(dying) >= 6 then
        set chance = chance + 15
    endif
    if GetUnitUserData(dying) == 888 then
        set chance = chance + 160
    endif
    // 1.2%-7.4% rare drops, depending on enemy wave and elite rank.
    if roll > chance then
        return
    endif
    if danger <= 3 then
        if GetRandomInt(0, 1) == 0 then
            set itemId = 'I007'
        else
            set itemId = 'I008'
        endif
    elseif danger <= 6 then
        if GetRandomInt(0, 1) == 0 then
            set itemId = 'I003'
        else
            set itemId = 'I006'
        endif
    elseif danger <= 8 then
        if GetRandomInt(0, 1) == 0 then
            set itemId = 'I004'
        else
            set itemId = 'I002'
        endif
    else
        if GetRandomInt(0, 2) == 0 then
            set itemId = 'I00A'
        elseif GetRandomInt(0, 1) == 0 then
            set itemId = 'I00B'
        else
            set itemId = 'I00C'
        endif
    endif
    call CreateItem(itemId, GetUnitX(dying), GetUnitY(dying))
endfunction


function Arena_HeroBurst takes unit caster, real radius, real damage, boolean heal returns nothing
    local group g = CreateGroup()
    local unit u
    local real x = GetUnitX(caster)
    local real y = GetUnitY(caster)
    call GroupEnumUnitsInRange(g, x, y, radius, null)
    loop
        set u = FirstOfGroup(g)
        exitwhen u == null
        call GroupRemoveUnit(g, u)
        if GetWidgetLife(u) > 0.405 then
            if heal then
                if IsUnitAlly(u, GetOwningPlayer(caster)) then
                    call SetUnitState(u, UNIT_STATE_LIFE, GetUnitState(u, UNIT_STATE_LIFE) + damage)
                endif
            elseif IsUnitEnemy(u, GetOwningPlayer(caster)) and u != caster then
                call UnitDamageTarget(caster, u, damage, true, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            endif
        endif
    endloop
    call DestroyGroup(g)
    set g = null
    set u = null
endfunction

function Arena_SpellVFX takes unit caster, string path returns nothing
    local effect fx = AddSpecialEffect(path, GetUnitX(caster), GetUnitY(caster))
    call DestroyEffect(fx)
    set fx = null
endfunction

function Arena_SpellAid takes unit caster, real heal, real mana returns nothing
    call Arena_ItemPulses(caster, heal, mana)
endfunction

// Profession-specific rider effects on RELIABLE stock hero spells.
// The original classic skills remain fully learnable, without loading custom W3A.
function Arena_ProfessionSpell takes unit caster, integer pid returns nothing
    local integer profession = udg_HeroKind[pid]
    local integer ability = GetSpellAbilityId()
    local real level = I2R(GetUnitAbilityLevel(caster, ability))
    local real boost = 12.0 + 14.0 * level
    local unit target = GetSpellTargetUnit()
    if level < 1.0 then
        return
    endif
    if profession == 1 then
        // Paladin: battlefield triage and an oath that punishes nearby enemies.
        call Arena_ItemPulses(caster, 25.0 + 20.0 * level, 0.0)
        call Arena_HeroBurst(caster, 215.0, boost, false)
    elseif profession == 2 then
        // Blademaster: a precise strike followed by a short-radius blade whirl.
        call Arena_HeroBurst(caster, 270.0, boost * 1.30, false)
    elseif profession == 3 then
        // Archmage: storm discharge plus party mana restoration.
        call Arena_HeroBurst(caster, 360.0, boost * 1.10, false)
        call Arena_ItemPulses(caster, 0.0, 10.0 + 11.0 * level)
    elseif profession == 4 then
        // Death knight: drain enemies, strengthen the caster.
        call Arena_HeroBurst(caster, 255.0, boost * 1.2, false)
        call SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + boost * 1.1)
    elseif profession == 5 then
        // Demon hunter: close range fel eruption with mana recuperation.
        call Arena_HeroBurst(caster, 260.0, boost * 1.35, false)
        call SetUnitState(caster, UNIT_STATE_MANA, GetUnitState(caster, UNIT_STATE_MANA) + 10.0 + 7.0 * level)
    elseif profession == 6 then
        // Moon priestess: party moonlight blessing with modest splash damage.
        call Arena_ItemPulses(caster, 18.0 + 15.0 * level, 5.0 * level)
        call Arena_HeroBurst(caster, 280.0, boost * 0.65, false)
    elseif profession == 7 then
        // Alchemist: unstable reagent bursts followed by a small antidote pulse.
        call Arena_HeroBurst(caster, 330.0, boost * 1.10, false)
        call Arena_ItemPulses(caster, 12.0 + 12.0 * level, 0.0)
    elseif profession == 8 then
        // Mountain king: ground-shattering shockwave with heavy local damage.
        call Arena_HeroBurst(caster, 245.0, boost * 1.55, false)
    elseif profession == 9 then
        // Warden: shadow execution; more effective with a valid selected target.
        if target != null and IsUnitEnemy(target, GetOwningPlayer(caster)) and GetWidgetLife(target) > 0.405 then
            call UnitDamageTarget(caster, target, boost * 1.10, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
        endif
        call Arena_HeroBurst(caster, 235.0, boost * 0.80, false)
    elseif profession == 10 then
        // Lich: deathly frost field with sustain from the siphoned essence.
        call Arena_HeroBurst(caster, 365.0, boost * 1.25, false)
        call SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + boost * 0.55)
    endif
    set target = null
endfunction

function Arena_CustomSpell takes integer kind, integer slot returns integer
    if kind == 1 then
        if slot == 1 then
            return 'A101'
        elseif slot == 2 then
            return 'A102'
        elseif slot == 3 then
            return 'A10D'
        elseif slot == 4 then
            return 'A10E'
        endif
    elseif kind == 2 then
        if slot == 1 then
            return 'A103'
        elseif slot == 2 then
            return 'A104'
        elseif slot == 3 then
            return 'A10F'
        elseif slot == 4 then
            return 'A10G'
        endif
    elseif kind == 3 then
        if slot == 1 then
            return 'A105'
        elseif slot == 2 then
            return 'A106'
        elseif slot == 3 then
            return 'A10H'
        elseif slot == 4 then
            return 'A10I'
        endif
    elseif kind == 4 then
        if slot == 1 then
            return 'A107'
        elseif slot == 2 then
            return 'A108'
        elseif slot == 3 then
            return 'A10J'
        elseif slot == 4 then
            return 'A10K'
        endif
    elseif kind == 5 then
        if slot == 1 then
            return 'A109'
        elseif slot == 2 then
            return 'A10A'
        elseif slot == 3 then
            return 'A10L'
        elseif slot == 4 then
            return 'A10M'
        endif
    elseif kind == 6 then
        if slot == 1 then
            return 'A10B'
        elseif slot == 2 then
            return 'A10C'
        elseif slot == 3 then
            return 'A10N'
        elseif slot == 4 then
            return 'A10O'
        endif
    elseif kind == 7 then
        if slot == 1 then
            return 'A111'
        elseif slot == 2 then
            return 'A112'
        elseif slot == 3 then
            return 'A113'
        elseif slot == 4 then
            return 'A114'
        endif
    elseif kind == 8 then
        if slot == 1 then
            return 'A115'
        elseif slot == 2 then
            return 'A116'
        elseif slot == 3 then
            return 'A117'
        elseif slot == 4 then
            return 'A118'
        endif
    elseif kind == 9 then
        if slot == 1 then
            return 'A119'
        elseif slot == 2 then
            return 'A11A'
        elseif slot == 3 then
            return 'A11B'
        elseif slot == 4 then
            return 'A11C'
        endif
    elseif kind == 10 then
        if slot == 1 then
            return 'A11D'
        elseif slot == 2 then
            return 'A11E'
        elseif slot == 3 then
            return 'A11F'
        elseif slot == 4 then
            return 'A11G'
        endif
    endif
    return 0
endfunction

function Arena_CustomArea takes unit caster, real radius, real amount, boolean healing returns nothing
    local group g = CreateGroup()
    local unit u
    call GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), radius, null)
    loop
        set u = FirstOfGroup(g)
        exitwhen u == null
        call GroupRemoveUnit(g, u)
        if GetWidgetLife(u) > 0.405 then
            if healing and IsUnitAlly(u, GetOwningPlayer(caster)) and IsUnitType(u, UNIT_TYPE_HERO) then
                call SetUnitState(u, UNIT_STATE_LIFE, GetUnitState(u, UNIT_STATE_LIFE) + amount)
            elseif not healing and IsUnitEnemy(u, GetOwningPlayer(caster)) then
                call UnitDamageTarget(caster, u, amount, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            endif
        endif
    endloop
    call DestroyGroup(g)
    set u = null
    set g = null
endfunction

function Arena_CustomSummon takes unit caster, integer rawId, integer count, real duration returns nothing
    local unit u
    local integer i = 0
    loop
        exitwhen i >= count
        set u = CreateUnit(GetOwningPlayer(caster), rawId, GetUnitX(caster) + GetRandomReal(-130.0, 130.0), GetUnitY(caster) + GetRandomReal(-130.0, 130.0), 270.0)
        if u != null then
            call UnitApplyTimedLife(u, 'BTLF', duration)
            call IssuePointOrder(u, "attack", GetUnitX(caster) + 500.0, GetUnitY(caster))
        endif
        set i = i + 1
    endloop
    set u = null
endfunction

function Arena_CustomMove takes unit caster, real distance returns nothing
    local real a = GetUnitFacing(caster) * bj_DEGTORAD
    call SetUnitPosition(caster, GetUnitX(caster) + distance * Cos(a), GetUnitY(caster) + distance * Sin(a))
endfunction

function Arena_CustomFinisher takes unit caster, real damage returns nothing
    local group g = CreateGroup()
    local unit target
    call GroupEnumUnitsInRange(g, GetUnitX(caster), GetUnitY(caster), 450.0, null)
    loop
        set target = FirstOfGroup(g)
        exitwhen target == null
        call GroupRemoveUnit(g, target)
        if IsUnitEnemy(target, GetOwningPlayer(caster)) and GetWidgetLife(target) > 0.405 then
            if GetWidgetLife(target) < GetUnitState(target, UNIT_STATE_MAX_LIFE) * 0.25 then
                call UnitDamageTarget(caster, target, damage * 2.4, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            else
                call UnitDamageTarget(caster, target, damage, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            endif
            exitwhen true
        endif
    endloop
    call DestroyGroup(g)
    set target = null
    set g = null
endfunction

function Arena_CustomCast takes unit caster, integer id returns boolean
    local integer pid = GetPlayerId(GetOwningPlayer(caster))
    local integer role
    local integer slot = 1
    local integer rank
    local integer i = 0
    local real amount
    if pid < 0 or pid > 3 or udg_Heroes[pid] != caster then
        return false
    endif
    set role = udg_HeroKind[pid]
    loop
        exitwhen slot > 4 or Arena_CustomSpell(role, slot) == id
        set slot = slot + 1
    endloop
    if slot > 4 then
        return false
    endif
    set rank = GetUnitAbilityLevel(caster, id)
    set amount = 32.0 + 21.0 * I2R(rank)
    if slot == 1 then
        // Q is the offensive identity: execution, pierce, leap, or magic blast.
        if role == 2 or role == 5 or role == 9 then
            call Arena_CustomMove(caster, 200.0 + 30.0 * I2R(rank))
            call Arena_CustomArea(caster, 310.0, amount * 1.3, false)
        elseif role == 1 or role == 4 or role == 9 then
            call Arena_CustomFinisher(caster, amount * 2.5)
        else
            call Arena_CustomArea(caster, 390.0 + 22.0 * I2R(rank), amount * 1.8, false)
        endif
        if role == 6 then
            call Arena_CustomArea(caster, 450.0, amount * 0.65, true)
        elseif role == 7 then
            call Arena_CustomArea(caster, 260.0, amount, false)
        endif
    elseif slot == 2 then
        // W: persistent-feeling area patterns, regeneration or resource manipulation.
        if role == 1 or role == 6 then
            call Arena_CustomArea(caster, 600.0, amount * 2.1, true)
        elseif role == 4 then
            call Arena_CustomSummon(caster, 'uske', 1 + rank / 2, 14.0)
        elseif role == 8 then
            call Arena_CustomArea(caster, 300.0, amount * 1.5, false)
        elseif role == 5 or role == 3 then
            call Arena_CustomArea(caster, 520.0, amount * 1.1, false)
            call SetUnitState(caster, UNIT_STATE_MANA, GetUnitState(caster, UNIT_STATE_MANA) + amount)
        else
            set i = 0
            loop
                exitwhen i >= 4
                call Arena_CustomArea(caster, 260.0 + I2R(i) * 65.0, amount * 0.50, false)
                set i = i + 1
            endloop
        endif
    elseif slot == 3 then
        // E: defensive stance, minions, energy conversion or retreat.
        if role == 2 or role == 4 or role == 10 then
            call Arena_CustomSummon(caster, 'uske', 1 + rank / 2, 12.0 + I2R(rank))
        elseif role == 9 then
            call Arena_CustomMove(caster, 230.0 + 20.0 * I2R(rank))
            call SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + amount)
        elseif role == 3 or role == 6 or role == 7 then
            call Arena_ItemPulses(caster, amount, amount * 0.7)
        else
            call SetUnitState(caster, UNIT_STATE_LIFE, GetUnitState(caster, UNIT_STATE_LIFE) + amount * 2.4)
            call Arena_CustomArea(caster, 240.0, amount * 0.4, false)
        endif
    else
        // R: class-defining ultimates; each scales with its own signature support.
        if role == 1 then
            set i = 0
            loop
                exitwhen i >= 4
                if udg_Heroes[i] != null and GetWidgetLife(udg_Heroes[i]) <= 0.405 and IsUnitAlly(udg_Heroes[i], GetOwningPlayer(caster)) then
                    call ReviveHero(udg_Heroes[i], GetUnitX(caster), GetUnitY(caster), true)
                endif
                set i = i + 1
            endloop
            call Arena_CustomArea(caster, 900.0, amount * 3.1, true)
        elseif role == 2 then
            call Arena_CustomSummon(caster, 'uske', 2, 16.0)
            call Arena_CustomArea(caster, 550.0, amount * 4.4, false)
        elseif role == 3 or role == 10 then
            set i = 0
            loop
                exitwhen i >= 8
                call Arena_CustomArea(caster, 600.0 + I2R(i) * 25.0, amount * 0.58, false)
                set i = i + 1
            endloop
        elseif role == 4 then
            call Arena_CustomSummon(caster, 'uske', 3 + rank, 25.0)
        elseif role == 5 then
            call Arena_CustomSummon(caster, 'nfel', 2, 16.0)
            call Arena_CustomArea(caster, 550.0, amount * 2.4, false)
        elseif role == 6 then
            call Arena_CustomArea(caster, 850.0, amount * 2.7, true)
            call Arena_CustomArea(caster, 850.0, amount * 1.9, false)
        elseif role == 7 then
            call Arena_CustomArea(caster, 720.0, amount * 2.0, true)
            call Arena_CustomArea(caster, 720.0, amount * 2.0, false)
            call SetPlayerState(GetOwningPlayer(caster), PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(GetOwningPlayer(caster), PLAYER_STATE_RESOURCE_GOLD) + rank * 35)
        elseif role == 8 then
            call Arena_CustomSummon(caster, 'hfoo', 2 + rank / 2, 18.0)
            call Arena_CustomArea(caster, 740.0, amount * 3.0, false)
        else
            call Arena_CustomFinisher(caster, amount * 6.0)
            call Arena_CustomArea(caster, 400.0, amount * 1.9, false)
        endif
    endif
    return true
endfunction

function Trig_HeroSpell_Actions takes nothing returns nothing
    local unit hero = GetTriggerUnit()
    local integer id = GetSpellAbilityId()
    local real lv = I2R(GetUnitAbilityLevel(hero, id))
    local real amount = 30.0 + 20.0 * lv
    if hero == null or lv < 1.0 then
        return
    endif
    if Arena_CustomCast(hero, id) then
        return
    endif
    if GetPlayerId(GetOwningPlayer(hero)) >= 0 and GetPlayerId(GetOwningPlayer(hero)) < 4 then
        if hero == udg_Heroes[GetPlayerId(GetOwningPlayer(hero))] then
            call Arena_ProfessionSpell(hero, GetPlayerId(GetOwningPlayer(hero)))
        endif
    endif
    if id == 'A101' or id == 'A10B' then
        call Arena_HeroBurst(hero, 260.0, amount, false)
    elseif id == 'A102' or id == 'A10C' then
        call Arena_SpellAid(hero, 35.0 + 25.0 * lv, 10.0 * lv)
    elseif id == 'A103' then
        call Arena_HeroBurst(hero, 450.0, amount * 1.2, false)
    elseif id == 'A104' then
        call SetUnitState(hero, UNIT_STATE_LIFE, GetUnitState(hero, UNIT_STATE_LIFE) + amount * 1.4)
    elseif id == 'A105' or id == 'A108' then
        call Arena_HeroBurst(hero, 490.0, amount * 1.4, false)
    elseif id == 'A106' then
        call Arena_SpellAid(hero, 0.0, 30.0 + 15.0 * lv)
    elseif id == 'A107' then
        call Arena_HeroBurst(hero, 250.0, amount, false)
        call SetUnitState(hero, UNIT_STATE_LIFE, GetUnitState(hero, UNIT_STATE_LIFE) + amount)
    elseif id == 'A109' then
        call Arena_HeroBurst(hero, 280.0, amount * 1.6, false)
    elseif id == 'A10A' then
        call SetUnitState(hero, UNIT_STATE_LIFE, GetUnitState(hero, UNIT_STATE_LIFE) + amount * 1.3)
    elseif id == 'A111' or id == 'A115' or id == 'A119' or id == 'A11D' then
        call Arena_HeroBurst(hero, 325.0, amount * 1.15, false)
        call Arena_SpellVFX(hero, "Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl")
    elseif id == 'A112' or id == 'A116' or id == 'A11A' or id == 'A11E' then
        call Arena_SpellAid(hero, amount * 1.20, amount * 0.30)
    elseif id == 'A113' or id == 'A117' or id == 'A11B' or id == 'A11F' then
        call SetUnitState(hero, UNIT_STATE_LIFE, GetUnitState(hero, UNIT_STATE_LIFE) + amount * 1.50)
        call Arena_SpellVFX(hero, "Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl")
    elseif id == 'A114' or id == 'A118' or id == 'A11C' or id == 'A11G' then
        call Arena_HeroBurst(hero, 560.0, amount * 2.3, false)
        call Arena_SpellAid(hero, amount, 0.0)
        call Arena_SpellVFX(hero, "Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl")
    endif
    set hero = null
endfunction

function Arena_UpdateHeroLabels takes nothing returns nothing
    // No follower-name texttags above playable heroes.
endfunction

function Arena_CreateEnemy takes integer unitId, real x, real y returns nothing
    local unit u = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), unitId, x, y, 270.0)
    if u == null then
        return
    endif
    set udg_EnemiesAlive = udg_EnemiesAlive + 1
    call SetUnitUserData(u, 777)
    call SetUnitCreepGuard(u, false)
    call UnitWakeUp(u)
    call SetUnitAcquireRange(u, 4000.0)
    call IssuePointOrder(u, "attack", 0.0, 0.0)
    set u = null
endfunction

function Arena_SpawnRing takes integer unitId, integer count, real dist returns nothing
    local integer i = 0
    local integer scaled = (count * (udg_HumanCount + 2) + 3) / 4
    local real ang
    if scaled < 2 then
        set scaled = 2
    endif
    loop
        exitwhen i >= scaled or udg_EnemiesAlive >= 70
        set ang = (3.14159 * 2.0) * I2R(i) / I2R(scaled)
        call Arena_CreateEnemy(unitId, dist * Cos(ang) + GetRandomReal(-70.0, 70.0), dist * Sin(ang) + GetRandomReal(-70.0, 70.0))
        set i = i + 1
    endloop
endfunction


function Arena_EliteName takes integer wave returns string
    if wave == 5 then
        return "Вожак головорезов"
    elseif wave == 10 then
        return "Капитан беззакония"
    elseif wave == 15 then
        return "Тролль-знахарь"
    elseif wave == 20 then
        return "Огр-землелом"
    elseif wave == 25 then
        return "Пророк костей"
    elseif wave == 30 then
        return "Могильный исполин"
    elseif wave == 35 then
        return "Ловчий Скверны"
    elseif wave == 40 then
        return "Пожиратель стали"
    elseif wave == 45 then
        return "Сборщик душ"
    endif
    return "Предвестник Каз'Рула"
endfunction

function Arena_EliteType takes integer wave returns integer
    if wave == 5 then
        return 'nrog'
    elseif wave == 10 then
        return 'ngno'
    elseif wave == 15 then
        return 'nftr'
    elseif wave == 20 then
        return 'nogr'
    elseif wave == 25 then
        return 'nska'
    elseif wave == 30 then
        return 'ucry'
    elseif wave == 35 then
        return 'nfel'
    elseif wave == 40 then
        return 'nogr'
    elseif wave == 45 then
        return 'uabo'
    endif
    return 'uabo'
endfunction

function Arena_EliteVoicePath takes integer wave returns string
    if wave <= 10 then
        return "Units\\Creeps\\Bandit\\BanditPissed1.wav"
    elseif wave <= 20 then
        return "Units\\Creeps\\Ogre\\OgrePissed1.wav"
    elseif wave <= 30 then
        return "Units\\Undead\\CryptFiend\\CryptFiendPissed1.wav"
    elseif wave <= 40 then
        return "Units\\Demon\\Felgaurd\\FelgaurdPissed1.wav"
    endif
    return "Units\\Undead\\Abomination\\AbominationPissed1.wav"
endfunction

function Arena_EliteTaunt takes integer wave returns string
    if wave == 5 then
        return "Слабаков не щадить! Моя арена!"
    elseif wave == 10 then
        return "Все ваши сокровища теперь мои!"
    elseif wave == 15 then
        return "Духи жаждут ваших душ!"
    elseif wave == 20 then
        return "Я сотру вас в пыль!"
    elseif wave == 25 then
        return "Мертвые восстанут по моему слову!"
    elseif wave == 30 then
        return "Земля поглотит живых!"
    elseif wave == 35 then
        return "Скверна сильнее вашей воли!"
    elseif wave == 40 then
        return "Пусть ваши клинки сломаются!"
    elseif wave == 45 then
        return "Ваши души принадлежат тьме!"
    endif
    return "Ваш конец станет началом Каз'Рула!"
endfunction

function Arena_EliteAnnouncement takes integer wave, real x, real y returns nothing
    local texttag tag = CreateTextTag()
    local sound alert = CreateSound(Arena_EliteVoicePath(wave), false, false, false, 10, 10, "")
    local string title = Arena_EliteName(wave)
    call Arena_Msg("|cffff8844[ОСОБАЯ ВОЛНА " + I2S(wave) + "]|r " + title + ": |cffffcc77" + Arena_EliteTaunt(wave) + "|r")
    call SetTextTagText(tag, "|cffff6622" + title + "|r", 0.035)
    call SetTextTagPos(tag, x - 180.0, y, 140.0)
    call SetTextTagColor(tag, 255, 150, 65, 255)
    call SetTextTagPermanent(tag, false)
    call SetTextTagLifespan(tag, 7.0)
    call SetTextTagFadepoint(tag, 5.0)
    call PingMinimap(x, y, 5.0)
    if alert != null then
        call SetSoundVolume(alert, 105)
        call StartSound(alert)
        call KillSoundWhenDone(alert)
    endif
    set tag = null
    set alert = null
endfunction

function Arena_SpawnElite takes integer wave returns nothing
    local real x = 0.0
    local real y = 1510.0
    local unit elite
    if udg_EnemiesAlive >= 70 then
        return
    endif
    set elite = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), Arena_EliteType(wave), x, y, 270.0)
    if elite == null then
        return
    endif
    set udg_EnemiesAlive = udg_EnemiesAlive + 1
    call SetUnitUserData(elite, 888)
    call SetUnitScale(elite, 1.20 + 0.003 * I2R(wave), 1.20 + 0.003 * I2R(wave), 1.20 + 0.003 * I2R(wave))
    call SetUnitVertexColor(elite, 255, 155, 110, 255)
    call SetUnitCreepGuard(elite, false)
    call UnitWakeUp(elite)
    call SetUnitAcquireRange(elite, 4500.0)
    // A small defensive aura makes the miniboss recognizable without a dragon-like damage spike.
    if wave >= 25 then
        call UnitAddAbility(elite, 'ACav')
    endif
    call Arena_EliteAnnouncement(wave, x, y)
    call IssuePointOrder(elite, "attack", 0.0, 0.0)
    set elite = null
endfunction

function Arena_PayWaveGold takes integer gold returns nothing
    local integer i = 0
    loop
        exitwhen i > 3
        if Arena_IsHuman(i) then
            call SetPlayerState(Player(i), PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(Player(i), PLAYER_STATE_RESOURCE_GOLD) + gold)
        endif
        set i = i + 1
    endloop
endfunction

function Arena_WaveTheme takes integer wave returns string
    local integer chapter = (wave - 1) / 5
    if chapter == 0 then
        return "Разбойничий тракт"
    elseif chapter == 1 then
        return "Гнолльи стаи"
    elseif chapter == 2 then
        return "Троллья засада"
    elseif chapter == 3 then
        return "Огрские заставы"
    elseif chapter == 4 then
        return "Восстание костей"
    elseif chapter == 5 then
        return "Склеп паучьего короля"
    elseif chapter == 6 then
        return "Осквернённая охота"
    elseif chapter == 7 then
        return "Врата Скверны"
    elseif chapter == 8 then
        return "Некрополь"
    endif
    return "Последняя армия Каз'Рула"
endfunction

function Arena_SpawnWaveCreeps takes integer wave returns nothing
    local integer chapter = (wave - 1) / 5
    local integer front = 5 + wave / 8
    local integer back = 2 + wave / 15
    local integer eliteSupport = 0
    // 10 chapters of 5 waves, each with a coherent battlefield identity.
    // Tanky units enter slowly; no dragons or huge surprise damage spikes.
    if ModuloInteger(wave, 5) == 0 then
        set eliteSupport = 1
    endif
    if chapter == 0 then
        call Arena_SpawnRing('nban', front, 1210.0)
        call Arena_SpawnRing('ngno', back, 1480.0)
    elseif chapter == 1 then
        call Arena_SpawnRing('nrog', front, 1220.0)
        call Arena_SpawnRing('ngna', back, 1450.0)
    elseif chapter == 2 then
        call Arena_SpawnRing('nftr', front, 1260.0)
        call Arena_SpawnRing('nftb', back, 1480.0)
    elseif chapter == 3 then
        call Arena_SpawnRing('ngno', front + 2, 1220.0)
        call Arena_SpawnRing('nogr', back, 1470.0)
    elseif chapter == 4 then
        call Arena_SpawnRing('uske', front + 2, 1210.0)
        call Arena_SpawnRing('nska', back + 1, 1490.0)
    elseif chapter == 5 then
        call Arena_SpawnRing('uske', front, 1240.0)
        call Arena_SpawnRing('ucry', back, 1490.0)
    elseif chapter == 6 then
        call Arena_SpawnRing('nfel', front, 1250.0)
        call Arena_SpawnRing('nska', back, 1490.0)
    elseif chapter == 7 then
        call Arena_SpawnRing('nfel', front + 1, 1220.0)
        call Arena_SpawnRing('nogr', back, 1480.0)
    elseif chapter == 8 then
        call Arena_SpawnRing('uske', front + 3, 1210.0)
        call Arena_SpawnRing('nfel', back + 1, 1480.0)
    else
        call Arena_SpawnRing('uske', front + 4, 1240.0)
        call Arena_SpawnRing('uabo', 1 + eliteSupport, 1480.0)
        call Arena_SpawnRing('nska', back + 1, 1600.0)
    endif
endfunction

function Arena_SpawnBoss takes nothing returns nothing
    if udg_Boss != null or udg_GameOver then
        return
    endif
    set udg_BossPhase = 0
    set udg_Boss = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), 'Nplh', 0.0, 900.0, 270.0)
    if udg_Boss == null then
        call Arena_Msg("Boss creation failed: check Nplh in Object Editor.")
        return
    endif
    // SetHeroProperName is unavailable on 1.26a; name is announced via messages/quest.
    call SetHeroLevel(udg_Boss, 14 + udg_HumanCount, false)
    call SetHeroStr(udg_Boss, 52 + 12 * udg_HumanCount, true)
    call SetHeroAgi(udg_Boss, 20 + 3 * udg_HumanCount, true)
    call SetHeroInt(udg_Boss, 25 + 4 * udg_HumanCount, true)
    call SetUnitState(udg_Boss, UNIT_STATE_LIFE, GetUnitState(udg_Boss, UNIT_STATE_MAX_LIFE))
    call UnitAddAbility(udg_Boss, 'ACua')
    call UnitAddAbility(udg_Boss, 'ACah')
    call UnitAddItemById(udg_Boss, 'ckng')
    call UnitAddItemById(udg_Boss, 'modt')
    call SetUnitAcquireRange(udg_Boss, 5000.0)
    call IssuePointOrder(udg_Boss, "attack", 0.0, 0.0)
    call QuestSetEnabled(udg_QuestBoss, true)
    call QuestSetDiscovered(udg_QuestBoss, true)
    call Arena_Msg("|cffff4444Kaz'Rul has arrived! At 65% and 30% health he summons reinforcements.|r")
    call PingMinimap(0.0, 900.0, 6.00)
endfunction

//===========================================================================
function Arena_CountPickedHumans takes nothing returns integer
    local integer pid = 0
    local integer count = 0
    loop
        exitwhen pid >= 4
        if Arena_IsHuman(pid) and udg_Picked[pid] then
            set count = count + 1
        endif
        set pid = pid + 1
    endloop
    return count
endfunction

function Arena_TryStartWaves takes nothing returns nothing
    if udg_WavesStarted or Arena_CountPickedHumans() < udg_HumanCount then
        return
    endif
    set udg_WavesStarted = true
    call DisableTrigger(gg_trg_Pick)
    call DisableTrigger(gg_trg_SelectPoll)
    call PauseTimer(udg_SelectTimeout)
    call TimerStart(udg_WaveTimer, 15.00, false, function Arena_DoNothing)
    call TimerDialogSetTitle(udg_WaveTD, "Волна 1")
    call TimerDialogDisplay(udg_WaveTD, true)
    call Arena_Msg("Все герои выбраны. Первая волна через 15 сек. Магазины по углам центра.")
endfunction


function Arena_SelectX takes integer k returns real
    return -1600.0 + 800.0 * I2R(ModuloInteger(k - 1, 5))
endfunction

function Arena_SelectY takes integer k returns real
    if k <= 5 then
        return 6500.0
    endif
    return 7200.0
endfunction

// Keep the selection showcase independent of custom object imports.
// The selected playable hero still uses the custom hero ID via Arena_HeroType.
function Arena_HeroPreviewType takes integer kind returns integer
    if kind == 1 then
        return 'Hpal'
    elseif kind == 2 then
        return 'Obla'
    elseif kind == 3 then
        return 'Hamg'
    elseif kind == 4 then
        return 'Udea'
    elseif kind == 5 then
        return 'Edem'
    elseif kind == 6 then
        return 'Emoo'
    elseif kind == 7 then
        return 'Nalc'
    elseif kind == 8 then
        return 'Hmkg'
    elseif kind == 9 then
        return 'Ewar'
    endif
    return 'Ulic'
endfunction

function Arena_CreateSelectionPlaza takes nothing returns nothing
    local integer k = 1
    local real x
    local real y
    local rect zone
    local texttag label
    local unit preview
    loop
        exitwhen k > 10
        set x = Arena_SelectX(k)
        set y = Arena_SelectY(k)
        set zone = Rect(x - 235.0, y - 235.0, x + 235.0, y + 235.0)
        set udg_SelectRegion[k] = CreateRegion()
        call RegionAddRect(udg_SelectRegion[k], zone)
        call TriggerRegisterEnterRegion(gg_trg_Pick, udg_SelectRegion[k], null)
        set preview = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), Arena_HeroPreviewType(k), x, y, 270.0)
        set udg_SelectPreview[k] = preview
        if preview != null then
            call SetUnitInvulnerable(preview, true)
            call SetUnitPathing(preview, false)
            call PauseUnit(preview, true)
            call SetUnitScale(preview, 1.10, 1.10, 1.10)
        endif
        set label = CreateTextTag()
        call SetTextTagText(label, I2S(k) + ". " + Arena_HeroProfession(k), 0.025)
        call SetTextTagPos(label, x - 175.0, y, 200.0)
        call SetTextTagColor(label, 255, 220, 130, 255)
        call SetTextTagPermanent(label, true)
        call SetTextTagVisibility(label, true)
        call RemoveRect(zone)
        set k = k + 1
    endloop
    set preview = null
    set zone = null
    set label = null
endfunction

function Arena_SelectHero takes integer pid, integer k returns nothing
    if pid < 0 or pid >= 4 or k < 1 or k > 10 then
        return
    endif
    if udg_GameOver or udg_Picked[pid] or not Arena_IsHuman(pid) then
        return
    endif
    // Never commit the pick or hide the Wisp until a hero is created successfully.
    if not Arena_SpawnHero(pid, k) then
        set udg_PendingPick[pid] = 0
        return
    endif
    set udg_Picked[pid] = true
    set udg_PendingPick[pid] = 0
    set udg_PickCount = udg_PickCount + 1
    if udg_SelectWisp[pid] != null then
        call SetUnitPathing(udg_SelectWisp[pid], false)
        call ShowUnit(udg_SelectWisp[pid], false)
    endif
    call Arena_Msg(GetPlayerName(Player(pid)) + " выбрал профессию: " + Arena_HeroProfession(k))
    call Arena_TryStartWaves()
endfunction

function Trig_Pick_Actions takes nothing returns nothing
    local unit u = GetEnteringUnit()
    local integer pid
    local integer k = 1
    if u == null then
        return
    endif
    set pid = GetPlayerId(GetOwningPlayer(u))
    if pid >= 0 and pid < 4 and u == udg_SelectWisp[pid] and not udg_Picked[pid] then
        loop
            exitwhen k > 10
            if GetTriggeringRegion() == udg_SelectRegion[k] then
                set udg_PendingPick[pid] = k
                exitwhen true
            endif
            set k = k + 1
        endloop
    endif
    set u = null
endfunction

function Trig_SelectPoll_Actions takes nothing returns nothing
    local integer pid = 0
    local integer k
    local real dx
    local real dy
    local unit u
    loop
        exitwhen pid >= 4
        set u = udg_SelectWisp[pid]
        if u != null and Arena_IsHuman(pid) and not udg_Picked[pid] then
            if udg_PendingPick[pid] != 0 then
                call Arena_SelectHero(pid, udg_PendingPick[pid])
            else
                set k = 1
                loop
                    exitwhen k > 10
                    set dx = GetUnitX(u) - Arena_SelectX(k)
                    set dy = GetUnitY(u) - Arena_SelectY(k)
                    if dx * dx + dy * dy <= 52900.0 then
                        set udg_PendingPick[pid] = k
                        exitwhen true
                    endif
                    set k = k + 1
                endloop
            endif
        endif
        set pid = pid + 1
    endloop
    set u = null
endfunction

function Arena_KillWaveEnemies takes nothing returns nothing
    local group g = CreateGroup()
    local unit u
    call GroupEnumUnitsOfPlayer(g, Player(PLAYER_NEUTRAL_AGGRESSIVE), null)
    loop
        set u = FirstOfGroup(g)
        exitwhen u == null
        call GroupRemoveUnit(g, u)
        if u == udg_Boss or GetUnitUserData(u) == 777 or GetUnitUserData(u) == 888 then
            call KillUnit(u)
        endif
    endloop
    call DestroyGroup(g)
    set g = null
    set u = null
endfunction

function Trig_TestChat_Actions takes nothing returns nothing
    local integer pid = GetPlayerId(GetTriggerPlayer())
    local string cmd = GetEventPlayerChatString()
    if cmd == "-kill" and pid == 0 then
        call Arena_Msg("Тест: зачистка всех врагов текущей волны.")
        call Arena_KillWaveEnemies()
    elseif cmd == "-next" and pid == 0 then
        if udg_WavesStarted and not udg_GameOver and udg_Boss == null then
            call Arena_KillWaveEnemies()
            call TimerStart(udg_WaveTimer, 0.05, false, function Arena_DoNothing)
            call Arena_Msg("|cff88ccffСледующая волна вызывается досрочно.|r")
        else
            call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 6.0, "Команда -next доступна после выбора героев и до появления босса.")
        endif
    elseif cmd == "-maxlvl" then
        if pid >= 0 and pid < 4 and udg_Heroes[pid] != null then
            call SetHeroLevel(udg_Heroes[pid], 20, true)
            call Arena_SyncHeroGrowth(pid)
            call Arena_UpdateCustomRanks()
            call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 8.0, "Герой повышен до 20 уровня. Очки умений доступны для распределения.")
        endif
    elseif cmd == "-stats" then
        if pid >= 0 and pid < 4 and udg_Heroes[pid] != null then
            call Arena_SyncHeroGrowth(pid)
            call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 14.0, "|cff66ccffУровень " + I2S(GetHeroLevel(udg_Heroes[pid])) + " | Сила " + I2S(GetHeroStr(udg_Heroes[pid], false)) + " | Ловкость " + I2S(GetHeroAgi(udg_Heroes[pid], false)) + " | Разум " + I2S(GetHeroInt(udg_Heroes[pid], false)) + "|r")
        endif
    elseif cmd == "-revive" then
        if udg_Heroes[pid] != null and GetWidgetLife(udg_Heroes[pid]) <= 0.405 then
            call ReviveHero(udg_Heroes[pid], 0.0, 0.0, true)
        endif
    endif
endfunction

function Trig_SelectChat_Actions takes nothing returns nothing
    local integer pid = GetPlayerId(GetTriggerPlayer())
    local string msg = GetEventPlayerChatString()
    local integer k
    if pid < 0 or pid >= 4 or udg_Picked[pid] then
        return
    endif
    if SubString(msg, 0, 6) == "-pick " then
        set k = S2I(SubString(msg, 6, 8))
        if k >= 1 and k <= 10 then
            call Arena_SelectHero(pid, k)
        else
            call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 8.0, "Команда: -pick 1 ... -pick 10")
        endif
    endif
endfunction

function Arena_AutoPick takes nothing returns nothing
    local integer pid = 0
    loop
        exitwhen pid >= 4
        if Arena_IsHuman(pid) and not udg_Picked[pid] then
            call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 8.0, "Время вышло: случайный герой.")
            call Arena_SelectHero(pid, GetRandomInt(1, 10))
        endif
        set pid = pid + 1
    endloop
endfunction

function Arena_ShowPicks takes nothing returns nothing
    local integer pid = 0
    local unit wisp
    // IMPORTANT: spawn the player's controllable Wisp before any hero previews.
    // This makes the first interaction independent of custom Object Editor files.
    set gg_trg_SelectPoll = CreateTrigger()
    call TriggerRegisterTimerEvent(gg_trg_SelectPoll, 0.25, true)
    call TriggerAddAction(gg_trg_SelectPoll, function Trig_SelectPoll_Actions)
    set gg_trg_SelectChat = CreateTrigger()
    loop
        exitwhen pid >= 4
        call TriggerRegisterPlayerChatEvent(gg_trg_SelectChat, Player(pid), "-pick ", false)
        if Arena_IsHuman(pid) then
            set wisp = CreateUnit(Player(pid), 'ewsp', -225.0 + 150.0 * I2R(pid), 5700.0, 90.0)
            set udg_SelectWisp[pid] = wisp
            if wisp != null then
                call SetUnitInvulnerable(wisp, true)
                call SetUnitMoveSpeed(wisp, 310.0)
                call SelectUnitForPlayerSingle(wisp, Player(pid))
                call PanCameraToTimedForPlayer(Player(pid), 0.0, 6790.0, 0.00)
                call SetCameraFieldForPlayer(Player(pid), CAMERA_FIELD_TARGET_DISTANCE, 2300.0, 0.00)
                call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 18.0, "|cffffcc00ВЫБОР ГЕРОЯ|r: подведите светлячка к герою. Запасной способ: -pick 1 ... -pick 10. Автовыбор через 90 сек.")
            else
                call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 15.0, "Светлячок не создан: используйте -pick 1 ... -pick 10.")
            endif
        endif
        set pid = pid + 1
    endloop
    call TriggerAddAction(gg_trg_SelectChat, function Trig_SelectChat_Actions)
    call Arena_Msg("|cff88ff88[Арена 2/4]|r Светлячки созданы; создаём зал героев.")
    call Arena_CreateSelectionPlaza()
    set udg_SelectTimeout = CreateTimer()
    call TimerStart(udg_SelectTimeout, 90.00, false, function Arena_AutoPick)
    set wisp = null
endfunction

//===========================================================================
function Trig_Wave_Actions takes nothing returns nothing
    if udg_GameOver then
        return
    endif
    if udg_Wave >= 50 then
        call TimerDialogDisplay(udg_WaveTD, false)
        call Arena_SpawnBoss()
        return
    endif
    set udg_Wave = udg_Wave + 1
    set udg_WaveCleared = false
    call Arena_SpawnWaveCreeps(udg_Wave)
    if ModuloInteger(udg_Wave, 5) == 0 then
        call Arena_SpawnElite(udg_Wave)
    endif
    call Arena_PayWaveGold(38 + udg_Wave * 5)
    call Arena_Msg("|cffffcc00Волна " + I2S(udg_Wave) + "/50|r — " + Arena_WaveTheme(udg_Wave) + ". Врагов: " + I2S(udg_EnemiesAlive))
    if udg_Wave < 50 then
        call TimerDialogSetTitle(udg_WaveTD, "Волна " + I2S(udg_Wave + 1))
    else
        call TimerDialogSetTitle(udg_WaveTD, "Финальный босс")
    endif
    call TimerStart(udg_WaveTimer, 100.00, false, function Arena_DoNothing)
endfunction

//===========================================================================
function Arena_ReviveHero takes integer pid returns nothing
    local real x
    local real y
    if udg_GameOver then
        return
    endif
    if udg_Heroes[pid] == null then
        return
    endif
    if pid == 0 then
        set x = -144.0
        set y = -144.0
    elseif pid == 1 then
        set x = 144.0
        set y = -144.0
    elseif pid == 2 then
        set x = -144.0
        set y = 144.0
    else
        set x = 144.0
        set y = 144.0
    endif
    call ReviveHero(udg_Heroes[pid], x, y, true)
    call SetUnitState(udg_Heroes[pid], UNIT_STATE_LIFE, GetUnitState(udg_Heroes[pid], UNIT_STATE_MAX_LIFE) * 0.60)
    call SetUnitState(udg_Heroes[pid], UNIT_STATE_MANA, GetUnitState(udg_Heroes[pid], UNIT_STATE_MAX_MANA) * 0.40)
    call PanCameraToTimedForPlayer(Player(pid), x, y, 0.00)
    call DisplayTimedTextToPlayer(Player(pid), 0, 0, 6.00, "Вы воскресли в центре арены.")
endfunction

function Trig_Revive0 takes nothing returns nothing
    call Arena_ReviveHero(0)
endfunction
function Trig_Revive1 takes nothing returns nothing
    call Arena_ReviveHero(1)
endfunction
function Trig_Revive2 takes nothing returns nothing
    call Arena_ReviveHero(2)
endfunction
function Trig_Revive3 takes nothing returns nothing
    call Arena_ReviveHero(3)
endfunction

function Arena_CheckWaveClear takes nothing returns nothing
    if udg_WavesStarted and udg_Wave >= 1 and udg_Wave <= 50 and udg_EnemiesAlive == 0 and not udg_WaveCleared and udg_Boss == null and not udg_GameOver then
        set udg_WaveCleared = true
        call Arena_Msg("|cff66ff99Волна зачищена! Следующая через 7 секунд.|r")
        call TimerStart(udg_WaveTimer, 7.00, false, function Arena_DoNothing)
    endif
endfunction

function Trig_Death_Actions takes nothing returns nothing
    local unit u = GetDyingUnit()
    local unit killer = GetKillingUnit()
    local integer pid
    local integer reward
    if GetOwningPlayer(u) == Player(PLAYER_NEUTRAL_AGGRESSIVE) and u != udg_Boss then
        if udg_EnemiesAlive > 0 then
            set udg_EnemiesAlive = udg_EnemiesAlive - 1
        endif
        set udg_TotalKills = udg_TotalKills + 1
        call Arena_DropLoot(u)
        if GetUnitUserData(u) == 888 then
            call Arena_Msg("|cffffcc66Побеждён мини-босс! Команде начислена награда.|r")
            call Arena_PayWaveGold(50 + udg_Wave * 3)
        endif
        if udg_EnemiesAlive == 0 then
            call Arena_CheckWaveClear()
        endif
        if killer != null then
            set pid = GetPlayerId(GetOwningPlayer(killer))
            if pid >= 0 and pid < 4 and Arena_IsHuman(pid) then
                set reward = 5 + udg_Wave
                set udg_PlayerKills[pid] = udg_PlayerKills[pid] + 1
                call SetPlayerState(Player(pid), PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(Player(pid), PLAYER_STATE_RESOURCE_GOLD) + reward)
            endif
        endif
        set u = null
        set killer = null
        return
    endif
    if IsUnitType(u, UNIT_TYPE_HERO) == false or GetOwningPlayer(u) == Player(PLAYER_NEUTRAL_AGGRESSIVE) then
        set u = null
        set killer = null
        return
    endif
    set pid = GetPlayerId(GetOwningPlayer(u))
    if pid < 0 or pid > 3 or not Arena_IsHuman(pid) or u != udg_Heroes[pid] then
        set u = null
        set killer = null
        return
    endif
    call DisplayTimedTextToPlayer(Player(pid), 0, 0, 8.00, "Смерть. Воскрешение через 12 сек.")
    if pid == 0 then
        call TimerStart(udg_ReviveTimer[0], 12.00, false, function Trig_Revive0)
    elseif pid == 1 then
        call TimerStart(udg_ReviveTimer[1], 12.00, false, function Trig_Revive1)
    elseif pid == 2 then
        call TimerStart(udg_ReviveTimer[2], 12.00, false, function Trig_Revive2)
    else
        call TimerStart(udg_ReviveTimer[3], 12.00, false, function Trig_Revive3)
    endif
    set u = null
    set killer = null
endfunction

function Trig_Boss_Actions takes nothing returns nothing
    if udg_GameOver or GetDyingUnit() != udg_Boss then
        return
    endif
    set udg_GameOver = true
    call PauseTimer(udg_WaveTimer)
    call TimerDialogDisplay(udg_WaveTD, false)
    call QuestSetCompleted(udg_QuestMain, true)
    call QuestSetCompleted(udg_QuestBoss, true)
    call Arena_Msg("|cff00ff00Победа! Каз'Рул повержен. Арена остается открытой для свободной игры.|r")
    call Arena_PayWaveGold(800)
    // No CustomVictoryBJ or other forced victory/dialog/end-game call.
endfunction

//===========================================================================
function Arena_BossNova takes real damage returns nothing
    local integer i = 0
    local unit hero
    local effect fx = AddSpecialEffect("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", GetUnitX(udg_Boss), GetUnitY(udg_Boss))
    call DestroyEffect(fx)
    loop
        exitwhen i >= 4
        set hero = udg_Heroes[i]
        if hero != null and GetWidgetLife(hero) > 0.405 and IsUnitInRange(hero, udg_Boss, 600.0) then
            call UnitDamageTarget(udg_Boss, hero, damage, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
        endif
        set i = i + 1
    endloop
    set hero = null
    set fx = null
endfunction

function Trig_BossThink_Actions takes nothing returns nothing
    local real health
    if udg_GameOver or udg_Boss == null or GetWidgetLife(udg_Boss) <= 0.405 then
        return
    endif
    set health = GetUnitLifePercent(udg_Boss)
    if udg_BossPhase == 0 and health <= 65.0 then
        set udg_BossPhase = 1
        call Arena_Msg("|cffff8844Kaz'Rul summons his Bone Legion!|r")
        call Arena_SpawnRing('uske', 4 + 2 * udg_HumanCount, 780.0)
        call Arena_BossNova(45.0 + 12.0 * udg_HumanCount)
    elseif udg_BossPhase == 1 and health <= 30.0 then
        set udg_BossPhase = 2
        call Arena_Msg("|cffff4444Kaz'Rul is enraged!|r")
        call Arena_SpawnRing('uske', 3 + udg_HumanCount, 850.0)
        call UnitAddAbility(udg_Boss, 'ACro')
        call IssueImmediateOrder(udg_Boss, "roar")
        call Arena_BossNova(70.0 + 16.0 * udg_HumanCount)
    endif
endfunction

function Trig_Leave_Actions takes nothing returns nothing
    local integer pid = GetPlayerId(GetTriggerPlayer())
    if pid < 0 or pid > 3 then
        return
    endif
    if udg_Heroes[pid] != null then
        call RemoveUnit(udg_Heroes[pid])
        set udg_Heroes[pid] = null
    endif
    call Arena_RefreshBalance()
    call Arena_Msg("Игрок вышел. Игроков на арене: " + I2S(udg_HumanCount))
    call Arena_TryStartWaves()
endfunction

function Trig_Aura_Actions takes nothing returns nothing
    local integer i = 0
    local unit u
    local real life
    local real mana
    local real addHp
    local real addMp
    // Catch instant level jumps and missed level events, even with 4 players.
    set i = 0
    loop
        exitwhen i >= 4
        call Arena_SyncHeroGrowth(i)
        set i = i + 1
    endloop
    // Update custom QWER ranks for every player, including four-player matches.
    call Arena_UpdateCustomRanks()
    // Aura carriers remain at (0,0), inside the central monument.
    if udg_HumanCount >= 4 then
        return
    endif
    set i = 0
    if udg_HumanCount <= 1 then
        set addHp = 18.00
        set addMp = 10.00
    elseif udg_HumanCount == 2 then
        set addHp = 10.00
        set addMp = 5.00
    else
        set addHp = 5.00
        set addMp = 2.50
    endif
    loop
        exitwhen i > 3
        set u = udg_Heroes[i]
        if u != null then
            if GetWidgetLife(u) > 0.405 then
                set life = GetUnitState(u, UNIT_STATE_LIFE)
                set mana = GetUnitState(u, UNIT_STATE_MANA)
                if life < GetUnitState(u, UNIT_STATE_MAX_LIFE) then
                    call SetUnitState(u, UNIT_STATE_LIFE, life + addHp)
                endif
                if mana < GetUnitState(u, UNIT_STATE_MAX_MANA) then
                    call SetUnitState(u, UNIT_STATE_MANA, mana + addMp)
                endif
            endif
        endif
        set i = i + 1
    endloop
    set u = null
endfunction

//===========================================================================
function Arena_CreateQuests takes nothing returns nothing
    set udg_QuestMain = CreateQuest()
    call QuestSetTitle(udg_QuestMain, "Арена героев")
    call QuestSetDescription(udg_QuestMain, "50 волн; каждые 10 волн новый этап. Полная зачистка ускоряет следующую волну. Команды: -kill (хост), -revive (каждый игрок). Максимальный уровень 20.")
    call QuestSetIconPath(udg_QuestMain, "ReplaceableTextures\\CommandButtons\\BTNHeroPaladin.blp")
    call QuestSetRequired(udg_QuestMain, true)
    call QuestSetDiscovered(udg_QuestMain, true)
    call QuestSetEnabled(udg_QuestMain, true)

    set udg_QuestBoss = CreateQuest()
    call QuestSetTitle(udg_QuestBoss, "Каз'Рул")
    call QuestSetDescription(udg_QuestBoss, "Убейте архидемона после десятой волны.")
    call QuestSetIconPath(udg_QuestBoss, "ReplaceableTextures\\CommandButtons\\BTNInfernal.blp")
    call QuestSetRequired(udg_QuestBoss, true)
    call QuestSetDiscovered(udg_QuestBoss, false)
    call QuestSetEnabled(udg_QuestBoss, false)
endfunction

function Arena_ExplainBalance takes nothing returns nothing
    if udg_HumanCount <= 1 then
        call Arena_Msg("|cff66ccffСоло: полные ауры, сильный реген по всей карте, +HP.|r")
    elseif udg_HumanCount == 2 then
        call Arena_Msg("|cff66ccffДвое: средние ауры и реген.|r")
    elseif udg_HumanCount == 3 then
        call Arena_Msg("|cff66ccffТрое: слабый реген и аура выносливости.|r")
    else
        call Arena_Msg("|cff66ccffЧетверо: без бонусных аур. Чистая арена.|r")
    endif
endfunction

//===========================================================================
function Trig___________________________u_Actions takes nothing returns nothing
endfunction

function InitTrig___________________________u takes nothing returns nothing
    set gg_trg___________________________u = CreateTrigger()
    call TriggerAddAction(gg_trg___________________________u, function Trig___________________________u_Actions)
endfunction

function Trig_____________________________________001_Actions takes nothing returns nothing
endfunction

function InitTrig_____________________________________001 takes nothing returns nothing
    set gg_trg_____________________________________001 = CreateTrigger()
    call TriggerAddAction(gg_trg_____________________________________001, function Trig_____________________________________001_Actions)
endfunction

// Build walkable terrain and low-cost landmark geometry at runtime.
// No impassable decorations inside hero trigger pads or creep spawn circles.
function Arena_PaintDisc takes real cx, real cy, real radius, integer terrain returns nothing
    local real x = cx - radius
    local real y
    loop
        exitwhen x > cx + radius
        set y = cy - radius
        loop
            exitwhen y > cy + radius
            if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius then
                call SetTerrainType(x, y, terrain, -1, 1, 0)
            endif
            set y = y + 128.0
        endloop
        set x = x + 128.0
    endloop
endfunction

function Arena_CreateGeometry takes nothing returns nothing
    local integer k = 1
    local integer i = 0
    local real x
    local real y
    local real angle
    local destructable d
    // Flat fighting circle with an inner stone dais and a subtle grassy boundary.
    call Arena_PaintDisc(0.0, 0.0, 2200.0, 'Lgrs')
    call Arena_PaintDisc(0.0, 0.0, 1840.0, 'Lrok')
    call Arena_PaintDisc(0.0, 0.0, 760.0, 'Ldro')
    // A northern, six-pad paved selection hall with a central stone walkway.
    call Arena_PaintDisc(0.0, 6860.0, 2450.0, 'Lgrs')
    set y = 2368.0
    loop
        exitwhen y > 6210.0
        set x = -192.0
        loop
            exitwhen x > 192.0
            call SetTerrainType(x, y, 'Ldro', -1, 1, 0)
            set x = x + 128.0
        endloop
        set y = y + 128.0
    endloop
    loop
        exitwhen k > 10
        set x = Arena_SelectX(k)
        set y = Arena_SelectY(k)
        call Arena_PaintDisc(x, y, 385.0, 'Lrok')
        call Arena_PaintDisc(x, y, 270.0, 'Ldro')
        set k = k + 1
    endloop
    // Non-blocking effect landmarks: outer arc leaves the four cardinal gates clear.
    loop
        exitwhen i >= 32
        if ModuloInteger(i, 8) != 0 and ModuloInteger(i, 8) != 1 then
            set angle = 6.2831853 * I2R(i) / 32.0
            set d = CreateDestructable('LTlt', 2670.0 * Cos(angle), 2670.0 * Sin(angle), 0.0, 0.80, 0)
            if d != null then
                call SetDestructableInvulnerable(d, true)
            endif
        endif
        set i = i + 1
    endloop
    set d = null
endfunction

function Arena_CreateAuraMonument takes nothing returns nothing
    local unit statue = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), 'hfoo', 0.0, 0.0, 270.0)
    local texttag title = CreateTextTag()
    if statue != null then
        call SetUnitPathing(statue, false)
        call SetUnitInvulnerable(statue, true)
        call PauseUnit(statue, true)
        call SetUnitScale(statue, 0.80, 0.80, 0.80)
        call SetUnitVertexColor(statue, 165, 185, 255, 220)
        call UnitAddAbility(statue, 'Aloc')
    endif
    call AddSpecialEffect("Abilities\\Spells\\Other\\GeneralAuraTarget\\GeneralAuraTarget.mdl", 0.0, 0.0)
    call SetTextTagText(title, "ХРАНИТЕЛЬ АРЕНЫ", 0.022)
    call SetTextTagPos(title, -170.0, 0.0, 220.0)
    call SetTextTagPermanent(title, true)
    call SetTextTagColor(title, 165, 205, 255, 255)
    set title = null
    set statue = null
endfunction

function Trig_Arena_Actions takes nothing returns nothing
    local integer i
    call FogEnableOff()
    call FogMaskEnableOff()
    call SetTimeOfDay(12.00)
    call SetTimeOfDayScale(0.00)
    call SuspendTimeOfDay(true)
    call SetCameraPosition(0.0, 0.0)
    set udg_HumanCount = Arena_CountHumans()
    if udg_HumanCount < 1 then
        set udg_HumanCount = 1
    endif
    call Arena_AllyPlayers()
    call Arena_ApplyHandicap()
    // 1.26a may terminate a trigger that paints thousands of terrain cells.
    // Runtime geometry is disabled during startup; keep the original terrain.
    call Arena_Msg("|cff88ff88[Арена 1/4]|r Инициализация игроков.")

    set udg_WaveTimer = CreateTimer()
    set udg_WaveTD = CreateTimerDialog(udg_WaveTimer)
    set i = 0
    loop
        exitwhen i > 3
        set udg_ReviveTimer[i] = CreateTimer()
        set i = i + 1
    endloop

    set gg_trg_Pick = CreateTrigger()
    call TriggerAddAction(gg_trg_Pick, function Trig_Pick_Actions)

    set gg_trg_Wave = CreateTrigger()
    call TriggerRegisterTimerExpireEvent(gg_trg_Wave, udg_WaveTimer)
    call TriggerAddAction(gg_trg_Wave, function Trig_Wave_Actions)

    set gg_trg_Death = CreateTrigger()
    call TriggerRegisterAnyUnitEventBJ(gg_trg_Death, EVENT_PLAYER_UNIT_DEATH)
    call TriggerAddAction(gg_trg_Death, function Trig_Death_Actions)

    set gg_trg_Boss = CreateTrigger()
    call TriggerRegisterPlayerUnitEvent(gg_trg_Boss, Player(PLAYER_NEUTRAL_AGGRESSIVE), EVENT_PLAYER_UNIT_DEATH, null)
    call TriggerAddAction(gg_trg_Boss, function Trig_Boss_Actions)

    set gg_trg_Leave = CreateTrigger()
    set i = 0
    loop
        exitwhen i > 3
        call TriggerRegisterPlayerEvent(gg_trg_Leave, Player(i), EVENT_PLAYER_LEAVE)
        set i = i + 1
    endloop
    call TriggerAddAction(gg_trg_Leave, function Trig_Leave_Actions)

    set gg_trg_BossThink = CreateTrigger()
    call TriggerRegisterTimerEvent(gg_trg_BossThink, 1.00, true)
    call TriggerAddAction(gg_trg_BossThink, function Trig_BossThink_Actions)

    set gg_trg_HeroSpell = CreateTrigger()
    call TriggerRegisterAnyUnitEventBJ(gg_trg_HeroSpell, EVENT_PLAYER_UNIT_SPELL_EFFECT)
    call TriggerAddAction(gg_trg_HeroSpell, function Trig_HeroSpell_Actions)

    set gg_trg_ItemPickup = CreateTrigger()
    call TriggerRegisterAnyUnitEventBJ(gg_trg_ItemPickup, EVENT_PLAYER_UNIT_PICKUP_ITEM)
    call TriggerAddAction(gg_trg_ItemPickup, function Trig_ItemPickup_Actions)
    set gg_trg_ItemDrop = CreateTrigger()
    call TriggerRegisterAnyUnitEventBJ(gg_trg_ItemDrop, EVENT_PLAYER_UNIT_DROP_ITEM)
    call TriggerAddAction(gg_trg_ItemDrop, function Trig_ItemDrop_Actions)
    set gg_trg_ItemUse = CreateTrigger()
    call TriggerRegisterAnyUnitEventBJ(gg_trg_ItemUse, EVENT_PLAYER_UNIT_USE_ITEM)
    call TriggerAddAction(gg_trg_ItemUse, function Trig_ItemUse_Actions)

    set gg_trg_HeroLevel = CreateTrigger()
    call TriggerRegisterAnyUnitEventBJ(gg_trg_HeroLevel, EVENT_PLAYER_HERO_LEVEL)
    call TriggerAddAction(gg_trg_HeroLevel, function Trig_HeroLevel_Actions)
    set gg_trg_Cheat = CreateTrigger()
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(0), "-kill", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(0), "-next", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(0), "-maxlvl", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(1), "-maxlvl", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(2), "-maxlvl", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(3), "-maxlvl", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(0), "-stats", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(1), "-stats", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(2), "-stats", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(3), "-stats", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(0), "-revive", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(1), "-revive", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(2), "-revive", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(3), "-revive", true)
    call TriggerAddAction(gg_trg_Cheat, function Trig_TestChat_Actions)
    set gg_trg_Aura = CreateTrigger()
    call TriggerRegisterTimerEvent(gg_trg_Aura, 1.00, true)
    call TriggerAddAction(gg_trg_Aura, function Trig_Aura_Actions)

    call Arena_ShowPicks()
    call Arena_Msg("|cff88ff88[Арена 3/4]|r Выбор героев готов.")
    call Arena_CreateShops()
    call Arena_CreateAuraMonument()
    call Arena_CreateQuests()
    call Arena_ExplainBalance()
    call Arena_Msg("|cff88ff88[Арена 4/4]|r Магазины и события готовы. Используйте -pick 1 ... -pick 10.")
endfunction

function InitTrig_Arena takes nothing returns nothing
    set gg_trg_Arena = CreateTrigger()
    // Delay until the game UI is initialized; dialogs in main() were unreliable.
    call TriggerRegisterTimerEvent(gg_trg_Arena, 0.50, false)
    call TriggerAddAction(gg_trg_Arena, function Trig_Arena_Actions)
endfunction

function InitCustomTriggers takes nothing returns nothing
    call InitTrig___________________________u()
    call InitTrig_____________________________________001()
    call InitTrig_Arena()
endfunction

function RunInitializationTriggers takes nothing returns nothing
    call ConditionalTriggerExecute(gg_trg___________________________u)
endfunction

//===========================================================================
function InitCustomPlayerSlots takes nothing returns nothing
    local integer i = 0
    loop
        exitwhen i > 3
        call SetPlayerStartLocation(Player(i), i)
        call SetPlayerColor(Player(i), ConvertPlayerColor(i))
        call SetPlayerRacePreference(Player(i), RACE_PREF_HUMAN)
        call SetPlayerRaceSelectable(Player(i), false)
        call SetPlayerController(Player(i), MAP_CONTROL_USER)
        set i = i + 1
    endloop
endfunction

function InitCustomTeams takes nothing returns nothing
    local integer i = 0
    loop
        exitwhen i > 3
        call SetPlayerTeam(Player(i), 0)
        set i = i + 1
    endloop
endfunction

//===========================================================================
function main takes nothing returns nothing
    call SetCameraBounds(-9472.0 + GetCameraMargin(CAMERA_MARGIN_LEFT), -9728.0 + GetCameraMargin(CAMERA_MARGIN_BOTTOM), 9472.0 - GetCameraMargin(CAMERA_MARGIN_RIGHT), 9216.0 - GetCameraMargin(CAMERA_MARGIN_TOP), -9472.0 + GetCameraMargin(CAMERA_MARGIN_LEFT), 9216.0 - GetCameraMargin(CAMERA_MARGIN_TOP), 9472.0 - GetCameraMargin(CAMERA_MARGIN_RIGHT), -9728.0 + GetCameraMargin(CAMERA_MARGIN_BOTTOM))
    call SetDayNightModels("Environment\\DNC\\DNCLordaeron\\DNCLordaeronTerrain\\DNCLordaeronTerrain.mdl", "Environment\\DNC\\DNCLordaeron\\DNCLordaeronUnit\\DNCLordaeronUnit.mdl")
    call NewSoundEnvironment("Default")
    call SetAmbientDaySound("LordaeronSummerDay")
    call SetAmbientNightSound("LordaeronSummerNight")
    call SetMapMusic("Music", true, 0)
    call InitBlizzard()
    call InitGlobals()
    call InitCustomTriggers()
    call RunInitializationTriggers()
endfunction

//===========================================================================
function config takes nothing returns nothing
    call SetMapName("Hero Arena")
    call SetMapDescription("Кооперативная арена: выбор класса, магазины, 50 волн и босс. Меньше игроков — сильнее ауры.")
    call SetPlayers(4)
    call SetTeams(1)
    call SetGamePlacement(MAP_PLACEMENT_TEAMS_TOGETHER)
    call DefineStartLocation(0, 0.0, 0.0)
    call DefineStartLocation(1, 0.0, 0.0)
    call DefineStartLocation(2, 0.0, 0.0)
    call DefineStartLocation(3, 0.0, 0.0)
    call InitCustomPlayerSlots()
    call InitCustomTeams()
    call SetPlayerSlotAvailable(Player(0), MAP_CONTROL_USER)
    call SetPlayerSlotAvailable(Player(1), MAP_CONTROL_USER)
    call SetPlayerSlotAvailable(Player(2), MAP_CONTROL_USER)
    call SetPlayerSlotAvailable(Player(3), MAP_CONTROL_USER)
endfunction
