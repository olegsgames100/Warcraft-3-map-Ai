-- Exactly one event dispatcher. Defensive diagnostic output for actual Reforged runtime.
local A=Arena
function A.initAbilities()
    A.spellEvents={}
    A.spellDebug=false
    local trigger=CreateTrigger()
    for pid=0,3 do
        TriggerRegisterPlayerUnitEvent(trigger,Player(pid),EVENT_PLAYER_UNIT_SPELL_CAST,nil)
        TriggerRegisterPlayerUnitEvent(trigger,Player(pid),EVENT_PLAYER_UNIT_SPELL_EFFECT,nil)
    end
    TriggerAddAction(trigger,function()
        local hero,ability=GetTriggerUnit(),GetSpellAbilityId()
        local pid=GetPlayerId(GetOwningPlayer(hero))
        if pid<0 or pid>3 or A.heroUnits[pid]~=hero then return end
        local kind=A.heroKind[pid]
        local known=false
        for _,id in ipairs(A.spells[kind]) do
            if FourCC(id)==ability then known=true;break end
        end
        if not known then return end
        local k=tostring(GetHandleId(hero))..":"..tostring(ability)
        local event=GetTriggerEventId()
        local function execute(snapshot,label)
            local ok,message=xpcall(function()
                return A.castHero(hero,ability,snapshot)
            end,function(err) return tostring(err)..(debug and debug.traceback and debug.traceback("",2) or "") end)
            if not ok then A.playerText(pid,"|cffff3333[LUA ERROR] "..tostring(message):sub(1,400).."|r")
            elseif A.spellDebug then A.playerText(pid,label.." "..(message and "OK" or "NO HANDLER")) end
        end
        if event==EVENT_PLAYER_UNIT_SPELL_CAST then
            local marker={target=GetSpellTargetUnit(),x=GetSpellTargetX(),y=GetSpellTargetY(),used=false}
            A.spellEvents[k]=marker
            if A.spellDebug then A.playerText(pid,"CAST "..tostring(ability)) end
            A.after(.32,function()
                if A.spellEvents[k]==marker and not marker.used and A.alive(hero) then
                    marker.used=true
                    execute(marker,"FALLBACK")
                end
                if A.spellEvents[k]==marker then A.spellEvents[k]=nil end
            end)
        else
            local marker=A.spellEvents[k]
            if marker and marker.used then return end
            if marker then marker.used=true end
            execute(marker,"EFFECT")
        end
    end)
end
