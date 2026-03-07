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
local is_first_shot = mods.vertexutil.is_first_shot

------------
-- PARSER --
------------
local function parser(node)
    return {doStealth = true}
end

-----------
-- LOGIC --
-----------
local function logic()
    script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
        local stealth = weaponInfo[weapon.blueprint.name]["stealth"]
        if stealth and stealth.doStealth then
            local ship = Hyperspace.ships(weapon.iShipId)
            if ship.cloakSystem and ship.cloakSystem.bTurnedOn and ship:HasAugmentation("CLOAK_FIRE") == 0 and is_first_shot(weapon, true) then
                local timer = ship.cloakSystem.timer
                timer.currTime = timer.currTime - timer.currGoal/5
            end
        end
    end)
end

tag_add_weapons("stealth", parser, logic)
