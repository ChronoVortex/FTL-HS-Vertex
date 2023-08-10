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
local userdata_table = mods.vertexutil.userdata_table

------------
-- PARSER --
------------
local function parser(node)
    local hack = {}
    
    if not node:first_attribute("duration") then error("hack tag requires a duration!") end
    hack.duration = tonumber(node:first_attribute("duration"):value())
    if not hack.duration then error("Invalid number for hack 'duration' attribute!") end
    
    if node:first_attribute("immuneAfterHack") then
        hack.immuneAfterHack = tonumber(node:first_attribute("immuneAfterHack"):value())
        if not hack.immuneAfterHack then
            error("Invalid number for hack 'immuneAfterHack' attribute!")
        end
    end
    
    if node:first_attribute("hitShieldDuration") then
        hack.hitShieldDuration = tonumber(node:first_attribute("hitShieldDuration"):value())
        if not hack.hitShieldDuration then
            error("Invalid number for hack 'hitShieldDuration' attribute!")
        end
    end
    
    hack.systemDurations = {}
    for systemDuration in Children(node) do
        local sysDurations = {}
        hack.systemDurations[systemDuration:name()] = sysDurations
        
        if not systemDuration:value() then error("hack nested system tag "..tostring(systemDuration:name()).." requires a duration!") end
        sysDurations.duration = tonumber(node:first_attribute("duration"):value())
        if not sysDurations.duration then error("Invalid number for hack nested system tag "..tostring(systemDuration:name()).."!") end
        
        if systemDuration:first_attribute("immuneAfterHack") then
            sysDurations.immuneAfterHack = tonumber(systemDuration:first_attribute("immuneAfterHack"):value())
            if not sysDurations.immuneAfterHack then
                error("Invalid number for hack nested system tag "..tostring(systemDuration:name()).." 'immuneAfterHack' attribute!")
            end
        end
    end
    
    return hack
end

-----------
-- LOGIC --
-----------
local function logic()
    -- Track hack time for systems hacked by a weapon
    script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
        for system in vter(ship.vSystemList) do
            local sysHackData = userdata_table(system, "mods.vertex.hack")
            if sysHackData.time and sysHackData.time > 0 then
                if ship.bDestroyed then
                    sysHackData.time = 0
                else
                    sysHackData.time = math.max(sysHackData.time - Hyperspace.FPS.SpeedFactor/16, 0)
                end
                if sysHackData.time == 0 then
                    system.iHackEffect = 0
                    system.bUnderAttack = false
                end
            elseif sysHackData.immuneTime and sysHackData.immuneTime > 0 then
                sysHackData.immuneTime = math.max(sysHackData.immuneTime - Hyperspace.FPS.SpeedFactor/16, 0)
            end
        end
    end)

    -- General function for applying hack to a system on hit
    local function apply_hack(hack, system)
        if system then
            local sysHackData = userdata_table(system, "mods.vertex.hack")
            if not sysHackData.immuneTime or sysHackData.immuneTime <= 0 then
                local sysDuration = hack.systemDurations[Hyperspace.ShipSystem.SystemIdToName(system:GetId())]
                
                -- Set hacking time for system
                if sysDuration then
                    sysHackData.time = math.max(sysDuration.duration, sysHackData.time or 0)
                    sysHackData.immuneTime = math.max(sysDuration.immuneAfterHack or hack.immuneAfterHack or 0, sysHackData.immuneTime or 0)
                else
                    sysHackData.time = math.max(hack.duration, sysHackData.time or 0)
                    sysHackData.immuneTime = math.max(hack.immuneAfterHack or 0, sysHackData.immuneTime or 0)
                end
                
                -- Apply the actual hack effect
                system.iHackEffect = 2
                system.bUnderAttack = true
            end
        end
    end

    -- Handle hacking beams
    script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
        hack = weaponInfo[projectile.extend.name]["hack"]
        if hack and hack.duration and hack.duration > 0 and beamHitType == Defines.BeamHit.NEW_ROOM then
            apply_hack(hack, shipManager:GetSystemInRoom(get_room_at_location(shipManager, location, true)))
        end
        return Defines.Chain.CONTINUE, beamHitType
    end)

    -- Handle other hacking weapons
    script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
        local hack = nil
        pcall(function() hack = weaponInfo[projectile.extend.name]["hack"] end)
        if hack and hack.duration and hack.duration > 0 then
            apply_hack(hack, shipManager:GetSystemInRoom(get_room_at_location(shipManager, location, true)))
        end
    end)

    -- Hack shields if shield bubble hit
    script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
        local hack = nil
        pcall(function() hack = weaponInfo[projectile.extend.name]["hack"] end)
        if hack and hack.hitShieldDuration and hack.hitShieldDuration > 0 then
            local shieldDuration = {}
            shieldDuration["shields"] = hack.hitShieldDuration
            apply_hack({systemDurations = shieldDuration}, shipManager:GetSystem(0))
        end
    end)
end

tag_add_weapons("hack", parser, logic)
