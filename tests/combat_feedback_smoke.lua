local timers, orders, resets, effects = {},0,{},{}
function CreateTimer() local t={};table.insert(timers,t);return t end
function TimerStart(t,delay,periodic,callback) t.delay=delay;t.callback=callback end
function OrderId(order) return order end
function IsUnitPaused(u) return u.paused==true end
function GetUnitCurrentOrder(u) return u.order or 0 end
function IssueTargetOrder(u,order,target) u.order=order;u.target=target;orders=orders+1 end
function BlzEndUnitAbilityCooldown(u,ability) table.insert(resets,ability) end
function IsUnitAlly(u,owner) return u.owner==owner end
InitGlobals()
local hero={owner=Player(0),x=100,y=100,life=1000,maxHp=1000,id=FourCC('H003'),abilities={},speed=300,intelligence=100}
Heroes[0]=hero
local creep={owner=Player(PLAYER_NEUTRAL_AGGRESSIVE),x=0,y=0,life=1000,id=FourCC('nban')}
Arena_PrepareEnemy(creep)
assert(creep.owner==Player(PLAYER_NEUTRAL_AGGRESSIVE) and creep.guardCleared and creep.guardRemoved)
creep.order='move'
Arena_UpdateEnemyOrders()
assert(orders==1 and creep.target==hero and creep.order=='attack')
Arena_UpdateEnemyOrders()
assert(orders==1, 'do not reset attack windups every second')
creep.order='channel'
Arena_UpdateEnemyOrders()
assert(orders==1, 'do not interrupt enemy spell casts')
creep.order='move';creep.paused=true
Arena_UpdateEnemyOrders()
assert(orders==1, 'do not overwrite crowd control')
creep.life=0
Arena_UpdateEnemyOrders()
assert(ArenaEnemies[creep]==nil)

Arena_ResetRoninDash(hero)
assert(#resets==0)
timers[#timers].callback()
assert(#resets==1 and resets[1]==FourCC('A115'), 'only the dash may reset')

function GetSpellTargetUnit() return hero end
Arena_Priestess_W(hero,1)
local state=PriestessCoronaShield[hero]
assert(hero.abilities[FourCC('AC01')] and hero.speed==405 and state.timer.delay==5)
Arena_Priestess_W(hero,1)
assert(state.timer.destroyed and hero.speed==405, 'refresh must not stack speed')
local current=PriestessCoronaShield[hero]
state.timer.callback()
assert(PriestessCoronaShield[hero]==current)
current.timer.callback()
assert(hero.speed==300 and not hero.abilities[FourCC('AC01')] and PriestessCoronaShield[hero]==nil)

function AddSpecialEffect(path,x,y)
    local effect={path=path,x=x,y=y};table.insert(effects,effect);return effect
end
function AddSpecialEffectTarget(path,unit)
    local effect={path=path,unit=unit};table.insert(effects,effect);return effect
end
function DestroyEffect(effect) effect.destroyed=true end
for _,class in ipairs(HeroClasses) do
    for _,spell in ipairs(class.spells) do
        local count=#effects
        Arena_PlayAbilityCue(hero,spell)
        assert(#effects==count+1 and not effects[#effects].destroyed)
        assert(timers[#timers].delay>0)
        timers[#timers].callback()
        assert(effects[#effects].destroyed, 'temporary effects must be cleaned up')
    end
end
assert(#effects==40)
