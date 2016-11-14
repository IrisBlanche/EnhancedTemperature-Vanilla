--[[

   Copyright 2016 Iris Blanche

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

]]

-- #########################################################################################################
-- additional scripts needed
-- #########################################################################################################
require "/scripts/IB_EHT/util.lua"

-- #########################################################################################################
-- 'class' definition
-- #########################################################################################################
EHT = {}
EHT.__index = EHT

-- #########################################################################################################
-- class init
-- #########################################################################################################
function EHT.create()
	local data = setmetatable({}, EHT)
	
	data.config = root.assetJson("/IB_EHT_config/core.config")
	local configs = { "equip.config", "heatsources.config", "hybridsources.config", "liquids.config", "planetTypes.config", "status.config", "weather.config" }
	for _,config in ipairs(configs) do
		data.config = sb.jsonMerge(data.config, root.assetJson("/IB_EHT_config/" .. config))
	end

	data.lvlFlag = {
		hypo3 = false,
		hypo2 = false,
		hypo1 = false,
		switch = false,
		hyper1 = false,
		hyper2 = false,
		hyper3 = false
	}
	
	data.offset = 0
	data.oldid = "NA"

	-- Get planetsizes based on config (patched)
	data.planetSizes = root.assetJson("/terrestrial_worlds.config:planetSizes")
	
	return data
end

-- #########################################################################################################
-- Apply starter effect when first installed or on death
-- #########################################################################################################
function EHT:applyStarterEffect()
	if self:noEffects() then
		status.addEphemeralEffect(self.config.exposure.effects.hyper0, math.huge)
		self.lvlFlag = {
			hypo3 = false,
			hypo2 = false,
			hypo1 = false,
			switch = false,
			hyper1 = false,
			hyper2 = false,
			hyper3 = false
		}
	end
end

-- #########################################################################################################
-- Status check for death handler
-- #########################################################################################################
function EHT:noEffects()
	local ret = false
	local effects = {"hypo3","hypo2","hypo1","hypo0","hyper0","hyper1","hyper2","hyper3"}
	for _, v in ipairs (effects) do
		if self:hasEffect(self.config.exposure.effects[v]) then
			return false
		end
	end
	return true
end

-- #########################################################################################################
-- get the ongoing direction based on value as string
-- #########################################################################################################
function EHT:direction(modifier)
	if modifier < 0.0 then
		return "-"
	elseif modifier > 0.0 then
		return "+"
	end
	return "#"
end

-- #########################################################################################################
-- Switch effects (remove from, add to)
-- #########################################################################################################
function EHT:switchEffects(from, to)
	status.removeEphemeralEffect(from)
	status.addEphemeralEffect(to, math.huge)
end

-- #########################################################################################################
-- Is the player on the planet?
-- #########################################################################################################
function EHT:IsOnPlanet(planettype)
	return world.type() == planettype
end

-- #########################################################################################################
-- Does the player has the effect?
-- #########################################################################################################
function EHT:hasEffect(effect)
	-- Scan for effect
	local status = status.activeUniqueStatusEffectSummary()
	
	for i, v in ipairs (status) do
		if v[1] == effect then
			-- effect found
			return true
		end
	end
	
	-- effect not found
	return false
end

-- #########################################################################################################
-- Is it night?
-- #########################################################################################################
function EHT:IsNight()
	return not Util:between( (self:FormatTime()).hour, self.config.DayStart, self.config.NightStart-1)
end

-- #########################################################################################################
-- Format time to a table
-- #########################################################################################################
function EHT:FormatTime()
	local t = (24 * world.timeOfDay()) + 6
	if t >= 24.0 then
		t = t - 24
	end
	
	local h,m = math.modf(t)
	
	return {
		hour = h,
		minute = m,
		minute60 = m*60
	}
end

-- #########################################################################################################
-- Calculate temperature based on planettype, wind and time
-- #########################################################################################################
function EHT:CalculateTemperature()
	
	-- Temperature value
	local temperature = 0.0
	
	-- Are we on our ship?
	if player.worldId() == player.ownShipWorldId() then
		-- Our ship will give us a nice temperature, regardless of the orbiting planet
		temperature = 25.0
		self:getLayers() -- add the shipworld layer to prevent compat cards
	else
		-- Temperature table with standard skipCheck
		local temp = {
			skipCheck = true -- should the planettype be skipped in calculation?
		}
		
		-- Get temperature based on planettype environmental status
		for k,v in pairs(self.config.planetTypes) do
			if self:IsOnPlanet(k) then
				temp = v
			end
		end
		
		-- Only apply additional calculation when the planettype is not marked for skip
		if not temp.skipCheck then
			
			-- get planetlayers
			local layers = world.getProperty("eht_layers", nil)
			
			if layers == nil then
				layers = self:getLayers()
			end
			
			-- Define layers for testing
			local layerdefinition = { "space", "atmosphere", "surface", "subsurface", "underground1", "underground2", "underground3", "core" }
			local layercount = 1
			
			-- Check layer and get the according target temperature
			for _,l in pairs(layerdefinition) do
				if self:isInLayer(l, layers) then
					if self:IsNight() then
						temperature = self:layerOffset(true, layercount, layers, temp)
					else
						temperature = self:layerOffset(false, layercount, layers, temp)
					end
					break -- stop running the loop since we have the data
				end
				layercount = layercount + 1
			end
			
			-- apply weather offset
			for _,v in pairs(self.config.weathertypes) do
				if self:hasEffect(v.name) then
					-- check type
					-- only allow hypo and hyper
					if v.type == "hypo" then
						temperature = temperature - v.mod
						-- apply wind if not skipping
						-- "hypothermia weather" will cause cold wind
						if v.skipWind ~= false then
							temperature = temperature - math.abs(world.windLevel(entity.position())) / 10
						end
					elseif v.type == "hyper" then
						temperature = temperature + v.mod
						-- apply wind if not skipping
						-- "hyperthermia weather" will cause hot wind
						if v.skipWind ~= false then
							temperature = temperature + math.abs(world.windLevel(entity.position())) / 10
						end
					end
					
					break
				end
			end
			
			-- offset is fresh so set the current temperature
			if self.offset == 0 then
				self.offset = temperature
			end
			
			-- still the same world?
			if(self.oldid == player.worldId()) then
				-- yes, add offset
				temperature = self.offset + self:modHelper(self.offset, temperature, Util:mmDiv( Util:diff(self.offset, temperature), 10, 0.1, 1.0))
			else
				-- no, we set the new id and return the actual temperature as an absolute value without any transition
				self.oldid = player.worldId()
			end
		else
			-- apply standard regardless of the rest (for missions and stuff since we don't want to have the missions too hard)
			temperature = self.config.fallbackTemperature
		end
	end
	
	-- set offset to the actual temperature
	self.offset = temperature
	
	-- return the calculated temperature
	return temperature
end

-- #########################################################################################################
-- Get the planet layers temperature offset between each other
-- #########################################################################################################
function EHT:layerOffset(isNight, layercount, layers, temp)
	
	-- Get world time
	local timer = self:FormatTime()
	
	-- get current position
	local pos = entity.position()[2]
	
	local temperature = 0
	local temperature2 = 0
	
	local offsetDirection = "-"
	
	-- Temperature difference between layers
	local tmp = 0
	
	if isNight then
		
		-- Time based calculation?
		if Util:between(timer.hour, self.config.NightStart, self.config.NightStart + (self.config.TransitionTime-1) ) then
			
			-- YES
		
			-- get minute
			local minute = (timer.minute + (timer.hour - self.config.NightStart) ) / self.config.TransitionTime
			
			-- Get layer temperature based on time
			local layertime_curr =  ( ( temp.day[layercount] - temp.night[layercount] ) * minute)
			
			-- if not space
			if pos < layers.space.layerLevel then
				
				-- calculate layer difference
				local layertime_other = ( ( temp.day[layercount - 1] - temp.night[layercount - 1] ) * minute)
				
				-- get layer difference
				tmp = math.abs( Util:diff(temp.day[layercount] - layertime_curr, temp.day[layercount - 1] - layertime_other) )
				
				-- set direction
				if (temp.day[layercount] - layertime_curr) > (temp.day[layercount - 1] - layertime_other) then
					offsetDirection = "+"
				end
		
				-- set temperature2
				temperature2 = temp.day[layercount - 1] - layertime_curr
			end
			
			-- set temperature
			temperature = temp.day[layercount] - layertime_curr
		else
			
			-- NO
			
			-- if not space
			if pos < layers.space.layerLevel then
				-- get layer difference
				tmp = Util:diff( temp.night[layercount], temp.night[layercount - 1] )
			
				-- set direction
				if temp.night[layercount] > temp.night[layercount - 1] then
					offsetDirection = "+"
				end
		
				-- set temperature2
				temperature2 = temp.night[layercount - 1]
			end
			
			-- set temperature
			temperature = temp.night[layercount]
		end
	else
		-- Time based calculation?
		if Util:between(timer.hour, self.config.DayStart, self.config.DayStart + (self.config.TransitionTime-1) ) then
			
			-- YES
			
			-- get minute
			local minute = (timer.minute + (timer.hour - self.config.DayStart) ) / self.config.TransitionTime
			
			-- Get layer time based on time
			local layertime_curr =  ( ( temp.day[layercount] - temp.night[layercount] ) * minute)
			
			-- if not space
			if pos < layers.space.layerLevel then
				local layertime_other = ( ( temp.day[layercount - 1] - temp.night[layercount - 1] ) * minute)
				
				-- get layer difference
				tmp = math.abs( Util:diff( temp.night[layercount] + layertime_curr, temp.night[layercount - 1] + layertime_other ) )
				
				-- set direction
				if ( temp.night[layercount] + layertime_curr ) > ( temp.night[layercount - 1] + layertime_other ) then
					offsetDirection = "+"
				end
					
				-- set temperature2
				temperature2 = temp.night[layercount - 1] + layertime_curr
			end
			
			-- set temperature
			temperature = temp.night[layercount] + layertime_curr
		else
			
			-- NO
			
			-- if not space
			if pos < layers.space.layerLevel then
			
				-- get layer difference
				tmp = Util:diff(temp.day[layercount], temp.day[layercount - 1])
				
				-- set direction
				if temp.day[layercount] > temp.day[layercount - 1] then
					offsetDirection = "+"
				end
			
				-- set temperature2
				temperature2 = temp.day[layercount - 1]
			end
			
			-- set temperature
			temperature = temp.day[layercount]
		end
	end
	
	-- Blocks to calculate for each layer
	local tmpcmp = self.config.blockRange
	
	-- layerlevel
	local layerLevel = {
		layers.space.layerLevel,
		layers.atmosphere.layerLevel,
		layers.surface.layerLevel,
		layers.subsurface.layerLevel,
		layers.underground1.layerLevel,
		layers.underground2.layerLevel,
		layers.underground3.layerLevel
	}
	
	-- get offset
	if pos < layers.space.layerLevel then
		for _,l in pairs(layerLevel) do
			-- are we in calculation range?
			if Util:between(pos, l - tmpcmp, l) then
				-- get percentage
				local pct = 1.0 - ( ( pos - (l - tmpcmp) ) / tmpcmp )
				
				-- return new temperature based on layer calculation
				if offsetDirection == "+" then
					return temperature2 + ( tmp * pct )
				else
					return temperature2 - ( tmp * pct )
				end
			end
		end
	end
	
	-- return temperature if no offset
	return temperature
end

-- #########################################################################################################
-- Get the current planet layers
-- #########################################################################################################
function EHT:getLayers()
	-- do not perform the check when we're on our ship
	if player.worldId() == player.ownShipWorldId() then
		world.setProperty("eht_layers", { shipworld = true })
		return { shipworld = true }
	end
	
	-- get xwrap of this world
	local size = Util:getPlanetSize()
	
	-- get associated world
	for k,v in pairs(self.planetSizes) do
		if v.size[1] == size then
			world.setProperty("eht_layers", v.layers)
			return v.layers
		end
	end
end

-- #########################################################################################################
-- Is in layer
-- #########################################################################################################
function EHT:isInLayer(layername, layers)
	
	-- get the position (we only need the y value)
	local pos = entity.position()[2]
	
	-- check for space (no need for adding the max value, there is nothing above space)
	if layername == "space" and pos >= layers.space.layerLevel then
		return true
	end
	
	-- check for atmosphere
	if layername == "atmosphere" and Util:between(pos, layers.atmosphere.layerLevel, layers.space.layerLevel) then
		return true
	end
	
	-- check for surface
	if layername == "surface" and Util:between(pos, layers.surface.layerLevel, layers.atmosphere.layerLevel) then
		return true
	end
	
	-- check for subsurface
	if layername == "subsurface" and Util:between(pos, layers.subsurface.layerLevel, layers.surface.layerLevel) then
		return true
	end
	
	-- check for underground1
	if layername == "underground1" and Util:between(pos, layers.underground1.layerLevel, layers.subsurface.layerLevel) then
		return true
	end
	
	-- check for underground2
	if layername == "underground2" and Util:between(pos, layers.underground2.layerLevel, layers.underground1.layerLevel) then
		return true
	end
	
	-- check for underground3
	if layername == "underground3" and Util:between(pos, layers.underground3.layerLevel, layers.underground2.layerLevel) then
		return true
	end
	
	-- check for core
	if layername == "core" and Util:between(pos, layers.core.layerLevel, layers.underground3.layerLevel) then
		return true
	end
	
	return false
end

-- #########################################################################################################
-- Calculate modifier based on value and diff step 
-- #########################################################################################################
function EHT:modHelper(value, target, diff)
	
	if diff == nil then
		diff = 0.1
	end
	if value >= (target + diff) then
		return -diff
	elseif Util:between(value, target, target + diff) then
		return -Util:diff(value, target)
	elseif value <= (target - diff) then
		return diff
	elseif Util:between(value, target - diff, target) then
		return Util:diff(value, target)
	end
	return 0.0
end

-- #########################################################################################################
-- Calculate exposure modifier
-- #########################################################################################################
function EHT:CalculateModifier(temperature)
	
	-- Get exposure
	local exposure = status.resource("exposure")
	
	-- Target exposure based on temperature
	local targetexposure = 90 + temperature
	
	-- Is hybrid?
	local isHybrid = false
	
	-- Is liquid?
	local isLiquid = false
	
	-- Set factor
	local factor = 1
	
	-- set higher targetexposure dependent on current level
	
	-- Hypothermia
	if Util:between(temperature, -15, -0.1) then
		targetexposure = targetexposure * 0.5
		factor = factor + (factor * 0.1)
	elseif temperature < -15 then
		targetexposure = targetexposure * 0.45
		factor = factor + (factor * 0.25)
	
		-- Hyperthermia
	elseif Util:between(temperature, 34.5, 50) then
		targetexposure = targetexposure * 1.5
		factor = factor + (factor * 0.1)
	elseif temperature > 50 then
		targetexposure = targetexposure * 1.55
		factor = factor + (factor * 0.25)
	end
	
	
	-- Penalty for unequipped main slots (back slot not included!)
	local slots = {"head","chest","legs"}
	for _,s in pairs(slots) do
		local it = player.equippedItem(s)
		if it == nil then
			targetexposure = targetexposure - 3
		end
	end
	
	-- Apply special status effects
	for _,v in pairs(self.config.status) do
		if self.hasEffect(v.effect) then
			factor = factor + v.factor
			if v.type == "hypo" then
				targetexposure = targetexposure + v.value
			elseif v.type == "hyper" then
				targetexposure = targetexposure - v.value
			end
		end
	end
	
	-- Apply equip stats
	for _,v in pairs(self.config.equip) do
		local it = player.equippedItem(v.slot)
		if it ~= nil then
			if it.name == v.type then
				local pass = true
				if v.needStatus ~= false then
					pass = self.hasEffect(v.needStatus)
				end
				
				if pass then
					-- Hypothermia protection
					if v.protection.type == "hypo" then
						targetexposure = targetexposure + v.protection.value
						if exposure > targetexposure then
							factor = factor - v.protection.factor
						else
							factor = factor + v.protection.factor
						end
					-- Hyperthermia protection
					elseif v.protection.type == "hyper" then
						targetexposure = targetexposure - v.protection.value
						if exposure < targetexposure then
							factor = factor - v.protection.factor
						else
							factor = factor + v.protection.factor
						end
					-- Hybrid protection
					elseif v.protection.type == "hybrid" then
						if targetexposure >= 125 then
							targetexposure = targetexposure - v.protection.value
							factor = factor - v.protection.factor
						elseif targetexposure <= 75 then
							targetexposure = targetexposure + v.protection.value
							factor = factor - v.protection.factor
						end
					end
				end
			end
		end
	end
	
	-- Apply liquid stats
	local pos = entity.position()
	pos[2] = pos[2] - 1
	
	local liq = world.liquidAt(pos)
	if liq ~= nil then
		isLiquid = true -- we're in liquid regardless of possible modifier
		for _,v in pairs(self.config.liquid) do
			if liq[1] == v.type then
				targetexposure = targetexposure + v.mod
				factor = factor + v.factor
				break
			end
		end
	end
	
	-- apply hybrid source when we're not in liquid ( vents doesn't work well in liquid >v< )
	if not isLiquid then
		local hybridchange = 0
		
		for _,v in pairs(self.config.hybridSources) do
			local objects = world.objectQuery(entity.position(), v.range, { order = "nearest", name = v.name } )
			for _,k in pairs(objects) do
				local isVisible = Util:EHTdetect(entity.position(), world.entityPosition(k))
				liq = world.liquidAt( world.entityPosition(k) )
				if liq == nil and isVisible then -- if the vent is in liquid it won't work, also we have to see it
					targetexposure = 115
					isHybrid = true
					factor = factor + 1 -- faster rate for hybrid sources
					break -- we have a vent outside of liquid
				end
			end
		end
	end
	
	-- no hybrid detected: apply heatsource offset instead
	if not isHybrid and not isLiquid then
		local heatchange = 0
		for _,v in pairs(self.config.heatSources) do
			local objects = world.objectQuery(entity.position(), self.config.heatSourcesRange, { order = "nearest", name = v.name } )
			for _,k in pairs(objects) do
				liq = world.liquidAt( world.entityPosition(k) )
				local isVisible = Util:EHTdetect(entity.position(), world.entityPosition(k))
				if liq == nil and isVisible then -- if the source is in liquid it won't work
					-- check if a certain animation state is needed
					local vstated = true
					if v.state.needed then
						if not world.getObjectParameter(k,"provideWarmth") then
							vstated = false
						end
					end
					
					if vstated then
						
						local range = world.magnitude(world.entityPosition(k), entity.position())/5
						local tmp = v.exposure_mod
						
						
						if range ~= 0 then
							tmp = tmp / range
						end
						
						if tmp > v.exposure_mod then
							tmp = v.exposure_mod
						end
						
						-- more heat sources = quicker warmth (will be limited later to max value) and more exposure increase
						heatchange = heatchange + tmp
						factor = factor + 1 -- faster rate for heat sources
					
					end
					-- we need to run through all heat sources to get the current modified warmth in range
				end
			end
		end
		
		-- apply heatchange
		targetexposure = targetexposure + heatchange
	end
	
	-- Get current protection based on armor rating
	local armor = 0
	for _,v in pairs(status.getPersistentEffects("armor")) do
		if v.stat == "protection" then
			armor = armor + v.amount
		end
	end
	
	-- apply dynamic armor rating
	factor = factor * ( 1 - armor * 0.0025 )
	if factor < 0.001 then
		factor = 0.001
	end
	
	-- Targetexposure limit
	targetexposure = Util:limiter(targetexposure, 0, 200)
	
	-- calculate modifier
	local modifier = self:modHelper(exposure, targetexposure, factor)
	
	-- When heat protection then hyperthermia increases slower
	if(status.stat("biomeheatImmunity") == 1.0) and modifier > 0.0 and exposure >= 100 then
		modifier = modifier * 0.5
	end
	
	-- When cold protection hypothermia increases slower
	if(status.stat("biomecoldImmunity") == 1.0) and modifier < 0.0 and exposure <= 100 then
		modifier = modifier * 0.5
	end
	
	-- Modify exposure
	status.modifyResource("exposure", modifier)
	
	-- Return the current modifier
	return modifier
end

-- #########################################################################################################
-- Messagehelper
-- #########################################################################################################
function EHT:msgHelper(exposure, value, dir, lvlFlag, radioMsg, effect1, effect2, _type)
	
	local v,_ = math.modf(exposure)
	
	if _type == "hypo" then
		if v <= value then
			if dir == "-" and not self.lvlFlag[lvlFlag] then
				if radioMsg ~= nil then
					player.radioMessage(radioMsg)
				end
				self:switchEffects(effect2, effect1)
				self.lvlFlag[lvlFlag] = true
				return true
			end
		elseif v > value then
			if dir == "+" and self.lvlFlag[lvlFlag] then
				self:switchEffects(effect1, effect2)
				self.lvlFlag[lvlFlag] = false
				return true
			end
		end
	elseif _type == "hyper" then
		if v >= value then
			if dir == "+" and not self.lvlFlag[lvlFlag] then
				if radioMsg ~= nil then
					player.radioMessage(radioMsg)
				end
				self:switchEffects(effect2, effect1)
				self.lvlFlag[lvlFlag] = true
				return true
			end
		elseif v < value then
			if dir == "-" and self.lvlFlag[lvlFlag] then
				self:switchEffects(effect1, effect2)
				self.lvlFlag[lvlFlag] = false
				return true
			end
		end
	end
	return false
end

-- #########################################################################################################
-- Sail talk to me! (and set the effects)
-- #########################################################################################################
function EHT:ShowMessage(modifier)
	
	-- get the current exposure
	local exposure = status.resource("exposure")
	
	-- get direction
	local d = self:direction(modifier)
	
	if self:msgHelper(exposure, 25, d, "hypo3", "exposure_25", self.config.exposure.effects.hypo3, self.config.exposure.effects.hypo2, "hypo") then
		return -- skip unnecessary checks
	elseif self:msgHelper(exposure, 50, d, "hypo2", "exposure_50", self.config.exposure.effects.hypo2, self.config.exposure.effects.hypo1, "hypo") then
		return -- skip unnecessary checks
	elseif self:msgHelper(exposure, 75, d, "hypo1", "exposure_75", self.config.exposure.effects.hypo1, self.config.exposure.effects.hypo0, "hypo") then
		return -- skip unnecessary checks
	elseif self:msgHelper(exposure, 100, d, "switch", nil, self.config.exposure.effects.hypo0, self.config.exposure.effects.hyper0, "hypo") then
		return -- skip unnecessary checks
	elseif self:msgHelper(exposure, 125, d, "hyper1", "exposure_125", self.config.exposure.effects.hyper1, self.config.exposure.effects.hyper0, "hyper") then
		return -- skip unnecessary checks
	elseif self:msgHelper(exposure, 150, d, "hyper2", "exposure_150", self.config.exposure.effects.hyper2, self.config.exposure.effects.hyper1, "hyper") then
		return -- skip unnecessary checks
	elseif self:msgHelper(exposure, 175, d, "hyper3", "exposure_175", self.config.exposure.effects.hyper3, self.config.exposure.effects.hyper2, "hyper") then
		return -- skip unnecessary checks
	end
	
	-- return anyways >v<
	return
end
-- #########################################################################################################
-- #########################################################################################################
-- #########################################################################################################
