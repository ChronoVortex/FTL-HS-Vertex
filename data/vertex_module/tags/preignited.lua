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

local vter = mods.vertexutil.vter
local under_mind_system = mods.vertexutil.under_mind_system
local can_be_mind_controlled = mods.vertexutil.can_be_mind_controlled
local get_ship_crew_point = mods.vertexutil.get_ship_crew_point
local get_adjacent_rooms = mods.vertexutil.get_adjacent_rooms
local get_room_at_location = mods.vertexutil.get_room_at_location
local crew_data = mods.vertexutil.crew_data

------------
-- PARSER --
------------
customTagsWeapons["preignited"] = function(node)
    return {doPreignite = true}
end

-----------
-- LOGIC --
-----------
local wasJumping = false
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local isJumping = false
    if pcall(function() isJumping = Hyperspace.ships.player.bJumping end) then
        if not isJumping and wasJumping then
            local weapons = nil
            pcall(function() weapons = Hyperspace.ships.player.weaponSystem.weapons end)
            if weapons then
                for weapon in vter(weapons) do
                    local preignited = weaponInfo[weapon.blueprint.name]["preignited"]
                    if preignited and preignited.doPreignite and weapon.powered and weapon.cooldown.first < weapon.cooldown.second then
                        weapon.cooldown.first = weapon.cooldown.second - Hyperspace.FPS.SpeedFactor/16
                    end
                end
            end
        end
        wasJumping = isJumping
    end
end)
