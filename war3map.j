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
    // Custom heroes have individual learnable skill lists in war3map.w3u.
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
    endif
    return 'E002'
endfunction

function Arena_HeroTitle takes integer kind returns string
    if kind == 1 then
        return "Рейнар Светокованный"
    elseif kind == 2 then
        return "Зархан Быстрокрылый"
    elseif kind == 3 then
        return "Мирелла Искророждённая"
    elseif kind == 4 then
        return "Морвен Праховестник"
    elseif kind == 5 then
        return "Вальтир Безликий"
    endif
    return "Селена Звездочёт"
endfunction

function Arena_HeroEpithet takes integer kind returns string
    if kind == 1 then
        return "Хранитель последнего рассвета"
    elseif kind == 2 then
        return "Танцующий среди песков"
    elseif kind == 3 then
        return "Шепчущая бурям"
    elseif kind == 4 then
        return "Наследник забытого трона"
    elseif kind == 5 then
        return "Блуждающий между мирами"
    endif
    return "Последняя дочь ночи"
endfunction

function Arena_GiveSkills takes unit u, integer kind returns nothing
    // Hero skills are learned only through the Warcraft III level-up menu.
    // Never pre-add or pre-level these custom hero abilities here.
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
    // Invisible 1.26a stock unit avoids malformed custom dummy model.
    set carrier = CreateUnit(Player(pid), 'hfoo', GetUnitX(hero), GetUnitY(hero), 0.0)
    set udg_AuraCarrier[pid] = carrier
    if carrier != null then
        call UnitAddAbility(carrier, 'Aloc')
        call SetUnitInvulnerable(carrier, true)
        call SetUnitPathing(carrier, false)
        call UnitAddAbility(carrier, 'ACae')
        if udg_HumanCount <= 2 then
            call UnitAddAbility(carrier, 'ACua')
        endif
        if udg_HumanCount == 1 then
            call UnitAddAbility(carrier, 'ACav')
            call UnitAddAbility(carrier, 'ACac')
        endif
        call SetUnitVertexColor(carrier, 255, 255, 255, 0)
    endif
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

function Arena_SpawnHero takes integer pid, integer kind returns nothing
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
    set hero = CreateUnit(Player(pid), Arena_HeroType(kind), x, y, 270.0)
    if hero == null then
        call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 10.0, "Ошибка создания героя.")
        return
    endif
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
    else
        call SetHeroStr(hero, 18, true)
        call SetHeroAgi(hero, 25, true)
        call SetHeroInt(hero, 24, true)
    endif
    call Arena_GiveSkills(hero, kind)
    call UnitAddItemById(hero, 'phea')
    call UnitAddItemById(hero, 'pman')
    call UnitAddItemById(hero, 'ciri')
    set udg_Heroes[pid] = hero
    set udg_HeroKind[pid] = kind
    call Arena_GiveAuras(hero)
    call SelectUnitForPlayerSingle(hero, Player(pid))
    call PanCameraToTimedForPlayer(Player(pid), x, y, 0.00)
    set hero = null
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
    local integer chance = 9 + danger * 3
    local integer itemId
    if IsUnitType(dying, UNIT_TYPE_HERO) then
        set chance = chance + 20
    endif
    if GetUnitLevel(dying) >= 6 then
        set chance = chance + 15
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

function Trig_HeroSpell_Actions takes nothing returns nothing
    local unit hero = GetTriggerUnit()
    local integer id = GetSpellAbilityId()
    local real level = I2R(GetUnitAbilityLevel(hero, id))
    if id == 'A101' then
        call Arena_HeroBurst(hero, 260.0, 30.0 + level * 12.0, false)
    elseif id == 'A102' then
        call Arena_HeroBurst(hero, 420.0, 55.0 + level * 30.0, true)
    elseif id == 'A103' then
        call Arena_HeroBurst(hero, 400.0, 45.0 + level * 25.0, false)
    elseif id == 'A104' then
        call SetUnitState(hero, UNIT_STATE_LIFE, GetUnitState(hero, UNIT_STATE_LIFE) + 40.0 + level * 28.0)
    elseif id == 'A105' then
        call Arena_HeroBurst(hero, 500.0, 45.0 + level * 32.0, false)
    elseif id == 'A106' then
        call Arena_ItemPulses(hero, 0.0, 35.0 + level * 18.0)
    elseif id == 'A107' then
        call SetUnitState(hero, UNIT_STATE_LIFE, GetUnitState(hero, UNIT_STATE_LIFE) + 35.0 + level * 22.0)
    elseif id == 'A108' then
        call Arena_HeroBurst(hero, 300.0, 38.0 + level * 24.0, false)
    elseif id == 'A109' then
        call Arena_HeroBurst(hero, 280.0, 42.0 + level * 28.0, false)
    elseif id == 'A10A' then
        call SetUnitState(hero, UNIT_STATE_LIFE, GetUnitState(hero, UNIT_STATE_LIFE) + 55.0 + level * 19.0)
    elseif id == 'A10B' then
        call Arena_HeroBurst(hero, 320.0, 35.0 + level * 22.0, false)
    elseif id == 'A10C' then
        call Arena_ItemPulses(hero, 45.0 + level * 20.0, 18.0 + level * 12.0)
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
    call SetUnitCreepGuard(u, false)
    call UnitWakeUp(u)
    call SetUnitUserData(u, 777)
    call SetUnitAcquireRange(u, 4000.0)
    call SetUnitCreepGuard(u, false)
    call UnitWakeUp(u)
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
    local integer tier = (wave - 1) / 10
    local integer front = 5 + wave / 7
    local integer support = 2 + wave / 12
    if ModuloInteger(wave, 10) == 0 then
        set front = front + 2
        set support = support + 1
    endif
    if tier == 0 then
        call Arena_SpawnRing('nban', front, 1200.0)
        call Arena_SpawnRing('ngno', support, 1420.0)
    elseif tier == 1 then
        call Arena_SpawnRing('nftr', front, 1250.0)
        call Arena_SpawnRing('nogr', support, 1450.0)
    elseif tier == 2 then
        call Arena_SpawnRing('uske', front + 2, 1230.0)
        call Arena_SpawnRing('nska', support, 1440.0)
    elseif tier == 3 then
        call Arena_SpawnRing('nfel', front, 1250.0)
        call Arena_SpawnRing('nogr', support + 1, 1480.0)
    else
        call Arena_SpawnRing('uske', front + 3, 1250.0)
        call Arena_SpawnRing('nfel', support, 1460.0)
        if ModuloInteger(wave, 5) == 0 then
            call Arena_SpawnRing('uabo', 2, 1580.0)
        endif
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
    call SetHeroLevel(udg_Boss, 9 + 2 * udg_HumanCount, false)
    call SetHeroStr(udg_Boss, 70 + 25 * udg_HumanCount, true)
    call SetHeroAgi(udg_Boss, 20 + 7 * udg_HumanCount, true)
    call SetHeroInt(udg_Boss, 28 + 6 * udg_HumanCount, true)
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
    if k == 1 or k == 4 then
        return -1000.0
    elseif k == 2 or k == 5 then
        return 0.0
    endif
    return 1000.0
endfunction

function Arena_SelectY takes integer k returns real
    if k <= 3 then
        return 6500.0
    endif
    return 7200.0
endfunction

function Arena_CreateSelectionPlaza takes nothing returns nothing
    local integer k = 1
    local real x
    local real y
    local rect zone
    local texttag label
    local unit preview
    loop
        exitwhen k > 6
        set x = Arena_SelectX(k)
        set y = Arena_SelectY(k)
        set zone = Rect(x - 235.0, y - 235.0, x + 235.0, y + 235.0)
        set udg_SelectRegion[k] = CreateRegion()
        call RegionAddRect(udg_SelectRegion[k], zone)
        call TriggerRegisterEnterRegion(gg_trg_Pick, udg_SelectRegion[k], null)
        set preview = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), Arena_HeroType(k), x, y, 270.0)
        set udg_SelectPreview[k] = preview
        if preview != null then
            call SetUnitInvulnerable(preview, true)
            call SetUnitPathing(preview, false)
            call PauseUnit(preview, true)
            call SetUnitScale(preview, 1.10, 1.10, 1.10)
        endif
        set label = CreateTextTag()
        call SetTextTagText(label, I2S(k) + ". " + Arena_HeroTitle(k), 0.025)
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
    if pid < 0 or pid >= 4 or k < 1 or k > 6 then
        return
    endif
    if udg_GameOver or udg_Picked[pid] or not Arena_IsHuman(pid) then
        return
    endif
    // Hero selection occurs in timer callback, never directly in region event.
    set udg_Picked[pid] = true
    set udg_PendingPick[pid] = 0
    set udg_PickCount = udg_PickCount + 1
    if udg_SelectWisp[pid] != null then
        call ShowUnit(udg_SelectWisp[pid], false)
    endif
    call Arena_SpawnHero(pid, k)
    call Arena_Msg(GetPlayerName(Player(pid)) + " выбрал: " + Arena_HeroTitle(k))
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
            exitwhen k > 6
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
                    exitwhen k > 6
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
        if u == udg_Boss or GetUnitUserData(u) == 777 then
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
    if pid != 0 then
        return
    endif
    if cmd == "-kill" then
        call Arena_Msg("Тест: зачистка всех врагов текущей волны.")
        call Arena_KillWaveEnemies()
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
        if k >= 1 and k <= 6 then
            call Arena_SelectHero(pid, k)
        else
            call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 8.0, "Команда: -pick 1 ... -pick 6")
        endif
    endif
endfunction

function Arena_AutoPick takes nothing returns nothing
    local integer pid = 0
    loop
        exitwhen pid >= 4
        if Arena_IsHuman(pid) and not udg_Picked[pid] then
            call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 8.0, "Время вышло: случайный герой.")
            call Arena_SelectHero(pid, GetRandomInt(1, 6))
        endif
        set pid = pid + 1
    endloop
endfunction

function Arena_ShowPicks takes nothing returns nothing
    local integer pid = 0
    local unit wisp
    call Arena_CreateSelectionPlaza()
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
                call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 18.0, "|cffffcc00ВЫБОР ГЕРОЯ|r: подведите светлячка к герою. Запасной способ: -pick 1 ... -pick 6. Автовыбор через 90 сек.")
            else
                call DisplayTimedTextToPlayer(Player(pid), 0.0, 0.0, 15.0, "Светлячок не создан: используйте -pick 1 ... -pick 6.")
            endif
        endif
        set pid = pid + 1
    endloop
    call TriggerAddAction(gg_trg_SelectChat, function Trig_SelectChat_Actions)
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
    call Arena_PayWaveGold(30 + udg_Wave * 7)
    call Arena_Msg("|cffffcc00Волна " + I2S(udg_Wave) + "/50|r  Врагов: " + I2S(udg_EnemiesAlive))
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
        if udg_EnemiesAlive == 0 then
            call Arena_CheckWaveClear()
        endif
        if udg_EnemiesAlive == 0 then
            call Arena_CheckWaveClear()
        endif
        if killer != null then
            set pid = GetPlayerId(GetOwningPlayer(killer))
            if pid >= 0 and pid < 4 and Arena_IsHuman(pid) then
                set reward = 4 + 2 * udg_Wave
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
        call Arena_BossNova(75.0 + 20.0 * udg_HumanCount)
    elseif udg_BossPhase == 1 and health <= 30.0 then
        set udg_BossPhase = 2
        call Arena_Msg("|cffff4444Kaz'Rul is enraged!|r")
        call Arena_SpawnRing('ninf', 2 + udg_HumanCount, 850.0)
        call UnitAddAbility(udg_Boss, 'ACro')
        call IssueImmediateOrder(udg_Boss, "roar")
        call Arena_BossNova(115.0 + 25.0 * udg_HumanCount)
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
    set i = 0
    loop
        exitwhen i >= 4
        if udg_AuraCarrier[i] != null and udg_Heroes[i] != null then
            if GetWidgetLife(udg_Heroes[i]) > 0.405 then
                call SetUnitX(udg_AuraCarrier[i], GetUnitX(udg_Heroes[i]))
                call SetUnitY(udg_AuraCarrier[i], GetUnitY(udg_Heroes[i]))
            endif
        endif
        set i = i + 1
    endloop
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
    call QuestSetDescription(udg_QuestMain, "Выберите героя. Зачистка волны ускоряет следующую (7 сек). После 10 волны босс. Четыре разных магазина у центра. Вечный день.")
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
    call Arena_PaintDisc(0.0, 6860.0, 1900.0, 'Lgrs')
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
        exitwhen k > 6
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

function Trig_Arena_Actions takes nothing returns nothing
    local integer i
    call FogEnableOff()
    call FogMaskEnableOff()
    call SetTimeOfDay(12.00)
    call SetTimeOfDayScale(0.00)
    call SuspendTimeOfDay(true)
    call SetTimeOfDayScale(0.00)
    call SuspendTimeOfDay(true)
    call SetCameraPosition(0.0, 0.0)
    set udg_HumanCount = Arena_CountHumans()
    if udg_HumanCount < 1 then
        set udg_HumanCount = 1
    endif
    call Arena_AllyPlayers()
    call Arena_ApplyHandicap()
    call Arena_CreateGeometry()
    call Arena_CreateShops()
    call AddSpecialEffect("Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl", 0.0, 0.0)
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

    set gg_trg_Cheat = CreateTrigger()
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(0), "-kill", true)
    call TriggerRegisterPlayerChatEvent(gg_trg_Cheat, Player(0), "-revive", true)
    call TriggerAddAction(gg_trg_Cheat, function Trig_TestChat_Actions)
    set gg_trg_Aura = CreateTrigger()
    call TriggerRegisterTimerEvent(gg_trg_Aura, 1.00, true)
    call TriggerAddAction(gg_trg_Aura, function Trig_Aura_Actions)

    call Arena_ShowPicks()
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
