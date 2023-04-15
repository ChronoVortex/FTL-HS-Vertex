-------------
-- IMPORTS --
-------------
local weaponInfo = mods.vertexdata.weaponInfo
local tag_add_weapons = mods.vertexdata.tag_add_weapons

local vter = mods.vertexutil.vter
local get_room_at_location = mods.vertexutil.get_room_at_location

local GetLimitAmount = mods.vertexutil.GetLimitAmount
local SetLimitAmount = mods.vertexutil.SetLimitAmount

local EffectVector = mods.vertexutil.EffectVector
------------
-- PARSER --
------------
local function parser(node)
    local limitEffect = {}
    
    limitEffect.duration = node:first_attribute("duration"):value()
    if not limitEffect.duration then
        error("limitEffect tag requires a value for duration!", 2)
    elseif not tonumber(limitEffect.duration) then
        error("Invalid number for limitEffect duration attribute!", 2)
    end
    limitEffect.duration = tonumber(limitEffect.duration)
    
    if node:first_attribute("strength") then
        limitEffect.strength = tonumber(node:first_attribute("strength"):value())
        if not limitEffect.strength then
            error("Invalid number for limitEffect 'strength' attribute!", 2)
        elseif math.floor(limitEffect.strength) ~= limitEffect.strength then
            error("limitEffect 'strength' attribute must be an integer!", 2)
        end
    end 
    return limitEffect
end

-----------
-- LOGIC --
-----------




local function logic()
    local LIMIT_EFFECTS = {} --Table are unique, guarenteed to be a unique key.
    --Initialize system limit effect tables.
  

    script.on_internal_event(Defines.InternalEvents.SHIP_LOOP,
    function(ShipManager)
      for system in vter(ShipManager.vSystemList) do
        if not system.table[LIMIT_EFFECTS] then
          system.table[LIMIT_EFFECTS] = EffectVector:New()
        end
      end
    end, 2147483647) 
    
    script.on_internal_event(Defines.InternalEvents.SHIP_LOOP,
    function(ShipManager)
      for system in vter(ShipManager.vSystemList) do
        local effectVector = system.table[LIMIT_EFFECTS]            
        effectVector:Update()
        system.extend.additionalPowerLoss = system.extend.additionalPowerLoss + effectVector:Calculate()
        system:CheckMaxPower()
        system:CheckForRepower()
      end
    end) 



    local function LimitWeaponDamage(ShipManager, Projectile, Location)
      local effectDefinition = weaponInfo[Projectile.extend.name]["limitEffect"]
      local roomNumber = get_room_at_location(ShipManager, Location, true)
      local system
      if roomNumber ~= -1 then 
        system = ShipManager:GetSystemInRoom(roomNumber) 
      end
      if effectDefinition and system then
        system.table[LIMIT_EFFECTS]:Apply(effectDefinition)
      end
    end
    
    script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM,
    function(ShipManager, Projectile, Location, Damage, realNewTile, beamHitType)
      if beamHitType == Defines.BeamHit.NEW_ROOM then
        LimitWeaponDamage(ShipManager, Projectile, Location)
      end
      return Defines.Chain.CONTINUE
    end
    )
    
    script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT,
    function(ShipManager, Projectile, Location, Damage, shipFriendlyFireLocal)
      LimitWeaponDamage(ShipManager, Projectile, Location)
      return Defines.Chain.CONTINUE
    end)
end

tag_add_weapons("limitEffect", parser, logic)
function prep()
  local enemyShip = Hyperspace.ships.enemy
  enemyShip.weaponSystem:UpgradeSystem(-10)
  enemyShip.teleportSystem:UpgradeSystem(-10)
  enemyShip.shieldSystem:UpgradeSystem(-10)
  enemyShip.ship.hullIntegrity.second = 1000
  enemyShip.ship.hullIntegrity.first = 1000
end



  
