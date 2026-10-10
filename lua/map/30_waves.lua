-- Wave director: ten themed chapters (five waves each), escalating budgets,
-- minibosses with taunts and an end boss without a victory modal.
local A=Arena
A.chapters={
 {"Разбойничий тракт","nban","nrog","ngno"},
 {"Гнолльи стаи","ngno","ngna","nrog"},
 {"Троллья засада","nftr","nftb","nogr"},
 {"Огрские заставы","nogr","nrog","nftr"},
 {"Восстание костей","uske","nska","ucry"},
 {"Склеп паучьего короля","ucry","uske","nska"},
 {"Осквернённая охота","nfel","nska","nftr"},
 {"Врата Скверны","nfel","nogr","uske"},
 {"Некрополь","uske","uabo","nska"},
 {"Армия Каз'Рула","uske","nfel","uabo"}
}
A.eliteNames={"Вожак головорезов","Капитан стаи","Шаман троллей",
"Огр-землелом","Пророк костей","Паучий патриарх",
"Ловчий Скверны","Пожиратель стали","Собиратель душ",
"Предвестник Каз'Рула"}
A.eliteTaunts={
"Ваши головы украсят нашу крепость!",
"Мы охотимся стаей!",
"Предки требуют ваши души!",
"Я раскрошу ваши кости!",
"Мёртвые встают по моей воле!",
"Паутина станет вашей могилой!",
"Скверна пожрёт вашу плоть!",
"Ваши клинки сломаются!",
"Каждая смерть приближает повелителя!",
"Каз'Рул уже ждёт вас!"
}
local function theme(wave)
    local chapter=math.max(1,math.min(10,math.floor((wave-1)/5)+1))
    return A.chapters[chapter],chapter
end
local function randomPosition(radius)
    local angle=GetRandomReal(0,math.pi*2)
    return math.cos(angle)*radius+GetRandomReal(-100,100),
           math.sin(angle)*radius+GetRandomReal(-100,100)
end
function A.spawnEnemy(raw,rank,elite)
    if A.waveAlive>=70 then return nil end
    local x,y=randomPosition(GetRandomReal(1140,1550))
    local u=CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE),A.raw(raw),x,y,270)
    if not u then return nil end
    local id=GetHandleId(u)
    A.waveUnits[id]={unit=u,wave=A.wave,elite=elite and true or false}
    A.waveAlive=A.waveAlive+1
    SetUnitCreepGuard(u,false)
    UnitWakeUp(u)
    SetUnitAcquireRange(u,4100)
    if elite then
        SetUnitScale(u,1.3,1.3,1.3)
        SetUnitVertexColor(u,255,170,110,255)
        UnitAddAbility(u,A.raw("ACav"))
    end
    IssuePointOrder(u,"attack",0,0)
    return u
end
function A.rewardGold(amount)
    for pid=0,3 do if A.active[pid] then
        local p=Player(pid)
        SetPlayerState(p,PLAYER_STATE_RESOURCE_GOLD,
            GetPlayerState(p,PLAYER_STATE_RESOURCE_GOLD)+amount)
    end end
end
function A.eliteSpawn()
    local wave=A.wave
    local chapter=math.floor((wave-1)/5)+1
    local conf=A.chapters[chapter]
    local elite=A.spawnEnemy(conf[3],wave,true)
    if not elite then return end
    A.elite=elite
    A.say("|cffff7744[МИНИ-БОСС] "..A.eliteNames[chapter]..
       ": "..A.eliteTaunts[chapter].."|r",13)
    A.text(GetUnitX(elite),GetUnitY(elite),A.eliteNames[chapter],0.034,9)
    PingMinimap(GetUnitX(elite),GetUnitY(elite),5)
    A.fx([[Abilities\Spells\Human\ThunderClap\ThunderClapCaster.mdl]],GetUnitX(elite),GetUnitY(elite))
end
function A.beginWaves()
    if A.phase~="selection" then return end
    A.phase="waves"
    A.say("|cff88ccffВсе герои выбраны. Первая волна через 12 секунд.|r")
    A.scheduleNext(12)
end
function A.scheduleNext(wait)
    A.nextAt=A.clock+wait
end
function A.nextWave()
    if A.phase~="waves" then return end
    if A.wave>=50 then
        A.spawnBoss()
        return
    end
    A.wave=A.wave+1
    A.nextAt=nil
    local cfg,chapter=theme(A.wave)
    local count=math.min(25,5+math.floor(A.wave*.22)+2*A.playerCount())
    local support=math.min(12,2+math.floor(A.wave*.1)+A.playerCount())
    for i=1,count do A.spawnEnemy(cfg[2],A.wave,false) end
    for i=1,support do A.spawnEnemy(cfg[3],A.wave,false) end
    if A.wave%5==0 then A.eliteSpawn() end
    A.rewardGold(35+5*A.wave)
    A.say("|cffffcc00Волна "..A.wave.."/50 — "..cfg[1]..
        "|r. Врагов: "..A.waveAlive)
    A.nextAt=A.clock+95
end
function A.dropLoot(unit,elite)
    local wave=A.wave
    local chance=math.min(0.115,0.009+wave*.0012+(elite and .09 or 0))
    if GetRandomReal(0,1)>chance then return end
    local tiers={
      {"I007","I008","I00F"},
      {"I001","I003","I00D","I00E"},
      {"I004","I005","I00G","I00H"},
      {"I009","I00I","I00J","I00K","I00L"},
      {"I00A","I00B","I00C","I00M","I00N","I00O"}
    }
    local tier=math.min(5,1+math.floor(wave/11))
    local options=tiers[tier]
    local id=options[GetRandomInt(1,#options)]
    CreateItem(A.raw(id),GetUnitX(unit),GetUnitY(unit))
end
function A.enemyDied(unit)
    local id=GetHandleId(unit)
    local tracked=A.waveUnits[id]
    if tracked then
        A.waveUnits[id]=nil
        A.waveAlive=math.max(0,A.waveAlive-1)
        A.kills=A.kills+1
        -- XP is explicitly controlled here before removing the tracked enemy.
        local killer=GetKillingUnit()
        if killer then
            local pid=GetPlayerId(GetOwningPlayer(killer))
            local hero=pid>=0 and pid<=3 and A.heroUnits[pid] or nil
            if A.alive(hero) then
                AddHeroXP(hero,math.floor(4+A.wave*.65+(tracked.elite and 24 or 0)),true)
            end
        end
        A.dropLoot(unit,tracked.elite)
        if A.onEnemyKill then A.onEnemyKill(unit,tracked.elite) end
        A.rewardGold(2+math.floor(A.wave*.45))
        if tracked.elite then
            A.rewardGold(45+A.wave*3)
            A.say("|cff99ff66Мини-босс повержен! Бонусное золото команде.|r")
        end
        if A.waveAlive==0 and A.phase=="waves" and A.wave>0 then
            A.say("|cff77ff77Волна зачищена! Следующая через 7 сек.|r")
            A.scheduleNext(7)
        end
        return
    end
    if unit==A.boss then A.endBoss() end
end
function A.spawnBoss()
    if A.phase~="waves" or A.boss then return end
    A.phase="boss"
    A.nextAt=nil
    local u=CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE),A.raw("Nplh"),0,1120,270)
    if not u then
        A.say("Босс не создан: проверьте Nplh.")
        return
    end
    A.boss=u
    SetHeroLevel(u,16+A.playerCount(),false)
    SetHeroStr(u,65+12*A.playerCount(),true)
    SetHeroAgi(u,20+4*A.playerCount(),true)
    SetHeroInt(u,28+5*A.playerCount(),true)
    A.say("|cffff5555[ФИНАЛЬНЫЙ БОСС] Каз'Рул: Ни один герой не выйдет отсюда живым!|r",18)
    PingMinimap(0,1120,7)
    A.bossPhase=0
    IssuePointOrder(u,"attack",0,0)
end
function A.tickBoss()
    local boss=A.boss
    if not A.alive(boss) then return end
    local ratio=GetWidgetLife(boss)/math.max(1,GetUnitState(boss,UNIT_STATE_MAX_LIFE))
    local phase=ratio<=.3 and 2 or (ratio<=.65 and 1 or 0)
    if phase>A.bossPhase then
       A.bossPhase=phase
       A.say("|cffff7755Каз'Рул: "..(phase==1 and "Вы пробудили мою ярость!" or "Последние силы тьмы!"))
       for i=1,3+A.playerCount() do A.spawnEnemy("uske",A.wave,false) end
       for pid=0,3 do if A.alive(A.heroUnits[pid]) then
          A.area(boss,GetUnitX(boss),GetUnitY(boss),430,
              (phase==2 and 55 or 42)+10*A.playerCount())
          break
       end end
    end
end
function A.endBoss()
    if A.phase~="boss" then return end
    A.phase="postgame"
    A.boss=nil
    A.rewardGold(1500)
    A.say("|cff66ff99ПОБЕДА! Каз'Рул уничтожен. Арена остаётся открытой. Окно победы отключено.|r",30)
end
function A.clearEnemies()
    local units={}
    for _,entry in pairs(A.waveUnits) do units[#units+1]=entry.unit end
    for _,unit in ipairs(units) do
        if A.alive(unit) then KillUnit(unit) end
    end
    if A.alive(A.boss) then KillUnit(A.boss) end
end
function A.forceNextWave()
    if A.phase~="waves" then return end
    A.clearEnemies()
    A.scheduleNext(.4)
end
function A.tickWaves()
    if A.phase=="waves" and A.nextAt and A.clock>=A.nextAt then
       A.nextWave()
    elseif A.phase=="boss" then
       A.tickBoss()
    end
end
function A.initWaves()
    SetPlayerHandicapXP(Player(PLAYER_NEUTRAL_AGGRESSIVE),1.0)
    local deathTrigger=CreateTrigger()
    TriggerRegisterAnyUnitEventBJ(deathTrigger,EVENT_PLAYER_UNIT_DEATH)
    TriggerAddAction(deathTrigger,function()A.enemyDied(GetTriggerUnit())end)
end
