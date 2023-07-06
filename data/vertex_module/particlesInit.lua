mods.vertexparts = {}

local vter = mods.vertexutil.vter
local Children = mods.vertexdata.Children
local parse_xml_bool = mods.vertexdata.parse_xml_bool
local INT_MAX = 2147483647

----------------------
-- HELPER FUNCTIONS --
----------------------
local function seconds_per_tick()
    return Hyperspace.FPS.SpeedFactor/16
end

local function rand_range(min, max)
    return (Hyperspace.random32()/INT_MAX)*(max - min) + min
end

local function lerp(a, b, amount)
    return a + (b - a)*amount
end

local function node_get_value(node, errorMsg)
    if not node then error(errorMsg, 2) end
    local ret = node:value()
    if not ret then error(errorMsg, 2) end
    return ret
end

local function node_get_number(node, errorMsg)
    if not node then error(errorMsg, 2) end
    local ret = tonumber(node:value())
    if not ret then error(errorMsg, 2) end
    return ret
end

local function node_get_number_default(node, default)
    if not node then return default end
    local ret = tonumber(node:value())
    if not ret then return default end
    return ret
end

local function node_get_bool_default(node, default)
    if not node then return default end
    local ret = node:value()
    if not ret then return default end
    return parse_xml_bool(ret)
end

-----------------
-- DEFENITIONS --
-----------------
mods.vertexparts.particleLayers = {}
local particleLayers = mods.vertexparts.particleLayers

mods.vertexparts.particles = {}
local particles = mods.vertexparts.particles

mods.vertexparts.particleTypes = {}
local particleTypes = mods.vertexparts.particleTypes

mods.vertexparts.emitterEvents = {}
local emitterEvents = mods.vertexparts.emitterEvents

mods.vertexparts.emitterShapes = {}
local emitterShapes = mods.vertexparts.emitterShapes

mods.vertexparts.particleEmitters = {}
local particleEmitters = mods.vertexparts.particleEmitters
particleEmitters.activeEmitters = {}

----------------------
-- PARTICLE TRACKER --
----------------------
particleLayers.TOP = 0
particleLayers.BOTTOM = 1

function particles:Create(typeName, x, y, space, layer, rotate, mirror)
    local particle = {}
    table.insert(self, particle)
    particle.type = particleTypes[typeName]
    if not particle.type then error(tostring(typeName).." particle type does not exist!") end
    particle.x = x
    particle.y = y
    particle.space = space
    particle.layer = layer
    particle.rotate = rotate
    particle.mirror = mirror
    particle.anim = Hyperspace.Global.GetInstance():GetAnimationControl():GetAnimation(particle.type.anim.name)
    particle.anim.position.x = -particle.anim.info.frameWidth/2
    particle.anim.position.y = -particle.anim.info.frameHeight/2
    if particle.type.anim.random then
        particle.anim:SetCurrentFrame(Hyperspace.random32()%particle.anim.info.numFrames)
    end
    if particle.type.anim.animated then
        particle.anim.tracker.loop = true
        particle.anim:Start(false)
    end
    local col = particle.type.colors[1]
    particle.color = Graphics.GL_Color(col.r, col.g, col.b, col.a)
    particle.lifetime = rand_range(particle.type.lifetime.min, particle.type.lifetime.max)
    particle.lifeRemaining = particle.lifetime
    particle.speed = rand_range(particle.type.speed.min, particle.type.speed.max)
    if mirror then
        particle.angleSign = -1
        if particle.rotate then
            particle.xscaleSign = 1
            particle.yscaleSign = -1
        else
            particle.xscaleSign = -1
            particle.yscaleSign = 1
        end
    else
        particle.angleSign = 1
        particle.xscaleSign = 1
        particle.yscaleSign = 1
    end
    particle.direction = particle.angleSign*rand_range(particle.type.direction.min, particle.type.direction.max)
    particle.orientation = particle.angleSign*rand_range(particle.type.orientation.min, particle.type.orientation.max)
    if rotate then
        particle.direction = particle.direction - particle.angleSign*90
        particle.orientation = particle.orientation - particle.angleSign*90
        particle.orientationOffset = 0
    else
        particle.orientationOffset = 90
        -- for some reason the direction needs an offset of 180 degrees if we're mirrored but not rotated
        -- angleSign math is a hacky way to avoid checking if mirror
        particle.direction = particle.direction + (particle.angleSign/2 + 1.5)*180
    end
    particle.scale = rand_range(particle.type.scale.min, particle.type.scale.max)
end

function particles:Update()
    for index, particle in ipairs(self) do
        particle.lifeRemaining = particle.lifeRemaining - seconds_per_tick()
        if particle.lifeRemaining <= 0 then
            table.remove(self, index)
        else
            local lifeProgress = 1 - particle.lifeRemaining/particle.lifetime
            if particle.type.anim.animated then
                if particle.type.anim.lifetime then
                    particle.anim:SetProgress(lifeProgress)
                else
                    particle.anim:Update()
                end
            end
            local numColors = #(particle.type.colors)
            if numColors > 1 then
                local colorProgress = (numColors - 1)*lifeProgress
                local firstColIndex = math.floor(colorProgress) + 1
                colorProgress = colorProgress%1
                local col1 = particle.type.colors[firstColIndex]
                local col2 = particle.type.colors[firstColIndex + 1]
                particle.color.r = lerp(col1.r, col2.r, colorProgress)
                particle.color.g = lerp(col1.g, col2.g, colorProgress)
                particle.color.b = lerp(col1.b, col2.b, colorProgress)
                particle.color.a = lerp(col1.a, col2.a, colorProgress)
            end
            local dirRadians = math.rad(particle.direction)
            particle.x = particle.x + math.cos(dirRadians)*particle.speed*seconds_per_tick()
            particle.y = particle.y + -math.sin(dirRadians)*particle.speed*seconds_per_tick()
            particle.speed = particle.speed + particle.type.speed.increment*seconds_per_tick()
            particle.direction = particle.direction + particle.type.direction.increment*particle.angleSign*seconds_per_tick()
            particle.orientation = particle.orientation + particle.type.orientation.increment*particle.angleSign*seconds_per_tick()
            particle.scale = particle.scale + particle.type.scale.increment*seconds_per_tick()
        end
    end
end

function particles:Render(space, layer)
    for index, particle in ipairs(self) do
        if space == particle.space and layer == particle.layer then
            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_Translate(particle.x, particle.y)
            local angle = particle.orientation
            if particle.type.orientation.relative then
                angle = angle + particle.direction - particle.orientationOffset
            end
            Graphics.CSurface.GL_Rotate(-angle, 0, 0)
            Graphics.CSurface.GL_Scale(particle.xscaleSign*particle.scale, particle.yscaleSign*particle.scale, 1)
            particle.anim:OnRender(1, particle.color, false)
            Graphics.CSurface.GL_PopMatrix()
        end
    end
end

--------------------
-- PARTICLE TYPES --
--------------------
function particleTypes:ParseNew(particleTypeNode)
    local partTypeName = node_get_value(particleTypeNode:first_attribute("name"), "particleType requires a name!")
    log("Parsing particleType tag "..partTypeName)
    local partType = {}
    self[partTypeName] = partType
    
    -- Animation
    partType.anim = {}
    local animNode = particleTypeNode:first_node("anim")
    if not animNode then error("particleType requires an anim tag!") end
    partType.anim.name = node_get_value(animNode, "particleType anim tag requires a value!")
    partType.anim.animated = node_get_bool_default(animNode:first_attribute("animated"), false)
    partType.anim.random = node_get_bool_default(animNode:first_attribute("random"), false)
    partType.anim.lifetime = node_get_bool_default(animNode:first_attribute("lifetime"), false)
    
    -- Colors
    partType.colors = {}
    local colorsNode = particleTypeNode:first_node("colors")
    if not colorsNode then
        table.insert(partType.colors, {r = 1, g = 1, b = 1, a = 1})
    else
        for colorNode in Children(colorsNode) do
            local rVal = node_get_number(colorNode:first_attribute("r"), "particleType color tag requires a red value!")/255
            local gVal = node_get_number(colorNode:first_attribute("g"), "particleType color tag requires a green value!")/255
            local bVal = node_get_number(colorNode:first_attribute("b"), "particleType color tag requires a blue value!")/255
            local aVal = node_get_number(colorNode:first_attribute("a"), "particleType color tag requires an alpha value!")
            table.insert(partType.colors, {r = rVal, g = gVal, b = bVal, a = aVal})
        end
        if #(partType.colors) <= 0 then error("particleType colors tag requires at least one color!") end
    end
    
    -- Lifetime
    partType.lifetime = {}
    local lifetimeNode = particleTypeNode:first_node("lifetime")
    if not lifetimeNode then error("particleType requires an lifetime tag!") end
    partType.lifetime.min = node_get_number(lifetimeNode:first_attribute("min"), "particleType lifetime tag requires a valid minimum!")
    if partType.lifetime.min < 0 then error("particleType lifetime minimum must be positive!") end
    partType.lifetime.max = node_get_number(lifetimeNode:first_attribute("max"), "particleType lifetime tag requires a valid maximum!")
    if partType.lifetime.min > partType.lifetime.max then error("particleType lifetime maximum must be greater than or equal to minimum!") end
    
    -- Speed
    partType.speed = {}
    local speedNode = particleTypeNode:first_node("speed")
    if not speedNode then
        partType.speed.min = 0
        partType.speed.max = 0
        partType.speed.increment = 0
    else
        partType.speed.min = node_get_number(speedNode:first_attribute("min"), "particleType speed tag requires a valid minimum!")
        partType.speed.max = node_get_number(speedNode:first_attribute("max"), "particleType speed tag requires a valid maximum!")
        if partType.speed.min > partType.speed.max then error("particleType speed maximum must be greater than or equal to minimum!") end
        partType.speed.increment = node_get_number_default(speedNode:first_attribute("increment"), 0)
    end
    
    -- Direction
    partType.direction = {}
    local directionNode = particleTypeNode:first_node("direction")
    if not directionNode then
        if speedNode then error("particleType with speed tag also requires a valid direction tag!") end
        partType.direction.min = 0
        partType.direction.max = 0
        partType.direction.increment = 0
    else
        partType.direction.min = node_get_number(directionNode:first_attribute("min"), "particleType direction tag requires a valid minimum!")
        partType.direction.max = node_get_number(directionNode:first_attribute("max"), "particleType direction tag requires a valid maximum!")
        if partType.direction.min > partType.direction.max then error("particleType direction maximum must be greater than or equal to minimum!") end
        partType.direction.increment = node_get_number_default(directionNode:first_attribute("increment"), 0)
    end
    
    -- Orientation
    partType.orientation = {}
    local orientationNode = particleTypeNode:first_node("orientation")
    if not orientationNode then
        partType.orientation.min = 0
        partType.orientation.max = 0
        partType.orientation.increment = 0
        partType.orientation.relative = false
    else
        partType.orientation.min = node_get_number(orientationNode:first_attribute("min"), "particleType orientation tag requires a valid minimum!")
        partType.orientation.max = node_get_number(orientationNode:first_attribute("max"), "particleType orientation tag requires a valid maximum!")
        if partType.orientation.min > partType.orientation.max then error("particleType orientation maximum must be greater than or equal to minimum!") end
        partType.orientation.increment = node_get_number_default(orientationNode:first_attribute("increment"), 0)
        partType.orientation.relative = node_get_bool_default(orientationNode:first_attribute("relative"), false)
    end
    
    -- Scale
    partType.scale = {}
    local scaleNode = particleTypeNode:first_node("scale")
    if not scaleNode then
        partType.scale.min = 1
        partType.scale.max = 1
        partType.scale.increment = 0
    else
        partType.scale.min = node_get_number(scaleNode:first_attribute("min"), "particleType scale tag requires a valid minimum!")
        partType.scale.max = node_get_number(scaleNode:first_attribute("max"), "particleType scale tag requires a valid maximum!")
        if partType.scale.min > partType.scale.max then error("particleType scale maximum must be greater than or equal to minimum!") end
        partType.scale.increment = node_get_number_default(scaleNode:first_attribute("increment"), 0)
    end
end

-----------------------
-- PARTICLE EMITTERS --
-----------------------
emitterEvents.FIRE = 0
emitterEvents.EXPLOSION = 1

emitterShapes.LINE = 0
emitterShapes.RECT = 1
emitterShapes.ELLIPSE = 2

function particleEmitters:ParseNew(particleEmitterNode, weaponName)
    local partEmitter = {}
    local baseEmitterName = nil
    if weaponName then
        log("Parsing particleEmitter tag in weapon "..weaponName)
        baseEmitterName = particleEmitterNode:first_attribute("name")
        if baseEmitterName then -- Give tables with parents a metatable that makes them draw values from their parent as defaults
            baseEmitterName = baseEmitterName:value()
            local baseEmitter = self[baseEmitterName]
            if not baseEmitter then error("particleEmitter "..baseEmitterName.." does not exist in animations xml!") end
            setmetatable(partEmitter, {
                __index = function(t, k)
                    return baseEmitter[k]
                end
            })
        end
        local weaponEmitters = self.activeEmitters[weaponName]
        if not weaponEmitters then
            weaponEmitters = {}
            self.activeEmitters[weaponName] = weaponEmitters
        end
        table.insert(weaponEmitters, partEmitter)
    else
        local partEmitterName = node_get_value(particleEmitterNode:first_attribute("name"), "particleEmitter requires a name!")
        log("Parsing particleEmitter tag "..partEmitterName)
        if partEmitterName == "activeEmitters" then error("particleEmitter name must not be activeEmitters!") end
        self[partEmitterName] = partEmitter
    end
    
    -- Type
    local function get_type()
        partEmitter.type = node_get_value(particleEmitterNode:first_node("type"), "particleEmitter requires a valid type!")
    end
    if baseEmitterName then pcall(get_type) else get_type() end
    
    -- Event
    local function get_event()
        partEmitter.on = emitterEvents[node_get_value(particleEmitterNode:first_node("on"), "particleEmitter requires a valid event!")]
        if not partEmitter.on then error("particleEmitter requires a valid event!") end
    end
    if baseEmitterName then pcall(get_event) else get_event() end
    
    -- Location
    local default = nil
    if not baseEmitterName then default = 0 end
    partEmitter.x = node_get_number_default(particleEmitterNode:first_node("x"), default)
    partEmitter.y = node_get_number_default(particleEmitterNode:first_node("y"), default)
    
    -- Count
    if not baseEmitterName then default = 1 end
    partEmitter.count = node_get_number_default(particleEmitterNode:first_node("count"), default)
    
    -- Layer
    if not baseEmitterName then default = false end
    local renderUnderShip = node_get_bool_default(particleEmitterNode:first_node("renderUnderShip"), default)
    if renderUnderShip ~= nil then
        if renderUnderShip then
            partEmitter.layer = particleLayers.BOTTOM
        else
            partEmitter.layer = particleLayers.TOP
        end
    end
    
    -- Shape
    local shapeNode = particleEmitterNode:first_node("shape")
    if shapeNode then
        partEmitter.shape = emitterShapes[node_get_value(shapeNode, "particleEmitter shape tag requires a valid value!")]
    end
    
    -- Shape size
    if baseEmitterName or not partEmitter.shape then
        partEmitter.width = node_get_number_default(particleEmitterNode:first_node("w"), nil)
        partEmitter.height = node_get_number_default(particleEmitterNode:first_node("h"), nil)
    else
        partEmitter.width = node_get_number(particleEmitterNode:first_node("w"), "particleEmitter with shape tag requires a valid width!")
        partEmitter.height = node_get_number(particleEmitterNode:first_node("h"), "particleEmitter with shape tag requires a valid height!")
    end
    if partEmitter.width then
        if partEmitter.shape == emitterShapes.LINE then
            if partEmitter.width == 0 and partEmitter.width == 0 then error("particleEmitter with LINE shape must have non-zero width or height!") end
        else
            if partEmitter.width == 0 or partEmitter.width == 0 then error("particleEmitter with non-LINE shape must have non-zero width and height!") end
        end
    end
end

local function generate_shape_offset(emitter)
    local offsetX, offsetY
    if emitter.shape == emitterShapes.LINE then
        local offsetMagnitude = Hyperspace.random32()/INT_MAX
        offsetX = offsetMagnitude*emitter.width
        offsetY = offsetMagnitude*emitter.height
    elseif emitter.shape == emitterShapes.RECT then
        if emitter.width < 0 then
            offsetX = rand_range(emitter.width, 0)
        else
            offsetX = rand_range(0, emitter.width)
        end
        if emitter.height < 0 then
            offsetY = rand_range(emitter.height, 0)
        else
            offsetY = rand_range(0, emitter.height)
        end
    elseif emitter.shape == emitterShapes.ELLIPSE then
        local halfWidth = emitter.width/2
        local r = halfWidth*math.sqrt(Hyperspace.random32()/INT_MAX)
        local theta = 2*math.pi*(Hyperspace.random32()/INT_MAX)
        offsetX = halfWidth + r*math.cos(theta)
        offsetY = (halfWidth + r*math.sin(theta))*(emitter.height/emitter.width)
    end
    return offsetX, offsetY
end

function particleEmitters:Emit(emitter, event, weapon, posX, posY, shipId)
    if event == emitter.on then
        local emitPointX = posX or 0
        local emitPointY = posY or 0
        local rotate = false
        local mirror = false
        local vertMod = 1
        if weapon then
            rotate = weapon.mount.rotate
            mirror = weapon.mount.mirror
            if mirror then vertMod = -1 end
            
            -- Calculate weapon coodinates
            local weaponAnim = weapon.weaponVisual
            local ship = Hyperspace.Global.GetInstance():GetShipManager(weapon.iShipId).ship
            local shipGraph = Hyperspace.ShipGraph.GetShipInfo(weapon.iShipId)
            local slideOffset = weaponAnim:GetSlide()
            emitPointX = emitPointX + ship.shipImage.x + shipGraph.shipBox.x + weaponAnim.renderPoint.x + slideOffset.x
            emitPointY = emitPointY + ship.shipImage.y + shipGraph.shipBox.y + weaponAnim.renderPoint.y + slideOffset.y

            -- Add emitter and mount point offset
            if rotate then
                emitPointX = emitPointX - emitter.y + weaponAnim.mountPoint.y
                emitPointY = emitPointY + (emitter.x - weaponAnim.mountPoint.x)*vertMod
            else
                emitPointX = emitPointX + (emitter.x - weaponAnim.mountPoint.x)*vertMod
                emitPointY = emitPointY + emitter.y - weaponAnim.mountPoint.y
            end
        else
            emitPointX = emitPointX + emitter.x
            emitPointY = emitPointY + emitter.y
        end

        -- Emit particles
        if emitter.shape then
            if rotate then
                for i = 1, emitter.count do
                    local offsetX, offsetY = generate_shape_offset(emitter)
                    particles:Create(emitter.type, emitPointX - offsetY, emitPointY + offsetX*vertMod, shipId or weapon.iShipId,
                        emitter.layer, rotate, mirror)
                end
            else
                for i = 1, emitter.count do
                    local offsetX, offsetY = generate_shape_offset(emitter)
                    particles:Create(emitter.type, emitPointX + offsetX*vertMod, emitPointY + offsetY, shipId or weapon.iShipId,
                        emitter.layer, rotate, mirror)
                end
            end
        else
            for i = 1, emitter.count do
                particles:Create(emitter.type, emitPointX, emitPointY, shipId or weapon.iShipId, emitter.layer, rotate, mirror)
            end
        end
    end
end

--------------------------
-- PARSE ANIMATIONS XML --
--------------------------
local animationFiles = {
    "data/animations.xml",
    "data/dlcAnimations.xml",
}
for _, file in ipairs(animationFiles) do
    local doc = RapidXML.xml_document(file)
    for node in Children(doc:first_node("FTL") or doc) do
        if node:name() == "particleType" then
            particleTypes:ParseNew(node)
        elseif node:name() == "particleEmitter" then
            particleEmitters:ParseNew(node)
        end
    end
    doc:clear()
end
