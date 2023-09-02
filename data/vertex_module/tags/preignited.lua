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

------------
-- PARSER --
------------
local function parser(node)
    return {doPreignite = true}
end

-----------
-- LOGIC --
-----------
local function logic()
    script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(ship)
        local weapons = nil
        if pcall(function() weapons = ship.weaponSystem.weapons end) and weapons then
            for weapon in vter(weapons) do
                local preignited = weaponInfo[weapon.blueprint.name]["preignited"]
                if preignited and preignited.doPreignite and weapon.powered and weapon.cooldown.first < weapon.cooldown.second then
                    weapon:ForceCoolup()
                end
            end
        end
    end)
end

tag_add_weapons("preignited", parser, logic)
