local vter = mods.vertexutil.vter

-- Make sure that inferno core was patched before this mod if it was patched
local infernoInstalled = false
if mods.inferno then infernoInstalled = true end
script.on_load(function()
    if not infernoInstalled and mods.inferno then
        Hyperspace.ErrorMessage("Vertex Tags and Utility Functions was patched before Inferno-Core! Please re-patch your mods, and make sure to put Inferno-Core first!")
    end
end)

-- Implement the inferno weapon fire callbacks ourselves if inferno isn't patched
if not infernoInstalled then

local callback_runner = {
    identifier = "",

    __call = function(self, ...)
        for key, functable in ipairs(self) do
            for _, func in ipairs(functable) do
                local success, res = pcall(func, ...)
                if not success then
                    log(string.format("Failed to call function in callback '%s' due to error:\n %s", self.identifier, res))
                elseif res then
                    return
                end
            end
        end
    end,

    add = function(self, func, priority)
        local priority = priority or 0
        if type(priority) ~= 'number' or math.floor(priority) ~= priority then
            error("Priority argument must be an integer!", 3)
        end
        local priority = priority or 0
        local ptab = nil
        for _,v in ipairs(self) do
            if getmetatable(v).priority == priority then
                ptab = v break
            end
        end
        if not ptab then 
            ptab = setmetatable({}, {priority = priority}) 
            table.insert(self, ptab) 
        end
        if type(func) ~= 'function' then
            error("Second argument must be a function!", 3)
        end
        table.insert(ptab, func)
        table.sort(self, function(lesser,greater) 
            return getmetatable(lesser).priority > getmetatable(greater).priority -- larger numbers come first
        end)
    end,

    new = function(self, o)
        o = o or {}
        self.__index = self
        setmetatable(o, self)
        return o
    end,
}

Defines.FireEvents = {
    WEAPON_FIRE = callback_runner:new({identifier = "Defines.FireEvents.WEAPON_FIRE"}),
    ARTILLERY_FIRE = callback_runner:new({identifier = "Defines.FireEvents.ARTILLERY_FIRE"}),
}

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    for i = 0, 1 do
        local weapons = nil
        local ship = Hyperspace.Global.GetInstance():GetShipManager(i)
        pcall(function() weapons = ship.weaponSystem.weapons end)
        if weapons and ship.weaponSystem:Powered() then 
            for weapon in vter(weapons) do
                while true do
                    local projectile = weapon:GetProjectile()
                    if projectile then
                        Hyperspace.Global.GetInstance():GetCApp().world.space.projectiles:push_back(projectile)
                        Defines.FireEvents.WEAPON_FIRE(ship, weapon, projectile)
                    else
                        break
                    end
                end
            end
        end
    end
end, 1000)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    for i = 0, 1 do
        local artilleries = nil
        local ship = Hyperspace.Global.GetInstance():GetShipManager(i)
        pcall(function() artilleries = ship.artillerySystems end)
        if artilleries then 
            for artillery in vter(artilleries) do
                while true do
                    local weapon = artillery.projectileFactory
                    local projectile = weapon:GetProjectile()
                    if projectile then
                        Hyperspace.Global.GetInstance():GetCApp().world.space.projectiles:push_back(projectile)
                        Defines.FireEvents.ARTILLERY_FIRE(ship, artillery, projectile)
                    else
                        break
                    end
                end
            end
        end
    end
end, 1000)

function script.on_fire_event(FireEvent, func, priority)
    local validEvent = false
    for _, v in pairs(Defines.FireEvents) do
        if v == FireEvent then validEvent = true break end
    end
    if not validEvent then
        log("\n\nValid FireEvents:\nWEAPON_FIRE\nARTILLERY_FIRE")
        error("First argument of function 'script.on_fire_event' must be a valid FireEvent! Check the FTL_HS.log file for more information.", 2)
    end
    FireEvent:add(func, priority)
end

end
