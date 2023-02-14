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
customTagsWeapons["hack"] = function(node)
    local hack = {}
    
    if not node:first_attribute("duration") then error("hack tag requires a duration!", 2) end
    hack.duration = tonumber(node:first_attribute("duration"):value())
    if not hack.duration then error("Invalid number for hack 'duration' attribute!", 2) end
    
    if node:first_attribute("hitShieldDuration") then
        hack.hitShieldDuration = tonumber(node:first_attribute("hitShieldDuration"):value())
        if not hack.hitShieldDuration then
            error("Invalid number for hack 'hitShieldDuration' attribute!", 2)
        end
    end
    
    hack.systemDurations = {}
    for systemDuration in Children(node) do
        hack.systemDurations[systemDuration:name()] = tonumber(systemDuration:value())
    end
    
    return hack
end

-----------
-- LOGIC --
-----------
local systemHackTimers = {}
systemHackTimers[0] = {}
systemHackTimers[1] = {}
local artilleryHackTimers = {}
artilleryHackTimers[0] = {}
artilleryHackTimers[1] = {}

-- Handle systems hacked by a weapon
local function handle_hack_for_ship(shipManager, clearShipId)
    local shipId = nil
    pcall(function() shipId = shipManager.iShipId end)
    if shipId then
        for systemId, hackTime in pairs(systemHackTimers[shipId]) do
            if hackTime and hackTime > 0 then
                systemHackTimers[shipId][systemId] = math.max(hackTime - Hyperspace.FPS.SpeedFactor/16, 0)
                if systemHackTimers[shipId][systemId] == 0 then
                    local system = shipManager:GetSystem(systemId)
                    system.iHackEffect = 0
                    system.bUnderAttack = false
                end
            end
        end
        for artyId, hackTime in pairs(artilleryHackTimers[shipId]) do
            if hackTime and hackTime > 0 then
                artilleryHackTimers[shipId][artyId] = math.max(hackTime - Hyperspace.FPS.SpeedFactor/16, 0)
                if artilleryHackTimers[shipId][artyId] == 0 then
                    local system = shipManager.artillerySystems[artyId]
                    system.iHackEffect = 0
                    system.bUnderAttack = false
                end
            end
        end
    else
        if #(systemHackTimers[clearShipId]) > 0 then
            for systemId in pairs(systemHackTimers[clearShipId]) do
                systemHackTimers[clearShipId][systemId] = 0
            end
        end
        if #(artilleryHackTimers[clearShipId]) > 0 then
            for systemId in pairs(artilleryHackTimers[clearShipId]) do
                artilleryHackTimers[clearShipId][systemId] = 0
            end
        end
    end
end
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    -- Make sure the game isn't paused
    if not Hyperspace.Global.GetInstance():GetCApp().world.space.gamePaused then
        handle_hack_for_ship(Hyperspace.ships.player, 0)
        handle_hack_for_ship(Hyperspace.ships.enemy, 1)
    end
end)

-- General function for applying hack to a system on hit
local function apply_hack(hack, shipManager, system)
    if system then
        local durationSystem = hack.systemDurations[Hyperspace.ShipSystem.SystemIdToName(system:GetId())]
        if system:GetId() == 11 then -- Special case for artillery
            -- Find the index of the artillery system on the ship
            artyIndex = 0
            for arillery in vter(shipManager.artillerySystems) do
                if system == arillery then break end
                artyIndex = artyIndex + 1
            end
            
            -- Set hacking time for artillery
            if durationSystem then
                artilleryHackTimers[shipManager.iShipId][artyIndex] = math.max(
                    durationSystem,
                    artilleryHackTimers[shipManager.iShipId][artyIndex] or 0)
            else
                artilleryHackTimers[shipManager.iShipId][artyIndex] = math.max(
                    hack.duration,
                    artilleryHackTimers[shipManager.iShipId][artyIndex] or 0)
            end
        else
            -- Set hacking time for non-artillery
            if durationSystem then
                systemHackTimers[shipManager.iShipId][system:GetId()] = math.max(
                    durationSystem,
                    systemHackTimers[shipManager.iShipId][system:GetId()] or 0)
            else
                systemHackTimers[shipManager.iShipId][system:GetId()] = math.max(
                    hack.duration,
                    systemHackTimers[shipManager.iShipId][system:GetId()] or 0)
            end
            
            -- Stop mind control
            if system:GetId() == 14 then
                if shipManager.mindSystem.controlTimer.first < shipManager.mindSystem.controlTimer.second then
                    shipManager.mindSystem.controlTimer.first = shipManager.mindSystem.controlTimer.second - Hyperspace.FPS.SpeedFactor/16
                end
            end
        end
        
        -- Apply the actual hack effect
        system.iHackEffect = 2
        system.bUnderAttack = true
    end
end

-- Handle hacking beams
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    hack = weaponInfo[Hyperspace.Get_Projectile_Extend(projectile).name]["hack"]
    if hack and hack.duration and hack.duration > 0 and beamHitType == Defines.BeamHit.NEW_ROOM then
        apply_hack(hack, shipManager, shipManager:GetSystemInRoom(get_room_at_location(shipManager, location, true)))
    end
    return Defines.Chain.CONTINUE, beamHitType
end)

-- Handle other hacking weapons
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local hack = nil
    pcall(function() hack = weaponInfo[Hyperspace.Get_Projectile_Extend(projectile).name]["hack"] end)
    if hack and hack.duration and hack.duration > 0 then
        apply_hack(hack, shipManager, shipManager:GetSystemInRoom(get_room_at_location(shipManager, location, true)))
    end
end)

-- Hack shields if shield bubble hit
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
    local hack = nil
    pcall(function() hack = weaponInfo[Hyperspace.Get_Projectile_Extend(projectile).name]["hack"] end)
    if hack and hack.hitShieldDuration and hack.hitShieldDuration > 0 then
        local shieldDuration = {}
        shieldDuration["shields"] = hack.hitShieldDuration
        apply_hack({systemDurations = shieldDuration}, shipManager, shipManager:GetSystem(0))
    end
end)
