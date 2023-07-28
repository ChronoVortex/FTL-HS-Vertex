if not (Hyperspace.version and Hyperspace.version.major == 1 and Hyperspace.version.minor >= 6) then
    error("Incorrect Hyperspace version detected! Vertex Tags and Utility Functions requires Hyperspace 1.6+")
end

mods.vertexutil = {}
local INT_MAX = 2147483647

----------------------------
-- MISC UTILITY FUNCTIONS --
----------------------------
-- Generic iterator for C vectors
function mods.vertexutil.vter(cvec)
    local i = -1 -- so the first returned value is indexed at zero
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end
local vter = mods.vertexutil.vter

-- Copy a table recursively
--[[ taken from
https://stackoverflow.com/questions/42178768/lua-copying-a-table-efficiently-deep-copy#answer-45867020
https://gist.github.com/cpeosphoros/0aa286c6b39c1e452d9aa15d7537ac95
--]]
function mods.vertexutil.table_copy_deep(value, cache, promises, copies)
    cache    = cache    or {}
    promises = promises or {}
    copies   = copies   or {}
    local copy
    if type(value) == 'table' then
        if (cache[value]) then
            copy = cache[value]
        else
            promises[value] = promises[value] or {}
            copy = {}
            for k, v in next, value, nil do
                local nKey   = promises[k] or mods.vertexutil.table_copy_deep(k, cache, promises, copies)
                local nValue = promises[v] or mods.vertexutil.table_copy_deep(v, cache, promises, copies)
                copies[nKey]   = type(k) == "table" and k or nil
                copies[nValue] = type(v) == "table" and v or nil
                copy[nKey] = nValue
            end
            local mt = getmetatable(value)
            if mt then
                setmetatable(copy, mt.__immutable and mt or mods.vertexutil.table_copy_deep(mt, cache, promises, copies))
            end
            cache[value]    = copy
        end
    else -- number, string, boolean, etc
        copy = value
    end
    for k, v in pairs(copies) do
        if k == cache[v] then
            copies[k] = nil
        end
    end
    local function correctRec(tbl)
        if type(tbl) ~= "table" then return tbl end
        if copies[tbl] and cache[copies[tbl]] then
            return cache[copies[tbl]]
        end
        local new = {}
        for k, v in pairs(tbl) do
            local oldK = k
            k, v = correctRec(k), correctRec(v)
            if k ~= oldK then
                tbl[oldK] = nil
                new[k] = v
            else
                tbl[k] = v
            end
        end
        for k, v in pairs(new) do
            tbl[k] = v
        end
        return tbl
    end
    correctRec(copy)
    return copy
end

-- Check if a given crew member is being mind controlled by a ship system
function mods.vertexutil.under_mind_system(crewmem)
    local controlledCrew = nil
    local otherShipId = (crewmem.iShipId + 1)%2
    pcall(function() controlledCrew = Hyperspace.Global.GetInstance():GetShipManager(otherShipId).mindSystem.controlledCrew end)
    if controlledCrew then
        for crew in vter(controlledCrew) do
            if crewmem == crew then
                return true
            end
        end
    end
    return false
end
local under_mind_system = mods.vertexutil.under_mind_system

-- Check if a given crew member is resistant to mind control
function mods.vertexutil.resists_mind_control(crewmem)
    do
        local _, telepathic = crewmem.extend:CalculateStat(Hyperspace.CrewStat.IS_TELEPATHIC)
        if telepathic then return true end
    end
    do
        local _, resistMc = crewmem.extend:CalculateStat(Hyperspace.CrewStat.RESISTS_MIND_CONTROL)
        if resistMc then return true end
    end
    return false
end
local resists_mind_control = mods.vertexutil.resists_mind_control

-- Check if a given crew member can be mind controlled
function mods.vertexutil.can_be_mind_controlled(crewmem)
    return not (crewmem:IsDrone() or resists_mind_control(crewmem)) and not under_mind_system(crewmem)
end

-- Returns a table of all crew belonging to the given ship on the room tile at the given point
function mods.vertexutil.get_ship_crew_point(shipManager, x, y, maxCount)
    res = {}
    x = x//35
    y = y//35
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and x == crewmem.x//35 and y == crewmem.y//35 then
            table.insert(res, crewmem)
            if maxCount and #res >= maxCount then
                return res
            end
        end
    end
    return res
end

-- Returns a table where the indices are the IDs of all rooms adjacent to the given room
function mods.vertexutil.get_adjacent_rooms(shipId, roomId, diagonals)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipId)
    local roomShape = shipGraph:GetRoomShape(roomId)
    local adjacentRooms = {}
    local currentRoom = nil
    function check_for_room(x, y)
        currentRoom = shipGraph:GetSelectedRoom(x, y, false)
        if currentRoom > -1 then adjacentRooms[currentRoom] = true end
    end
    for offset = 0, roomShape.w - 35, 35 do
        check_for_room(roomShape.x + offset + 17, roomShape.y - 17)
        check_for_room(roomShape.x + offset + 17, roomShape.y + roomShape.h + 17)
    end
    for offset = 0, roomShape.h - 35, 35 do
        check_for_room(roomShape.x - 17,               roomShape.y + offset + 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + offset + 17)
    end
    if diagonals then
        check_for_room(roomShape.x - 17,               roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + roomShape.h + 17)
        check_for_room(roomShape.x - 17,               roomShape.y + roomShape.h + 17)
    end
    return adjacentRooms
end

-- Find ID of a room at the given location
function mods.vertexutil.get_room_at_location(shipManager, location, includeWalls)
    return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

-- Check if a weapon's current shot is its first
function mods.vertexutil.is_first_shot(weapon, afterFirstShot)
    local shots = weapon.numShots
    if weapon.weaponVisual.iChargeLevels > 0 then shots = shots*(weapon.weaponVisual.boostLevel + 1) end
    if weapon.blueprint.miniProjectiles:size() > 0 then shots = shots*weapon.blueprint.miniProjectiles:size() end
    if afterFirstShot then shots = shots - 1 end
    return shots == weapon.queuedProjectiles:size()
end

-- Generate a random point within the radius of a given point
function mods.vertexutil.random_point_radius(origin, radius)
    local r = radius*math.sqrt(Hyperspace.random32()/INT_MAX)
    local theta = 2*math.pi*(Hyperspace.random32()/INT_MAX)
    return Hyperspace.Pointf(origin.x + r*math.cos(theta), origin.y + r*math.sin(theta))
end

-- Get a table for a userdata value by name
function mods.vertexutil.userdata_table(userdata, tableName)
    if not userdata.table[tableName] then userdata.table[tableName] = {} end
    return userdata.table[tableName]
end

---------------------------
-- BETTER PRINT FUNCTION --
---------------------------
local PrintHelper = {
    queue = {},

    timer = 999,           -- So it doesn't render on game startup
    config = {
        x = 154,           -- x coordinate of printed lines
        y = 100,           -- y coordinate of printed lines
        font = 10,         -- The font to use
        line_length = 250, -- How long a line can be before it is broken
        duration = 5,      -- The number of seconds before something is cleared from the console
        messages = 10,     -- How many messages can be on the console at once
        use_speed = false, -- If true, uses game speed, if false, uses real time
    },
    Render = function(self)
        if self.timer <= self.config.duration then
           Graphics.freetype.easy_printAutoNewlines(
               self.config.font,
               self.config.x,
               self.config.y,
               self.config.line_length,
               table.concat(self.queue, "\n")
           )
            local increment = self.config.use_speed and (Hyperspace.FPS.SpeedFactor/16) or (1/Hyperspace.FPS.NumFrames)
            self.timer = self.timer + increment
        else
            self.timer = 0
            table.remove(self.queue, 1)
        end
    end,
    
    AddString = function(self, ...)
        self.timer = 0
        local string = ""
        for i = 1, select("#", ...) do
          string = string..tostring(select(i, ...)) .. "    "
        end
        table.insert(self.queue, string)
        if #self.queue > self.config.messages then
            table.remove(self.queue, 1)
        end
    end,
}

script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function() end, function()
    PrintHelper:Render()
end)

local OldPrint=print
function print(...)
    PrintHelper:AddString(...)
    OldPrint(...)
end

function printf(...)
    return print(string.format(...))
end

----------------------------
-- TUTORIAL ARROW MANAGER --
----------------------------
local tutArrowAlphaInterval = 0.38
local tutArrowSpr1 = Hyperspace.Resources:GetImageId("tutorial/arrow.png")
local tutArrowSpr2 = Hyperspace.Resources:GetImageId("tutorial/arrow2.png")
local tutArrow = {
    visible = false,
    dir = 0,
    x = 0,
    y = 0,
    timer = 0
}
function mods.vertexutil.ShowTutorialArrow(dir, x, y)
    tutArrow.visible = true
    tutArrow.dir = dir
    tutArrow.x = x
    tutArrow.y = y
    tutArrow.timer = 0
end
function mods.vertexutil.HideTutorialArrow()
    tutArrow.visible = false
end
script.on_render_event(Defines.RenderEvents.GUI_CONTAINER, function() end, function()
    if tutArrow.visible then
        Graphics.CSurface.GL_BlitImage(
            tutArrowSpr1,
            tutArrow.x, tutArrow.y,
            tutArrowSpr1.width, tutArrowSpr1.height,
            tutArrow.dir*90, Graphics.GL_Color(1, 1, 1, 1), false
        )
        Graphics.CSurface.GL_BlitImage(
            tutArrowSpr2,
            tutArrow.x, tutArrow.y,
            tutArrowSpr2.width, tutArrowSpr2.height,
            tutArrow.dir*90, Graphics.GL_Color(1, 1, 1, 1 - math.abs(tutArrow.timer - tutArrowAlphaInterval)/tutArrowAlphaInterval), false
        )
        tutArrow.timer = (tutArrow.timer + Hyperspace.FPS.SpeedFactor/16)%(2*tutArrowAlphaInterval)
    end
end)
script.on_game_event("START_GAME", false, mods.vertexutil.HideTutorialArrow)
script.on_game_event("START_BEACON", false, mods.vertexutil.HideTutorialArrow)
