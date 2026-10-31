local units,stocks,timers={},{},{}
function CreateUnit(owner,id,x,y)
    local unit={owner=owner,id=id,x=x,y=y,life=800,maxHp=1000,maxMana=500,mana=200,
        armor=4,str=20,agi=20,int=20,damage=30,speed=300,attackCooldown=2,inventory={}}
    units[#units+1]=unit;return unit
end
function GetUnitTypeId(u) return u.id end
function GetUnitX(u) return u.x end
function GetUnitY(u) return u.y end
function GetWidgetLife(u) return u.life end
function GetUnitState(u,key) return u[key] end
function SetUnitState(u,key,value) u[key]=value end
UNIT_STATE_LIFE,UNIT_STATE_MANA='life','mana'
function GetHeroStr(u) return u.str end
function GetHeroAgi(u) return u.agi end
function GetHeroInt(u) return u.int end
function SetHeroStr(u,v) u.str=v end
function SetHeroAgi(u,v) u.agi=v end
function SetHeroInt(u,v) u.int=v end
function BlzGetUnitArmor(u) return u.armor end
function BlzSetUnitArmor(u,v) u.armor=v end
function BlzGetUnitMaxHP(u) return u.maxHp end
function BlzSetUnitMaxHP(u,v) u.maxHp=v end
function BlzGetUnitMaxMana(u) return u.maxMana end
function BlzSetUnitMaxMana(u,v) u.maxMana=v end
function BlzGetUnitBaseDamage(u) return u.damage end
function BlzSetUnitBaseDamage(u,v) u.damage=v end
function GetUnitMoveSpeed(u) return u.speed end
function SetUnitMoveSpeed(u,v) u.speed=v end
function BlzGetUnitAttackCooldown(u) return u.attackCooldown end
function BlzSetUnitAttackCooldown(u,v) u.attackCooldown=v end
function UnitItemInSlot(u,slot) return u.inventory[slot] end
function UnitAddItemById(u,id)
    for slot=0,5 do
        if not u.inventory[slot] then
            local item={id=id,owner=u,slot=slot};u.inventory[slot]=item;return item
        end
    end
end
function RemoveItem(item) item.owner.inventory[item.slot]=nil end
function GetItemTypeId(item) return item.id end
function CreateTimer() local t={};timers[#timers+1]=t;return t end
function TimerStart(t,delay,periodic,callback) t.delay=delay;t.callback=callback end
function DestroyTimer(t) t.destroyed=true end
function AddItemToStock(shop,item,start,max)
    stocks[shop.id]=stocks[shop.id] or {};stocks[shop.id][item]={start,max}
end
InitGlobals()
Arena_InitEconomy()
assert(#units==2 and units[1].owner==Player(PLAYER_NEUTRAL_PASSIVE))
assert(stocks[FourCC('nS01')][FourCC('phea')][1]==3)
assert(stocks[FourCC('nS01')][FourCC('pman')][2]==3)
assert(stocks[FourCC('nS02')][FourCC('I0MA')])
assert(not stocks[FourCC('nS02')][FourCC('I005')], 'legendaries must be crafted, not bought')

-- Each of the nine documented recipes consumes exactly its components.
for _,recipe in ipairs(ItemCraftRecipes) do
    local hero=CreateUnit(Player(0),FourCC('H001'),0,0)
    for _,raw in ipairs(recipe.components) do UnitAddItemById(hero,raw) end
    local unrelated=UnitAddItemById(hero,FourCC('phea'))
    Arena_CheckItemCrafting(hero)
    local results,potions=0,0
    for _,item in pairs(hero.inventory) do
        if item.id==recipe.result then results=results+1 end
        if item==unrelated then potions=potions+1 end
    end
    assert(results==1 and potions==1 and not CraftingHeroes[hero])
end

local hero=CreateUnit(Player(0),FourCC('H001'),0,0)
UnitAddItemById(hero,FourCC('I001'))
UnitAddItemById(hero,FourCC('I002'))
UnitAddItemById(hero,FourCC('I004'))
Arena_UpdateGear(hero)
assert(hero.speed==370 and hero.str==25 and hero.agi==25 and hero.int==35)
assert(hero.armor==10 and hero.maxHp==1300 and hero.maxMana==750)
assert(math.abs(hero.attackCooldown-2/1.2)<0.0001)
assert(hero.life==800 and hero.mana==200, 'equipping cannot refill HP or mana')
Arena_UpdateGear(hero)
assert(hero.int==35 and hero.maxMana==750, 'bonuses must not accumulate on refresh')
hero.inventory={};Arena_UpdateGear(hero)
assert(hero.speed==300 and hero.str==20 and hero.int==20 and hero.maxHp==1000 and hero.maxMana==500)
assert(hero.armor==4 and math.abs(hero.attackCooldown-2)<0.0001)
local eventDamage
function BlzSetEventDamage(v) eventDamage=v end
EquippedItemStats[hero]={block=25}
Arena_ItemDamage(nil,hero,60,true)
assert(eventDamage==35)
EquippedItemStats[hero]={magic=.15}
Arena_ItemDamage(hero,units[1],100,false)
assert(math.abs(eventDamage-115)<0.0001)
