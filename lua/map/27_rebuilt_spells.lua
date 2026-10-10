-- Hero Arena: v3 tactical skills. 48 independent QWER actions; one dispatcher.
-- Keep spells / cooldowns / target modes aligned with party_heroes.json.
local A=Arena
local H={}
local F={}
local function p(rank)return 30+rank*23 end
local function res(pid,name,delta)
    local r=A.resources[pid]
    r[name]=math.max(0,math.min(100,(r[name] or 0)+delta))
    return r[name]
end
local function spend(pid,name)
    local n=A.resources[pid][name] or 0
    A.resources[pid][name]=0
    return n
end
local function s(pid)return A.role(pid)end
local function pos(u)return GetUnitX(u),GetUnitY(u)end
local function fx(path,x,y)
    A.visual(path,x,y,1.35)
end
local LIGHT=[[Abilities\Spells\Human\HolyBolt\HolyBoltSpecialArt.mdl]]
local ICE=[[Abilities\Spells\Undead\FrostNova\FrostNovaTarget.mdl]]
local BLOOD=[[Abilities\Spells\Other\Stampede\StampedeMissileDeath.mdl]]
local BOLT=[[Abilities\Spells\Orc\LightningShield\LightningShieldTarget.mdl]]
local BONES=[[Abilities\Spells\Undead\AnimateDead\AnimateDeadTarget.mdl]]
local function line(h,x,y,length,width,amount,school,onHit)
    A.launchShot(h,GetUnitX(h),GetUnitY(h),x,y,length,1500,width,amount,school,onHit)
end
local function allies(h,fn)A.forAllies(h,nil,fn)end
local function foes(h,x,y,r,fn)
    A.withUnits(x,y,r,function(u)if A.isEnemy(h,u)then fn(u)end end)
end
local function wound(h,target,amount,school)
    if target and A.isEnemy(h,target)then A.spellDamage(h,target,amount,school);return true end
    return false
end
local function enemy(h,t)return A.pickEnemy(h,t,900)end
local function defend(h,u,amount,seconds)
    A.addShield(u,amount,seconds)
    A.visual(LIGHT,GetUnitX(u),GetUnitY(u),1.2)
end
local function chooseFriend(h,target) return A.findAlly(h,target,1050) end
local function forward(h,range,arc,amount,school,cb) return A.spellCone(h,range,arc,amount,school,cb) end
local function area(h,x,y,r,amount,school,cb) return A.spellArea(h,x,y,r,amount,school,cb) end
local function delayed(h,delay,fn)A.after(delay,function()if A.alive(h)then fn()end end)end
local function ultPair(h,kind,amount)A.recordTwinUltimate(h,kind,amount)end

-- ARBITER REYNAR: protection player reads threat, positions shield and spends Resolve.
H[1]={
 function(c)
    local h=c.h
    local hits=forward(h,510,125,c.b*1.15,"physical",function(v) A.stunEnemy(h,v,.4) end)
    A.taunt(h,680)
    res(c.pid,"valor",8+hits*7)
    local x,y=pos(h)
    A.visualRing(LIGHT,x,y,250,7,1.1)
    A.showValor(c.pid,true)
 end,
 function(c)
    local h=c.h
    local st=s(c.pid)
    st.bastion={x=c.x,y=c.y,expires=A.clock+11,next=A.clock,radius=475,caster=h}
    A.spawnBastionDome(h,st.bastion)
    A.showValor(c.pid,true)
 end,
 function(c)
    local h=c.h
    local friend=c.target
    A.moveToward(h,GetUnitX(friend),GetUnitY(friend),825)
    defend(h,friend,c.b*2.2*A.statMultiplier(h,"physical"),8)
    A.protect(h,friend,.36,8)
    A.taunt(h,360)
    fx(LIGHT,GetUnitX(friend),GetUnitY(friend))
    res(c.pid,"valor",12)
 end,
 function(c)
    local h=c.h
    local valor=spend(c.pid,"valor")
    local str=A.statMultiplier(h,"physical")
    local x,y=pos(h)
    local n=0
    for pid=0,3 do
        local u=A.heroUnits[pid]
        if A.alive(u) and IsUnitAlly(u,GetOwningPlayer(h)) then
           local dx,dy=GetUnitX(u)-x,GetUnitY(u)-y
           if dx*dx+dy*dy<=1000*1000 then
              n=n+1
              A.grantLastOath(u,10,35)
              defend(h,u,(c.b+valor*.8)*str,10)
              fx(LIGHT,GetUnitX(u),GetUnitY(u))
           end
        end
    end
    A.visualRing(LIGHT,x,y,560,12,2)
    A.playerText(c.pid,"|cffffd966Клятва: "..n.." героев защищено, одно воскрешение у каждого.|r")
 end
}

-- ZARHAN: bleeding single-target swordsman, attack-timing counter, blink execute.
H[2]={
 function(c)
    local h=c.h
    A.moveToward(h,c.x,c.y,460)
    forward(h,330,95,c.b*1.6,"physical",function(v)
        A.applyBleed(h,v,2,9)
    end)
    res(c.pid,"combo",18)
 end,
 -- W is a persistent attack passive, processed by A.modifyIncoming.
 function(c) return end,
 function(c)
    local h=c.h
    s(c.pid).parry=A.clock+5
    A.haste(h,.13,5)
    defend(h,h,c.b*.65,5)
    fx(BLOOD,GetUnitX(h),GetUnitY(h))
 end,
 function(c)
    local h=c.h
    local t=enemy(h,c.target)
    if not t then return end
    local combo=spend(c.pid,"combo")
    local x,y=pos(t)
    A.moveToward(h,x,y,700)
    wound(h,t,c.b*(1.7+combo*.025),"physical")
    local stacks=A.popBleed(h,t,c.b*.55+combo*.06)
    delayed(h,.24,function()
        if A.isEnemy(h,t)then
            wound(h,t,c.b*(1.15+stacks*.16),"physical")
            if stacks>=3 then A.refundCooldown(h,1,4) end
        end
    end)
 end
}

-- MIRELLA: lightning hop is directed at unit; second spell is anchored point.
H[3]={
 function(c)
    local h=c.h
    local t=enemy(h,c.target)
    if not t then return end
    local seen={}
    local hit=0
    while t and hit<6 do
        hit=hit+1
        seen[GetHandleId(t)]=true
        wound(h,t,c.b*(1.2-(hit-1)*.10),"magic")
        A.buff(t,"vulnerable",.06*math.min(hit,4),6)
        fx(BOLT,GetUnitX(t),GetUnitY(t))
        local tx,ty=pos(t)
        t=A.findEnemy(h,tx,ty,465,function(v)return not seen[GetHandleId(v)]end)
    end
    res(c.pid,"storm",6+hit*5)
 end,
 function(c)
    local tower={x=c.x,y=c.y,expires=A.clock+10,next=A.clock,power=c.b*.85}
    s(c.pid).storm=tower
    A.visualRing(BOLT,c.x,c.y,230,6,2.2)
 end,
 function(c)
    local h=c.h
    local friend=chooseFriend(h,c.target)
    local charge=spend(c.pid,"storm")
    A.mana(friend,c.b*1.8+charge*1.4)
    A.buff(friend,"spellAmp",.18+charge*.002,10)
    A.refundCooldown(friend,1,2.3)
    fx(LIGHT,GetUnitX(friend),GetUnitY(friend))
 end,
 function(c)
    local h=c.h
    local charge=spend(c.pid,"storm")
    local st=s(c.pid).storm
    local places={{c.x,c.y}}
    if st and st.expires>A.clock then places[#places+1]={st.x,st.y};s(c.pid).storm=nil end
    for i=1,4 do
        delayed(h,i*.60,function()
            for _,pt in ipairs(places)do
                area(h,pt[1],pt[2],410,c.b*(1.1+charge*.008),"magic",function(v)
                    A.stunEnemy(h,v,.55)
                end)
                A.visualRing(BOLT,pt[1],pt[2],280,7,.7)
            end
        end)
    end
 end
}

-- MORVEN: curse executions, directed guardian, targeted transfer, corpse army.
H[4]={
 function(c)
    local h=c.h
    local t=enemy(h,c.target)
    if not t then return end
    wound(h,t,c.b*.94,"magic")
    A.doomMarks[GetHandleId(t)]={caster=h,pid=c.pid,expires=A.clock+12,power=c.b}
    fx(BONES,GetUnitX(t),GetUnitY(t))
 end,
 function(c)
    local h=c.h
    local friend=chooseFriend(h,c.target)
    local focus=A.closestEnemy(friend,520)
    A.summonGuard(h,"uske",2+math.floor(c.rank/2),23,focus)
    defend(h,friend,c.b*1.9,10)
    if friend~=h then A.protect(h,friend,.20,9)end
 end,
 function(c)
    local h=c.h
    local t=enemy(h,c.target)
    if not t then return end
    wound(h,t,c.b*1.45,"magic")
    local friend=A.lowestAlly(h,900)
    A.spellHeal(h,friend,c.b*2.1)
    if A.doomMarks[GetHandleId(t)]then res(c.pid,"souls",12)end
 end,
 function(c)
    local h=c.h
    local souls=spend(c.pid,"souls")
    local t=A.findEnemy(h,c.x,c.y,750)
    A.summonGuard(h,"uske",3+math.floor(souls/16),28,t)
    area(h,c.x,c.y,330,c.b*.9+souls*.65,"magic")
    allies(h,function(u)defend(h,u,c.b*1.1+souls,9)end)
    fx(BONES,c.x,c.y)
 end
}

-- VALTIR: physically positioned rift, unit mana burn, mine placement, demon.
H[5]={
 function(c)
    local h=c.h
    local ox,oy=pos(h)
    A.moveToward(h,c.x,c.y,520)
    local nx,ny=pos(h)
    area(h,ox,oy,205,c.b*.75,"physical")
    area(h,nx,ny,245,c.b*1.2,"physical")
    res(c.pid,"fury",17)
    s(c.pid).rift={x=nx,y=ny,expires=A.clock+7,next=A.clock,power=c.b*.27}
    fx(BLOOD,nx,ny)
 end,
 function(c)
    local h=c.h
    local t=enemy(h,c.target)
    if not t then return end
    wound(h,t,c.b*1.6,"magic")
    A.mana(h,c.b*1.6)
    A.spellHeal(h,h,c.b*.85)
    res(c.pid,"fury",14)
 end,
 function(c)
    local t=s(c.pid)
    t.mines=t.mines or {}
    if #t.mines>=3 then table.remove(t.mines,1)end
    t.mines[#t.mines+1]={x=c.x,y=c.y,expires=A.clock+22,power=c.b*1.9}
    A.visualRing(BLOOD,c.x,c.y,130,5,1.1)
 end,
 function(c)
    local h=c.h
    local fury=spend(c.pid,"fury")
    A.buff(h,"felForm",1,12)
    A.buff(h,"physicalAmp",.25+fury*.003,12)
    A.buff(h,"resist",.25,12)
    A.haste(h,.15,12)
    A.spellHeal(h,h,c.b*1.2)
    local mines=s(c.pid).mines or {}
    for _,mine in ipairs(mines)do
        area(h,mine.x,mine.y,320,mine.power,"magic")
        fx(BLOOD,mine.x,mine.y)
    end
    s(c.pid).mines={}
 end
}

-- SELENA: dedicated heal, planted grove, linked rescue, chain of moonlight.
H[6]={
 function(c)
    local h=c.h
    local friend=chooseFriend(h,c.target)
    local health=GetWidgetLife(friend)/math.max(1,GetUnitState(friend,UNIT_STATE_MAX_LIFE))
    A.spellHeal(h,friend,c.b*(2.3+(1-health)*2.1))
    if health>.75 then defend(h,friend,c.b*1.3,8)end
    res(c.pid,"moon",12)
    fx(LIGHT,GetUnitX(friend),GetUnitY(friend))
 end,
 function(c)
    s(c.pid).bloom={x=c.x,y=c.y,expires=A.clock+11,next=A.clock,radius=530,power=c.b*.96}
    A.visualRing(LIGHT,c.x,c.y,350,9,3)
    res(c.pid,"moon",15)
 end,
 function(c)
    local h=c.h
    local friend=chooseFriend(h,c.target)
    defend(h,friend,c.b*4.1,10)
    A.buff(friend,"resist",.28,10)
    A.buff(friend,"healAmp",.15,10)
    A.spellHeal(h,friend,c.b*.7)
    fx(LIGHT,GetUnitX(friend),GetUnitY(friend))
 end,
 function(c)
    local h=c.h
    local moon=spend(c.pid,"moon")
    local hx,hy=pos(h)
    for pid=0,3 do
        local friend=A.heroUnits[pid]
        if friend and IsUnitAlly(friend,GetOwningPlayer(h))then
            if not A.alive(friend)then ReviveHero(friend,hx,hy,true)end
            if A.alive(friend)then
                A.spellHeal(h,friend,c.b*2.4+moon*1.6)
                defend(h,friend,c.b*1.2,9)
            end
        end
    end
    local grove=s(c.pid).bloom
    if grove and grove.expires>A.clock then
        grove.power=grove.power*2;grove.expires=A.clock+10
    end
 end
}

-- FENN: unit-target stimulant, flask, mana catalyst, gold+team alchemy.
H[7]={
 function(c)
    local h=c.h
    local friend=chooseFriend(h,c.target)
    A.buff(friend,"physicalAmp",.28,12)
    A.haste(friend,.18,12)
    defend(h,friend,c.b*.50,7)
    fx(LIGHT,GetUnitX(friend),GetUnitY(friend))
 end,
 function(c)
    local h=c.h
    A.spellTrap(h,c.x,c.y,.65,300,c.b*.90,"magic",function(v)
        A.buff(v,"vulnerable",.27,9)
        A.slowEnemy(h,v,.27,5)
    end)
    fx(BLOOD,c.x,c.y)
 end,
 function(c)
    local h=c.h
    local friend=chooseFriend(h,c.target)
    A.mana(friend,c.b*2.1)
    A.buff(friend,"spellAmp",.30,11)
    A.refundCooldown(friend,2,3)
    fx(BOLT,GetUnitX(friend),GetUnitY(friend))
 end,
 function(c)
    local h=c.h
    local amount=0
    local hx,hy=pos(h)
    foes(h,hx,hy,530,function(v)
        if A.statusValue(v,"vulnerable")>0 then
            wound(h,v,c.b*1.25,"magic");amount=amount+1
        end
    end)
    local gold=math.min(120,amount*15)
    if gold>0 then
        local player=GetOwningPlayer(h)
        SetPlayerState(player,PLAYER_STATE_RESOURCE_GOLD,GetPlayerState(player,PLAYER_STATE_RESOURCE_GOLD)+gold)
    end
    allies(h,function(u)
        A.buff(u,"physicalAmp",.22,12)
        A.buff(u,"spellAmp",.22,12)
        A.haste(u,.12,12)
        defend(h,u,c.b*2.1,12)
        A.spellHeal(h,u,c.b)
    end)
 end
}

-- TORVIN: target hammer stun, gravity point, reactive stone, quake ring.
H[8]={
 function(c)
    local h=c.h
    local t=enemy(h,c.target)
    if not t then return end
    wound(h,t,c.b*1.65,"physical")
    A.stunEnemy(h,t,1.35)
    fx(BOLT,GetUnitX(t),GetUnitY(t))
 end,
 function(c)
    local h=c.h
    foes(h,c.x,c.y,580,function(v)
        A.moveToward(v,c.x,c.y,440)
        wound(h,v,c.b*.84,"physical")
        A.stunEnemy(h,v,.55)
    end)
    A.taunt(h,590)
    fx(BLOOD,c.x,c.y)
 end,
 function(c)
    local h=c.h
    local state=s(c.pid)
    state.stoneExpires=A.clock+12
    state.stoneCount=0
    defend(h,h,c.b*5.5,12)
    A.buff(h,"resist",.3,12)
    A.spellHeal(h,h,c.b*.8)
 end,
 function(c)
    local h=c.h
    local hx,hy=pos(h)
    local hits=A.spellRing(h,hx,hy,160,690,c.b*1.8,"physical",function(v)
       A.knockAway(h,v,hx,hy,220)
       A.stunEnemy(h,v,1.1)
    end)
    defend(h,h,c.b*(1+math.min(8,hits)*.35),10)
    A.taunt(h,740)
    A.visualRing(BLOOD,hx,hy,420,9,2)
 end
}

-- LYRISA: target backstab, branded execution, location return, finisher.
H[9]={
 function(c)
    local h=c.h
    local t=enemy(h,c.target)
    if not t then return end
    local st=s(c.pid)
    st.shadowX,st.shadowY=pos(h)
    local nx,ny=pos(t)
    local face=math.rad(GetUnitFacing(t))
    A.moveToward(h,nx-math.cos(face)*85,ny-math.sin(face)*85,760)
    wound(h,t,c.b*1.75,"physical")
    A.applyBleed(h,t,1,7)
    fx(BLOOD,nx,ny)
 end,
 function(c)
    local h=c.h
    local t=enemy(h,c.target)
    if not t then return end
    wound(h,t,c.b*.9,"physical")
    A.marks[GetHandleId(t)]={warden=c.pid,untilTime=A.clock+11}
    A.buff(t,"vulnerable",.28,11)
 end,
 function(c)
    local h=c.h
    local st=s(c.pid)
    if st.shadowX then
       A.moveToward(h,st.shadowX,st.shadowY,1100)
       st.shadowX=nil
    else A.moveToward(h,c.x,c.y,430)end
    st.parry=A.clock+2.2
    defend(h,h,c.b*.80,5)
    fx(ICE,GetUnitX(h),GetUnitY(h))
 end,
 function(c)
    local h=c.h
    local t=enemy(h,c.target)
    if not t then return end
    local mark=A.marks[GetHandleId(t)]
    local marked=mark and mark.warden==c.pid and mark.untilTime>A.clock
    local ratio=1-GetWidgetLife(t)/math.max(1,GetUnitState(t,UNIT_STATE_MAX_LIFE))
    wound(h,t,c.b*(1.7+ratio*3.1)*(marked and 1.65 or 1),"physical")
    if marked then
       A.marks[GetHandleId(t)]=nil
       A.refundCooldown(h,1,4)
    end
 end
}

-- ISSARA: true traveling frost bolt, unit root, oriented wall, shatter.
H[10]={
 function(c)
    line(c.h,c.x,c.y,940,110,c.b*1.30,"magic",function(v)
       A.addFrost(c.h,v,1)
    end)
 end,
 function(c)
    local h=c.h
    local t=enemy(h,c.target)
    if not t then return end
    A.addFrost(h,t,2)
    A.rootEnemy(h,t,2.2)
    foes(h,GetUnitX(t),GetUnitY(t),230,function(other)
       if other~=t then A.addFrost(h,other,1)end
    end)
    fx(ICE,GetUnitX(t),GetUnitY(t))
 end,
 function(c)
    local h=c.h
    local hx,hy=pos(h)
    local dx,dy=c.x-hx,c.y-hy
    local a=math.atan(dy,dx)+math.pi*.5
    s(c.pid).frostWall={x=c.x,y=c.y,dx=math.cos(a),dy=math.sin(a),
        expires=A.clock+9,next=A.clock,power=c.b}
    A.visualRing(ICE,c.x,c.y,260,7,3)
 end,
 function(c)
    local h=c.h
    local hx,hy=pos(h)
    foes(h,hx,hy,830,function(v)
        local data=A.frostStacks[GetHandleId(v)]
        local stacks=data and data.expiry>A.clock and data.stacks or 0
        wound(h,v,c.b*(1.3+stacks*.7),"magic")
        A.stunEnemy(h,v,.8+stacks*.45)
        A.frostStacks[GetHandleId(v)]=nil
    end)
    A.visualRing(ICE,hx,hy,560,12,2)
 end
}

-- AVALS: physical missile sniper, target volley, empowering stance, snipe.
H[11]={
 function(c)
    local h=c.h
    local st=s(c.pid)
    local charge=(A.boneBlessing[c.pid] or 0)>A.clock and 1.65 or 1
    local precision=1+math.min(6,st.precision or 0)*.10
    st.precision=0
    A.boneBlessing[c.pid]=nil
    line(h,c.x,c.y,1150,110,c.b*1.5*charge*precision,"physical",
        function(v)A.markBone(h,v,10)end)
 end,
 function(c)
    local h=c.h
    local brother=A.allyOfKind(12,h)
    for n=1,7 do
        local radians=n*2.399963
        local length=90+(n%3)*75
        local xx,yy=c.x+math.cos(radians)*length,c.y+math.sin(radians)*length
        delayed(h,n*.21,function()
           area(h,xx,yy,155,c.b*(brother and 1.05 or .84),"physical",
               function(v)A.markBone(h,v,10)end)
           fx(BONES,xx,yy)
        end)
    end
 end,
 function(c)
    local h=c.h
    local brother=A.allyOfKind(12,h)
    A.buff(h,"physicalAmp",.30,12)
    A.haste(h,.12,12)
    s(c.pid).precision=math.min(6,(s(c.pid).precision or 0)+2)
    if brother then defend(h,brother,c.b*2.9,10)end
 end,
 function(c)
    local h=c.h
    local t=enemy(h,c.target)
    if not t then return end
    local x,y=pos(t)
    A.markBone(h,t,12)
    for n=1,5 do
        delayed(h,n*.2,function()
            if A.isEnemy(h,t)then wound(h,t,c.b*(.85+n*.10),"physical")
            else area(h,x,y,230,c.b*.70,"physical")end
        end)
    end
    ultPair(h,11,c.b)
 end
}

-- GELO: detonation brawler, target protection, charge, brother ultimate.
H[12]={
 function(c)
    local h=c.h
    forward(h,445,135,c.b*1.55,"physical",function(v)
        if A.consumeBone(h,v)then
            wound(h,v,c.b*1.55,"physical")
            A.stunEnemy(h,v,1.0)
        end
    end)
 end,
 function(c)
    local h=c.h
    local friend=chooseFriend(h,c.target)
    defend(h,friend,c.b*3.8,10)
    defend(h,h,c.b*2.9,10)
    if friend~=h then A.protect(h,friend,.42,10)end
    local brother=A.allyOfKind(11,h)
    if brother then defend(h,brother,c.b*2.5,10)end
    A.taunt(h,580)
 end,
 function(c)
    local h=c.h
    A.moveToward(h,c.x,c.y,490)
    forward(h,290,160,c.b*1.55,"physical",function(v)
        if A.consumeBone(h,v)then wound(h,v,c.b*1.25,"physical")end
    end)
    local brother,pid=A.allyOfKind(11,h)
    if brother then A.boneBlessing[pid]=A.clock+10 end
 end,
 function(c)
    local h=c.h
    local hx,hy=pos(h)
    A.spellRing(h,hx,hy,0,570,c.b*1.4,"physical",function(v)
        A.stunEnemy(h,v,1.2)
    end)
    A.summonGuard(h,"uske",2+math.floor(c.rank/2),24,A.closestEnemy(h,700))
    ultPair(h,12,c.b)
    fx(BONES,hx,hy)
 end
}

function A.castHero(hero,ability,snapshot)
    local pid=GetPlayerId(GetOwningPlayer(hero))
    if pid<0 or pid>3 or A.heroUnits[pid]~=hero then return false end
    local kind=A.heroKind[pid]
    local slot=nil
    for index,id in ipairs(A.spells[kind])do if A.raw(id)==ability then slot=index;break end end
    if not slot then return false end
    local definition=A.spellDetails[kind][slot]
    local token=GetHandleId(hero)..":"..ability
    local remaining=(A.cooldowns[token] or 0)-A.clock
    if remaining>0 then
        if A.spellDebug then A.playerText(pid,"Cooldown: "..tostring(remaining))end
        return true
    end
    local rank=math.max(1,math.min(5,GetUnitAbilityLevel(hero,ability)))
    local target=(snapshot and snapshot.target) or GetSpellTargetUnit()
    local x=(snapshot and snapshot.x) or GetSpellTargetX()
    local y=(snapshot and snapshot.y) or GetSpellTargetY()
    local hx,hy=pos(hero)
    if definition.target=="instant" then x,y=hx,hy
    elseif definition.target=="unit" then
        if target and A.alive(target)then x,y=pos(target)
        else
            target=(definition.school=="heal" or definition.school=="buff")
                and A.lowestAlly(hero,1000) or A.closestEnemy(hero,900)
            if target then x,y=pos(target) else x,y=hx,hy end
        end
    elseif x==0 and y==0 then x,y=hx,hy end
    local data={h=hero,pid=pid,kind=kind,slot=slot,rank=rank,
        target=target,x=x,y=y,b=p(rank)}
    if kind==2 and slot==2 then return false end
    if kind==1 and slot==3 then
        if not target or target==hero or not A.alive(target) or
           not IsUnitAlly(target,GetOwningPlayer(hero)) or
           not IsUnitType(target,UNIT_TYPE_HERO) then
            A.playerText(pid,"|cffff7777Выбери другого союзного героя.|r")
            return false
        end
        local dx,dy=GetUnitX(target)-hx,GetUnitY(target)-hy
        if dx*dx+dy*dy>definition.range*definition.range then
            A.playerText(pid,"|cffff7777Союзник слишком далеко.|r")
            return false
        end
    end
    -- Lock after validation, not before: invalid target must not eat cooldown.
    A.cooldowns[token]=A.clock+definition.cooldown
    if BlzStartUnitAbilityCooldown then
        BlzStartUnitAbilityCooldown(hero,ability,definition.cooldown)
    end
    H[kind][slot](data)
    if A.onItemSpell then A.onItemSpell(hero,ability)end
    return true
end
