-- Reforged Arena world design. Batches terrain changes to keep startup responsive.
local A=Arena
A.worldVisuals={}
A.terrainQueue={}
local floor=FourCC("Lrok")
local stone=FourCC("Ldrg")
local grove=FourCC("Lgrs")
local soil=FourCC("Ldrt")
local ash=FourCC("Ldro")
local dark=FourCC("Lgrd")

local function add(x,y,terrain,variation)
    A.terrainQueue[#A.terrainQueue+1]={x=x,y=y,type=terrain,var=variation or 0}
end
local function disk(cx,cy,radius,tex,inner)
    for x=-radius,radius do
        for y=-radius,radius do
            local dist=math.sqrt(x*x+y*y)
            if dist<=radius and (not inner or dist>=inner) then
                add(cx+x*128,cy+y*128,tex,((x+y+80)%4))
            end
        end
    end
end
local function beam(cx,cy,model,scale)
    local effect=AddSpecialEffect(model,cx,cy)
    if effect~=nil then
        if scale then BlzSetSpecialEffectScale(effect,scale) end
        A.worldVisuals[#A.worldVisuals+1]=effect
    end
end

function A.buildTerrainPlan()
    -- Main central citadel ring. Outer stone rim and a readable combat floor.
    disk(0,0,12,stone)
    disk(0,0,9,floor)
    disk(0,0,4,dark)
    disk(0,0,2,floor)
    -- Four distinct merchant courts.
    disk(-768,-384,3,soil)
    disk(768,-384,3,floor)
    disk(-768,384,3,grove)
    disk(768,384,3,ash)
    -- Northern hero gallery, two rows of alcoves plus a broad approach.
    disk(0,6800,16,stone)
    for kind=1,10 do
        local px,py=A.selectorPos(kind)
        disk(px,py,2,kind<=5 and grove or floor)
    end
    for cell=16,47 do
        add(0,cell*128,stone)
        add(-128,cell*128,stone)
        add(128,cell*128,stone)
    end
    -- Portal lanes. Terrain identity changes with cardinal orientation.
    for i=8,15 do
        for side=-2,2 do
            add(i*128,side*128,ash)
            add(-i*128,side*128,stone)
            add(side*128,i*128,grove)
            add(side*128,-i*128,dark)
        end
    end
end

function A.createWorld()
    A.buildTerrainPlan()
    local step=0
    local total=#A.terrainQueue
    A.every(.08,function()
        local limit=math.min(total,step+42)
        for n=step+1,limit do
            local p=A.terrainQueue[n]
            SetTerrainType(p.x,p.y,p.type,p.var,1,0)
        end
        step=limit
        if step>=total and not A.worldFinished then
            A.worldFinished=true
            A.terrainQueue={}
        end
    end)
    -- Decorative persistent particles, intentionally NOT hidden combat units.
    local arc=[[Abilities\Spells\Human\Brilliance\Brilliance.mdl]]
    local stoneArt=[[Abilities\Spells\Other\GeneralAuraTarget\GeneralAuraTarget.mdl]]
    local portals={
        {1520,0},{-1520,0},{0,1520},{0,-1520},
        {1120,1120},{-1120,1120},{1120,-1120},{-1120,-1120}
    }
    for _,p in ipairs(portals) do beam(p[1],p[2],stoneArt,1.6) end
    for a=0,11 do
        local angle=a*math.pi/6
        beam(math.cos(angle)*1050,math.sin(angle)*1050,arc,1.0)
    end
    for kind=1,10 do
        local x,y=A.selectorPos(kind)
        beam(x,y-175,stoneArt,.85)
    end
    -- Merchants get visual identities independent of their stock goblin models.
    local shopFX={
        [[Abilities\Spells\Human\ThunderClap\ThunderClapCaster.mdl]],
        [[Abilities\Spells\Human\HolyBolt\HolyBoltSpecialArt.mdl]],
        [[Abilities\Spells\NightElf\Tranquility\TranquilityTarget.mdl]],
        [[Abilities\Spells\Undead\FrostNova\FrostNovaTarget.mdl]]
    }
    local xy={{-760,-380},{760,-380},{-760,380},{760,380}}
    for i=1,4 do beam(xy[i][1],xy[i][2],shopFX[i],.8) end
end
