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
customTagsAll["noPowerFix"] = function(node)
    return {doFix = true}
end

-----------
-- LOGIC --
-----------
local function fix_no_power_projectiles(weapons)
    for weapon in vter(weapons) do
        local noPowerFix = weaponInfo[weapon.blueprint.name]["noPowerFix"]
        if noPowerFix and noPowerFix.doFix then
            local projectile = weapon:GetProjectile()
            while projectile do
                Hyperspace.Global.GetInstance():GetCApp().world.space.projectiles:push_back(projectile)
                projectile = weapon:GetProjectile()
            end
        end
    end
end
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local weaponsPlayer = nil
    pcall(function() weaponsPlayer = Hyperspace.ships.player.weaponSystem.weapons end)
    if weaponsPlayer then fix_no_power_projectiles(weaponsPlayer) end
    
    local weaponsEnemy = nil
    pcall(function() weaponsEnemy = Hyperspace.ships.enemy.weaponSystem.weapons end)
    if weaponsEnemy then fix_no_power_projectiles(weaponsEnemy) end
end)
