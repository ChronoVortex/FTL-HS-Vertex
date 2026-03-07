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
    local lockdown = {}
    lockdown.doLockdown = true
    
    if node:first_attribute("chance") then
        lockdown.chance = tonumber(node:first_attribute("chance"):value())
        if not lockdown.chance then
            error("Invalid number for lockdown 'chance' attribute!")
        end
    end
    
    lockdown.sounds = {}
    for sound in Children(node) do
        if sound:name() ~= "sound" then
            error("Invalid child tag '"..sound:name().."' for 'lockdownBeam'!")
        end
        if not sound:value() then
            error("Invalid value for 'sound' child of 'lockdownBeam' tag!")
        end
        table.insert(lockdown.sounds, sound:value())
    end
    
    return lockdown
end

-----------
-- LOGIC --
-----------
local function logic()
    script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
        local lockdown = weaponInfo[projectile.extend.name]["lockdownBeam"]
        if lockdown.doLockdown then
            local doLockdown = 
                not lockdown.chance or
                lockdown.chance >= 10 or
                (lockdown.chance > 0 and lockdown.chance > math.random(10) - 1)
            if doLockdown and beamHitType == Defines.BeamHit.NEW_ROOM then
                shipManager.ship:LockdownRoom(get_room_at_location(shipManager, location, true), location)
                if #(lockdown.sounds) > 0 then
                    Hyperspace.Sounds:PlaySoundMix(lockdown.sounds[math.random(#(lockdown.sounds))], -1, false)
                end
            end
        end
        return Defines.Chain.CONTINUE, beamHitType
    end)
end

tag_add_weapons("lockdownBeam", parser, logic)
