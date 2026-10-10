-- Hero Arena: Reforged / Lua-only runtime
-- Everything in this folder is concatenated into the sole war3map.lua.
Arena = {
    clock = 0,
    tickRate = 0.25,
    maxWave = 50,
    active = {},
    picked = {},
    heroUnits = {},
    heroKind = {},
    wisp = {},
    markers = {},
    auraCarriers = {},
    resources = {},
    guards = {},
    marks = {},
    waveUnits = {},
    waveAlive = 0,
    wave = 0,
    phase = "selection",
    elite = nil,
    boss = nil,
    countdown = nil,
    currentWaveTimer = nil,
    kills = 0,
    stockShops = {},
}
local A = Arena

function A.raw(s)
    return FourCC(s)
end

function A.after(seconds, fn)
    local timer = CreateTimer()
    TimerStart(timer, math.max(0.02, seconds), false, function()
        DestroyTimer(timer)
        fn()
    end)
    return timer
end

function A.every(seconds, fn)
    local timer = CreateTimer()
    TimerStart(timer, seconds, true, fn)
    return timer
end

function A.alive(u)
    return u ~= nil and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
end

function A.playerCount()
    local total = 0
    for pid = 0, 3 do
        if A.active[pid] then total = total + 1 end
    end
    return math.max(1, total)
end

function A.say(message, duration)
    for pid = 0, 3 do
        if A.active[pid] then
            DisplayTimedTextToPlayer(Player(pid), 0, 0, duration or 9, message)
        end
    end
end

function A.playerText(pid, message)
    DisplayTimedTextToPlayer(Player(pid), 0, 0, 12, message)
end

function A.fx(path, x, y)
    local effect = AddSpecialEffect(path, x, y)
    if effect ~= nil then DestroyEffect(effect) end
end

function A.text(x, y, msg, size, life)
    local tag = CreateTextTag()
    SetTextTagText(tag, msg, size or 0.024)
    SetTextTagPos(tag, x - 125, y, 160)
    SetTextTagColor(tag, 255, 210, 130, 255)
    if life == nil then
        SetTextTagPermanent(tag, true)
    else
        SetTextTagPermanent(tag, false)
        SetTextTagLifespan(tag, life)
        SetTextTagFadepoint(tag, math.max(0, life - 1.5))
    end
    return tag
end

function A.withUnits(x, y, radius, callback)
    local group = CreateGroup()
    GroupEnumUnitsInRange(group, x, y, radius, nil)
    while true do
        local unit = FirstOfGroup(group)
        if unit == nil then break end
        GroupRemoveUnit(group, unit)
        if A.alive(unit) then callback(unit) end
    end
    DestroyGroup(group)
end

function A.isEnemy(caster, target)
    return A.alive(target)
       and target ~= caster
       and IsUnitEnemy(target, GetOwningPlayer(caster))
       and not IsUnitType(target, UNIT_TYPE_STRUCTURE)
end

function A.damage(caster, victim, amount)
    if A.isEnemy(caster, victim) then
        UnitDamageTarget(caster, victim, math.max(1, amount), true, false,
            ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
    end
end

function A.heal(target, amount)
    if A.alive(target) then
        SetWidgetLife(target, math.min(
            GetUnitState(target, UNIT_STATE_MAX_LIFE),
            GetWidgetLife(target) + amount))
    end
end

function A.area(caster, x, y, radius, damage, heal)
    A.withUnits(x, y, radius, function(victim)
        if heal then
            if IsUnitAlly(victim, GetOwningPlayer(caster)) and IsUnitType(victim, UNIT_TYPE_HERO) then
                A.heal(victim, heal)
            end
        else
            A.damage(caster, victim, damage)
        end
    end)
end

function A.line(caster, range, width, damage)
    local sx, sy = GetUnitX(caster), GetUnitY(caster)
    local angle = GetUnitFacing(caster) * math.pi / 180
    local dx, dy = math.cos(angle), math.sin(angle)
    A.withUnits(sx + dx * range / 2, sy + dy * range / 2, range, function(victim)
        if A.isEnemy(caster, victim) then
            local x, y = GetUnitX(victim) - sx, GetUnitY(victim) - sy
            local along = x * dx + y * dy
            local across = math.abs(x * dy - y * dx)
            if along >= 0 and along <= range and across <= width then
                A.damage(caster, victim, damage)
            end
        end
    end)
end

function A.zone(caster, x, y, radius, duration, pulse, amount, friendly, art)
    local times = math.max(1, math.floor(duration / pulse))
    local ticks = 0
    if art then A.fx(art, x, y) end
    A.after(pulse, function()
        -- Each pulse schedules the next callback independently.
        local function eachTick()
            ticks = ticks + 1
            if friendly then
                A.area(caster, x, y, radius, 0, amount)
            else
                A.area(caster, x, y, radius, amount, nil)
            end
            if ticks < times and A.alive(caster) then
                A.after(pulse, eachTick)
            end
        end
        eachTick()
    end)
end

function A.trap(caster, x, y, delay, radius, damage)
    A.fx([[Abilities\Spells\Other\GeneralAuraTarget\GeneralAuraTarget.mdl]], x, y)
    A.after(delay, function()
        if A.alive(caster) then
            A.fx([[Abilities\Spells\Human\ThunderClap\ThunderClapCaster.mdl]], x, y)
            A.area(caster, x, y, radius, damage)
        end
    end)
end

function A.guard(unit, seconds)
    A.guards[GetHandleId(unit)] = math.max(
        A.guards[GetHandleId(unit)] or 0, A.clock + seconds)
    A.fx([[Abilities\Spells\Human\DivineShield\DivineShieldTarget.mdl]],
        GetUnitX(unit), GetUnitY(unit))
end

function A.summon(caster, typeId, count, lifetime)
    for i = 1, count do
        local x = GetUnitX(caster) + GetRandomReal(-140, 140)
        local y = GetUnitY(caster) + GetRandomReal(-140, 140)
        local u = CreateUnit(GetOwningPlayer(caster), A.raw(typeId), x, y, 270)
        if u ~= nil then
            UnitApplyTimedLife(u, A.raw("BTLF"), lifetime)
            IssuePointOrder(u, "attack", 0, 0)
        end
    end
end

function A.dash(caster, distance, width, damage)
    A.line(caster, distance, width, damage)
    local rad = math.rad(GetUnitFacing(caster))
    local x = math.max(-1900, math.min(1900, GetUnitX(caster) + distance * math.cos(rad)))
    local y = math.max(-1900, math.min(1900, GetUnitY(caster) + distance * math.sin(rad)))
    SetUnitPosition(caster, x, y)
    A.fx([[Abilities\Spells\NightElf\Blink\BlinkTarget.mdl]], x, y)
end

function A.mana(unit, value)
    if A.alive(unit) then
        SetUnitState(unit, UNIT_STATE_MANA, math.min(
            GetUnitState(unit, UNIT_STATE_MAX_MANA),
            GetUnitState(unit, UNIT_STATE_MANA) + value))
    end
end

function A.closestEnemy(caster, radius)
    local nearest, best = nil, radius * radius
    local x, y = GetUnitX(caster), GetUnitY(caster)
    A.withUnits(x, y, radius, function(u)
        if A.isEnemy(caster, u) then
            local dist = (GetUnitX(u) - x)^2 + (GetUnitY(u) - y)^2
            if dist < best then nearest, best = u, dist end
        end
    end)
    return nearest
end

function A.reduceDamage()
    local t = CreateTrigger()
    for pid = 0, 3 do
        TriggerRegisterPlayerUnitEvent(t, Player(pid), EVENT_PLAYER_UNIT_DAMAGING, nil)
    end
    TriggerAddAction(t, function()
        local unit = GetTriggerUnit()
        local till = A.guards[GetHandleId(unit)]
        if till ~= nil and till > A.clock then
            BlzSetEventDamage(GetEventDamage() * 0.35)
        end
    end)
end

function A.gameTick()
    A.clock = A.clock + A.tickRate
    if A.phase == "selection" then A.pollSelections() end
    A.checkBalance()
    if A.tickHeroes then A.tickHeroes() end
    if A.tickWaves then A.tickWaves() end
end

function A.start()
    SetTimeOfDay(12)
    SetTimeOfDayScale(0)
    SuspendTimeOfDay(true)
    FogEnable(false)
    FogMaskEnable(false)

    for pid = 0, 3 do
        local player = Player(pid)
        A.active[pid] = GetPlayerController(player) == MAP_CONTROL_USER
                and GetPlayerSlotState(player) == PLAYER_SLOT_STATE_PLAYING
        A.picked[pid] = false
        A.resources[pid] = { valor=0, combo=0, storm=0, souls=0, fury=0,
            moon=0, reagent=0, fortitude=0, frost=0 }
        for other = 0, 3 do
            SetPlayerAlliance(player, Player(other), ALLIANCE_PASSIVE, true)
            SetPlayerAlliance(player, Player(other), ALLIANCE_SHARED_VISION, true)
        end
        if A.active[pid] then
            SetPlayerState(player, PLAYER_STATE_RESOURCE_GOLD, 550)
        end
    end

    A.createMonument()
    A.createShops()
    A.prepareSelections()
    A.initWaves()
    A.initInputs()
    A.initHeroEvents()
    A.reduceDamage()
    A.every(A.tickRate, A.gameTick)

    for pid = 0, 3 do
        if A.active[pid] then
            PanCameraToTimedForPlayer(Player(pid), 0, 6400, 0)
            A.playerText(pid, "Выбери профессию светлячком или напиши -pick 1..10")
        end
    end
    A.after(110, function()
        if A.phase == "selection" then
            for pid = 0, 3 do
                if A.active[pid] and not A.picked[pid] then
                    A.pick(pid, GetRandomInt(1, 10))
                end
            end
        end
    end)
    A.say("|cff99ff99Hero Arena Lua|r: 10 профессий, 50 волн, Q/W/E/R.")
end

function config()
    SetMapName("Hero Arena — Lua Reforged")
    SetMapDescription("50 волн, 10 классов, 40 уникальных умений, 1–4 игрока")
    SetPlayers(4)
    SetTeams(1)
    SetGamePlacement(MAP_PLACEMENT_TEAMS_TOGETHER)
    for pid = 0, 3 do
        DefineStartLocation(pid, 0, 0)
        local p = Player(pid)
        SetPlayerStartLocation(p, pid)
        SetPlayerColor(p, ConvertPlayerColor(pid))
        SetPlayerRacePreference(p, RACE_PREF_HUMAN)
        SetPlayerRaceSelectable(p, false)
        SetPlayerController(p, MAP_CONTROL_USER)
        SetPlayerSlotAvailable(p, MAP_CONTROL_USER)
    end
end

function main()
    SetCameraBounds(-9472 + GetCameraMargin(CAMERA_MARGIN_LEFT),
        -9728 + GetCameraMargin(CAMERA_MARGIN_BOTTOM),
        9472 - GetCameraMargin(CAMERA_MARGIN_RIGHT),
        9216 - GetCameraMargin(CAMERA_MARGIN_TOP),
        -9472 + GetCameraMargin(CAMERA_MARGIN_LEFT),
        9216 - GetCameraMargin(CAMERA_MARGIN_TOP),
        9472 - GetCameraMargin(CAMERA_MARGIN_RIGHT),
        -9728 + GetCameraMargin(CAMERA_MARGIN_BOTTOM))
    SetDayNightModels(
        [[Environment\DNC\DNCLordaeron\DNCLordaeronTerrain\DNCLordaeronTerrain.mdl]],
        [[Environment\DNC\DNCLordaeron\DNCLordaeronUnit\DNCLordaeronUnit.mdl]])
    NewSoundEnvironment("Default")
    SetAmbientDaySound("LordaeronSummerDay")
    SetAmbientNightSound("LordaeronSummerNight")
    SetMapMusic("Music", true, 0)
    InitBlizzard()
    Arena.start()
end
