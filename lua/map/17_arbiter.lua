-- Arbiter defensive kit: visible Valor/Resolve, persistent bastion, Last Oath.
local A=Arena
A.lastOaths={}
A.valorDisplay={}
local WHITE=[[Abilities\Spells\Human\DivineShield\DivineShieldTarget.mdl]]
local RING=[[Abilities\Spells\Human\MassTeleport\MassTeleportTarget.mdl]]
function A.grantLastOath(u,protection,charge)
    local id=GetHandleId(u)
    A.lastOaths[id]={unit=u,expires=A.clock+protection,reviveUntil=A.clock+charge,
                     charge=1,reviving=false}
    A.visual(WHITE,GetUnitX(u),GetUnitY(u),2,1.4)
end
function A.modifyLastOath(victim,damage)
    local oath=A.lastOaths[GetHandleId(victim)]
    if not oath or damage<=0 then return damage end
    if oath.expires>A.clock then
        local floor=math.max(1,GetUnitState(victim,UNIT_STATE_MAX_LIFE)*.1)
        return math.min(damage,math.max(0,GetWidgetLife(victim)-floor))
    end
    return damage
end
function A.reviveLastOath(hero)
    local id=GetHandleId(hero)
    local oath=A.lastOaths[id]
    if not oath or oath.charge~=1 or oath.reviveUntil<=A.clock then return false end
    oath.charge=0
    oath.reviving=true
    A.after(.15,function()
        if GetUnitTypeId(hero)~=0 then
            local x,y=GetUnitX(hero),GetUnitY(hero)
            ReviveHero(hero,x,y,true)
            if A.alive(hero) then
                SetWidgetLife(hero,GetUnitState(hero,UNIT_STATE_MAX_LIFE)*.40)
                A.visual(WHITE,x,y,2.5,1.6)
                A.say("|cffffdc88Клятва Арбитра воскресила героя!|r")
            end
        end
        A.lastOaths[id]=nil
    end)
    return true
end
function A.spawnBastionDome(caster,b)
    A.visualRing(RING,b.x,b.y,b.radius,14,2.5)
    A.text(b.x,b.y,"|cffffdd77БАСТИОН — 11 СЕКУНД|r",.025,11)
    A.say("|cffffff88Арбитр установил Бастион! Защищайте эту область.|r",4)
end
function A.showValor(pid,force)
    local u=A.heroUnits[pid]
    if not A.alive(u) or A.heroKind[pid]~=1 then return end
    local valor=A.resources[pid].valor or 0
    local resolve=(A.role(pid).resolve or 0)
    local msg=string.format("|cffffdb62ДОБЛЕСТЬ %d/100|r |cffbce8ffРЕШИМОСТЬ %d|r",valor,math.floor(resolve))
    if force or A.valorDisplay[pid]~=msg then
        A.valorDisplay[pid]=msg
        A.text(GetUnitX(u),GetUnitY(u),msg,.020,2.1)
        if force then A.playerText(pid,msg.." — Доблесть от Q и защиты союзников.") end
    end
end
local previousTick=A.tickCombat
function A.tickCombat()
    previousTick()
    if math.floor(A.clock*2)~=math.floor((A.clock-A.tickRate)*2) then
        for pid=0,3 do
            if A.heroKind[pid]==1 and A.alive(A.heroUnits[pid]) then
                A.showValor(pid,false)
                local h=A.heroUnits[pid]
                local st=A.role(pid)
                local b=st.bastion
                if b and b.expires>A.clock then
                    A.visualRing(RING,b.x,b.y,b.radius,12,1.4)
                    A.visual(WHITE,b.x,b.y,1.25,1.7)
                    A.forAllies(h,nil,function(u)
                        local dx,dy=GetUnitX(u)-b.x,GetUnitY(u)-b.y
                        if dx*dx+dy*dy<=b.radius*b.radius then
                            A.buff(u,"resist",.22,1.2)
                            if u~=h then A.protect(h,u,.22,1.2) end
                        end
                    end)
                end
            end
        end
    end
    for id,oath in pairs(A.lastOaths) do
        if oath.reviveUntil<=A.clock and not oath.reviving then
            A.lastOaths[id]=nil
        end
    end
end
