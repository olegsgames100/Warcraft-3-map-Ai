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
    integer         array   udg_HeroKind
    integer         array   udg_ReviveWait

    dialog          array   udg_PickDialog
    button          array   udg_PickButton

    timer                   udg_WaveTimer                  = null
    timerdialog             udg_WaveTD                     = null
    timer                   udg_AuraTimer                  = null
    timer           array   udg_ReviveTimer

    unit                    udg_Boss                       = null
    unit                    udg_ShopWeapon                 = null
    unit                    udg_ShopArmor                  = null
    unit                    udg_ShopMagic                  = null
    unit                    udg_ShopRelic                  = null

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
    local real hp = 1.00
    local real xp = 1.00
    if udg_HumanCount <= 1 then
        set hp = 1.85
        set xp = 1.55
    elseif udg_HumanCount == 2 then
        set hp = 1.40
        set xp = 1.25
    elseif udg_HumanCount == 3 then
        set hp = 1.18
        set xp = 1.10
    endif
    loop
        exitwhen i > 3
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

function Arena_CreateShops takes nothing returns nothing
    set udg_ShopWeapon = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), 'ngme', -640.0, -256.0, 270.0)
    set udg_ShopArmor  = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), 'ngme', 640.0, -256.0, 270.0)
    set udg_ShopMagic  = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), 'ngme', -640.0, 256.0, 270.0)
    set udg_ShopRelic  = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), 'ngme', 640.0, 256.0, 270.0)

    call SetUnitInvulnerable(udg_ShopWeapon, true)
    call SetUnitInvulnerable(udg_ShopArmor, true)
    call SetUnitInvulnerable(udg_ShopMagic, true)
    call SetUnitInvulnerable(udg_ShopRelic, true)
    call SetUnitMoveSpeed(udg_ShopWeapon, 0.00)
    call SetUnitMoveSpeed(udg_ShopArmor, 0.00)
    call SetUnitMoveSpeed(udg_ShopMagic, 0.00)
    call SetUnitMoveSpeed(udg_ShopRelic, 0.00)
    call RemoveGuardPosition(udg_ShopWeapon)
    call RemoveGuardPosition(udg_ShopArmor)
    call RemoveGuardPosition(udg_ShopMagic)
    call RemoveGuardPosition(udg_ShopRelic)

    // Weapon stall
    call Arena_Stock(udg_ShopWeapon, 'ratc', 8)
    call Arena_Stock(udg_ShopWeapon, 'ratf', 6)
    call Arena_Stock(udg_ShopWeapon, 'gcel', 6)
    call Arena_Stock(udg_ShopWeapon, 'rst1', 6)
    call Arena_Stock(udg_ShopWeapon, 'rag1', 4)
    call Arena_Stock(udg_ShopWeapon, 'ofro', 3)
    call Arena_Stock(udg_ShopWeapon, 'ocor', 3)
    call Arena_Stock(udg_ShopWeapon, 'ofir', 3)
    call Arena_Stock(udg_ShopWeapon, 'oli2', 3)

    // Armor / lab
    call Arena_Stock(udg_ShopArmor, 'rde2', 8)
    call Arena_Stock(udg_ShopArmor, 'rde3', 6)
    call Arena_Stock(udg_ShopArmor, 'rde4', 4)
    call Arena_Stock(udg_ShopArmor, 'bspd', 6)
    call Arena_Stock(udg_ShopArmor, 'belv', 4)
    call Arena_Stock(udg_ShopArmor, 'clfm', 3)
    call Arena_Stock(udg_ShopArmor, 'hval', 3)
    call Arena_Stock(udg_ShopArmor, 'hcun', 3)
    call Arena_Stock(udg_ShopArmor, 'brac', 4)
    call Arena_Stock(udg_ShopArmor, 'evtl', 3)
    call Arena_Stock(udg_ShopArmor, 'ciri', 8)
    call Arena_Stock(udg_ShopArmor, 'tkno', 8)
    call Arena_Stock(udg_ShopArmor, 'tstr', 10)
    call Arena_Stock(udg_ShopArmor, 'tagi', 10)
    call Arena_Stock(udg_ShopArmor, 'tint', 10)
    call Arena_Stock(udg_ShopArmor, 'manh', 8)

    // Magic
    call Arena_Stock(udg_ShopMagic, 'phea', 20)
    call Arena_Stock(udg_ShopMagic, 'pman', 20)
    call Arena_Stock(udg_ShopMagic, 'pghe', 12)
    call Arena_Stock(udg_ShopMagic, 'pgma', 12)
    call Arena_Stock(udg_ShopMagic, 'pnvu', 6)
    call Arena_Stock(udg_ShopMagic, 'pnvl', 6)
    call Arena_Stock(udg_ShopMagic, 'shrs', 10)
    call Arena_Stock(udg_ShopMagic, 'sres', 4)
    call Arena_Stock(udg_ShopMagic, 'ssan', 4)
    call Arena_Stock(udg_ShopMagic, 'kpin', 3)
    call Arena_Stock(udg_ShopMagic, 'penr', 4)
    call Arena_Stock(udg_ShopMagic, 'pmys', 4)

    // Relics
    call Arena_Stock(udg_ShopRelic, 'ckng', 2)
    call Arena_Stock(udg_ShopRelic, 'modt', 2)
    call Arena_Stock(udg_ShopRelic, 'desc', 3)
    call Arena_Stock(udg_ShopRelic, 'ajen', 2)
    call Arena_Stock(udg_ShopRelic, 'mcou', 3)
    call Arena_Stock(udg_ShopRelic, 'odef', 3)
    call Arena_Stock(udg_ShopRelic, 'rwiz', 4)
    call Arena_Stock(udg_ShopRelic, 'hlst', 3)
    call Arena_Stock(udg_ShopRelic, 'afac', 3)
    call Arena_Stock(udg_ShopRelic, 'fgsk', 4)
endfunction

//===========================================================================
function Arena_HeroType takes integer kind returns integer
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
    endif
    return 'Emoo'
endfunction

function Arena_HeroTitle takes integer kind returns string
    if kind == 1 then
        return "Арбитр Арены"
    elseif kind == 2 then
        return "Клинок Пыли"
    elseif kind == 3 then
        return "Хранитель Бури"
    elseif kind == 4 then
        return "Повелитель Праха"
    elseif kind == 5 then
        return "Охотник Бездны"
    endif
    return "Лунная Стражница"
endfunction

function Arena_GiveSkills takes unit u, integer kind returns nothing
    if kind == 1 then
        call UnitAddAbility(u, 'ACtb')
        call UnitAddAbility(u, 'ACae')
        call UnitAddAbility(u, 'ACav')
    elseif kind == 2 then
        call UnitAddAbility(u, 'ACba')
        call UnitAddAbility(u, 'ACev')
        call UnitAddAbility(u, 'ACac')
    elseif kind == 3 then
        call UnitAddAbility(u, 'ACfb')
        call UnitAddAbility(u, 'Alsh')
        call UnitAddAbility(u, 'ACfl')
    elseif kind == 4 then
        call UnitAddAbility(u, 'AUav')
        call UnitAddAbility(u, 'ACrd')
        call UnitAddAbility(u, 'ACua')
    elseif kind == 5 then
        call UnitAddAbility(u, 'ACim')
        call UnitAddAbility(u, 'ACah')
        call UnitAddAbility(u, 'ACev')
    else
        call UnitAddAbility(u, 'ACev')
        call UnitAddAbility(u, 'AInf')
        call UnitAddAbility(u, 'AEar')
    endif
endfunction

function Arena_GiveAuras takes unit u returns nothing
    if udg_HumanCount >= 4 then
        return
    endif
    if udg_HumanCount <= 1 then
        call UnitAddAbility(u, 'ACua')
        call UnitAddAbility(u, 'ACae')
        call UnitAddAbility(u, 'ACav')
        call UnitAddAbility(u, 'ACac')
        call UnitAddAbility(u, 'ACah')
        call UnitAddAbility(u, 'ACev')
    elseif udg_HumanCount == 2 then
        call UnitAddAbility(u, 'ACae')
        call UnitAddAbility(u, 'ACav')
        call UnitAddAbility(u, 'ACev')
    else
        call UnitAddAbility(u, 'ACae')
    endif
endfunction

function Arena_SpawnHero takes integer pid, integer kind returns nothing
    local real x
    local real y
    local unit u
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
    set u = CreateUnit(Player(pid), Arena_HeroType(kind), x, y, 270.0)
    call SetHeroProperName(u, Arena_HeroTitle(kind))
    call SetHeroLevel(u, 1, false)
    call Arena_GiveSkills(u, kind)
    call Arena_GiveAuras(u)
    call UnitAddItemById(u, 'ciri')
    call UnitAddItemById(u, 'phea')
    call UnitAddItemById(u, 'pman')
    call SelectUnitForPlayerSingle(u, Player(pid))
    call PanCameraToTimedForPlayer(Player(pid), x, y, 0.00)
    set udg_Heroes[pid] = u
    set udg_HeroKind[pid] = kind
    set u = null
endfunction

//===========================================================================
function Arena_CreateEnemy takes integer unitId, real x, real y returns nothing
    local unit u = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), unitId, x, y, 270.0)
    if u == null then
        return
    endif
    call SetUnitAcquireRange(u, 4000.0)
    call IssuePointOrder(u, "attack", 0.0, 0.0)
    set u = null
endfunction

function Arena_SpawnRing takes integer unitId, integer count, real dist returns nothing
    local integer i = 0
    local real ang
    local real x
    local real y
    loop
        exitwhen i >= count
        set ang = (3.14159 * 2.0) * I2R(i) / I2R(count)
        set x = dist * Cos(ang) + GetRandomReal(-70.0, 70.0)
        set y = dist * Sin(ang) + GetRandomReal(-70.0, 70.0)
        call Arena_CreateEnemy(unitId, x, y)
        set i = i + 1
    endloop
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

function Arena_SpawnWaveCreeps takes integer wave returns nothing
    if wave == 1 then
        call Arena_SpawnRing('nban', 8, 1200.0)
        call Arena_SpawnRing('nrog', 4, 1350.0)
    elseif wave == 2 then
        call Arena_SpawnRing('ngno', 8, 1200.0)
        call Arena_SpawnRing('ngna', 6, 1400.0)
    elseif wave == 3 then
        call Arena_SpawnRing('nftr', 8, 1200.0)
        call Arena_SpawnRing('nftb', 6, 1400.0)
    elseif wave == 4 then
        call Arena_SpawnRing('nogr', 8, 1250.0)
        call Arena_SpawnRing('nomg', 4, 1450.0)
    elseif wave == 5 then
        call Arena_SpawnRing('uske', 10, 1200.0)
        call Arena_SpawnRing('nska', 6, 1450.0)
    elseif wave == 6 then
        call Arena_SpawnRing('nfel', 8, 1250.0)
        call Arena_SpawnRing('nfov', 4, 1500.0)
    elseif wave == 7 then
        call Arena_SpawnRing('nrwm', 6, 1300.0)
        call Arena_SpawnRing('nrdk', 6, 1500.0)
    elseif wave == 8 then
        call Arena_SpawnRing('uabo', 6, 1300.0)
        call Arena_SpawnRing('unec', 4, 1500.0)
    elseif wave == 9 then
        call Arena_SpawnRing('nbal', 5, 1400.0)
        call Arena_SpawnRing('ninf', 3, 1600.0)
    else
        call Arena_SpawnRing('nbal', 4, 1400.0)
        call Arena_SpawnRing('ninf', 4, 1600.0)
        call Arena_SpawnRing('nsgg', 2, 1100.0)
    endif
endfunction

function Arena_SpawnBoss takes nothing returns nothing
    local integer i
    set udg_Boss = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), 'Nplh', 0.0, 900.0, 270.0)
    call SetHeroProperName(udg_Boss, "Каз'Рул Пожиратель Волн")
    call SetHeroLevel(udg_Boss, 12, false)
    set i = 0
    loop
        exitwhen i >= 12
        call UnitAddItemById(udg_Boss, 'manh')
        call UnitAddItemById(udg_Boss, 'tstr')
        set i = i + 1
    endloop
    call UnitAddAbility(udg_Boss, 'ACev')
    call UnitAddAbility(udg_Boss, 'ACua')
    call UnitAddAbility(udg_Boss, 'ACah')
    call UnitAddItemById(udg_Boss, 'modt')
    call UnitAddItemById(udg_Boss, 'ckng')
    call SetUnitAcquireRange(udg_Boss, 5000.0)
    call IssuePointOrder(udg_Boss, "attack", 0.0, 0.0)
    call QuestSetEnabled(udg_QuestBoss, true)
    call QuestSetDiscovered(udg_QuestBoss, true)
    call QuestMessageBJ(GetPlayersAll(), bj_QUESTMESSAGE_DISCOVERED, "|cffff0000БОСС|r: Каз'Рул Пожиратель Волн")
    call Arena_Msg("|cffff4444Каз'Рул выходит на арену!|r")
    call PingMinimap(0.0, 900.0, 6.00)
endfunction

//===========================================================================
function Arena_TryStartWaves takes nothing returns nothing
    if udg_WavesStarted then
        return
    endif
    if udg_PickCount < udg_HumanCount then
        return
    endif
    set udg_WavesStarted = true
    call TimerStart(udg_WaveTimer, 15.00, false, function Arena_DoNothing)
    call TimerDialogSetTitle(udg_WaveTD, "Волна 1")
    call TimerDialogDisplay(udg_WaveTD, true)
    call Arena_Msg("Все герои выбраны. Первая волна через 15 сек. Магазины по углам центра.")
endfunction

function Trig_Pick_Actions takes nothing returns nothing
    local player p = GetTriggerPlayer()
    local integer pid = GetPlayerId(p)
    local button b = GetClickedButton()
    local integer k = 1
    if udg_Picked[pid] then
        set p = null
        set b = null
        return
    endif
    loop
        exitwhen k > 6
        if b == udg_PickButton[pid * 8 + k] then
            set udg_Picked[pid] = true
            set udg_PickCount = udg_PickCount + 1
            call DialogDisplay(p, udg_PickDialog[pid], false)
            call Arena_SpawnHero(pid, k)
            call Arena_Msg(GetPlayerName(p) + " выбрал: |cffffcc00" + Arena_HeroTitle(k) + "|r")
            call Arena_TryStartWaves()
            set p = null
            set b = null
            return
        endif
        set k = k + 1
    endloop
    set p = null
    set b = null
endfunction

function Arena_BuildPickDialog takes integer pid returns nothing
    local dialog d = DialogCreate()
    set udg_PickDialog[pid] = d
    call DialogSetMessage(d, "Выберите героя")
    set udg_PickButton[pid * 8 + 1] = DialogAddButton(d, "1. Арбитр (танк, свет)", 49)
    set udg_PickButton[pid * 8 + 2] = DialogAddButton(d, "2. Клинок Пыли (мили)", 50)
    set udg_PickButton[pid * 8 + 3] = DialogAddButton(d, "3. Хранитель Бури (маг)", 51)
    set udg_PickButton[pid * 8 + 4] = DialogAddButton(d, "4. Повелитель Праха (нежить)", 52)
    set udg_PickButton[pid * 8 + 5] = DialogAddButton(d, "5. Охотник Бездны (ловкость)", 53)
    set udg_PickButton[pid * 8 + 6] = DialogAddButton(d, "6. Лунная Стражница (даль)", 54)
    call TriggerRegisterDialogEvent(gg_trg_Pick, d)
    set d = null
endfunction

function Arena_ShowPicks takes nothing returns nothing
    local integer i = 0
    loop
        exitwhen i > 3
        if Arena_IsHuman(i) then
            call Arena_BuildPickDialog(i)
            call DialogDisplay(Player(i), udg_PickDialog[i], true)
        endif
        set i = i + 1
    endloop
endfunction

//===========================================================================
function Trig_Wave_Actions takes nothing returns nothing
    if udg_GameOver then
        return
    endif
    if udg_Wave >= 10 then
        call TimerDialogDisplay(udg_WaveTD, false)
        call Arena_SpawnBoss()
        return
    endif
    set udg_Wave = udg_Wave + 1
    call Arena_SpawnWaveCreeps(udg_Wave)
    call Arena_PayWaveGold(40 + udg_Wave * 15)
    call Arena_Msg("|cffffcc00Волна " + I2S(udg_Wave) + "/10|r  (+золото)")
    call PingMinimap(0.0, 1200.0, 3.00)
    if udg_Wave < 10 then
        call TimerDialogSetTitle(udg_WaveTD, "Волна " + I2S(udg_Wave + 1))
        call TimerStart(udg_WaveTimer, 60.00, false, null)
    else
        call TimerDialogSetTitle(udg_WaveTD, "БОСС")
        call TimerStart(udg_WaveTimer, 20.00, false, null)
    endif
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

function Trig_Death_Actions takes nothing returns nothing
    local unit u = GetDyingUnit()
    local integer pid
    if IsUnitType(u, UNIT_TYPE_HERO) == false then
        set u = null
        return
    endif
    if GetOwningPlayer(u) == Player(PLAYER_NEUTRAL_AGGRESSIVE) then
        set u = null
        return
    endif
    set pid = GetPlayerId(GetOwningPlayer(u))
    if pid < 0 or pid > 3 then
        set u = null
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
endfunction

function Trig_Boss_Actions takes nothing returns nothing
    local integer i
    if udg_GameOver then
        return
    endif
    if GetDyingUnit() != udg_Boss then
        return
    endif
    set udg_GameOver = true
    call PauseTimer(udg_WaveTimer)
    call TimerDialogDisplay(udg_WaveTD, false)
    call QuestSetCompleted(udg_QuestMain, true)
    call QuestSetCompleted(udg_QuestBoss, true)
    call Arena_Msg("|cff00ff00Каз'Рул пал. Арена ваша!|r")
    call Arena_PayWaveGold(800)
    set i = 0
    loop
        exitwhen i > 3
        if Arena_IsHuman(i) then
            call CustomVictoryBJ(Player(i), true, true)
        endif
        set i = i + 1
    endloop
endfunction

//===========================================================================
function Trig_Aura_Actions takes nothing returns nothing
    local integer i = 0
    local unit u
    local real life
    local real mana
    local real addHp
    local real addMp
    if udg_HumanCount >= 4 then
        return
    endif
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
    call QuestSetDescription(udg_QuestMain, "Выберите героя. Волны каждую минуту. После 10 волны босс. Магазины у центра. Меньше игроков - сильнее реген и ауры. На 4 игроках бонусов нет.")
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

function Trig_Arena_Actions takes nothing returns nothing
    local integer i
    call FogEnableOff()
    call FogMaskEnableOff()
    call SetTimeOfDay(12.00)
    call SetCameraPosition(0.0, 0.0)
    set udg_HumanCount = Arena_CountHumans()
    if udg_HumanCount < 1 then
        set udg_HumanCount = 1
    endif
    call Arena_AllyPlayers()
    call Arena_ApplyHandicap()
    call Arena_CreateShops()
    call Arena_CreateQuests()
    call Arena_ExplainBalance()

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

    set gg_trg_Aura = CreateTrigger()
    call TriggerRegisterTimerEvent(gg_trg_Aura, 1.00, true)
    call TriggerAddAction(gg_trg_Aura, function Trig_Aura_Actions)

    call Arena_ShowPicks()
endfunction

function InitTrig_Arena takes nothing returns nothing
    set gg_trg_Arena = CreateTrigger()
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
    call ConditionalTriggerExecute(gg_trg_Arena)
endfunction

//===========================================================================
function config takes nothing returns nothing
    call SetMapName("Hero Arena")
    call SetMapDescription("Кооперативная арена: выбор героя, магазины, 10 волн и босс. Меньше игроков — сильнее ауры.")
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
