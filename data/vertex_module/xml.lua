local vter = mods.vertexutil.vter
local crew_data = mods.vertexutil.crew_data
local get_ship_crew_point = mods.vertexutil.get_ship_crew_point
local can_be_mind_controlled = mods.vertexutil.can_be_mind_controlled

----------------
-- XML LOADER --
----------------
local weaponInfo = {}
local droneInfo = {}

local blueprintFiles = {
    "data/blueprints.xml",
    "data/dlcBlueprints.xml",
}

-- XML node iterator
local Children
do
    local function nodeIter(Parent, Child)
        if Child == "Start" then return Parent:first_node() end
        return Child:next_sibling()
    end

    Children = function(Parent)
        if not Parent then error("Invalid node to Children iterator!", 2) end
        return nodeIter, Parent, "Start"
    end
end

-- Same boolean parsing as used by hyperspace
local function parse_xml_bool(s)
    return s == "true" or s == "True" or s == "TRUE"
end

-- Define parsers for custom tags
local customTagsAll = {}
local customTagsWeapons = {}
local customTagsDrones = {}
customTagsAll["augEffects"] = function(node) -- Gives a weapon or drone the effect of an augment
    local augEffects = {}
    for augEffectNode in Children(node) do
        local augEffect = {}
        if not augEffectNode:first_attribute("effect") then error("augEffect tag requires an effect!", 2)
        elseif not augEffectNode:first_attribute("amount") then error("augEffect tag requires an amount!", 2)
        elseif not tonumber(augEffectNode:first_attribute("amount"):value()) then error("Invalid number for augEffect 'amount' attribute!", 2)
        end
        
        augEffect.effect = augEffectNode:first_attribute("effect"):value()
        augEffect.amount = tonumber(augEffectNode:first_attribute("amount"):value())
        if not augEffectNode:first_attribute("needsPower") then 
            augEffect.needsPower = true  -- augEffects need power by default, could change
        else 
            augEffect.needsPower = parse_xml_bool(augEffectNode:first_attribute("needsPower"):value())
        end
        
        table.insert(augEffects, augEffect)
    end
    return augEffects
end
customTagsWeapons["mindControl"] = function(node) -- Makes a weapon mind control crew
    local mindControl = {}
    
    mindControl.duration = node:value()
    if not mindControl.duration then
        error("mindControl tag requires a value for duration!", 2)
    elseif not tonumber(mindControl.duration) then
        error("Invalid number for mindControl tag!", 2)
    end
    mindControl.duration = tonumber(mindControl.duration)
    
    if node:first_attribute("limit") then
        mindControl.limit = tonumber(node:first_attribute("limit"):value())
        if not mindControl.limit then
            error("Invalid number for mindControl 'limit' attribute!", 2)
        end
    end
    
    if node:first_attribute("endSound") then
        mindControl.endSound = node:first_attribute("endSound"):value()
        if not mindControl.endSound then
            error("Invalid number for mindControl 'endSound' attribute!", 2)
        end
    end
    
    return mindControl
end

-- Parse custom tags in blueprints and save them to tables
for _, file in ipairs(blueprintFiles) do
    local doc = RapidXML.xml_document()
    local text = Hyperspace.Resources:LoadFile(file)
    doc:parse(text)
    local parent = doc:first_node("FTL")
    for node in Children(parent) do
        if node:name() == "weaponBlueprint" then
            local thisWeaponInfo = {}
            local thisWeaponName = node:first_attribute("name"):value()
            for wepNode in Children(node) do
                local tag = wepNode:name()
                if customTagsAll[tag] then
                    log("Found tag "..tag.." for weapon "..thisWeaponName)
                    thisWeaponInfo[tag] = customTagsAll[tag](wepNode)
                end
                if customTagsWeapons[tag] then
                    log("Found tag "..tag.." for weapon "..thisWeaponName)
                    thisWeaponInfo[tag] = customTagsWeapons[tag](wepNode)
                end
            end
            for tag in pairs(customTagsAll) do
                if not thisWeaponInfo[tag] then
                    thisWeaponInfo[tag] = {}
                end
            end
            for tag in pairs(customTagsWeapons) do
                if not thisWeaponInfo[tag] then
                    thisWeaponInfo[tag] = {}
                end
            end
            weaponInfo[thisWeaponName] = thisWeaponInfo
        elseif node:name() == "droneBlueprint" then
            local thisDroneInfo = {}
            local thisDroneName = node:first_attribute("name"):value()
            for droneNode in Children(node) do
                local tag = droneNode:name()
                if customTagsAll[tag] then
                    log("Found tag "..tag.." for drone "..thisDroneName)
                    thisDroneInfo[tag] = customTagsAll[tag](droneNode)
                end
                if customTagsDrones[tag] then
                    log("Found tag "..tag.." for drone "..thisDroneName)
                    thisDroneInfo[tag] = customTagsDrones[tag](droneNode)
                end
            end
            for tag in pairs(customTagsAll) do
                if not thisDroneInfo[tag] then
                    thisDroneInfo[tag] = {}
                end
            end
            for tag in pairs(customTagsDrones) do
                if not thisDroneInfo[tag] then
                    thisDroneInfo[tag] = {}
                end
            end
            droneInfo[thisDroneName] = thisDroneInfo
        end
    end
    doc:clear()
end

---------------------------
-- CUSTOM TAG MANAGEMENT --
---------------------------
-- Apply custom augment effects to weapons and drones
local function get_aug_bonus(system, equipmentInfo, augName)
    local augBonusValue = 0
    if system then
        for equipment in vter(system) do
            for _, augEffect in ipairs(equipmentInfo[equipment.blueprint.name]["augEffects"]) do
                if augEffect.effect == augName and (not augEffect.needsPower or equipment.powered) then
                    augBonusValue = augBonusValue + augEffect.amount
                end
            end
        end
    end
    return augBonusValue
end
script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, augName, augValue)
    local weapons, drones
    
    pcall(function() weapons = shipManager.weaponSystem.weapons end)
    pcall(function() drones = shipManager.droneSystem.drones end)
    
    augValue = augValue + get_aug_bonus(weapons, weaponInfo, augName) + get_aug_bonus(drones, droneInfo, augName)
    
    return Defines.Chain.CONTINUE, augValue
end)

-- Handle crew mind controlled by weapons
script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    local crewmemData = crew_data(crewmem)
    if crewmemData.mcTime then
        if crewmem.bDead then
            crewmemData.mcTime = nil
            crewmemData.mcEndSound = nil
        else
            crewmemData.mcTime = math.max(crewmemData.mcTime - Hyperspace.FPS.SpeedFactor/16, 0)
            if crewmemData.mcTime == 0 then
                crewmem:SetMindControl(false)
                if crewmemData.mcEndSound then
                    Hyperspace.Global.GetInstance():GetSoundControl():PlaySoundMix(crewmemData.mcEndSound, 1, false)
                end
                crewmemData.mcTime = nil
                crewmemData.mcEndSound = nil
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
                crew_data(crewmem).mcTime = math.max(mindControl.duration, crew_data(crewmem).mcTime or 0)
                crew_data(crewmem).mcEndSound = mindControl.endSound
            elseif crewmem:IsTelepathic() and realNewTile then
                crewmem.bResisted = true
            end
        end
    end
    return Defines.Chain.CONTINUE, beamHitType
end)

-- Handle other mind control weapons
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, forceHit, shipFriendlyFire)
    if weaponInfo[Hyperspace.Get_Projectile_Extend(projectile).name] then
        local mindControl = weaponInfo[Hyperspace.Get_Projectile_Extend(projectile).name]["mindControl"]
        if mindControl.duration then
            local roomId = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, false)
            local mindControlledCrew = 0
            for crewmem in vter(shipManager.vCrewList) do
                local doControl = (not mindControl.limit or mindControlledCrew < mindControl.limit) and
                                  crewmem.iShipId == shipManager.iShipId and
                                  crewmem.iRoomId == roomId
                if doControl then
                    if can_be_mind_controlled(crewmem) then
                        crewmem:SetMindControl(true)
                        crew_data(crewmem).mcTime = math.max(mindControl.duration, crew_data(crewmem).mcTime or 0)
                        crew_data(crewmem).mcEndSound = mindControl.endSound
                        mindControlledCrew = mindControlledCrew + 1
                    elseif crewmem:IsTelepathic() then
                        crewmem.bResisted = true
                    end
                end
            end
        end
    end
    return Defines.Chain.CONTINUE, forceHit, shipFriendlyFire
end)
