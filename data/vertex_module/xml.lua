local vter = mods.vertexutil.vter

local WeaponInfo = {}
local DroneInfo = {}


local blueprintFiles = {
    "data/blueprints.xml",
    "data/dlcBlueprints.xml",
}

--iterator
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

local function ParseBoolean(string) --same boolean parsing as used by hyperspace
    return string == "true" or string == "True" or string == "TRUE"
end

local function ParseAugEffect(node)
    local augEffect = {}
    if not node:first_attribute("effect") then error("augEffect tag requires an effect!", 2)
    elseif not node:first_attribute("amount") then error("augEffect tag requires an amount!", 2)
    elseif not tonumber(node:first_attribute("amount"):value()) then error("Invalid number for augEffect 'amount' tag!", 2)
    end

    augEffect.effect = node:first_attribute("effect"):value()
    augEffect.amount = node:first_attribute("amount"):value()
    if not node:first_attribute("needsPower") then 
        augEffect.needsPower = true  --augEffects need power by default, could change
    else 
        augEffect.needsPower = ParseBoolean(node:first_attribute("needsPower"):value())
    end
    

    return augEffect
end



for _,file in ipairs(blueprintFiles) do
    local doc = RapidXML.xml_document()
    local text = Hyperspace.Resources:LoadFile(file)
    doc:parse(text)
    local parent = doc:first_node("FTL")
    for node in Children(parent) do
        if node:name() == "weaponBlueprint" then
            local name = node:first_attribute("name"):value()
            WeaponInfo[name] = {}
            WeaponInfo[name].augEffects = {}
            for wepNode in Children(node) do
                if wepNode:name() == "augEffects" then
                    for augEffectNode in Children(wepNode) do
                        local augEffect = ParseAugEffect(augEffectNode)
                        table.insert(WeaponInfo[name].augEffects, augEffect)
                    end
                end
            end
        elseif node:name() == "droneBlueprint" then
            local name = node:first_attribute("name"):value()
            DroneInfo[name] = {}
            DroneInfo[name].augEffects = {}
            for droneNode in Children(node) do
                if droneNode:name() == "augEffects" then
                    for augEffectNode in Children(droneNode) do
                        local augEffect = ParseAugEffect(augEffectNode)
                        table.insert(DroneInfo[name].augEffects, augEffect)
                    end
                end
            end
        end
    end
end

script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE,
function(ShipManager, AugName, AugValue)
  local weapons, drones
  pcall(function() weapons = ShipManager.weaponSystem.weapons end)
  pcall(function() drones = ShipManager.droneSystem.drones end)
  if weapons then
    for weapon in vter(weapons) do
        for _,augEffect in ipairs(WeaponInfo[weapon.blueprint.name].augEffects) do
            if augEffect.effect == AugName then
                if not augEffect.needsPower or weapon.powered then
                    AugValue = AugValue + augEffect.amount
                end
            end
        end
    end
  end

  if drones then
    for drone in vter(drones) do
        for _,augEffect in ipairs(DroneInfo[drone.blueprint.name].augEffects) do
            if augEffect.effect == AugName then
                if not augEffect.needsPower or drone:GetPowered() then
                    AugValue = AugValue + augEffect.amount
                end
            end
        end
    end
  end
  return Defines.Chain.CONTINUE, AugValue
end)