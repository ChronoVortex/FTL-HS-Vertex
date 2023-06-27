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
    local augEffects = {}
    for augEffectNode in Children(node) do
        local augEffect = {}
        if not augEffectNode:first_attribute("effect") then error("augEffect tag requires an effect!")
        elseif not augEffectNode:first_attribute("amount") then error("augEffect tag requires an amount!")
        elseif not tonumber(augEffectNode:first_attribute("amount"):value()) then error("Invalid number for augEffect 'amount' attribute!")
        end
        
        augEffect.effect = augEffectNode:first_attribute("effect"):value()
        augEffect.amount = tonumber(augEffectNode:first_attribute("amount"):value())
        if not augEffectNode:first_attribute("needsPower") then 
            augEffect.needsPower = true  -- augEffects need power by default, could change
        else 
            augEffect.needsPower = parse_xml_bool(augEffectNode:first_attribute("needsPower"):value())
        end
        if not augEffectNode:first_attribute("chargeScaling") then 
            augEffect.chargeScaling = false  -- augEffects do not scale by weapon charges by default
        else 
            augEffect.chargeScaling = parse_xml_bool(augEffectNode:first_attribute("chargeScaling"):value())
        end
        if not augEffectNode:first_attribute("nostack") then 
            augEffect.nostack = false  -- augEffects stack by default
        else 
            augEffect.nostack = parse_xml_bool(augEffectNode:first_attribute("nostack"):value())
        end
        
        table.insert(augEffects, augEffect)
    end
    return augEffects
end

-----------
-- LOGIC --
-----------
local function logic()
    local possibleValues = {}
    
    local function get_aug_bonus(system, equipmentInfo, augName)
        local augBonusValue = 0
        if system then
            for equipment in vter(system) do
                for _, augEffect in ipairs(equipmentInfo[equipment.blueprint.name]["augEffects"]) do
                    if augEffect.effect == augName and (not augEffect.needsPower or equipment.powered) then
                        local effectAmount = augEffect.amount
                        if augEffect.chargeScaling and equipment.blueprint:GetType() == 0 then
                            effectAmount = effectAmount*(equipment.chargeLevel/math.max(equipment.weaponVisual.iChargeLevels, 1))
                        end
                        if augEffect.nostack then
                            table.insert(possibleValues, effectAmount)
                        else
                            augBonusValue = augBonusValue + effectAmount
                        end
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
        
        local total = augValue + get_aug_bonus(weapons, weaponInfo, augName) + get_aug_bonus(drones, droneInfo, augName)
        augValue = math.max(total, table.unpack(possibleValues))
        for i in ipairs(possibleValues) do possibleValues[i] = nil end
        
        return Defines.Chain.CONTINUE, augValue
    end)
end

tag_add_all("augEffects", parser, logic)
