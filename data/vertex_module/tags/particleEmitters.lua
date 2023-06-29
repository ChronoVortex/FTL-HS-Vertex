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
    script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
        if not Hyperspace.Global.GetInstance():GetCApp().world.space.gamePaused then
            particles:Update()
        end
    end)
    
    -- Emitter fire event
    script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
        if weapon then
            local weaponEmitters = particleEmitters.activeEmitters[weapon.blueprint.name]
            if weaponEmitters then
                for i, emitter in ipairs(weaponEmitters) do
                    particleEmitters:Emit(emitter, emitterEvents.FIRE, weapon)
                end
            end
        end
    end)

    -- Emitter explosion event
    local function emitter_explosion(projectile)
        if projectile then
            local weaponEmitters = particleEmitters.activeEmitters[projectile.extend.name]
            if weaponEmitters then
                for i, emitter in ipairs(weaponEmitters) do
                    particleEmitters:Emit(emitter, emitterEvents.EXPLOSION, nil, projectile.position.x, projectile.position.y, projectile.currentSpace)
                end
            end
        end
    end
    script.on_internal_event(Defines.InternalEvents.DRONE_COLLISION, function(drone, projectile, damage, response)
        emitter_explosion(projectile)
    end)
    script.on_internal_event(Defines.InternalEvents.PROJECTILE_COLLISION, function(thisProjectile, otherProjectile, damage, response)
        emitter_explosion(thisProjectile)
    end)
    script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION_PRE, function(ship, projectile, damage, response)
        local shieldPower = nil
        pcall(function() shieldPower = ship.shieldSystem.shields.power end)
        if not shieldPower or shieldPower.super.first > 0 or shieldPower.first > damage.iShieldPiercing then
            emitter_explosion(projectile)
        end
    end)
    script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(ship, projectile, damage, response)
        emitter_explosion(projectile)
    end)
end

tag_add_weapons("particleEmitters", parser, logic)
