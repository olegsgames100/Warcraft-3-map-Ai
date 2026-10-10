-- Hero creation, professions, progression, guardian and shop/selection.
local A = Arena
A.heroIds = {"H001","O001","H002","U001","E001","E002","N001","H003","E003","U002"}
A.roles = {"Паладин-защитник","Мастер клинка","Боевой архимаг","Рыцарь смерти",
"Охотник на демонов","Лунная жрица","Алхимик-боевик","Горный король",
"Сумрачная охотница","Ледяной лич"}
A.growth = {
 {3.6,1.6,2.2},{2.0,3.7,1.6},{1.8,1.7,3.8},{3.3,1.7,2.8},
 {2.2,3.4,2.0},{2.0,3.1,3.0},{2.1,2.2,3.1},{3.4,1.5,1.9},
 {1.9,3.5,2.0},{1.6,1.9,3.7}
}
A.startStats={{28,14,20},{19,29,13},{16,15,29},{26,16,22},{20,28,17},
{18,25,24},{19,16,29},{30,15,17},{20,27,20},{17,18,30}}
A.spells={
 {"A101","A102","A10D","A10E"},{"A103","A104","A10F","A10G"},
 {"A105","A106","A10H","A10I"},{"A107","A108","A10J","A10K"},
 {"A109","A10A","A10L","A10M"},{"A10B","A10C","A10N","A10O"},
 {"A111","A112","A113","A114"},{"A115","A116","A117","A118"},
 {"A119","A11A","A11B","A11C"},{"A11D","A11E","A11F","A11G"}
}

function A.assignStats(pid)
 local hero=A.heroUnits[pid]
 if not A.alive(hero) then return end
 local kind=A.heroKind[pid]
 local stats=A.startStats[kind]
 local growth=A.growth[kind]
 local levels=math.max(0,math.min(19,GetHeroLevel(hero)-1))
 SetHeroStr(hero,stats[1]+math.floor(levels*growth[1]+0.5),true)
 SetHeroAgi(hero,stats[2]+math.floor(levels*growth[2]+0.5),true)
 SetHeroInt(hero,stats[3]+math.floor(levels*growth[3]+0.5),true)
 local rank=math.min(5,1+math.floor(levels/4))
 for _,ability in ipairs(A.spells[kind]) do
   local id=A.raw(ability)
   if GetUnitAbilityLevel(hero,id)==0 then UnitAddAbility(hero,id) end
   if GetUnitAbilityLevel(hero,id)>0 then SetUnitAbilityLevel(hero,id,rank) end
 end
 local points=GetHeroSkillPoints(hero)
 if points>0 then UnitModifySkillPoints(hero,-points) end
end

function A.createMonument()
 local p=Player(PLAYER_NEUTRAL_PASSIVE)
 local u=CreateUnit(p,A.raw("hhou"),0,0,270)
 if u then
   SetUnitInvulnerable(u,true)
   SetUnitPathing(u,false)
   UnitAddAbility(u,A.raw("Aloc"))
   SetUnitScale(u,0.72,0.72,0.72)
 end
 AddSpecialEffect([[Abilities\Spells\Other\GeneralAuraTarget\GeneralAuraTarget.mdl]],0,0)
 A.text(0,0,"|cff88ccffХРАНИТЕЛЬ АРЕНЫ|r",0.026)
end

function A.checkBalance()
 local n=A.playerCount()
 for pid=0,3 do
    local hero=A.heroUnits[pid]
    if A.active[pid] and hero and A.alive(hero) then
      local hp,mp=0,0
      if n==1 then hp,mp=5.0,3.0
      elseif n==2 then hp,mp=3.0,1.8
      elseif n==3 then hp,mp=1.4,0.8 end
      A.heal(hero,hp*A.tickRate)
      A.mana(hero,mp*A.tickRate)
    end
 end
end

function A.createShops()
 local ids={"nS01","nS02","nS03","nS04"}
 local titles={"КУЗНИЦА","БРОНЯ","АЛХИМИЯ","РЕЛИКВИИ"}
 local x={-760,760,-760,760}
 local y={-380,-380,380,380}
 for i=1,4 do
    local u=CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE),A.raw(ids[i]),x[i],y[i],270)
    A.stockShops[i]=u
    if u then
      SetUnitInvulnerable(u,true)
      SetUnitScale(u,1.1,1.1,1.1)
    end
    A.text(x[i],y[i],titles[i],0.023)
 end
end

function A.selectorPos(kind)
 local column=(kind-1)%5
 local row=math.floor((kind-1)/5)
 return -1600+column*800,6500+row*700
end

function A.prepareSelections()
 local stock={"Hpal","Obla","Hamg","Udea","Edem","Emoo","Nalc","Hmkg","Ewar","Ulic"}
 for kind=1,10 do
   local x,y=A.selectorPos(kind)
   A.markers[kind]={x=x,y=y}
   local preview=CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE),A.raw(stock[kind]),x,y,270)
   if preview then
      SetUnitInvulnerable(preview,true)
      SetUnitPathing(preview,false)
      PauseUnit(preview,true)
      UnitAddAbility(preview,A.raw("Aloc"))
   end
   A.text(x,y,kind..". "..A.roles[kind],0.024)
 end
 for pid=0,3 do
    if A.active[pid] then
        local x=-225+pid*150
        local w=CreateUnit(Player(pid),A.raw("ewsp"),x,5650,90)
        A.wisp[pid]=w
        if w then SelectUnitForPlayerSingle(w,Player(pid)) end
    end
 end
end

function A.pick(pid,kind)
 if not A.active[pid] or A.picked[pid] or kind<1 or kind>10 then return end
 local x=-140+(pid%2)*280
 local y=-140+math.floor(pid/2)*280
 local hero=CreateUnit(Player(pid),A.raw(A.heroIds[kind]),x,y,270)
 if not hero then
    A.playerText(pid,"Не получилось создать профессию. Проверьте war3map.w3u.")
    return
 end
 A.picked[pid]=true
 A.heroUnits[pid]=hero
 A.heroKind[pid]=kind
 A.assignStats(pid)
 UnitAddItemById(hero,A.raw("phea"))
 UnitAddItemById(hero,A.raw("pman"))
 local wisp=A.wisp[pid]
 if wisp then RemoveUnit(wisp);A.wisp[pid]=nil end
 SelectUnitForPlayerSingle(hero,Player(pid))
 PanCameraToTimedForPlayer(Player(pid),x,y,0)
 A.say(GetPlayerName(Player(pid)).." выбрал: "..A.roles[kind])
 local ready=true
 for p=0,3 do if A.active[p] and not A.picked[p] then ready=false end end
 if ready then A.beginWaves() end
end

function A.pollSelections()
 for pid=0,3 do
    local w=A.wisp[pid]
    if A.active[pid] and not A.picked[pid] and A.alive(w) then
        for kind=1,10 do
          local pos=A.markers[kind]
          if (GetUnitX(w)-pos.x)^2+(GetUnitY(w)-pos.y)^2<220^2 then
             A.pick(pid,kind)
             break
          end
        end
    end
 end
end

function A.initHeroEvents()
 local t=CreateTrigger()
 for pid=0,3 do TriggerRegisterPlayerUnitEvent(t,Player(pid),EVENT_PLAYER_HERO_LEVEL,nil) end
 TriggerAddAction(t,function()
    local hero=GetTriggerUnit()
    local pid=GetPlayerId(GetOwningPlayer(hero))
    if A.heroUnits[pid]==hero then
       A.assignStats(pid)
    end
 end)
end

function A.tickHeroes()
 for pid=0,3 do
   local hero=A.heroUnits[pid]
   if A.active[pid] and A.alive(hero) then
      A.assignStats(pid)
   end
 end
end

function A.initInputs()
 local commands={"-kill","-next","-revive","-maxlvl","-stats"}
 local trig=CreateTrigger()
 for pid=0,3 do
    TriggerRegisterPlayerChatEvent(trig,Player(pid),"-pick ",false)
    for _,cmd in ipairs(commands) do TriggerRegisterPlayerChatEvent(trig,Player(pid),cmd,true) end
 end
 TriggerAddAction(trig,function()
    local pid=GetPlayerId(GetTriggerPlayer())
    local cmd=GetEventPlayerChatString()
    local hero=A.heroUnits[pid]
    if cmd:sub(1,6)=="-pick " then
        local kind=tonumber(cmd:match("^%-pick%s+(%d+)$") or "")
        if kind and kind>=1 and kind<=10 then A.pick(pid,kind) end
    elseif cmd=="-revive" then
        if hero and not A.alive(hero) then ReviveHero(hero,0,0,true); A.assignStats(pid) end
    elseif cmd=="-maxlvl" then
        if hero then SetHeroLevel(hero,20,true);A.assignStats(pid) end
    elseif cmd=="-stats" then
        if hero then
            A.playerText(pid,string.format("Уровень %d | Сила %d | Ловкость %d | Интеллект %d",
                GetHeroLevel(hero),GetHeroStr(hero,false),GetHeroAgi(hero,false),GetHeroInt(hero,false)))
        end
    elseif cmd=="-kill" and pid==0 then A.clearEnemies()
    elseif cmd=="-next" and pid==0 then A.forceNextWave()
    end
 end)
end
