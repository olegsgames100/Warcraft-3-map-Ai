-- Hero Arena Reforged: first Lua-native gameplay module.
-- IMPORTANT: This module is not loaded by the existing JASS war3map.j.
-- Load it with require("arena.hero_growth") (or embed) after converting the map
-- in Reforged World Editor to Lua script mode. Keep single ownership of stat gains.
local Growth = {}
Growth.base = {
    [1]={str=28, agi=14, int=20, ds=3.6, da=1.6, di=2.2},
    [2]={str=19, agi=29, int=13, ds=2.0, da=3.7, di=1.6},
    [3]={str=16, agi=15, int=29, ds=1.8, da=1.7, di=3.8},
    [4]={str=26, agi=16, int=22, ds=3.3, da=1.7, di=2.8},
    [5]={str=20, agi=28, int=17, ds=2.2, da=3.4, di=2.0},
    [6]={str=18, agi=25, int=24, ds=2.0, da=3.1, di=3.0},
    [7]={str=19, agi=16, int=29, ds=2.1, da=2.2, di=3.1},
    [8]={str=30, agi=15, int=17, ds=2.1, da=2.2, di=3.1},
    [9]={str=20, agi=27, int=20, ds=2.1, da=2.2, di=3.1},
    [10]={str=17, agi=18, int=30, ds=2.1, da=2.2, di=3.1},
}
Growth.players = {}

local function progress(base, gain, level)
    return base + math.floor((level - 1) * gain + 0.5)
end

function Growth.preview(kind, level)
    local cfg = assert(Growth.base[kind], "Unknown hero profession")
    level = math.min(20, math.max(1, level))
    return progress(cfg.str, cfg.ds, level),
           progress(cfg.agi, cfg.da, level),
           progress(cfg.int, cfg.di, level)
end

function Growth.register(playerId, hero, kind)
    assert(Growth.base[kind], "Unknown profession: " .. tostring(kind))
    -- Object Editor growth must be set to ZERO when Lua owns the attributes.
    Growth.players[playerId] = {hero=hero, kind=kind}
    Growth.sync(playerId)
end

function Growth.sync(playerId)
    local state = Growth.players[playerId]
    if not state or GetUnitTypeId(state.hero) == 0 then return end
    local strength, agility, intelligence = Growth.preview(state.kind, GetHeroLevel(state.hero))
    SetHeroStr(state.hero, strength, true)
    SetHeroAgi(state.hero, agility, true)
    SetHeroInt(state.hero, intelligence, true)
end

function Growth.install()
    local trig = CreateTrigger()
    for pid=0,3 do
        TriggerRegisterPlayerUnitEvent(trig, Player(pid), EVENT_PLAYER_HERO_LEVEL, nil)
    end
    TriggerAddAction(trig, function()
        local hero=GetTriggerUnit()
        local pid=GetPlayerId(GetOwningPlayer(hero))
        if Growth.players[pid] and Growth.players[pid].hero==hero then
            Growth.sync(pid)
        end
    end)
    return trig
end

return Growth
