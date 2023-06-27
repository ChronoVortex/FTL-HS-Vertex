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
    local mindControl = {}
    
    mindControl.duration = node:value()
    if not mindControl.duration then
        error("mindControl tag requires a value for duration!")
    elseif not tonumber(mindControl.duration) then
        error("Invalid number for mindControl tag!")
    end
    mindControl.duration = tonumber(mindControl.duration)
    
    if node:first_attribute("limit") then
        mindControl.limit = tonumber(node:first_attribute("limit"):value())
        if not mindControl.limit then
            error("Invalid number for mindControl 'limit' attribute!")
        end
    end
    
    if node:first_attribute("endSound") then
        mindControl.endSound = node:first_attribute("endSound"):value()
        if not mindControl.endSound then
            error("Invalid mindControl 'endSound' attribute!")
        end
    end
    
    return mindControl
end

-----------
-- LOGIC --
-----------
local function logic()
    -- Handle crew mind controlled by weapons
    script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
        local mcTable = userdata_table(crewmem, "mods.vertex.mc")
        if mcTable.mcTime then
            if crewmem.bDead then
                mcTable.mcTime = nil
                mcTable.mcEndSound = nil
            else
                mcTable.mcTime = math.max(mcTable.mcTime - Hyperspace.FPS.SpeedFactor/16, 0)
                if mcTable.mcTime == 0 then
                    crewmem:SetMindControl(false)
                    if mcTable.mcEndSound then
                        Hyperspace.Global.GetInstance():GetSoundControl():PlaySoundMix(mcTable.mcEndSound, 1, false)
                    end
                    mcTable.mcTime = nil
                    mcTable.mcEndSound = nil
                end
            end
        end
    end)

    -- Handle mind control beams
    script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
        local mindControl = weaponInfo[Hyperspace.Get_Projectile_Extend(projectile).name]["mindControl"]
        if mindControl.duration then -- Doesn't check realNewTile anymore 'cause the beam kept missing crew that were on the move
            for i, crewmem in ipairs(get_ship_crew_point(shipManager, location.x, location.y)) do
                if can_be_mind_controlled(crewmem) then
                    crewmem:SetMindControl(true)
                    local mcTable = userdata_table(crewmem, "mods.vertex.mc")
                    mcTable.mcTime = math.max(mindControl.duration, mcTable.mcTime or 0)
                    mcTable.mcEndSound = mindControl.endSound
                elseif crewmem:IsTelepathic() and realNewTile then
                    crewmem.bResisted = true
                end
            end
        end
        return Defines.Chain.CONTINUE, beamHitType
    end)

    -- Handle other mind control weapons
    script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
        local mindControl = nil
        pcall(function() mindControl = weaponInfo[Hyperspace.Get_Projectile_Extend(projectile).name]["mindControl"] end)
        if mindControl and mindControl.duration then
            local roomId = get_room_at_location(shipManager, location, true)
            local mindControlledCrew = 0
            for crewmem in vter(shipManager.vCrewList) do
                local doControl = (not mindControl.limit or mindControlledCrew < mindControl.limit) and
                                  crewmem.iShipId == shipManager.iShipId and
                                  crewmem.iRoomId == roomId
                if doControl then
                    if can_be_mind_controlled(crewmem) then
                        crewmem:SetMindControl(true)
                        local mcTable = userdata_table(crewmem, "mods.vertex.mc")
                        mcTable.mcTime = math.max(mindControl.duration, mcTable.mcTime or 0)
                        mcTable.mcEndSound = mindControl.endSound
                        mindControlledCrew = mindControlledCrew + 1
                    elseif crewmem:IsTelepathic() then
                        crewmem.bResisted = true
                    end
                end
            end
        end
    end)
end

tag_add_weapons("mindControl", parser, logic)
