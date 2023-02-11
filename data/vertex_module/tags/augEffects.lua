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
local crew_data = mods.vertexutil.crew_data

------------
-- PARSER --
------------
customTagsAll["augEffects"] = function(node)
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

-----------
-- LOGIC --
-----------
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
