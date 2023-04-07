-------------
-- IMPORTS --
-------------
local weaponInfo = mods.vertexdata.weaponInfo
local Children = mods.vertexdata.Children
local tag_add_weapons = mods.vertexdata.tag_add_weapons


local vter = mods.vertexutil.vter
local ipairs_reverse = mods.vertexutil.ipairs_reverse
local get_room_at_location = mods.vertexutil.get_room_at_location
local timeIndex = mods.vertexutil.timeIndex

------------
-- PARSER --
------------
local function parser(node)
    local temporalEffect = {}
    
    temporalEffect.duration = node:first_attribute("duration"):value()
    if not temporalEffect.duration then
        error("temporalEffect tag requires a value for duration!", 2)
    elseif not tonumber(temporalEffect.duration) then
        error("Invalid number for temporalEffect duration attribute!", 2)
    end
    temporalEffect.duration = tonumber(temporalEffect.duration)
    
    if node:first_attribute("strength") then
        temporalEffect.strength = tonumber(node:first_attribute("strength"):value())
        if not temporalEffect.strength then
            error("Invalid number for temporalEffect 'strength' attribute!", 2)
        elseif math.floor(temporalEffect.strength) ~= temporalEffect.strength then
            error("temporalEffect 'strength' attribute must be an integer!", 2)
        end
    end 
    return temporalEffect
end

-----------
-- LOGIC --
-----------
local function logic()
    --Note: EffectVector can be repurposed for other effects as well, but I'm putting it local to here for now.
    local EffectVector = { 
        lastVal = 0,
        Update = function(self)
          local modifier = 0
          for i, effect in ipairs_reverse(self) do
            effect.timer = effect.timer - timeIndex()
            if effect.timer <= 0 then
              modifier = modifier + effect.strength
              table.remove(self, i)
            end
          end
          return modifier
        end,
        Apply = function(self, effectDefinition) --NOTE: you must still manually apply the effect, this is just for durations and tracking so there's no interference with the native applications of the effect.
          local effect = {
            strength = effectDefinition.strength,
            timer = effectDefinition.duration,
          }
          table.insert(self, effect)
          self.lastVal = self.lastVal + effectDefinition.strength
        end,
        Clear = function(self)
          for i, v in ipairs_reverse(self) do 
            table.remove(self, i)
          end
        end,
        New = function(self, o)
          o = o or {}
          self.__index = self
          setmetatable(o, self)
          return o
        end,
    }
    
  
    local TEMPORAL_EFFECTS = {} --Table are unique, guarenteed to be a unique key.
    --Initialize room temporal effect tables.
    script.on_internal_event(Defines.InternalEvents.ON_TICK,
    function()
      for i = 0, 1 do
        local ShipManager = Hyperspace.Global.GetInstance():GetShipManager(i)
        if ShipManager then
          local roomList = ShipManager.ship.vRoomList
          for room in vter(roomList) do
            if not room.table[TEMPORAL_EFFECTS] then
              room.table[TEMPORAL_EFFECTS] = EffectVector:New()
            end
          end
        end
      end
    end, 2147483647) 
    
    script.on_internal_event(Defines.InternalEvents.ON_TICK,
    function()
      for i = 0, 1 do
        local ShipManager = Hyperspace.Global.GetInstance():GetShipManager(i)
        if ShipManager then
          local roomList = ShipManager.ship.vRoomList
          for room in vter(roomList) do
            local effectVector = room.table[TEMPORAL_EFFECTS]
            if room.extend.timeDilation ~= effectVector.lastVal then
              effectVector:Clear() -- If the time dilation was changed by any other source, reset all effects. Temporal system will override all temporal weapons.
            else
              local modifier = effectVector:Update()
              room.extend.timeDilation = room.extend.timeDilation - modifier
            end
            effectVector.lastVal = room.extend.timeDilation
          end
        end
      end
    end) 
    
    local function TemporalWeaponDamage(ShipManager, Projectile, Location)
      local effectDefinition = weaponInfo[Projectile.extend.name]["temporalEffect"]
      local roomNumber = get_room_at_location(ShipManager, Location, true)
      local room = ShipManager.ship.vRoomList[roomNumber]
      if effectDefinition then
        room.extend.timeDilation = room.extend.timeDilation + effectDefinition.strength
        room.table[TEMPORAL_EFFECTS]:Apply(effectDefinition)
      end
    end
    
    script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM,
    function(ShipManager, Projectile, Location, Damage, realNewTile, beamHitType)
      if beamHitType == Defines.BeamHit.NEW_ROOM then
        TemporalWeaponDamage(ShipManager, Projectile, Location)
      end
      return Defines.Chain.CONTINUE
    end
    )
    
    script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT,
    function(ShipManager, Projectile, Location, Damage, shipFriendlyFireLocal)
      TemporalWeaponDamage(ShipManager, Projectile, Location)
      return Defines.Chain.CONTINUE
    end)
end

tag_add_weapons("temporalEffect", parser, logic)




  
  