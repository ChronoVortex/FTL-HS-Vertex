local weaponInfo = mods.vertexdata.weaponInfo
local droneInfo = mods.vertexdata.droneInfo
local customTagsAll = mods.vertexdata.customTagsAll
local customTagsWeapons = mods.vertexdata.customTagsWeapons
local customTagsDrones = mods.vertexdata.customTagsDrones
local Children = mods.vertexdata.Children
local parse_xml_bool = mods.vertexdata.parse_xml_bool

local blueprintFiles = {
    "data/blueprints.xml",
    "data/dlcBlueprints.xml",
}

-- Parse custom tags in blueprints and save them to tables
for _, file in ipairs(blueprintFiles) do
    local doc = RapidXML.xml_document(file)
    local parent = doc:first_node("FTL")
    for node in Children(parent) do
        if node:name() == "weaponBlueprint" then
            local thisWeaponInfo = {}
            local thisWeaponName = node:first_attribute("name"):value()
            for wepNode in Children(node) do
                local tag = wepNode:name()
                if customTagsAll[tag] then
                    if not customTagsAll[tag].hooked then
                        log("Hooking logic for "..tag.." tag")
                        customTagsAll[tag].logic()
                        customTagsAll[tag].hooked = true
                    end
                    log("Found "..tag.." tag for weapon "..thisWeaponName)
                    thisWeaponInfo[tag] = customTagsAll[tag].parser(wepNode, thisWeaponName)
                end
                if customTagsWeapons[tag] then
                    if not customTagsWeapons[tag].hooked then
                        log("Hooking logic for "..tag.." tag")
                        customTagsWeapons[tag].logic()
                        customTagsWeapons[tag].hooked = true
                    end
                    log("Found "..tag.." tag for weapon "..thisWeaponName)
                    thisWeaponInfo[tag] = customTagsWeapons[tag].parser(wepNode, thisWeaponName)
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
                    if not customTagsAll[tag].hooked then
                        log("Hooking logic for "..tag.." tag")
                        customTagsAll[tag].logic()
                        customTagsAll[tag].hooked = true
                    end
                    log("Found "..tag.." tag for drone "..thisDroneName)
                    thisDroneInfo[tag] = customTagsAll[tag].parser(droneNode, thisDroneName)
                end
                if customTagsDrones[tag] then
                    if not customTagsDrones[tag].hooked then
                        log("Hooking logic for "..tag.." tag")
                        customTagsDrones[tag].logic()
                        customTagsDrones[tag].hooked = true
                    end
                    log("Found "..tag.." tag for drone "..thisDroneName)
                    thisDroneInfo[tag] = customTagsDrones[tag].parser(droneNode, thisDroneName)
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
