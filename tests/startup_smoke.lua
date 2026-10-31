-- Minimal Warcraft API simulation. Undefined functions deliberately raise errors.
local state = {triggers = {}, timers = {}, starts = {}, players = {}, units = {}, chat = "", activePlayers = 1}
for _, name in ipairs({
    "MAP_CONTROL_USER", "MAP_CONTROL_COMPUTER", "PLAYER_SLOT_STATE_PLAYING",
    "ALLIANCE_PASSIVE", "ALLIANCE_SHARED_VISION", "EVENT_PLAYER_LEAVE",
    "RACE_PREF_HUMAN", "MAP_PLACEMENT_TEAMS_TOGETHER", "PLAYER_STATE_RESOURCE_GOLD",
    "CAMERA_MARGIN_LEFT", "CAMERA_MARGIN_RIGHT", "CAMERA_MARGIN_TOP", "CAMERA_MARGIN_BOTTOM",
    "EVENT_PLAYER_UNIT_ISSUED_ORDER", "EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER", "EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER", "EVENT_PLAYER_UNIT_ATTACKED", "EVENT_PLAYER_UNIT_SPELL_EFFECT",
    "EVENT_PLAYER_UNIT_PICKUP_ITEM", "EVENT_PLAYER_UNIT_DEATH", "EVENT_PLAYER_HERO_LEVEL", "EVENT_PLAYER_UNIT_DAMAGED"
}) do _G[name] = name end
PLAYER_NEUTRAL_PASSIVE = 27
PLAYER_NEUTRAL_AGGRESSIVE = 24
ABILITY_RLF_CAST_RANGE = 'castRange'

function FourCC(s)
    assert(#s == 4, "invalid rawcode: " .. s)
    local value = string.unpack(">I4", s)
    return value
end
function Player(id)
    state.players[id] = state.players[id] or {id = id, gold = 0}
    return state.players[id]
end
function GetPlayerId(p) return p.id end
function GetPlayerSlotState(p) return p.id < state.activePlayers and PLAYER_SLOT_STATE_PLAYING or "empty" end
function GetPlayerController(p) return p.controller end
function SetPlayerController(p, controller) p.controller = controller end
function SetPlayerSlotAvailable(p, controller) p.controller = controller end
function DefineStartLocation(id, x, y) state.starts[id] = {x, y} end
function SetPlayerStartLocation(p, id) assert(state.starts[id], "undefined start location") end
function GetCameraMargin() return 0 end
function ConvertPlayerColor(id) return id end
function GetLocalPlayer() return Player(0) end
function GetTriggerPlayer() return state.triggerPlayer or Player(0) end
function SetPlayerAlliance(p,other,kind,enabled)
    p.alliances=p.alliances or {};p.alliances[other.id]=p.alliances[other.id] or {}
    p.alliances[other.id][kind]=enabled
end
function GetTriggerUnit() return state.triggerUnit end
function GetClickedButton() return state.clicked end
function GetEventPlayerChatString() return state.chat end

local function handle() return {} end
function Location(x,y) return {x=x,y=y} end
function GetLocationZ() return 0 end
function RemoveLocation() end
function AddLightningEx() return {} end
function SetLightningColor() end
function DestroyLightning(lightning) lightning.destroyed=true end
function CreateTrigger()
    local trigger = {actions = {}}
    table.insert(state.triggers, trigger)
    return trigger
end
function TriggerAddAction(trigger, callback) table.insert(trigger.actions, callback) end
function TriggerRegisterTimerEvent(trigger, delay, periodic)
    trigger.delay, trigger.periodic = delay, periodic
end
function TriggerRegisterDialogEvent(trigger, dialog) trigger.dialog = dialog end
function TriggerRegisterPlayerEvent(trigger,player,event) trigger.playerEvent=event end
function TriggerRegisterAnyUnitEventBJ(trigger, event) trigger.event = event end
function CreateTimer()
    local timer = {}
    table.insert(state.timers, timer)
    return timer
end
function TimerStart(timer, delay, periodic, callback)
    assert(timer and type(callback) == "function", "invalid timer callback")
    timer.delay, timer.periodic, timer.callback = delay, periodic, callback
end
CreateTimerDialog, DialogCreate, DialogAddButton, CreateQuest = handle, handle, handle, handle
AddSpecialEffectTarget = handle
AddSpecialEffect = handle
function CreateUnit(owner, id, x, y, facing)
    if state.failCreate then return nil end
    local unit = {owner = owner, id = id, life = 100, x=x,y=y, abilities = {[FourCC('AHer')] = true}, inventory = {}}
    table.insert(state.units, unit)
    return unit
end
function UnitAddAbility(unit, id) unit.abilities[id] = true end
function BlzGetUnitAbility(unit, id) return unit.abilities[id] and {unit=unit,id=id} or nil end
function BlzSetAbilityRealLevelField(ability, field, level, value)
    assert(field==ABILITY_RLF_CAST_RANGE and level>=0 and level<=4)
    ability.unit.ranges = ability.unit.ranges or {}
    ability.unit.ranges[ability.id] = value
    return true
end
function GetUnitAbilityLevel(unit,id) return unit.levels and unit.levels[id] or 1 end
function SetUnitAbilityLevel(unit,id,level)
    unit.levels = unit.levels or {};unit.levels[id]=level
end
function UnitRemoveAbility(unit, id)
    assert(id ~= FourCC('AHer'), 'removing internal hero state can crash the client')
    unit.abilities[id] = nil
end
function BlzUnitDisableAbility(unit, id, disabled, hidden)
    if id ~= FourCC('AHer') then
        assert(unit.abilities[id], 'disable only attached abilities')
        unit.disabled = unit.disabled or {}
        unit.disabled[id] = disabled
        assert(hidden == false, 'locked abilities stay visible')
        return
    end
    assert(unit.abilities[id])
    assert(disabled == false and hidden == true, 'keep internal hero ability enabled')
    unit.learningHidden = hidden
    unit.hideCalls = (unit.hideCalls or 0) + 1
end
function GetHeroLevel(unit) return unit.heroLevel or 1 end
function BlzSetUnitBaseDamage(unit, amount) unit.baseDamage=amount end
function CreateDestructable() return {} end
function SelectUnitForPlayerSingle(unit)
    assert(unit.abilities[FourCC('AHer')], 'cannot select hero with removed internal state')
end
function GetHeroSkillPoints(unit) return unit.skillPoints or 1 end
function UnitModifySkillPoints(unit, delta) unit.skillPoints = GetHeroSkillPoints(unit) + delta end
function SetPlayerAbilityAvailable(player, id, available) player.learningAvailable = available end
function GetWidgetLife(unit) return unit.life end
function GetOwningPlayer(unit) return unit.owner end
function SetUnitOwner(unit,owner) unit.owner=owner end
function SetUnitCreepGuard(unit,flag)
    assert(unit.owner.id==9 and flag==false)
    unit.guardCleared=true
end
function RemoveGuardPosition(unit) unit.guardRemoved=true end
function UnitIgnoreAlarm(unit,flag) unit.ignoresAlarm=flag end
function GetPlayerState(p) return p.gold end
function SetPlayerState(p, field, value) p.gold = value end
function GetRandomReal(low, high) return (low + high) / 2 end
function UnitItemInSlot(unit, slot) return unit.inventory[slot] end
function GetItemTypeId(item) return item.id end
function RemoveItem(item) item.removed = true end
function UnitAddItemById(unit, id) state.crafted = id; return {id = id} end

local function noop() end
for name in string.gmatch([[
    SetPlayerColor SetPlayerRacePreference SetPlayerRaceSelectable SetPlayerTeam
    SetMapName SetMapDescription SetPlayers SetTeams SetGamePlacement SetCameraBounds
    SetDayNightModels NewSoundEnvironment SetAmbientDaySound SetAmbientNightSound SetMapMusic
    InitBlizzard TriggerRegisterPlayerUnitEvent
    TriggerRegisterPlayerChatEvent DialogSetMessage DialogDisplay
    TimerDialogSetTitle TimerDialogDisplay FogEnableOff FogMaskEnableOff
    PanCameraToTimedForPlayer DisplayTextToPlayer DisplayTimedTextToPlayer
    QuestSetTitle QuestSetDescription QuestSetRequired QuestSetDiscovered FlashQuestDialogButton
    AddItemToStock
    SetUnitUserData UnitWakeUp SetUnitAcquireRange IssuePointOrder DestroyEffect
    SetDestructableInvulnerable BlzSetSpecialEffectYaw BlzSetSpecialEffectScale
]], "%S+") do _G[name] = noop end
print = noop

local function chat(message)
    state.chat = message
    for _, action in ipairs(Arena_ChatTrigger.actions) do action() end
end

function RunStartupSmoke(role, activePlayers)
    state.activePlayers = activePlayers
    config()
    main()
    assert(#HeroClasses == 10 and udg_HumanCount == activePlayers)
    assert(not udg_WavesStarted)
    for _, trigger in ipairs(state.triggers) do
        if trigger.delay == 0.5 and not trigger.periodic then
            for _, action in ipairs(trigger.actions) do action() end
        end
    end
    assert(HeroDialog and #HeroDialogButtons == 10 and Arena_ChatTrigger)
    for _, timer in ipairs(state.timers) do
        if timer.periodic then timer.callback() end
    end
    chat("-1.5")
    chat("-11")
    chat("-hello")
    assert(Heroes[0] == nil and not udg_WavesStarted)

    state.failCreate = true
    SpawnSelectedHero(0, role)
    assert(Heroes[0] == nil and not udg_WavesStarted)
    state.failCreate = false
    if role % 2 == 0 then
        chat("-" .. role)
    else
        state.clicked = HeroDialogButtons[role]
        for _, trigger in ipairs(state.triggers) do
            if trigger.dialog == HeroDialog then
                for _, action in ipairs(trigger.actions) do action() end
            end
        end
    end
    local hero = Heroes[0]
    assert(hero and hero.id == HeroClasses[role].id and HeroKind[0] == role)
    assert(hero.disabled[HeroClasses[role].spells[4]], 'ultimate locked at level 1')
    assert(hero.skillPoints == 0 and hero.learningHidden == true)
    hero.skillPoints = 3
    state.triggerUnit = hero
    for _, trigger in ipairs(state.triggers) do
        if trigger.event == EVENT_PLAYER_HERO_LEVEL then
            for _, action in ipairs(trigger.actions) do action() end
        end
    end
    assert(hero.disabled[HeroClasses[role].spells[4]], 'ultimate still locked below level 5')
    hero.heroLevel = 5
    for _, trigger in ipairs(state.triggers) do
        if trigger.event == EVENT_PLAYER_HERO_LEVEL then
            for _, action in ipairs(trigger.actions) do action() end
        end
    end
    assert(not hero.disabled[HeroClasses[role].spells[4]], 'ultimate opens at level 5')
    assert(hero.skillPoints == 0, 'learning points must stay disabled after leveling')
    assert(hero.abilities[FourCC('AHer')] and hero.hideCalls == 1,
        'hero state must survive selection/leveling and hiding must not accumulate')
    for _, id in ipairs(HeroClasses[role].spells) do assert(hero.abilities[id]) end
    if role==3 then
        assert(hero.ranges[FourCC('A105')]==1200 and hero.ranges[FourCC('A106')]==1200)
    end
    if activePlayers>1 then
        assert(not udg_WavesStarted, 'wait for every connected player to choose')
        for pid=1,activePlayers-1 do SpawnSelectedHero(pid,(role+pid-1)%10+1) end
    end
    assert(udg_WavesStarted and udg_WaveTimer.delay == 15)
    local units = #state.units
    chat("-1")
    assert(Heroes[0] == hero and #state.units == units, "duplicate hero selection")
    udg_WaveTimer.callback()
    assert(udg_Wave == 1 and udg_EnemiesAlive > 0 and udg_WaveTimer.delay == 45)

    local first, second = {id = FourCC('boot')}, {id = FourCC('glov')}
    hero.inventory = {[0] = first, [1] = second}
    Arena_CheckItemCrafting(hero)
    assert(first.removed and second.removed and state.crafted == FourCC('I001'))
end

function RunCoopSmoke(leaveBeforeChoice)
    state.activePlayers=2
    config();main()
    for _,trigger in ipairs(state.triggers) do
        if trigger.delay==0.5 and not trigger.periodic then
            for _,action in ipairs(trigger.actions) do action() end
        end
    end
    assert(udg_HumanCount==2)
    for from=0,1 do
        local flags=Player(from).alliances[1-from]
        assert(flags[ALLIANCE_PASSIVE] and flags[ALLIANCE_SHARED_VISION])
    end
    state.triggerPlayer=Player(1)
    chat('-4')
    assert(Heroes[1] and Heroes[1].owner==Player(1) and Heroes[0]==nil)
    assert(not udg_WavesStarted and udg_WaveTimer.delay==nil)
    state.triggerPlayer=Player(0)
    if leaveBeforeChoice then
        for _,trigger in ipairs(state.triggers) do
            if trigger.playerEvent==EVENT_PLAYER_LEAVE then
                for _,action in ipairs(trigger.actions) do action() end
            end
        end
        assert(ArenaLeft[0] and udg_HumanCount==1)
    else
        chat('-3')
        assert(Heroes[0] and Heroes[0]~=Heroes[1] and HeroKind[0]==3 and HeroKind[1]==4)
        assert(Heroes[0].x~=Heroes[1].x or Heroes[0].y~=Heroes[1].y)
    end
    assert(udg_WavesStarted and udg_WaveTimer.delay==15)
    udg_WaveTimer.callback()
    assert(udg_Wave==1 and udg_EnemiesAlive>0 and udg_WaveTimer.delay==45)
    assert(Player(1).gold>0)
    if not leaveBeforeChoice then assert(Player(0).gold==Player(1).gold) end
end
