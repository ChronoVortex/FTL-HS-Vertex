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
local is_first_shot = mods.vertexutil.is_first_shot

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

    -- Used for dictating how much the hacking time is boosted by stack of boost
    hack.boostHackingTimeAddition = 0
    if node:first_attribute("boostHackingTimeAddition") then
        hack.boostHackingTimeAddition = tonumber(node:first_attribute("boostHackingTimeAddition"):value())
        if not hack.boostHackingTimeAddition then
            error("Invalid number for hack 'boostHackingTimeAddition' attribute!")
        end
    end
    
    hack.systemDurations = {}
    for systemDuration in Children(node) do
        local sysDurations = {}
        hack.systemDurations[systemDuration:name()] = sysDurations
        
        if not systemDuration:value() then error("hack nested system tag "..tostring(systemDuration:name()).." requires a duration!") end
        sysDurations.duration = tonumber(systemDuration:value() or node:first_attribute("duration"):value())
        if not sysDurations.duration then error("Invalid number for hack nested system tag "..tostring(systemDuration:name()).."!") end
        
        if systemDuration:first_attribute("immuneAfterHack") then
            sysDurations.immuneAfterHack = tonumber(systemDuration:first_attribute("immuneAfterHack"):value())
            if not sysDurations.immuneAfterHack then
                error("Invalid number for hack nested system tag "..tostring(systemDuration:name()).." 'immuneAfterHack' attribute!")
            end
        end

        if systemDuration:first_attribute("boostHackingTimeAddition") then
            sysDurations.boostHackingTimeAddition = tonumber(systemDuration:first_attribute("boostHackingTimeAddition"):value())
            if not sysDurations.boostHackingTimeAddition then
                error("Invalid number for hack nested system tag "..tostring(systemDuration:name()).." 'boostHackingTimeAddition' attribute!")
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
    local function apply_hack(hack, system, boost)
        print(boost)
        if system then
            local sysHackData = userdata_table(system, "mods.vertex.hack")
            if not sysHackData.immuneTime or sysHackData.immuneTime <= 0 then
                local sysDuration = hack.systemDurations[Hyperspace.ShipSystem.SystemIdToName(system:GetId())]

                -- Aquire the adaptive time for the system
                local adaptiveTime = boost and boost*(sysDuration and sysDuration.boostHackingTimeAddition or hack.boostHackingTimeAddition) or 0
                
                -- Set hacking time for system
                if sysDuration then
                    sysHackData.time = math.max(sysDuration.duration + adaptiveTime, sysHackData.time and (sysHackData.time + adaptiveTime) or 0)
                    sysHackData.immuneTime = math.max(sysDuration.immuneAfterHack or hack.immuneAfterHack or 0, sysHackData.immuneTime or 0)
                else
                    sysHackData.time = math.max(hack.duration + adaptiveTime, sysHackData.time and (sysHackData.time + adaptiveTime) or 0)
                    sysHackData.immuneTime = math.max(hack.immuneAfterHack or 0, sysHackData.immuneTime or 0)
                end
                
                -- Apply the actual hack effect
                system.iHackEffect = 2
                system.bUnderAttack = true
            end
        end
    end

    -- Track boost of weapons that fire hacking projectiles
    script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
        if weaponInfo[weapon.blueprint.name]["hack"] and weapon.blueprint.boostPower then
            local weapHackData = userdata_table(weapon, "mods.vertex.hack")
            if is_first_shot(weapon, true) then
                if (weapHackData.lastBoost and weapHackData.lastBoost == weapon.boostLevel and weapon.blueprint.boostPower.count == weapon.boostLevel) then
                    weapHackData.boost = weapon.boostLevel
                else
                    weapHackData.boost = weapon.boostLevel - 1
                end
                weapHackData.lastBoost = weapon.boostLevel
            end
            userdata_table(projectile, "mods.vertex.hack").boost = weapHackData.boost
        end
    end)

    -- Handle hacking beams
    script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
        hack = weaponInfo[projectile.extend.name]["hack"]
        if hack and hack.duration and hack.duration > 0 and beamHitType == Defines.BeamHit.NEW_ROOM then
            apply_hack(hack, shipManager:GetSystemInRoom(get_room_at_location(shipManager, location, true)), userdata_table(projectile, "mods.vertex.hack").boost)
        end
        return Defines.Chain.CONTINUE, beamHitType
    end)

    -- Handle other hacking weapons
    script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
        local hack = nil
        pcall(function() hack = weaponInfo[projectile.extend.name]["hack"] end)
        if hack and hack.duration and hack.duration > 0 then
            apply_hack(hack, shipManager:GetSystemInRoom(get_room_at_location(shipManager, location, true)), userdata_table(projectile, "mods.vertex.hack").boost)
        end
    end)

    -- Hack shields if shield bubble hit
    script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
        local hack = nil
        pcall(function() hack = weaponInfo[projectile.extend.name]["hack"] end)
        if hack and hack.hitShieldDuration and hack.hitShieldDuration > 0 then
            apply_hack({
                duration = hack.hitShieldDuration,
                immuneAfterHack = hack.systemDurations.shields and hack.systemDurations.shields.immuneAfterHack or hack.immuneAfterHack
            }, shipManager:GetSystem(0), userdata_table(projectile, "mods.vertex.hack").boost)
        end
    end)
end

tag_add_weapons("hack", parser, logic)
