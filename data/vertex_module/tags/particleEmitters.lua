-------------
-- IMPORTS --
-------------
local weaponInfo = mods.vertexdata.weaponInfo
local droneInfo = mods.vertexdata.droneInfo
local customTagsAll = mods.vertexdata.customTagsAll
local customTagsWeapons = mods.vertexdata.customTagsWeapons
local customTagsDrones = mods.vertexdata.customTagsDrones
local Children = mods.vertexdata.Children
local parse_xml_bool = mods.vertexdata.parse_xml_bool
local tag_add_all = mods.vertexdata.tag_add_all
local tag_add_weapons = mods.vertexdata.tag_add_weapons
local tag_add_drones = mods.vertexdata.tag_add_drones

local vter = mods.vertexutil.vter
local under_mind_system = mods.vertexutil.under_mind_system
local can_be_mind_controlled = mods.vertexutil.can_be_mind_controlled
local get_ship_crew_point = mods.vertexutil.get_ship_crew_point
local get_adjacent_rooms = mods.vertexutil.get_adjacent_rooms
local get_room_at_location = mods.vertexutil.get_room_at_location
local crew_data = mods.vertexutil.crew_data

local particleLayers = mods.vertexparts.particleLayers
local particles = mods.vertexparts.particles
local particleTypes = mods.vertexparts.particleTypes
local emitterEvents = mods.vertexparts.emitterEvents
local particleEmitters = mods.vertexparts.particleEmitters

------------
-- PARSER --
------------
local function parser(node, weaponName)
    for particleEmitterNode in Children(node) do
        particleEmitters:ParseNew(particleEmitterNode, weaponName)
    end
end

-----------
-- LOGIC --
-----------
local function logic()
    -- Render and update particles
    script.on_render_event(Defines.RenderEvents.SHIP, function(ship)
        particles:Render(ship.iShipId, particleLayers.BOTTOM)
    end, function(ship)
        particles:Render(ship.iShipId, particleLayers.TOP)
    end)
    script.on_internal_event(Defines.InternalEvents.ON_TICK, function(ship)
        if not Hyperspace.Global.GetInstance():GetCApp().world.space.gamePaused then
            particles:Update()
        end
    end)
    
    -- Emitter fire event
    local function emitter_fire(ship, weapon, projectile)
        local weaponEmitters = particleEmitters.activeEmitters[weapon.blueprint.name]
        if weaponEmitters then
            for i, emitter in ipairs(weaponEmitters) do
                particleEmitters:Emit(emitter, emitterEvents.FIRE, weapon)
            end
        end
    end
    script.on_fire_event(Defines.FireEvents.WEAPON_FIRE, emitter_fire)
    script.on_fire_event(Defines.FireEvents.ARTILLERY_FIRE, function(ship, artillery, projectile)
        emitter_fire(ship, artillery.projectileFactory, projectile)
    end)
end

tag_add_weapons("particleEmitters", parser, logic)